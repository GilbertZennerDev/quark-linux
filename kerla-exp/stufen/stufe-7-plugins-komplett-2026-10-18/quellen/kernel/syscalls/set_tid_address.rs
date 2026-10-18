use crate::result::Result;
use crate::{process::current_process, syscalls::SyscallHandler};
use kerla_runtime::address::UserVAddr;

impl<'a> SyscallHandler<'a> {
    pub fn sys_set_tid_address(&mut self, _uaddr: UserVAddr) -> Result<isize> {
        // musl speichert den Rueckgabewert als Thread-ID; 0 loest in exit() ein hlt aus.
        Ok(current_process().pid().as_i32() as isize)
    }
}
