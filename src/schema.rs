// @generated automatically by Diesel CLI.

diesel::table! {
    photos (id) {
        id -> Integer,
        path -> Text,
        full_hash -> Binary,
        partial_hash -> Text,
    }
}
