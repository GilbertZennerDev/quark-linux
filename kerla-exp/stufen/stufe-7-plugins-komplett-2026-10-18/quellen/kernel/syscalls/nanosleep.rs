use kerla_runtime::address::UserVAddr;

use crate::{
    poll::POLL_WAIT_QUEUE, prelude::*, syscalls::SyscallHandler, timer::read_monotonic_clock,
};

impl<'a> SyscallHandler<'a> {
    pub fn sys_nanosleep(&mut self, req: UserVAddr) -> Result<isize> {
        let sec = req.read::<i64>()?;
        let nsec = req.add(8).read::<i64>()?;
        let msecs = (sec as usize) * 1000 + (nsec as usize) / 1_000_000;
        let started_at = read_monotonic_clock();
        POLL_WAIT_QUEUE.sleep_signalable_until(|| {
            if started_at.elapsed_msecs() >= msecs {
                Ok(Some(0))
            } else {
                Ok(None)
            }
        })
    }
}
