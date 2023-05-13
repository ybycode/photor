#[macro_use]
extern crate log;

use clap::{Parser, Subcommand};
use diesel::sqlite::SqliteConnection;
use std::fs::File;
use std::io::{Seek, SeekFrom};
use std::path::PathBuf;

pub mod checksum;
pub mod db;
pub mod files;
pub mod models;
pub mod photoexif;
pub mod schema;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Sets a custom config file
    #[arg(short, long, value_name = "FILE")]
    config: Option<PathBuf>,

    /// Sets the target repository (defaults to the current directory)
    #[arg(short, long, value_name = "DIRECTORY")]
    repo: Option<PathBuf>,

    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Initializes a new repository
    Init {
        /// the directory where to create the repository (defaults to the current directory)
        #[arg(short, long)]
        directory: Option<PathBuf>,
    },

    /// Import photos from a directory into the repository
    Import {
        /// the directory to (deep) scan for photos
        #[arg(short, long)]
        directory: PathBuf,
    },
}

fn main() {
    env_logger::init();

    let cli = Cli::parse();

    // You can check the value provided by positional arguments, or option arguments
    if let Some(config_path) = cli.config.as_deref() {
        println!("Value for config: {}", config_path.display());
    }

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.command {
        Some(Commands::Init {
            directory: opt_directory,
        }) => {
            init(opt_directory);
        }

        Some(Commands::Import { directory }) => {
            import(directory);
        }

        None => {}
    }
}

fn init(opt_directory: &Option<PathBuf>) {
    let current_dir = std::env::current_dir().expect("yo");
    let dest = opt_directory.as_ref().unwrap_or_else(|| &current_dir);
    println!("TODO: Initialization of a new repo in {:?}", dest);
}

fn import(directory: &PathBuf) -> Result<String, String> {
    if directory.as_os_str().is_empty() {
        return Err("Not ok, bad".to_string());
    }

    let connection = &mut db::establish_connection();
    for file in files::find_photo_files(directory) {
        let photo_path = file.path().to_str().unwrap();

        let mut file = File::open(photo_path).map_err(|_| "Failed to open the file")?;
        let hash = checksum::hash_file_first_bytes(&mut file, 1024 * 512)?;
        match db::photo_lookup_by_hash(connection, hash)? {
            Some(_photo) => {
                println!("{}     already in DB, skipping...", photo_path);
                // TODO: check the file exists in the repo where it's supposed to be
            }
            None => {
                println!("{} +++ not yet in DB, inserting...", photo_path);
                // TODO:
                // - [ ] read the metadata from the photo
                // - [ ] create a directory for the date if it doesn't exist yet,
                // - [ ] copy the file from the imported folder to the repository,
                // - [ ] in case of success, write to the DB
                // - [ ] run a background task to calculate and insert the sha256 in the DB.
                file.seek(SeekFrom::Start(0)).expect("");

                let _r = import_photo(connection, &mut file, photo_path, hash);
            }
        }
    }

    Ok("yoo".to_string())
}

fn import_photo(
    connection: &mut SqliteConnection,
    file: &mut File,
    file_path: &str,
    file_partial_hash: u128,
) -> Result<String, String> {
    // The exif info we're interested in is extracted and returned in this struct:
    let pexif = photoexif::read(file)?;
    // the date YYYY-MM-DD when the photo was taken is parsed:
    let date =
        files::parse_date(pexif.date_time_original).ok_or("No valid date found".to_string())?;

    // create a folder named after this date if it doesn't exist already:
    files::create_date_folder(&date).map_err(|error| {
        format!(
            "Could not create a directory for the date {}: {}",
            date,
            error.to_string()
        )
    })?;

    // copy the file to this folder:
    files::copy_file_to_date_folder(file_path, &date)
        .map_err(|error| format!("Failed to copy the file {}: {}", file_path, error))?;

    // insertion in the database!
    let _p = db::insert_photo(connection, file_path, file_partial_hash);
    Ok(file_path.to_string())
}
