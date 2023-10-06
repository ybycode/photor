use crate::models::{NewPhoto, Photo};
use sqlx::sqlite::SqlitePool;

pub async fn pool(db_filename: &str) -> Result<SqlitePool, sqlx::Error> {
    SqlitePool::connect(db_filename).await
}

pub async fn insert_photo(pool: &SqlitePool, photo: NewPhoto) -> Result<i64, String> {
    let mut conn = pool.acquire().await.unwrap();

    let id = sqlx::query!(
        r#"
        insert into photos (
            create_date,
            filename,
            directory,
            partial_hash,
            file_size_bytes,
            image_height,
            image_width,
            mime_type,
            iso,
            aperture,
            shutter_speed,
            focal_length,
            make,
            model,
            lens_info,
            lens_make,
            lens_model
        )
        values (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17)
        "#,
        photo.create_date,
        photo.filename,
        photo.directory,
        photo.partial_hash,
        photo.file_size_bytes,
        photo.image_height,
        photo.image_width,
        photo.mime_type,
        photo.iso,
        photo.aperture,
        photo.shutter_speed,
        photo.focal_length,
        photo.make,
        photo.model,
        photo.lens_info,
        photo.lens_make,
        photo.lens_model
    )
    .execute(&mut *conn)
    .await
    .unwrap()
    .last_insert_rowid();

    Ok(id)
}

pub async fn photo_lookup_by_partial_hash(pool: &SqlitePool, hash: String) -> Option<Photo> {
    sqlx::query_as!(
        Photo,
        r#"
        select * from photos where partial_hash = ?1
        "#,
        hash
    )
    .fetch_optional(pool)
    .await
    .unwrap()
}

pub async fn list_photos(pool: &SqlitePool) -> anyhow::Result<Vec<Photo>> {
    let stream = sqlx::query_as::<_, Photo>(
        r#"
SELECT *
FROM photos
ORDER BY create_date, id
        "#,
    )
    .fetch_all(pool)
    .await?;

    Ok(stream)
}
