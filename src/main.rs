#[macro_use]
extern crate log;

use clap::{Parser, Subcommand};
use std::path::PathBuf;

pub mod db;
pub mod files;
pub mod models;
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

    /// Turn debugging information on
    #[arg(short, long, action = clap::ArgAction::Count)]
    debug: u8,

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
        directory: String,
    },
}

fn main() {
    env_logger::init();

    let cli = Cli::parse();

    // You can check the value provided by positional arguments, or option arguments
    if let Some(config_path) = cli.config.as_deref() {
        println!("Value for config: {}", config_path.display());
    }

    // You can see how many times a particular flag or argument occurred
    // Note, only flags can have multiple occurrences
    match cli.debug {
        0 => println!("Debug mode is off"),
        1 => println!("Debug mode is kind of on"),
        2 => println!("Debug mode is on"),
        _ => println!("Don't be crazy"),
    }

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.command {
        Some(Commands::Init { directory }) => match directory {
            Some(_dir) => {
                println!("dir!!!");
            }
            None => {}
        },

        Some(Commands::Import { directory }) => {
            if String::len(&directory) > 0 {
                for file in files::find_photo_files(&directory) {
                    println!("FILEEE: {:?}", file);
                }
            } else {
                println!("Not ok, bad");
            }
        }

        None => {}
    }

    // Continued program logic goes here...
}

// fn main_() {
//     let connection = &mut db::establish_connection();
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
