use crate::models::{NewPhoto, Photo};
use crate::schema::photos::dsl::*;
use diesel::prelude::*;
use diesel::sqlite::SqliteConnection;
use dotenvy::dotenv;
use std::env;

pub fn establish_connection() -> SqliteConnection {
    dotenv().ok();

    let database_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    SqliteConnection::establish(&database_url)
        .unwrap_or_else(|_| panic!("Error connecting to {}", database_url))
}

pub fn load_photos(conn: &mut SqliteConnection) -> Result<Vec<Photo>, diesel::result::Error> {
    photos.load::<Photo>(conn)
}

pub fn insert_photo(
    conn: &mut SqliteConnection,
    photo_path: &str,
    hash: String,
) -> Result<Photo, diesel::result::Error> {
    let new_photo = NewPhoto {
        path: photo_path,
        partial_hash: hash,
    };

    diesel::insert_into(photos)
        .values(&new_photo)
        .get_result(conn)
}

pub fn photo_lookup_by_hash(
    conn: &mut SqliteConnection,
    hash: String,
) -> Result<Option<Photo>, String> {
    use crate::schema::photos;

    // let target_hash = hash.to_be_bytes().to_vec();

    match photos::table
        .filter(photos::partial_hash.eq(hash))
        .first(conn)
    {
        Ok(photo) => Ok(Some(photo)),
        Err(diesel::NotFound) => Ok(None),
        Err(error) => Err(error.to_string()),
    }
}
