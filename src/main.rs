extern crate log;

use clap::{Args, Parser, Subcommand};
use diesel::sqlite::SqliteConnection;
use env_logger::Env;
use log::{error, info};
use photor::fuse_photo_fs::PhotosFS;
use photor::models::NewPhoto;
use photor::{checksum, db, files, fuse, photoexif};
use std::fs::File;
use std::path::{Path, PathBuf};

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

#[derive(Args)]
struct MountArgs {
    /// where FUSE filesystem is mounted
    to: PathBuf,
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
    Import(ImportArgs),

    /// Run database migrations
    Migrate,

    /// Mount the FUSE filesystem
    Mount(MountArgs),
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

        Some(Commands::Import(import_args)) => {
            import(&import_args.directory);
        }

        Some(Commands::Migrate {}) => {
            db::run_migrations();
        }

        Some(Commands::Mount(mount_args)) => {
            mount_fuse(&mount_args.to);
        }

        None => {}
    }
}

fn init(opt_directory: &Option<PathBuf>) {
    let current_dir = std::env::current_dir().expect("Failed to get the current directory");
    let dest = opt_directory.as_ref().unwrap_or_else(|| &current_dir);
    println!("TODO: Initialization of a new repo in {:?}", dest);
}

fn import(directory: &Path) {
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

        // TODO: see how to avoid the clone()
        match db::photo_lookup_by_partial_hash(connection, partial_hash.clone())
            .expect("Failed to query the database")
        {
            Some(_photo) => {
                info!("{}  already in DB, skipping...", photo_path.display());
                continue;
            }

            None => {}
        }

        info!("{} not yet in DB. Inserting...", photo_path.display());
        if let Err(err) = import_photo(connection, photo_path, partial_hash) {
            error!("Failed to import {}: {}", photo_path.display(), err);
        }
    }
}

fn import_photo(
    connection: &mut SqliteConnection,
    file_path: &Path,
    file_partial_hash: String,
) -> Result<String, String> {
    // The exif info we're interested in is extracted and returned in this struct:
    let pexif = photoexif::read(file_path)?;

    // the date "YYYY-MM-DD hh:mm:ss" when the photo was taken is parsed:
    let long_date = photoexif::find_usable_date(pexif.date_time_original, pexif.create_date)
        .ok_or("No usable date found".to_string())?;

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
    db::insert_photo(connection, &new_photo)
        .map_err(|error| format!("Failed to insert photo into the database: {}", error))?;
    Ok(file_path.display().to_string())
}

fn mount_fuse(to: &PathBuf) {
    let connection = &mut db::establish_connection();
    let mut photos_fs = PhotosFS::new();
    for photo in db::just_n_photos(connection, 100000).unwrap() {
        photos_fs.add_file(&photo.to_pathbuf()).unwrap();
    }

    fuse::mount(to, photos_fs)
}
