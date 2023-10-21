#[macro_use]
extern crate log;

use crate::models::NewPhoto;
use clap::{Args, Parser, Subcommand};
use env_logger::Env;
use log::{error, info};
use sqlx::sqlite::SqlitePool;
use std::fs::File;
use std::path::{Path, PathBuf};

pub mod checksum;
pub mod database;
pub mod files;
pub mod models;
pub mod photoexif;

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

#[derive(Args)]
struct ImportArgs {
    /// where the files to import are
    directory: PathBuf,
}

#[derive(Subcommand)]
enum Commands {
    /// Initializes a new repository
    Init {
        /// the directory where to create the repository (defaults to the current directory)
        #[arg(short, long)]
        directory: Option<PathBuf>,
    },
    List,

    /// Import photos from a directory into the repository
    Import(ImportArgs),

    /// Migrate the database
    Migrate,
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    // if no environment variables are set to define th elog level, "info" is the value by default.
    env_logger::Builder::from_env(Env::default().default_filter_or("info")).init();

    let cli = Cli::parse();

    // You can check for the existence of subcommands, and if found use their
    // matches just as you would the top level cmd
    match &cli.command {
        Some(Commands::Init { directory }) => init(directory),
        Some(Commands::Migrate) => return database::migrate().await,
        Some(Commands::List) => return list_photos().await,
        Some(Commands::Import(import_args)) => {
            return import(&import_args.directory).await;
        }

        None => (),
    };

    Ok(())
}

fn init(opt_directory: &Option<PathBuf>) {
    let current_dir = std::env::current_dir().expect("Failed to get the current directory");
    let dest = opt_directory.as_ref().unwrap_or_else(|| &current_dir);
    println!("TODO: Initialization of a new repo in {:?}", dest);
}

async fn list_photos() -> anyhow::Result<()> {
    let pool = database::pool().await?;
    let res = database::list_photos(&pool).await?;

    for p in res {
        println!("{}/{}", p.directory, p.filename);
    }

    Ok(())
}

async fn import(directory: &Path) -> anyhow::Result<()> {
    let pool = database::pool().await?;
    for file in files::find_photo_files(directory) {
        let photo_path = file.path();

        let mut file = match File::open(photo_path).map_err(|_| "Failed to open the file") {
            Ok(file) => file,

            Err(err) => {
                error!("Failed to open the file {}: {}", photo_path.display(), err);
                continue;
            }
        };

        let partial_hash = match checksum::hash_file_first_bytes(&mut file, 1024 * 512) {
            Ok(partial_hash) => partial_hash,

            Err(err) => {
                error!(
                    "Failed to calculate the partial hash of the file {}: {}",
                    photo_path.display(),
                    err
                );
                continue;
            }
        };

        match database::photo_lookup_by_partial_hash(&pool, &partial_hash).await {
            Some(photo_in_db) => {
                info!(
                    "{}  already in DB (in {}/{}), skipping...",
                    photo_path.display(),
                    photo_in_db.directory,
                    photo_in_db.filename
                );
                continue;
            }

            None => {}
        }

        info!("{} not yet in DB. Inserting...", photo_path.display());
        if let Err(err) = import_photo(&pool, photo_path, partial_hash).await {
            error!("Failed to import {}: {}", photo_path.display(), err);
        }
    }

    Ok(())
}

async fn import_photo(
    pool: &SqlitePool,
    file_path: &Path,
    file_partial_hash: String,
) -> Result<String, String> {
    // The exif info we're interested in is extracted and returned in this struct:
    let pexif = photoexif::read(file_path)?;

    // the date "YYYY-MM-DD hh:mm:ss" when the photo was taken is parsed:
    // if no date is found, 1970-01-01 is used.
    // TODO: better deal with this case:
    // - add an attribute like 'has_date' in the DB?
    // - prefix all image files with their partial hash to minimize names clashes in the 1970-01-01
    // folder (and others).
    let long_date = photoexif::find_usable_date(pexif.date_time_original, pexif.create_date)
        .unwrap_or_else(|| {
            warn!(
                "No usable date found in exif data of {}",
                file_path.display()
            );
            "1970-01-01".into()
        });

    let short_date = long_date[..10].to_string();

    // read the file size in bytes:
    let file_size_bytes =
        files::file_size_bytes(file_path).map_err(|err| format!("Can't read filesize: {}", err))?;

    // create a folder named after this date if it doesn't exist already:
    files::create_date_folder(&short_date).map_err(|error| {
        format!(
            "Could not create a directory for the date {}: {}",
            short_date,
            error.to_string()
        )
    })?;

    // copy the file to this folder:
    files::copy_file_to_date_folder(file_path, &short_date)
        .map_err(|error| format!("Failed to copy the file {}: {}", file_path.display(), error))?;

    let filename = file_path
        .file_name()
        .unwrap()
        .to_string_lossy()
        .into_owned();

    let new_photo = NewPhoto {
        create_date: long_date,
        filename,
        directory: short_date,
        partial_hash: file_partial_hash,
        file_size_bytes: file_size_bytes as i64,
        image_height: pexif.image_height.map(|value| value as i32),
        image_width: pexif.image_width.map(|value| value as i32),
        mime_type: pexif.mime_type,
        iso: pexif.iso.map(|value| value as i32),
        aperture: pexif.aperture,
        shutter_speed: pexif.shutter_speed,
        focal_length: pexif.focal_length,
        make: pexif.make,
        model: pexif.model,
        lens_info: pexif.lens_info,
        lens_make: pexif.lens_make,
        lens_model: pexif.lens_model,
    };

    // insertion in the database!
    database::insert_photo(pool, new_photo)
        .await
        .map_err(|error| format!("Failed to insert photo into the database: {}", error))?;
    Ok(file_path.display().to_string())
}
