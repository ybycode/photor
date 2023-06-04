use crate::models::{NewPhoto, Photo};
use crate::schema::photos::dsl::*;
use diesel::prelude::*;
use diesel::sqlite::SqliteConnection;
use dotenvy::dotenv;
use log::info;
use std::env;

use diesel_migrations::{embed_migrations, EmbeddedMigrations, MigrationHarness};
pub const MIGRATIONS: EmbeddedMigrations = embed_migrations!("./migrations");

pub fn run_migrations() {
    let mut conn = establish_connection();

    let migrations = conn.run_pending_migrations(MIGRATIONS).unwrap();
    info!("Ran {} migration(s)", migrations.len());
    ()
}

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
    photo: &NewPhoto,
) -> Result<Photo, diesel::result::Error> {
    diesel::insert_into(photos).values(photo).get_result(conn)
}

pub fn photo_lookup_by_partial_hash(
    conn: &mut SqliteConnection,
    hash: String,
) -> Result<Option<Photo>, String> {
    use crate::schema::photos;

    match photos::table
        .filter(photos::partial_hash.eq(hash))
        .first(conn)
    {
        Ok(photo) => Ok(Some(photo)),
        Err(diesel::NotFound) => Ok(None),
        Err(error) => Err(error.to_string()),
    }
}

pub fn just_10_photos(conn: &mut SqliteConnection) -> Result<Vec<Photo>, String> {
    use crate::schema::photos;

    match photos::table.limit(10).load(conn) {
        Ok(any) => Ok(any),
        Err(error) => Err(error.to_string()),
    }
}
