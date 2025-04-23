use lazy_static::lazy_static;
use regex::Regex;
use serde::de::{self, Deserializer};
use serde::Deserialize;
use serde_json::Value as JsonValue;
use std::path::Path;
use std::process::Command;

fn deserialize_shutter_speed<'de, D>(deserializer: D) -> Result<Option<String>, D::Error>
where
    D: Deserializer<'de>,
{
    let value = serde_json::Value::deserialize(deserializer)?;
    match value {
        JsonValue::String(s) => Ok(Some(s)),
        JsonValue::Number(n) => Ok(Some(n.to_string())),
        JsonValue::Null => Ok(None),

        _ => Err(de::Error::custom("Expected a string or a number")),
    }
}

#[derive(Debug, Deserialize)]
pub struct PExif {
    // 2 dates are fetched from the metadata: the OriginaleDateTime, and the CreateDate.
    // Both are defined as Option<String> here, as some files come with one or another.
    // Eventually only one makes its way to the database, OriginaleDateTime in priority.
    #[serde(rename = "DateTimeOriginal")]
    pub date_time_original: Option<String>,

    #[serde(rename = "CreateDate")]
    pub create_date: Option<String>,
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

    #[serde(rename = "FocalLength")]
    pub focal_length: Option<String>,

    // Most of the time and for sub second shutter speeds, the value comes as a String like
    // `"1/100"`. Sometimes though, they come as a float, like `0.3`
    // Also `default` is added so that in case of a missing "ShutterSpeedValue" key on the JSON,
    // None is returned. It is needed here since deserialize_shutter_speed doesn't manage this
    // case.
    #[serde(
        rename = "ShutterSpeedValue",
        default,
        deserialize_with = "deserialize_shutter_speed"
    )]
    pub shutter_speed: Option<String>,

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
        .args(["-json", "-d", "%Y-%m-%d %H:%M:%S"])
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

fn is_some_good_date(opt: &Option<String>) -> bool {
    lazy_static! {
        static ref RE: Regex = Regex::new(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$").unwrap();
    }

    // TODO: as_ref()? meeh
    opt.is_some() && RE.is_match(opt.as_ref().unwrap().as_str())
}

/// we look for a date we can use (defined and with the right format). We start by checking the
/// OriginaleDateTime, and then CreateDate.
pub fn find_usable_date(
    date_time_original: Option<String>,
    create_date: Option<String>,
) -> Option<String> {
    if is_some_good_date(&date_time_original) {
        return date_time_original;
    }

    if is_some_good_date(&create_date) {
        return create_date;
    }

    None
}
