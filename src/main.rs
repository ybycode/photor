#[macro_use]
extern crate log;

use clap::{Parser, Subcommand};
use diesel::sqlite::SqliteConnection;
use env_logger::Env;
use log::{error, info};
use std::fs::File;
use std::path::{Path, PathBuf};

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
    // if no environment variables are set to define th elog level, "info" is the value by default.
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();

    let cli = Cli::parse();

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

fn import(directory: &PathBuf) {
    let connection = &mut db::establish_connection();
    for file in files::find_photo_files(directory) {
        let photo_path = file.path();

        let mut file = match File::open(photo_path).map_err(|_| "Failed to open the file") {
            Ok(file) => file,

            Err(err) => {
                error!("Failed to open the file {}: {}", photo_path.display(), err);
                continue;
            }
        };

        let hash = match checksum::hash_file_first_bytes(&mut file, 1024 * 512) {
            Ok(hash) => hash,

            Err(err) => {
                error!(
                    "Failed to calculate the partial hash of the file {}: {}",
                    photo_path.display(),
                    err
                );
                continue;
            }
        };

        // TODO: see how to avoid the clone()
        match db::photo_lookup_by_hash(connection, hash.clone())
            .expect("Failed to query the database")
        {
            Some(_photo) => {
                info!("{}  already in DB, skipping...", photo_path.display());
                continue;
            }

            None => {}
        }

        info!("{} not yet in DB. Inserting...", photo_path.display());
        import_photo(connection, photo_path, hash).unwrap();
    }
}

fn import_photo(
    connection: &mut SqliteConnection,
    file_path: &Path,
    file_partial_hash: String,
) -> Result<String, String> {
    // The exif info we're interested in is extracted and returned in this struct:
    let pexif = photoexif::read(file_path)?;
    // the date YYYY-MM-DD when the photo was taken is parsed:
    let date =
        files::parse_date(pexif.DateTimeOriginal).ok_or("No valid date found".to_string())?;

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
        .map_err(|error| format!("Failed to copy the file {}: {}", file_path.display(), error))?;

    let filename = file_path
        .file_name()
        .unwrap()
        .to_string_lossy()
        .into_owned();

    // insertion in the database!
    db::insert_photo(connection, file_partial_hash, filename, date).unwrap();
    Ok(file_path.display().to_string())
}
