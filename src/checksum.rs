use std::fs::File;
use std::io;

use murmur3::murmur3_x64_128;

pub fn hash(file_path: &str) -> io::Result<u128> {
    let file = File::open(file_path)?;
    let mut reader = io::BufReader::new(file);
    murmur3_x64_128(&mut reader, 0)
}
