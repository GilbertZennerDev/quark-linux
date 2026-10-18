use crate::{
    prelude::*,
    user_buffer::{UserBufReader, UserBufWriter},
};
use core::{
    fmt,
    sync::atomic::{AtomicUsize, Ordering},
};

use super::{
    file_system::FileSystem,
    inode::{DirEntry, Directory, FileLike, FileType, INode, INodeNo, Symlink},
    path::PathBuf,
    opened_file::OpenOptions,
    stat::{FileMode, Stat, S_IFDIR, S_IFLNK, S_IFREG},
};
use crate::{
    result::{Errno, Error, Result},
    user_buffer::UserBuffer,
    user_buffer::UserBufferMut,
};
use hashbrown::HashMap;
use kerla_runtime::spinlock::SpinLock;
use kerla_utils::{downcast::downcast, once::Once};

pub static TMP_FS: Once<Arc<TmpFs>> = Once::new();

fn alloc_inode_no() -> INodeNo {
    // Inode #1 is reserved for the root dir.
    static NEXT_INODE_NO: AtomicUsize = AtomicUsize::new(2);

    INodeNo::new(NEXT_INODE_NO.fetch_add(1, Ordering::SeqCst))
}

pub struct TmpFs {
    root_dir: Arc<Dir>,
}

impl TmpFs {
    pub fn new() -> TmpFs {
        TmpFs {
            root_dir: Arc::new(Dir::new(INodeNo::new(1))),
        }
    }

    pub fn root_tmpfs_dir(&self) -> &Arc<Dir> {
        &self.root_dir
    }
}

impl FileSystem for TmpFs {
    fn root_dir(&self) -> Result<Arc<dyn Directory>> {
        Ok(self.root_dir.clone())
    }
}

enum TmpFsINode {
    File(Arc<dyn FileLike>),
    Directory(Arc<Dir>),
    Symlink(Arc<TmpSymlink>),
}

struct DirInner {
    files: HashMap<String, TmpFsINode>,
    stat: Stat,
}

pub struct Dir(SpinLock<DirInner>);

impl Dir {
    pub fn new(inode_no: INodeNo) -> Dir {
        Dir(SpinLock::new(DirInner {
            files: HashMap::new(),
            stat: Stat {
                inode_no,
                mode: FileMode::new(S_IFDIR | 0o755),
                ..Stat::zeroed()
            },
        }))
    }

    pub fn add_dir(&self, name: &str) -> Arc<Dir> {
        let dir = Arc::new(Dir::new(alloc_inode_no()));
        self.0
            .lock()
            .files
            .insert(name.to_owned(), TmpFsINode::Directory(dir.clone()));
        dir
    }

    pub fn add_file(&self, name: &str, file: Arc<dyn FileLike>) {
        self.0
            .lock()
            .files
            .insert(name.to_owned(), TmpFsINode::File(file));
    }
}

impl Directory for Dir {
    fn lookup(&self, name: &str) -> Result<INode> {
        self.0
            .lock()
            .files
            .get(name)
            .map(|tmpfs_inode| match tmpfs_inode {
                TmpFsINode::File(file) => file.clone().into(),
                TmpFsINode::Directory(dir) => (dir.clone() as Arc<dyn Directory>).into(),
                TmpFsINode::Symlink(link) => (link.clone() as Arc<dyn Symlink>).into(),
            })
            .ok_or_else(|| Error::new(Errno::ENOENT))
    }

    fn readdir(&self, index: usize) -> Result<Option<DirEntry>> {
        let dir_lock = self.0.lock();
        let (name, inode) = match dir_lock.files.iter().nth(index) {
            Some(entry) => entry,
            None => {
                return Ok(None);
            }
        };

        let entry = match inode {
            TmpFsINode::Directory(dir) => {
                let dir = dir.0.lock();
                DirEntry {
                    inode_no: dir.stat.inode_no,
                    file_type: FileType::Directory,
                    name: name.clone(),
                }
            }
            TmpFsINode::File(file) => DirEntry {
                inode_no: file.stat()?.inode_no,
                file_type: FileType::Regular,
                name: name.clone(),
            },
            TmpFsINode::Symlink(link) => DirEntry {
                inode_no: link.stat.inode_no,
                file_type: FileType::Link,
                name: name.clone(),
            },
        };

        Ok(Some(entry))
    }

    fn stat(&self) -> Result<Stat> {
        Ok(self.0.lock().stat)
    }

    fn link(&self, name: &str, link_to: &INode) -> Result<()> {
        let tmpfs_inode = match link_to {
            INode::FileLike(file_like) => TmpFsINode::File(file_like.clone()),
            INode::Directory(dir) => {
                let dir: &Arc<Dir> = downcast(dir).unwrap();
                TmpFsINode::Directory(dir.clone())
            }
            INode::Symlink(link) => {
                let target = link.linked_to()?;
                TmpFsINode::Symlink(Arc::new(TmpSymlink::new(target.as_str())))
            }
        };

        self.0.lock().files.insert(name.to_owned(), tmpfs_inode);
        Ok(())
    }

    fn create_file(&self, name: &str, _mode: FileMode) -> Result<INode> {
        let mut dir_lock = self.0.lock();
        if dir_lock.files.contains_key(name) {
            return Err(Errno::EEXIST.into());
        }

        let inode = Arc::new(File::new(alloc_inode_no()));
        dir_lock
            .files
            .insert(name.to_owned(), TmpFsINode::File(inode.clone()));

        Ok((inode as Arc<dyn FileLike>).into())
    }

    fn unlink(&self, name: &str) -> Result<()> {
        let mut g = self.0.lock();
        let r = g.files.remove(name);
        match r {
            Some(_) => Ok(()),
            None => Err(Errno::ENOENT.into()),
        }
    }

    fn create_symlink(&self, name: &str, target: &str) -> Result<()> {
        let mut dir_lock = self.0.lock();
        if dir_lock.files.contains_key(name) {
            return Err(Errno::EEXIST.into());
        }
        dir_lock
            .files
            .insert(name.to_owned(), TmpFsINode::Symlink(Arc::new(TmpSymlink::new(target))));
        Ok(())
    }

    fn create_dir(&self, name: &str, _mode: FileMode) -> Result<INode> {
        if self.0.lock().files.contains_key(name) {
            return Err(Errno::EEXIST.into());
        }
        let inode = Arc::new(Dir::new(alloc_inode_no()));
        self.0
            .lock()
            .files
            .insert(name.to_owned(), TmpFsINode::Directory(inode.clone()));

        Ok((inode as Arc<dyn Directory>).into())
    }
}

impl fmt::Debug for Dir {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TmpFsDir").finish()
    }
}

struct TmpSymlink {
    target: String,
    stat: Stat,
}

impl TmpSymlink {
    fn new(target: &str) -> TmpSymlink {
        TmpSymlink {
            target: target.to_owned(),
            stat: Stat {
                inode_no: alloc_inode_no(),
                mode: FileMode::new(S_IFLNK | 0o777),
                ..Stat::zeroed()
            },
        }
    }
}

impl Symlink for TmpSymlink {
    fn stat(&self) -> Result<Stat> {
        Ok(self.stat)
    }

    fn linked_to(&self) -> Result<PathBuf> {
        Ok(PathBuf::from(self.target.as_str()))
    }
}

impl fmt::Debug for TmpSymlink {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TmpFsSymlink").finish()
    }
}

struct File {
    data: SpinLock<Vec<u8>>,
    stat: Stat,
}

impl File {
    pub fn new(inode_no: INodeNo) -> File {
        File {
            data: SpinLock::new(Vec::new()),
            stat: Stat {
                inode_no,
                mode: FileMode::new(S_IFREG | 0o644),
                ..Stat::zeroed()
            },
        }
    }
}

impl FileLike for File {
    fn stat(&self) -> Result<Stat> {
        let mut st = self.stat;
        st.size = super::stat::FileSize(self.data.lock().len() as isize);
        Ok(st)
    }

    fn truncate(&self) -> Result<()> {
        self.data.lock().clear();
        Ok(())
    }

    fn read(&self, offset: usize, buf: UserBufferMut<'_>, _options: &OpenOptions) -> Result<usize> {
        let data = self.data.lock();
        if offset > data.len() {
            return Ok(0);
        }

        let mut writer = UserBufWriter::from(buf);
        writer.write_bytes(&data[offset..])
    }

    fn write(&self, offset: usize, buf: UserBuffer<'_>, _options: &OpenOptions) -> Result<usize> {
        let mut data = self.data.lock();
        let mut reader = UserBufReader::from(buf);
        let end = offset + reader.remaining_len();
        if end > data.len() {
            data.resize(end, 0);
        }
        reader.read_bytes(&mut data[offset..end])
    }
}

impl fmt::Debug for File {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TmpFsFile").finish()
    }
}

pub fn init() {
    TMP_FS.init(|| Arc::new(TmpFs::new()));
}
