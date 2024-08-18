use sha2::{Digest, Sha256};
use std::fs::File;
use std::io::{self, BufReader, Read};

/// Returns the sha256 hash of the file size and content of the first `nbytes`
/// of the file.
pub fn hash_file_first_bytes(file: &File, nbytes: u64) -> Result<String, String> {
    let mut hasher = Sha256::new();

    let filesize = file
        .metadata()
        .map_err(|e| format!("Failed to get file metadata: {}", e))?
        .len();

    hasher.update(filesize.to_string().as_bytes());

    let mut file_reader = BufReader::new(file).take(nbytes);

    io::copy(&mut file_reader, &mut hasher)
        .map_err(|e| format!("Failed to compute sha256 hash: {}", e))?;

    Ok(format!("{:x}", hasher.finalize()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;

    fn compute_hash(filepath: &str, nbytes: u64) -> Result<String, String> {
        let file = File::open(filepath).map_err(|e| format!("Failed to open file: {}", e))?;
        hash_file_first_bytes(&file, nbytes)
    }

    #[test]
    fn test_whole_file() {
        let hash = compute_hash("tests/assets/checksum.txt", 1000).unwrap();
        assert_eq!(
            hash,
            "e85655adf07244724785569c2180d8604c81dd6126a502dee002b6c7459322ba"
        );
    }

    #[test]
    fn test_first_byte() {
        let hash = compute_hash("tests/assets/checksum.txt", 1).unwrap();
        assert_eq!(
            hash,
            "16dc368a89b428b2485484313ba67a3912ca03f2b2b42429174a4f8b3dc84e44"
        );
    }

    #[test]
    fn test_no_bytes() {
        let hash = compute_hash("tests/assets/checksum.txt", 0).unwrap();
        assert_eq!(
            hash,
            "4a44dc15364204a80fe80e9039455cc1608281820fe2b24f1e5233ade6af1dd5"
        );
    }
}
