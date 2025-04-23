use crate::checksum;
use crate::database;
use crate::files;
use crate::models::NewPhoto;
use crate::photoexif;
use log::{error, info};
use sqlx::sqlite::SqlitePool;
use std::fs::File;
use std::path::Path;

const PARTIAL_HASH_NBYTES: u64 = 1024 * 512;

pub async fn run(directory: &Path) -> anyhow::Result<()> {
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

        let partial_hash = match checksum::hash_file_first_bytes(&mut file, PARTIAL_HASH_NBYTES) {
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
        partial_sha256_hash: file_partial_hash,
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
