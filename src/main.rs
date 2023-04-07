use diesel::prelude::*;

pub mod db;
pub mod models;
pub mod schema;

fn main() {
    use self::schema::photos::dsl::*;

    let connection = &mut db::establish_connection();

    let results = photos
        .load::<models::Photos>(connection)
        .expect("Error loading posts");

    println!("{:?}", results);
}

fn insert() -> Result<i32, String> {
    Ok(0)
}
