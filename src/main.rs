#[macro_use]
extern crate log;

use clap::{Parser, Subcommand};
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
    println!("Initialization of a new repo in {:?}", dest);
}

fn import(directory: &PathBuf) {
    if directory.as_os_str().is_empty() {
        println!("Not ok, bad");
        return;
    }

    let connection = &mut db::establish_connection();
    for file in files::find_photo_files(directory) {
        let photo_path = file.path().to_str().unwrap();
        match checksum::hash(photo_path) {
            Ok(hash) => {
                print!(".");

                match db::photo_lookup_by_hash(connection, hash) {
                    Ok(_photo) => {
                        println!("{}     already in DB, skipping...", photo_path);
                    }
                    Err(diesel::NotFound) => {
                        println!("{} +++ not yet in DB, inserting...", photo_path);
                        let _p = db::insert_photo(connection, photo_path, hash).unwrap();
                    }
                    Err(e) => {
                        println!("Error querying photo: {:?}", e);
                    }
                }
            }
            Err(err) => {
                error!("Error with file at {}: {}", photo_path, err)
            }
        }
    }
}

// fn main_() {
//     let p1 = db::insert_photo(connection, "hello").unwrap();
//     let p2 = db::insert_photo(connection, "hello again").unwrap();
//
//     println!("{:?}", p1);
//     println!("{:?}", p2);
//
//     let results = db::load_photos(connection).expect("Error loading posts");
//
//     println!("{:?}", results);
// }
