import re
def rw(p, f):
    raw = open(p, encoding='utf-8', newline='').read()
    s = re.sub(r'\r\n', '\n', raw)
    t = f(s)
    print(p, 'geaendert' if t != s else 'UNVERAENDERT')
    open(p, 'w', encoding='utf-8', newline='').write(re.sub(r'\n', '\r\n', t))
def sg(s):
    s = s.replace("pub enum SigAction {\n    Ignore,\n", "pub enum SigAction {\n    Ignore,\n    /// Standardaktion von SIGCHLD: nichts tun, Kinder bleiben aber waitbar.\n    DefaultIgnore,\n")
    s = s.replace("    /* SIGCHLD */ SigAction::Ignore,", "    /* SIGCHLD */ SigAction::DefaultIgnore,")
    return s
rw('process/signal.rs', sg)
rw('process/process.rs', lambda s: s.replace("                    SigAction::Ignore => {}\n", "                    SigAction::Ignore | SigAction::DefaultIgnore => {}\n"))
