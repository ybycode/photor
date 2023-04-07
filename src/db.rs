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
) -> Result<Photo, diesel::result::Error> {
    let new_photo = NewPhoto { path: photo_path };

    diesel::insert_into(photos)
        .values(&new_photo)
        .get_result(conn)
}
