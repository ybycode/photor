// @generated automatically by Diesel CLI.

diesel::table! {
    photos (id) {
        id -> Integer,
        partial_hash -> Text,
        filename -> Text,
        directory -> Text,
        full_sha256_hash -> Text,
        file_size_bytes -> Integer,
        image_height -> Nullable<Integer>,
        image_width -> Nullable<Integer>,
        mime_type -> Nullable<Text>,
        iso -> Nullable<Integer>,
        aperture -> Nullable<Float>,
        shutter_speed -> Nullable<Text>,
        focal_length -> Nullable<Text>,
        make -> Nullable<Text>,
        model -> Nullable<Text>,
        lens_info -> Nullable<Text>,
        lens_make -> Nullable<Text>,
        lens_model -> Nullable<Text>,
        create_date -> Text,
        create_day -> Nullable<Text>,
    }
}
