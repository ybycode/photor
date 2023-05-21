use lazy_static::lazy_static;
use regex::Regex;
use std::collections::HashSet;
use std::fs;
use std::path::Path;
use walkdir::{DirEntry, Error as WalkDirError, WalkDir};

lazy_static! {
    static ref PHOTO_FILES_EXTENSIONS: HashSet<String> = {
        // here are defined the file extensions looked for by the WalkDir iterator:
        ["jpg", "jpeg", "mp4", "png", "raw", "raf"]
            .iter()
            .map(|ext| ext.to_lowercase())
            .collect()
    };
}

pub fn parse_date(date_string: String) -> Option<String> {
    lazy_static! {
        static ref RE: Regex = Regex::new(r"^(\d{4})[-: ](\d{2})[-: ](\d{2})").unwrap();
    }

    if let Some(captures) = RE.captures(&date_string) {
        let year = captures.get(1).unwrap().as_str();
        let month = captures.get(2).unwrap().as_str();
        let day = captures.get(3).unwrap().as_str();

        Some(format!("{}-{}-{}", year, month, day))
    } else {
        None
    }
}

pub fn file_size_bytes(filepath: &Path) -> Result<u64, String> {
    fs::metadata(filepath)
        .map(|meta| meta.len())
        .map_err(|err| err.to_string())
}

pub fn find_photo_files(directory: &Path) -> impl Iterator<Item = DirEntry> {
    WalkDir::new(directory)
        .sort_by_file_name()
        .min_depth(1)
        .into_iter()
        .filter_entry(walker_filter)
        .filter_map(|res| match res {
            // we don't want the iterator to yield directories. Files and symlinks are
            // yielded.
            Ok(entry) => {
                if !entry.file_type().is_dir() {
                    Some(entry)
                } else {
                    None
                }
            }
            // errors are logged, but not yielded
            Err(err) => {
                error!("{}", err_msg(err));
                None
            }
        })
}

fn walker_filter(entry: &DirEntry) -> bool {
    if entry.file_type().is_file() {
        // if it's a file, it needs to have the extension of an image:
        let extension = entry
            .path()
            .extension()
            .and_then(|ext| ext.to_str())
            .map(|ext| ext.to_lowercase())
            .unwrap_or_default();
        return PHOTO_FILES_EXTENSIONS.contains(&extension);
    }
    if entry.file_type().is_dir() {
        return !entry
            .file_name()
            .to_str()
            .map(|s| s.starts_with("."))
            .unwrap_or(false);
    }

    // TODO what to do with symlinks?
    false
}

fn err_msg(err: WalkDirError) -> String {
    let path = err.path().unwrap_or(Path::new("")).display();
    let base_msg = format!("Failed to access entry {}", path);
    if let Some(inner) = err.io_error() {
        format!("{}: {}", base_msg, inner)
    } else {
        format!("{} - unknown error", base_msg)
    }
}

pub fn create_date_folder(date: &str) -> std::io::Result<()> {
    let path = Path::new(date);
    if !path.exists() {
        fs::create_dir(date)?;
    }
    Ok(())
}

/// Copies the file at src to a directory named after the given date.
/// The copy happens in 2 steps to avoid to get partially copied files on disc
/// in the case where the process is interrupted mid-way:
/// 1. the file is copied to the destination folder but named with `_temp` as suffix,
/// 2. on copy completion, the temporary file is renamed to its original file name.
/// TODO: deal with the case where a temp file already exists.
pub fn copy_file_to_date_folder(src: &Path, date: &str) -> Result<(), String> {
    let dest_folder = Path::new(date);

    let src_path = Path::new(src);

    let file_name = src_path.file_name().unwrap();
    let file_name_temp = format!("{}.temp", file_name.to_string_lossy());

    let dest_path = dest_folder.join(file_name);
    let dest_path_temp = dest_folder.join(&file_name_temp);

    match fs::copy(src, &dest_path_temp) {
        Ok(_size) => match fs::rename(&dest_path_temp, &dest_path) {
            Ok(_) => Ok(()),
            Err(err) => {
                println!("Partially copied file cleanup...");
                let _ = fs::remove_file(&dest_path_temp);
                Err(err.to_string())
            }
        },
        Err(err) => Err(err.to_string()),
    }
}
