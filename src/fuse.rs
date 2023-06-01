// use crate::db;
use crate::models::Photo;
use fuser::{
    FileAttr, FileType, Filesystem, MountOption, ReplyAttr, ReplyData, ReplyDirectory, ReplyEntry,
    Request,
};
use libc::ENOENT;
use std::ffi::OsStr;
use std::path::PathBuf;
use std::time::{Duration, UNIX_EPOCH};

const TTL: Duration = Duration::from_secs(1); // 1 second

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

const HELLO_TXT_CONTENT: &str = "Hello World!\n";

fn make_photo_attr(ino: u64, size: u64) -> FileAttr {
    FileAttr {
        ino,
        size,
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
        blksize: 69,
    }
}

#[derive(Debug)]
struct Folder {
    ino: u64,
    name: String,
    photos: Vec<Photo>,
}

#[derive(Debug)]
struct PhotosFS {
    folders: Vec<Folder>,
}

impl Filesystem for PhotosFS {
    // fn lookup(&mut self, _req: &Request, parent: u64, _name: &OsStr, reply: ReplyEntry) {
    //     if parent == 1 {
    //         reply.entry(&TTL, &make_photo_attr(511, 1000), 0);
    //     } else {
    //         reply.error(ENOENT);
    //     }
    // }

    // fn getattr(&mut self, _req: &Request, ino: u64, reply: ReplyAttr) {
    //     match ino {
    //         1 => reply.attr(&TTL, &make_photo_attr(522, 2000)),
    //         2 => reply.attr(&TTL, &make_photo_attr(523, 2001)),
    //         _ => reply.error(ENOENT),
    //     }
    // }

    // fn read(
    //     &mut self,
    //     _req: &Request,
    //     ino: u64,
    //     _fh: u64,
    //     offset: i64,
    //     _size: u32,
    //     _flags: i32,
    //     _lock: Option<u64>,
    //     reply: ReplyData,
    // ) {
    //     if ino == 2 {
    //         reply.data(&HELLO_TXT_CONTENT.as_bytes()[offset as usize..]);
    //     } else {
    //         reply.error(ENOENT);
    //     }
    // }

    fn readdir(
        &mut self,
        _req: &Request,
        _ino: u64,
        _fh: u64,
        offset: i64,
        mut reply: ReplyDirectory,
    ) {
        // if ino != 1 {
        //     reply.error(ENOENT);
        //     return;
        // }

        for (i, folder) in self.folders.iter().enumerate().skip(offset as usize) {
            // i + 1 means the index of the next entry
            if reply.add(i as u64, (i + 1) as i64, FileType::Directory, &folder.name) {
                break;
            }
        }
        reply.ok();
    }
}

pub fn mount(to: &PathBuf) {
    let options = vec![
        MountOption::RO,
        MountOption::FSName("photo_disc".to_string()),
        // MountOption::AutoUnmount,
        // MountOption::AllowRoot,
    ];
    // let connection = &mut db::establish_connection();

    let photo_fs = PhotosFS {
        folders: vec![
            Folder {
                ino: 1,
                name: "folder 1".to_string(),
                photos: vec![],
            },
            Folder {
                ino: 2,
                name: "folder 2".to_string(),
                photos: vec![],
            },
            Folder {
                ino: 3,
                name: "folder 3".to_string(),
                photos: vec![],
            },
        ], // db::just_10_photos(connection).unwrap(),
    };

    println!("photo_fs: {:?}", photo_fs);

    fuser::mount2(photo_fs, to, &options).unwrap();
}
