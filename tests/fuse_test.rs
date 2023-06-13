// use fuser::Session;
// use photor::fuse_photo_fs::PhotosFS;
// use photor::models::Photo;
// use std::fs;
// use std::thread;
// use std::time::Duration;
// use tempfile::TempDir;
//
// fn make_photo(id: i32, directory: &str, filename: &str) -> Photo {
//     return Photo {
//         id,
//         partial_hash: "some hash".to_string(),
//         filename: filename.to_string(),
//         directory: directory.to_string(),
//         full_sha256_hash: "bla".to_string(),
//         file_size_bytes: 100,
//         image_height: None,
//         image_width: None,
//         mime_type: None,
//         iso: None,
//         aperture: None,
//         shutter_speed: None,
//         focal_length: None,
//         make: None,
//         model: None,
//         lens_info: None,
//         lens_make: None,
//         lens_model: None,
//         create_date: "2021-12-12 09:54:23".to_string(),
//     };
// }
//
// #[test]
// #[cfg(target_os = "linux")]
// fn fuse1() {
//     let tmpdir: TempDir = tempfile::tempdir().unwrap();
//
//     let mut photos = vec![
//         make_photo(1, "a/b", "file1.jpg"),
//         make_photo(2, "a/b", "file2.jpg"),
//         make_photo(3, "a/b", "file3.jpg"),
//         make_photo(4, "a/b", "file4.jpg"),
//     ];
//     let photos_fs = PhotosFS::from_photos(&mut photos);
//
//     println!("{:?}", photos_fs);
//
//     let mut session = Session::new(photos_fs, tmpdir.path(), &[]).unwrap();
//
//     let mut unmounter = session.unmount_callable();
//     thread::spawn(move || {
//         let paths = fs::read_dir(tmpdir.path()).unwrap();
//         for path in paths {
//             println!("Name: {}", path.unwrap().path().display())
//         }
//
//         thread::sleep(Duration::from_secs(1));
//
//         // cleanup: unmount and remove the temporary directory:
//         unmounter.unmount().unwrap();
//         fs::remove_dir(tmpdir.path()).unwrap();
//     });
//     session.run().unwrap();
// }
