use std::collections::HashMap;
use std::ffi::{OsStr, OsString};
use std::path::{Component, Path};

pub type Inode = u64;
pub type NameToInode = HashMap<OsString, Inode>;

#[derive(Debug)]
pub struct Tree {
    map: HashMap<Inode, NameToInode>,
}

impl Tree {
    pub fn new() -> Self {
        Self {
            map: HashMap::new(),
        }
    }

    pub fn add_node(&mut self, parent_inode: &Inode) {
        self.map.insert(parent_inode.to_owned(), HashMap::new());
    }
    pub fn add_node_item(
        &mut self,
        parent_inode: &Inode,
        name: &OsStr,
        inode: Inode,
    ) -> Result<(), String> {
        // get the NameToInode value associated to the parent_inode:
        let val = match self.map.get_mut(parent_inode) {
            None => return Err(String::from("parent_inode not in the tree")),
            Some(val) => val,
        };

        val.insert(name.into(), inode);

        Ok(())
    }

    pub fn lookup(&self, parent_inode: &Inode, name: &OsStr) -> Option<&Inode> {
        // get the NameToInode value associated to the parent_inode:
        let val = match self.map.get(parent_inode) {
            None => return None,
            Some(val) => val,
        };

        val.get(name)
    }
}

#[derive(Debug)]
pub struct Directory {
    pub inode: Inode,
    pub path: OsString,
    // the inodes of the files this directory contains:
    // TODO: to remove since we have Tree?
    pub files_inodes: Vec<Inode>,
}

#[derive(Debug)]
pub struct File {
    // inode: Inode,
    // TODO: rename to 'name'?
    pub path: OsString,
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
    // TODO: to replace
    pub name_to_inode_map: HashMap<OsString, Inode>,
    pub tree_lookup: Tree,
    pub directories_inodes: Vec<Inode>,
}

impl PhotosFS {
    pub fn new() -> PhotosFS {
        Self {
            next_inode: 2,
            // map inode -> FSItem (file or directory). This is what holds the actual definition of
            // files and directory attributes.
            inode_map: HashMap::new(),
            tree_lookup: Tree::new(),
            // TODO: to remove
            name_to_inode_map: HashMap::new(),
            // a list of the inodes of directories. Might not be needed soon.
            directories_inodes: vec![],
        }
    }

    fn next_inode(&mut self) -> Inode {
        let inode = self.next_inode;
        self.next_inode += 1;
        inode
    }

    fn is_path_already_used<P: AsRef<Path>>(&self, _path: P) -> bool {
        // TODO
        false
    }

    // HERE
    fn directory_lookup_mut(&mut self, path: &OsStr) -> Option<&mut Directory> {
        // TODO: to remove
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

    /// Add  a file in the filesystem. It splits the path into components and adds each dir, then
    /// adds the file.
    pub fn add_file(&mut self, path: &Path) -> Result<Inode, String> {
        let mut inode = 1; // the root
        let filename = Path::file_name(path).expect("path ends with \"..\"?");
        for comp in path.components() {
            match comp {
                Component::RootDir => {
                    // do something
                }
                Component::Normal(plop) => {
                    // do something
                }
                _ => {
                    // fail?
                }
            }
        }
        Ok(1)
        // if self.is_path_already_used(path) {
        //     return Err(format!("Path {} already used", "TODO path here"));
        // }

        // // TODO: clunky with OsString and Path here
        // // Create the Directory of where this file is, if it doesn't exist already:
        // let ppath = Path::new(&path);
        // let dir_path = if let Some(p) = Path::parent(ppath) {
        //     p.as_os_str()
        // } else {
        //     return Err("File is not in a directory??".to_string());
        // };

        // // the file is inserted in the filesystem:

        // let inode = self.next_inode();
        // let file = File {
        //     // inode,
        //     path: Path::file_name(ppath).unwrap().into(),
        // };

        // self.inode_map.insert(inode, FSItem::File(file));
        // // TODO: to remove
        // self.name_to_inode_map.insert(path.into(), inode);

        // // we now need to insert the file's inode in the right Directory.

        // // a Directory is found if already in the filesystem, or it is created:
        // let dir = match self.directory_lookup_mut(dir_path) {
        //     None => self.add_directory(dir_path.to_owned()).unwrap(),
        //     Some(dir) => dir,
        // };

        // // we have the dir, the file's inode is added to it:
        // dir.files_inodes.push(inode);

        // Ok(inode)
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
                path: path.clone(),
                files_inodes: vec![],
            }),
        );
        // TODO: to remove
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
