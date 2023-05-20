use serde::Deserialize;
use std::path::Path;
use std::process::Command;

#[derive(Debug, Deserialize)]
pub struct PExif {
    #[serde(rename = "CreateDate")]
    pub create_date: String,

    // ------------------------------
    // file:
    #[serde(rename = "ImageHeight")]
    pub image_height: Option<u32>,

    #[serde(rename = "ImageWidth")]
    pub image_width: Option<u32>,

    #[serde(rename = "MIMEType")]
    pub mime_type: Option<String>,

    // ------------------------------
    // Shot:
    #[serde(rename = "ISO")]
    pub iso: Option<u32>,

    #[serde(rename = "ApertureValue")]
    pub aperture: Option<f32>,

    #[serde(rename = "ShutterSpeedValue")]
    pub shutter_speed: Option<String>,

    #[serde(rename = "FocalLength")]
    pub focal_length: Option<String>,

    // ------------------------------
    // Camera:
    #[serde(rename = "Make")]
    pub make: Option<String>,

    #[serde(rename = "Model")]
    pub model: Option<String>,

    // ------------------------------
    // Lens:
    #[serde(rename = "LensInfo")]
    pub lens_info: Option<String>,

    #[serde(rename = "LensMake")]
    pub lens_make: Option<String>,

    #[serde(rename = "LensModel")]
    pub lens_model: Option<String>,
}

pub fn read(photo_path: &Path) -> Result<PExif, String> {
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
