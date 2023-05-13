use lazy_static::lazy_static;
use regex::Regex;
use std::collections::HashSet;
use std::path::Path;
use std::path::PathBuf;
use walkdir::{DirEntry, Error as WalkDirError, WalkDir};

lazy_static! {
    static ref PHOTO_FILES_EXTENSIONS: HashSet<String> = {
        // here are defined the file extensions looked for by the WalkDir iterator:
        ["jpg", "jpeg", "png", "raw", "raf"]
            .iter()
            .map(|ext| ext.to_lowercase())
            .collect()
    };
}

fn parse_date(date_string: String) -> Option<String> {
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

pub fn find_photo_files(directory: &PathBuf) -> impl Iterator<Item = DirEntry> {
    WalkDir::new(directory)
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
