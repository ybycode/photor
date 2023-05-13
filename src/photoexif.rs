use exif::{Exif, Tag};
use std::fs::File;

#[derive(Debug)]
pub struct PExif {
    pub date_time_original: String,
}

pub fn read(photo_path: &str) -> Result<PExif, String> {
    open_photo_file(photo_path)
        .and_then(read_file_exif)
        .and_then(new_pexif)
}

fn open_photo_file(file_path: &str) -> Result<File, String> {
    std::fs::File::open(file_path)
        .map_err(|err| format!("failed to open the file: {}", err.to_string()))
}

fn read_file_exif(file: File) -> Result<Exif, String> {
    let mut bufreader = std::io::BufReader::new(&file);
    let exifreader = exif::Reader::new();
    exifreader
        .read_from_container(&mut bufreader)
        .map_err(|err| format!("failed to read the EXIF data: {}", err.to_string()))
}

extern crate exif;

fn read_datetime(exif: Exif) -> Result<String, String> {
    for field in exif.fields() {
        if let Tag::DateTime = field.tag {
            return Ok(field.value.display_as(field.tag).to_string());
        }
    }
    Err("DateTime tag not found".to_string())
}

fn new_pexif(exif: Exif) -> Result<PExif, String> {
    read_datetime(exif).map(|str_date| PExif {
        date_time_original: str_date,
    })
}

// helper function
pub fn print_exif_data(exif_data: Exif) -> Exif {
    for f in exif_data.fields() {
        println!(
            "{} {} {}",
            f.tag,
            f.ifd_num,
            f.display_value().with_unit(&exif_data)
        );
    }
    exif_data
}
