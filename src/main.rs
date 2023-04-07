pub mod db;
pub mod models;
pub mod schema;

fn main() {
    let connection = &mut db::establish_connection();
    let p1 = db::insert_photo(connection, "hello").unwrap();
    let p2 = db::insert_photo(connection, "hello again").unwrap();

    println!("{:?}", p1);
    println!("{:?}", p2);

    let results = db::load_photos(connection).expect("Error loading posts");

    println!("{:?}", results);
}
