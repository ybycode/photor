use murmur3::murmur3_x64_128;
use std::fs::File;
use std::io::{self, BufReader, Read};

/// Returns the murmur3 hash of the file size and content of the first `nbytes`
/// of the file.
pub fn hash_file_first_bytes(file_path: &str, nbytes: u64) -> io::Result<u128> {
    let file = File::open(file_path)?;
    let size = &(file.metadata().unwrap().len().to_be_bytes());

    let file_reader = BufReader::new(file).take(nbytes);

    let mut handle = size.chain(file_reader);
    murmur3_x64_128(&mut handle, 0)
}
