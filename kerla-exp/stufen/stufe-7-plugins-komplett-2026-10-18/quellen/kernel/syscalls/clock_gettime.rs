use kerla_runtime::address::UserVAddr;

use crate::result::{Errno, Result};
use crate::user_buffer::UserBufWriter;
use crate::{
    ctypes::{c_clockid, c_long, c_time, CLOCK_MONOTONIC, CLOCK_REALTIME},
    timer::read_wall_clock,
};
use crate::{syscalls::SyscallHandler, timer::read_monotonic_clock};
use core::{convert::TryInto, mem::size_of};

impl<'a> SyscallHandler<'a> {
    pub fn sys_clock_gettime(&mut self, clock: c_clockid, buf: UserVAddr) -> Result<isize> {
        let (tv_sec, tv_nsec) = match clock {
            // 5 = REALTIME_COARSE
            CLOCK_REALTIME | 5 => {
                let now = read_wall_clock();
                (now.secs_from_epoch(), now.nanosecs_from_epoch())
            }
            // 2/3 = CPUTIME (grob als Monotonic), 4 = MONOTONIC_RAW, 6 = MONOTONIC_COARSE, 7 = BOOTTIME
            CLOCK_MONOTONIC | 2 | 3 | 4 | 6 | 7 => {
                let now = read_monotonic_clock();
                (now.secs(), now.nanosecs())
            }
            _ => {
                debug_warn!("clock_gettime: unsupported clock id: {}", clock);
                return Err(Errno::ENOSYS.into());
            }
        };

        let mut writer = UserBufWriter::from_uaddr(buf, size_of::<c_time>() + size_of::<c_long>());
        writer.write::<c_time>(tv_sec.try_into().unwrap())?;
        writer.write::<c_long>(tv_nsec.try_into().unwrap())?;

        Ok(0)
    }

    pub fn sys_gettimeofday(&mut self, tv: Option<UserVAddr>) -> Result<isize> {
        if let Some(buf) = tv {
            let now = read_wall_clock();
            let mut writer =
                UserBufWriter::from_uaddr(buf, size_of::<c_time>() + size_of::<c_long>());
            writer.write::<c_time>(now.secs_from_epoch().try_into().unwrap())?;
            writer.write::<c_long>((now.nanosecs_from_epoch() / 1000).try_into().unwrap())?;
        }
        Ok(0)
    }
}
