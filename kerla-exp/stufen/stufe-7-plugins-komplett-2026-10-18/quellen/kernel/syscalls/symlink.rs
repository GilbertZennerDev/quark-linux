use crate::fs::path::Path;
use crate::prelude::*;
use crate::{process::current_process, syscalls::SyscallHandler};

impl<'a> SyscallHandler<'a> {
    pub fn sys_symlink(&mut self, target: &Path, linkpath: &Path) -> Result<isize> {
        let (parent_dir, name) = linkpath
            .parent_and_basename()
            .ok_or_else::<Error, _>(|| Errno::EEXIST.into())?;

        current_process()
            .root_fs()
            .lock()
            .lookup_dir(parent_dir)?
            .create_symlink(name, target.as_str())?;

        Ok(0)
    }
}
