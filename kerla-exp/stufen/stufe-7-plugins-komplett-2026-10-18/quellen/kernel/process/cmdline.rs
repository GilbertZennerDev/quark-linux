use arrayvec::ArrayString;

#[derive(Clone)]
pub struct Cmdline {
    cmdline: ArrayString<128>,
    argv0: ArrayString<128>,
}

impl Cmdline {
    pub fn new() -> Cmdline {
        Cmdline {
            cmdline: ArrayString::new(),
            argv0: ArrayString::new(),
        }
    }

    pub fn from_argv(argv: &[&[u8]]) -> Cmdline {
        let mut cmdline = Cmdline::new();
        cmdline.set_by_argv(argv);
        cmdline
    }

    pub fn as_str(&self) -> &str {
        &self.cmdline
    }

    pub fn argv0(&self) -> &str {
        &self.argv0
    }

    pub fn set_by_argv(&mut self, argv: &[&[u8]]) {
        self.cmdline.clear();
        for (i, arg) in argv.iter().enumerate() {
            let _ = self
                .cmdline
                .try_push_str(core::str::from_utf8(arg).unwrap_or("[invalid utf-8]"));
            if i != argv.len() - 1 {
                let _ = self.cmdline.try_push(' ');
            }
        }

        self.argv0.clear();
        let _ = self.argv0.try_push_str(self.cmdline.split(' ').next().unwrap());
    }
}
