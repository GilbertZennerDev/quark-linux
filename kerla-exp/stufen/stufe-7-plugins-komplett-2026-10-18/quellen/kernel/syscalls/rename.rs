use crate::fs::path::Path;
use crate::result::Result;
use crate::{
    process::current_process,
    syscalls::{CwdOrFd, SyscallHandler},
};

impl<'a> SyscallHandler<'a> {
    pub fn sys_rename(&mut self, src: &Path, dst: &Path) -> Result<isize> {
        self.sys_renameat(CwdOrFd::AtCwd, src, CwdOrFd::AtCwd, dst)
    }

    /// Umbenennen = Eintrag im Zielverzeichnis anlegen (link) und den alten entfernen (unlink).
    pub fn sys_renameat(
        &mut self,
        src_dir: CwdOrFd,
        src_path: &Path,
        dst_dir: CwdOrFd,
        dst_path: &Path,
    ) -> Result<isize> {
        let current = current_process();
        let root_fs = current.root_fs().lock();
        let opened_files = current.opened_files().lock();

        let src = root_fs.lookup_path_at(&opened_files, &src_dir, src_path, false)?;
        let (src_parent, src_name) =
            root_fs.lookup_parent_path_at(&opened_files, &src_dir, src_path, true)?;
        let (dst_parent, dst_name) =
            root_fs.lookup_parent_path_at(&opened_files, &dst_dir, dst_path, true)?;

        // Gleicher Ort und gleicher Name: nichts zu tun.
        if src_name == dst_name
            && src_parent.inode.stat()?.inode_no.as_u64()
                == dst_parent.inode.stat()?.inode_no.as_u64()
        {
            return Ok(0);
        }

        let dst_dir_inode = dst_parent.inode.as_dir()?;
        // Ein vorhandenes Ziel wird ersetzt (wie bei POSIX rename).
        let _ = dst_dir_inode.unlink(dst_name);
        dst_dir_inode.link(dst_name, &src.inode)?;
        src_parent.inode.as_dir()?.unlink(src_name)?;
        Ok(0)
    }
}
