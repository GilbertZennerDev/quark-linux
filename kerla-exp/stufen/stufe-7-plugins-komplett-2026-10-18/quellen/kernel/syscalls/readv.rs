use super::{IoVec, IOV_MAX, MAX_READ_WRITE_LEN};
use crate::prelude::*;
use crate::{fs::opened_file::Fd, user_buffer::UserBufferMut};
use crate::{process::current_process, syscalls::SyscallHandler};
use core::cmp::min;
use core::mem::size_of;
use kerla_runtime::address::UserVAddr;

impl<'a> SyscallHandler<'a> {
    pub fn sys_readv(&mut self, fd: Fd, iov_base: UserVAddr, iov_count: usize) -> Result<isize> {
        let iov_count = min(iov_count, IOV_MAX);

        let opened_file = current_process().get_opened_file_by_fd(fd)?;
        let mut total_len: usize = 0;
        for i in 0..iov_count {
            let mut iov: IoVec = iov_base.add(i * size_of::<IoVec>()).read()?;

            match total_len.checked_add(iov.len) {
                Some(len) if len > MAX_READ_WRITE_LEN => {
                    iov.len = MAX_READ_WRITE_LEN - total_len;
                }
                None => {
                    iov.len = MAX_READ_WRITE_LEN - total_len;
                }
                _ => {}
            }

            if iov.len == 0 {
                continue;
            }

            let n = opened_file.read(UserBufferMut::from_uaddr(iov.base, iov.len))?;
            total_len += n;
            // Kurzer Lesevorgang: nicht weiter blockieren.
            if n < iov.len {
                break;
            }
        }

        Ok(total_len as isize)
    }
}
