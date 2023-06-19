use crate::fuse_photo_fs::{FSItem, Inode, PhotosFS};
// // use crate::models::Photo;
use fuser::{
    FileAttr, FileType, Filesystem, MountOption, ReplyAttr, ReplyDirectory, ReplyEntry, Request,
};
use libc::ENOENT;
use std::ffi::OsStr;
use std::path::PathBuf;
use std::time::{Duration, UNIX_EPOCH};

const TTL: Duration = Duration::from_secs(1); // 1 second
                                              //
fn regular_dir_attr(inode: Inode) -> FileAttr {
    FileAttr {
        ino: inode,
        size: 4096,
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
fn regular_file_attr(inode: Inode, size: u64) -> FileAttr {
    FileAttr {
        ino: inode,
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

        if name.to_str() == Some("hello.txt") {
            reply.entry(&TTL, &regular_file_attr(7258, 1024), 0);
            return;
        }

        let inode = match self.name_to_inode_map.get(name) {
            Some(inode) => {
                println!("Case with inode. inode: {:?}", inode);
                inode
            }
            None => {
                println!("Case with ENOENT. name: {:?}", name);
                reply.error(ENOENT);
                return;
            }
        };

        match self.inode_map.get(inode).unwrap() {
            // TODO: use file and dir vars to populate actual attributes
            FSItem::File(_file) => reply.entry(&TTL, &regular_file_attr(*inode, 1024), 0),
            FSItem::Directory(_dir) => reply.entry(&TTL, &regular_dir_attr(*inode), 0),
        };
    }

    fn getattr(&mut self, _req: &Request, inode: Inode, reply: ReplyAttr) {
        println!("in getattr: inode: {:?}", inode);
        if inode == 1 {
            // the root folder
            // TODO: declare it in PhotosFS?
            reply.attr(&TTL, &regular_dir_attr(inode));
            return;
        }

        match self.inode_map.get(&inode) {
            Some(FSItem::File(_file)) => reply.attr(&TTL, &regular_file_attr(inode, 1025)),
            Some(FSItem::Directory(_dir)) => reply.attr(&TTL, &regular_dir_attr(inode)),
            None => reply.error(ENOENT),
        };
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
        if ino == 1 {
            // ino == 1 is the root, where we list the directories of photos.
            let static_entries = vec![
                (1u64, FileType::Directory, "."),
                (1u64, FileType::Directory, ".."),
            ]
            .into_iter();

            let dirs = self.directories_inodes.iter().map(|inode| {
                match self.inode_map.get(inode).unwrap() {
                    FSItem::File(f) => (
                        *inode,
                        FileType::RegularFile,
                        f.path.as_os_str().to_str().unwrap_or(""),
                    ),
                    FSItem::Directory(d) => (
                        *inode,
                        FileType::Directory,
                        d.path.as_os_str().to_str().unwrap_or(""),
                    ),
                }
            });

            for (i, entry) in static_entries.chain(dirs).enumerate().skip(offset as usize) {
                // i + 1 means the index of the next entry
                if reply.add(entry.0, (i + 1) as i64, entry.1, entry.2) {
                    break;
                }
            }
            reply.ok();
        } else {
            let dir = match self.inode_map.get(&ino).unwrap() {
                FSItem::File(_file) => {
                    // shouldn't be a file. TODO: find a better way to deal with this case.
                    reply.ok();
                    return;
                }
                FSItem::Directory(dir) => dir,
            };
            let static_entries = vec![
                (dir.inode, FileType::Directory, "."),
                (1u64, FileType::Directory, ".."),
                (7258, FileType::RegularFile, "hello.txt"),
            ]
            .into_iter();

            let files = dir.files_inodes.iter().map(|inode| {
                match self.inode_map.get(inode).unwrap() {
                    FSItem::File(f) => {
                        let i = *inode;
                        let path = f.path.as_os_str().to_str().unwrap_or("");
                        println!("Iterator loaded with: {:?}, {:?}", i, path);

                        (i, FileType::RegularFile, path)
                    }
                    FSItem::Directory(d) => {
                        println!("Whaaaaaaat");

                        (
                            // NOTE: shouldn't happen but it's fine to leave this here for now I guess.
                            *inode,
                            FileType::Directory,
                            d.path.as_os_str().to_str().unwrap_or(""),
                        )
                    }
                }
            });

            for (i, entry) in static_entries
                .chain(files)
                .enumerate()
                .skip(offset as usize)
            {
                // i + 1 means the index of the next entry
                if reply.add(entry.0, (i + 1) as i64, entry.1, entry.2) {
                    break;
                }
            }

            reply.ok();
        }
    }
}
// }
//
pub fn mount(mountpoint: &PathBuf, photos_fs: PhotosFS) {
    let options = vec![
        MountOption::RO,
        MountOption::FSName("hello".to_string()),
        // MountOption::AutoUnmount,
        // MountOption::AllowRoot,
    ];

    fuser::mount2(photos_fs, mountpoint, &options).unwrap();
}
