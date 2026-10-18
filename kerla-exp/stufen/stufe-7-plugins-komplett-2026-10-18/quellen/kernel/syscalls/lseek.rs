use crate::fs::opened_file::Fd;
use crate::process::current_process;
use crate::result::{Errno, Result};
use crate::syscalls::SyscallHandler;

impl<'a> SyscallHandler<'a> {
    pub fn sys_lseek(&mut self, fd: Fd, off: isize, whence: i32) -> Result<isize> {
        let opened_file = current_process().get_opened_file_by_fd(fd)?;
        let base = match whence {
            0 => 0,
            1 => opened_file.pos() as isize,
            2 => opened_file.path().inode.stat()?.size.0,
            _ => return Err(Errno::EINVAL.into()),
        };
        let new = base + off;
        if new < 0 {
            return Err(Errno::EINVAL.into());
        }
        opened_file.set_pos(new as usize);
        Ok(new)
    }
}
