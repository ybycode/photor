use photor::fuse_photo_fs::{FSItem, PhotosFS};
use std::ffi::OsStr;

#[test]
#[cfg(target_os = "linux")]
fn test_add_files() {
    let mut fs = PhotosFS::new();

    let res1 = fs.add_file("a/b/c.jpg".into());
    let res2 = fs.add_file("a/d.jpg".into());

    println!("{:?}", fs);

    assert!(res1.is_ok());
    assert!(res2.is_ok());

    let ino = fs.name_to_inode_map.get(OsStr::new("a/b/c.jpg")).unwrap();
    assert_eq!(*ino, 1);

    let ino = fs.name_to_inode_map.get(OsStr::new("a/b")).unwrap();
    assert_eq!(*ino, 2);

    let item = fs.inode_map.get(&1).unwrap();
    assert!(matches!(item, FSItem::File(_)));

    let item = fs.inode_map.get(&2).unwrap();
    assert!(matches!(item, FSItem::Directory(_)));

    assert_eq!(fs.directories_inodes.len(), 2);
    assert_eq!(
        fs.directories_inodes.get(0..2).map(|s| s.as_ref()),
        Some(&[2, 4][..])
    );
}
