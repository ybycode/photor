use serde::Deserialize;
use std::process::Command;

#[derive(Debug, Deserialize)]
pub struct PExif {
    pub DateTimeOriginal: String,
}

pub fn read(photo_path: &str) -> Result<PExif, String> {
    let output = Command::new("exiftool")
        .arg("-json")
        .arg(photo_path)
        .output()
        .map_err(|_err| format!("failed to execute process"))?;

    parse_json(output.stdout)
        .map_err(|err| format!("Failed to parse the JSON to a PExif: {:?}", err))
}

fn parse_json(data: Vec<u8>) -> Result<PExif, String> {
    // exiftool returns an array containing one object (the EXIF), hence the Vec here.
    let mut datas: Vec<PExif> = serde_json::from_slice(&data).map_err(|err| err.to_string())?;

    // pop is used to remove the value from the Vec, so that the PExif *value* can be returned,
    // without problems of lifetimes.
    datas.pop().ok_or("No EXIF data found?".to_string())
}
