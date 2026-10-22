import re
def rw(p, f):
    raw = open(p, encoding='utf-8', newline='').read()
    s = re.sub(r'\r\n', '\n', raw)
    t = f(s)
    print(p, 'geaendert' if t != s else 'UNVERAENDERT')
    open(p, 'w', encoding='utf-8', newline='').write(re.sub(r'\n', '\r\n', t))

rw('fs/stat.rs', lambda s: s.replace("pub const S_IFCHR: u32 = 0o020000;\n", "pub const S_IFCHR: u32 = 0o020000;\npub const S_IFIFO: u32 = 0o010000;\n"))
rw('fs/inode.rs', lambda s: s.replace("fn ioctl(&self, _cmd: usize, _arg: usize) -> Result<isize> {\n        Err(Error::new(Errno::EBADF))", "fn ioctl(&self, _cmd: usize, _arg: usize) -> Result<isize> {\n        Err(Error::new(Errno::ENOTTY))"))

ST = '''    fn stat(&self) -> Result<Stat> {
        Ok(Stat {
            inode_no: INodeNo::new(4),
            mode: FileMode::new(S_IFIFO | 0o600),
            ..Stat::zeroed()
        })
    }

'''

def pf(s):
    s = s.replace("        inode::{FileLike, PollStatus},\n        opened_file::OpenOptions,\n", "        inode::{FileLike, INodeNo, PollStatus},\n        opened_file::OpenOptions,\n        stat::{FileMode, Stat, S_IFIFO},\n")
    s = s.replace("impl FileLike for PipeReader {\n", "impl FileLike for PipeReader {\n" + ST, 1)
    s = s.replace("impl FileLike for PipeWriter {\n", "impl FileLike for PipeWriter {\n" + ST, 1)
    return s

rw('pipe.rs', pf)
