use super::MAX_READ_WRITE_LEN;
use crate::{fs::opened_file::Fd, result::Result};
use crate::{net::socket::write_sockaddr, net::RecvFromFlags, user_buffer::UserBufferMut};
use crate::{process::current_process, syscalls::SyscallHandler};
use core::cmp::min;
use kerla_runtime::address::UserVAddr;

impl<'a> SyscallHandler<'a> {
    pub fn sys_recvfrom(
        &mut self,
        fd: Fd,
        uaddr: UserVAddr,
        len: usize,
        flags: RecvFromFlags,
        src_addr: Option<UserVAddr>,
        addr_len: Option<UserVAddr>,
    ) -> Result<isize> {
        let len = min(len, MAX_READ_WRITE_LEN);

        let opened_file = current_process().get_opened_file_by_fd(fd)?;
        let (read_len, sockaddr) =
            opened_file.recvfrom(UserBufferMut::from_uaddr(uaddr, len), flags)?;

        write_sockaddr(&sockaddr, src_addr, addr_len)?;

        // MAX_READ_WRITE_LEN limit guarantees len is in the range of isize.
        Ok(read_len as isize)
    }

    // Vereinfachtes recvmsg: nur der erste iovec, keine Zusatzdaten.
    pub fn sys_recvmsg(&mut self, fd: Fd, msg: UserVAddr, flags: RecvFromFlags) -> Result<isize> {
        let name: usize = msg.read()?;
        let iov: usize = msg.add(16).read()?;
        let iovlen: usize = msg.add(24).read()?;
        if iovlen == 0 {
            return Ok(0);
        }
        let base: usize = UserVAddr::new_nonnull(iov)?.read()?;
        let len: usize = UserVAddr::new_nonnull(iov)?.add(8).read()?;
        let len = min(len, MAX_READ_WRITE_LEN);

        let opened_file = current_process().get_opened_file_by_fd(fd)?;
        let (read_len, sockaddr) = opened_file.recvfrom(
            UserBufferMut::from_uaddr(UserVAddr::new_nonnull(base)?, len),
            flags,
        )?;
        write_sockaddr(&sockaddr, UserVAddr::new(name), UserVAddr::new(msg.add(8).value()))?;
        msg.add(40).write(&0usize)?;
        Ok(read_len as isize)
    }
}
