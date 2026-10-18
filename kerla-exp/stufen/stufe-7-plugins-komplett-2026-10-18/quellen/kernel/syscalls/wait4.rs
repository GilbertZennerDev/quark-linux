use crate::{
    ctypes::*,
    prelude::*,
    process::{current_process, PId, ProcessState, JOIN_WAIT_QUEUE},
    syscalls::SyscallHandler,
};

use bitflags::bitflags;
use kerla_runtime::address::UserVAddr;

bitflags! {
    pub struct WaitOptions: c_int {
        const WNOHANG   = 1;
        const WUNTRACED = 2;
    }
}

impl<'a> SyscallHandler<'a> {
    pub fn sys_wait4(
        &mut self,
        pid: PId,
        status: Option<UserVAddr>,
        options: WaitOptions,
        _rusage: Option<UserVAddr>,
    ) -> Result<isize> {
        let (got_pid, status_value) = JOIN_WAIT_QUEUE.sleep_signalable_until(|| {
            let current = current_process();
            if !current.children().iter().any(|c| pid.as_i32() <= 0 || c.pid() == pid) {
                return Err(Errno::ECHILD.into());
            }
            for child in current.children().iter() {
                if pid.as_i32() > 0 && child.pid() != pid {
                    // Wait for the specific PID.
                    continue;
                }

                if pid.as_i32() == 0 {
                    // TODO: Wait for any children in the same process group.
                    todo!();
                }

                if let ProcessState::ExitedWith(status_value) = child.state() {
                    return Ok(Some((child.pid(), status_value)));
                }
            }

            if options.contains(WaitOptions::WNOHANG) {
                return Ok(Some((PId::new(0), 0)));
            }

            Ok(None)
        })?;

        // Evict the joined processs object.
        current_process().children().retain(|p| p.pid() != got_pid);

        if let Some(status) = status {
            // Linux-Format: Exit-Code in Bits 8..15 (Signal-Tod nicht abgebildet).
            status.write::<c_int>(&((status_value & 0xff) << 8))?;
        }
        Ok(got_pid.as_i32() as isize)
    }
}
