use crate::fuse_photo_fs::{Inode, PhotosFS};
// // use crate::models::Photo;
use fuser::{
    FileAttr, FileType, Filesystem, MountOption, ReplyAttr, ReplyData, ReplyDirectory, ReplyEntry,
    Request,
};
use libc::ENOENT;
use std::ffi::{OsStr, OsString};
use std::path::PathBuf;
use std::time::{Duration, UNIX_EPOCH};

const TTL: Duration = Duration::from_secs(1); // 1 second
                                              //
                                              // const HELLO_DIR_ATTR: FileAttr = FileAttr {
                                              //     ino: 1,
                                              //     size: 0,
                                              //     blocks: 0,
                                              //     atime: UNIX_EPOCH, // 1970-01-01 00:00:00
                                              //     mtime: UNIX_EPOCH,
                                              //     ctime: UNIX_EPOCH,
                                              //     crtime: UNIX_EPOCH,
                                              //     kind: FileType::Directory,
                                              //     perm: 0o755,
                                              //     nlink: 2,
                                              //     uid: 501,
                                              //     gid: 20,
                                              //     rdev: 0,
                                              //     flags: 0,
                                              //     blksize: 512,
                                              // };
                                              //
                                              // const HELLO_TXT_CONTENT: &str = "Hello World!\n";
                                              //
fn regular_dir_attr(inode: Inode) -> FileAttr {
    FileAttr {
        ino: inode,
        size: 0,
        blocks: 0,
        atime: UNIX_EPOCH, // 1970-01-01 00:00:00
        mtime: UNIX_EPOCH,
        ctime: UNIX_EPOCH,
        crtime: UNIX_EPOCH,
        kind: FileType::Directory,
        perm: 0o755,
        nlink: 2,
        uid: 501,
        gid: 20,
        rdev: 0,
        flags: 0,
        blksize: 512,
    }
}
fn regular_file_attr(inode: Inode) -> FileAttr {
    FileAttr {
        ino: inode,
        size: 13,
        blocks: 1,
        atime: UNIX_EPOCH, // 1970-01-01 00:00:00
        mtime: UNIX_EPOCH,
        ctime: UNIX_EPOCH,
        crtime: UNIX_EPOCH,
        kind: FileType::RegularFile,
        perm: 0o644,
        nlink: 1,
        uid: 501,
        gid: 20,
        rdev: 0,
        flags: 0,
        blksize: 512,
    }
}
//
// // #[derive(Debug)]
// // pub struct PhotosFS {}
//
impl Filesystem for PhotosFS {
    fn lookup(&mut self, _req: &Request, parent: Inode, name: &OsStr, reply: ReplyEntry) {
        println!("in lookup: parent: {:?}, name: {:?}", parent, name);
        if name == "some_dir" {
            reply.entry(&TTL, &regular_dir_attr(2), 0);

            return;
        }
        if name == "hello.txt" {
            reply.entry(&TTL, &regular_file_attr(3), 0);

            return;
        }
        reply.error(ENOENT);
    }

    fn getattr(&mut self, _req: &Request, inode: Inode, reply: ReplyAttr) {
        println!("in getattr: inode: {:?}", inode);
        if inode == 1 || inode == 2 {
            // the root folder
            reply.attr(&TTL, &regular_dir_attr(inode));
            return;
        }
        reply.error(ENOENT);
        // match ino {
        //     1 => reply.attr(&TTL, &regular_file_attr(1)),
        //     2 => reply.attr(&TTL, &regular_file_attr(2)),
        //     _ => reply.error(ENOENT),
        // }
    }
    //
    //     fn read(
    //         &mut self,
    //         _req: &Request,
    //         ino: Inode,
    //         _fh: u64,
    //         offset: i64,
    //         _size: u32,
    //         _flags: i32,
    //         _lock: Option<u64>,
    //         reply: ReplyData,
    //     ) {
    //         if ino == 2 {
    //             reply.data(&HELLO_TXT_CONTENT.as_bytes()[offset as usize..]);
    //         } else {
    //             reply.error(ENOENT);
    //         }
    //     }
    //
    fn readdir(
        &mut self,
        _req: &Request,
        ino: u64,
        _fh: u64,
        offset: i64,
        mut reply: ReplyDirectory,
    ) {
        println!("in readdir: ino: {:?}, offset: {:?}", ino, offset);
        if ino != 1 {
            reply.error(ENOENT);
            return;
        }

        // let entries = vec![
        //     (1, FileType::Directory, "."),
        //     (1, FileType::Directory, ".."),
        //     (2, FileType::RegularFile, "hello.txt"),
        // ];

        // for (i, entry) in entries.into_iter().enumerate().skip(offset as usize) {
        //     // i + 1 means the index of the next entry
        //     if reply.add(entry.0, (i + 1) as i64, entry.1, entry.2) {
        //         break;
        //     }
        // }
        // reply.ok();

        if !reply.add(1, 1, FileType::Directory, ".") {
            let entries = vec![
                (1, FileType::Directory, ".."),
                (2, FileType::Directory, "some_dir"),
                (3, FileType::RegularFile, "hello.txt"),
            ];

            for (i, entry) in entries.into_iter().enumerate().skip(offset as usize) {
                // i + 1 means the index of the next entry
                if reply.add(entry.0, (i + 2) as i64, entry.1, entry.2) {
                    break;
                }
            }
        }
        reply.ok();
    }
}
// }
//
pub fn mount(mountpoint: &PathBuf) {
    let options = vec![
        MountOption::RO,
        MountOption::FSName("hello".to_string()),
        // MountOption::AutoUnmount,
        // MountOption::AllowRoot,
    ];

    // let mut photos: Vec<Photo> = vec![];
    let mut photos_fs = PhotosFS::new();
    photos_fs.add_file("b/hallo.txt".into()).unwrap();
    photos_fs.add_file("a/hey.txt".into()).unwrap();
    // println!("photo_fs: {:?}", photos_fs);

    fuser::mount2(photos_fs, mountpoint, &options).unwrap();
}
