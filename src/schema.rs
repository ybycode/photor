// @generated automatically by Diesel CLI.

diesel::table! {
    photos (id) {
        id -> Integer,
        partial_hash -> Text,
        filename -> Text,
        directory -> Text,
        full_sha256_hash -> Text,
    }
}
