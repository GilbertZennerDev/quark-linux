import re
def rw(p, f):
    raw = open(p, encoding='utf-8', newline='').read()
    s = re.sub(r'\r\n', '\n', raw)
    t = f(s)
    print(p, 'geaendert' if t != s else 'UNVERAENDERT')
    open(p, 'w', encoding='utf-8', newline='').write(re.sub(r'\n', '\r\n', t))
rw('fs/opened_file.rs', lambda s: s.replace("        const O_DIRECTORY = 0o200000;\n", "        const O_DIRECTORY = 0o200000;\n        const O_NOFOLLOW = 0o400000;\n"))
