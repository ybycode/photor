use exif::Exif;
use std::fs::File;

pub fn read(photo_path: &str) -> Result<Exif, String> {
    open_photo_file(photo_path).and_then(read_file_exif)
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
