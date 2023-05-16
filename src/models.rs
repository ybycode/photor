use crate::schema::photos;
use diesel::prelude::*;

#[derive(Debug, Queryable)]
pub struct Photo {
    pub id: i32,
    pub filename: String,
    pub directory: String,
    pub full_sha256_hash: String,
    pub partial_hash: String,
}

#[derive(Insertable)]
#[diesel(table_name = photos)]
pub struct NewPhoto {
    pub partial_hash: String,
    pub filename: String,
    pub directory: String,
}
