use core::fmt;

use crate::{
    fs::{
        inode::{FileLike, INodeNo},
        opened_file::OpenOptions,
        stat::{FileMode, Stat, S_IFCHR},
    },
    random::read_secure_random,
    result::Result,
    user_buffer::UserBuffer,
    user_buffer::UserBufferMut,
};

/// Die Dateien `/dev/urandom` und `/dev/random`.
pub(super) struct URandomFile {}

impl URandomFile {
    pub fn new() -> URandomFile {
        URandomFile {}
    }
}

impl fmt::Debug for URandomFile {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DevURandom").finish()
    }
}

impl FileLike for URandomFile {
    fn stat(&self) -> Result<Stat> {
        Ok(Stat {
            inode_no: INodeNo::new(3),
            mode: FileMode::new(S_IFCHR | 0o666),
            ..Stat::zeroed()
        })
    }

    fn read(&self, _offset: usize, buf: UserBufferMut<'_>, _options: &OpenOptions) -> Result<usize> {
        read_secure_random(buf)
    }

    fn write(&self, _offset: usize, buf: UserBuffer<'_>, _options: &OpenOptions) -> Result<usize> {
        Ok(buf.len())
    }
}
