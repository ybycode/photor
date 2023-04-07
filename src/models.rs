use crate::schema::photos;
use diesel::prelude::*;

#[derive(Debug, Queryable)]
pub struct Photo {
    pub id: i32,
    pub path: String,
}

#[derive(Insertable)]
#[diesel(table_name = photos)]
pub struct NewPhoto<'a> {
    pub path: &'a str,
}
