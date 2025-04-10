#[derive(sqlx::FromRow, Debug)]
pub struct Photo {
    pub id: i64,
    pub filename: String,
    pub directory: String,
    pub partial_sha256_hash: String,
    pub full_sha256_hash: String,
    pub file_size_bytes: i64,
    pub image_height: Option<i64>,
    pub image_width: Option<i64>,
    pub mime_type: Option<String>,
    pub iso: Option<i64>,
    pub aperture: Option<f64>,
    pub shutter_speed: Option<String>,
    pub focal_length: Option<String>,
    pub make: Option<String>,
    pub model: Option<String>,
    pub lens_info: Option<String>,
    pub lens_make: Option<String>,
    pub lens_model: Option<String>,
    pub create_date: String,
    pub create_day: Option<String>,
    pub inserted_at: String,
}

pub struct NewPhoto {
    // ------------------------------
    // file:
    pub partial_sha256_hash: String,
    pub filename: String,
    pub directory: String,
    pub file_size_bytes: i64,
    pub image_height: Option<i32>,
    pub image_width: Option<i32>,
    pub mime_type: Option<String>,
    // // ------------------------------
    // // Shot:
    pub iso: Option<i32>,
    pub aperture: Option<f32>,
    pub shutter_speed: Option<String>,
    pub focal_length: Option<String>,

    // // ------------------------------
    // // Camera:
    pub make: Option<String>,
    pub model: Option<String>,

    // // ------------------------------
    // // Lens:
    pub lens_info: Option<String>,
    pub lens_make: Option<String>,
    pub lens_model: Option<String>,

    pub create_date: String,
}
