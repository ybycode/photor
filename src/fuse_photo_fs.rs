use std::collections::HashMap;
use std::ffi::{OsStr, OsString};
use std::path::Path;

pub type Inode = u64;

#[derive(Debug)]
pub struct Directory {
    inode: Inode,
    // the inodes of the files this directory contains:
    files_inodes: Vec<Inode>,
}

#[derive(Debug)]
pub struct File {
    inode: Inode,
    // sha256sum: String,
    // bytesize: u64,
}

#[derive(Debug)]
pub enum FSItem {
    File(File),
    Directory(Directory),
}

impl FSItem {
    pub fn as_directory_mut(&mut self) -> Option<&mut Directory> {
        match self {
            FSItem::Directory(directory) => Some(directory),
            _ => None,
        }
    }
}

#[derive(Debug)]
pub struct PhotosFS {
    next_inode: Inode,
    pub inode_map: HashMap<Inode, FSItem>,
    pub name_to_inode_map: HashMap<OsString, Inode>,
    pub directories_inodes: Vec<Inode>,
}

impl PhotosFS {
    pub fn new() -> PhotosFS {
        Self {
            next_inode: 2,
            inode_map: HashMap::new(),
            name_to_inode_map: HashMap::new(),
            directories_inodes: vec![],
        }
    }

    fn next_inode(&mut self) -> Inode {
        let inode = self.next_inode;
        self.next_inode += 1;
        inode
    }

    fn is_path_already_used(&self, _path: &OsString) -> bool {
        // TODO
        false
    }

    fn directory_lookup_mut(&mut self, path: &OsStr) -> Option<&mut Directory> {
        let dir_inode = match self.name_to_inode_map.get_mut(path) {
            None => return None,
            Some(inode) => inode,
        };

        let dir = match self.inode_map.get_mut(dir_inode) {
            None => return None,
            // TODO: meeeeeh
            Some(FSItem::File(_f)) => return None,
            Some(FSItem::Directory(d)) => d,
        };

        Some(dir)
    }

    pub fn add_file(&mut self, path: OsString) -> Result<Inode, String> {
        if self.is_path_already_used(&path) {
            return Err(format!("Path {} already used", "TODO path here"));
        }

        // TODO: clunky with OsString and Path here
        // Create the Directory of where this file is, if it doesn't exist already:
        let dir_path = if let Some(p) = Path::parent(Path::new(&path)) {
            p.as_os_str()
        } else {
            return Err("File is not in a directory??".to_string());
        };

        // the file is inserted in the filesystem:

        let inode = self.next_inode();
        let file = File { inode };

        self.inode_map.insert(inode, FSItem::File(file));
        self.name_to_inode_map.insert(path.clone(), inode);

        // we now need to insert the file's inode in the right Directory.

        // a Directory is found if already in the filesystem, or it is created:
        let dir = match self.directory_lookup_mut(dir_path) {
            None => self.add_directory(dir_path.to_owned()).unwrap(),
            Some(dir) => dir,
        };

        // we have the dir, the file's inode is added to it:
        dir.files_inodes.push(inode);

        Ok(inode)
    }

    pub fn add_directory(&mut self, path: OsString) -> Result<&mut Directory, String> {
        // this shouldn't happen with our use case
        if self.is_path_already_used(&path) {
            return Err(format!("Path {} already used", "TODO path here"));
        }

        let inode = self.next_inode();

        self.inode_map.insert(
            inode,
            FSItem::Directory(Directory {
                inode,
                files_inodes: vec![],
            }),
        );
        self.name_to_inode_map.insert(path.into(), inode);
        self.directories_inodes.push(inode);

        // the reference to the newly created instance of Directory is found:
        let new_dir = self
            .inode_map
            .get_mut(&inode)
            .unwrap()
            .as_directory_mut()
            .unwrap();
        // and returned:
        Ok(new_dir)
    }
}
