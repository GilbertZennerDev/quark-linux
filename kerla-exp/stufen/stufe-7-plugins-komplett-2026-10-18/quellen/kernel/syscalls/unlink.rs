use crate::fs::path::Path;
use crate::prelude::*;
use crate::{process::current_process, syscalls::SyscallHandler};

impl<'a> SyscallHandler<'a> {
    pub fn sys_unlink(&mut self, path: &Path) -> Result<isize> {
        let (parent_dir, name) = path
            .parent_and_basename()
            .ok_or_else::<Error, _>(|| Errno::EPERM.into())?;

        current_process()
            .root_fs()
            .lock()
            .lookup_dir(parent_dir)?
            .unlink(name)?;

        Ok(0)
    }
}
