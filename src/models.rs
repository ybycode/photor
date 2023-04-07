use diesel::prelude::*;

#[derive(Debug, Queryable)]
pub struct Photos {
    pub id: i32,
    pub path: String,
}
