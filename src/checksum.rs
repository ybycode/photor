use murmur3::murmur3_x64_128;
use std::fs::File;
use std::io::{BufReader, Read};

/// Returns the murmur3 hash of the file size and content of the first `nbytes`
/// of the file.
pub fn hash_file_first_bytes(file: &mut File, nbytes: u64) -> Result<u128, String> {
    let size = file
        .metadata()
        .map_err(|e| format!("Failed to get file metadata: {}", e))?
        .len()
        .to_be_bytes();

    let file_reader = BufReader::new(file).take(nbytes);

    let mut handle = size.chain(file_reader);
    murmur3_x64_128(&mut handle, 0).map_err(|e| format!("Failed to compute murmur3 hash: {}", e))
}
