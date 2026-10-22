import re
def rw(p, f):
    raw = open(p, encoding='utf-8', newline='').read()
    s = re.sub(r'\r\n', '\n', raw)
    t = f(s)
    print(p, 'geaendert' if t != s else 'UNVERAENDERT')
    open(p, 'w', encoding='utf-8', newline='').write(re.sub(r'\n', '\r\n', t))
def cg(s):
    s = s.replace("            CLOCK_REALTIME => {", "            // 5 = REALTIME_COARSE\n            CLOCK_REALTIME | 5 => {")
    s = s.replace("            CLOCK_MONOTONIC => {", "            // 2/3 = CPUTIME (grob als Monotonic), 4 = MONOTONIC_RAW, 6 = MONOTONIC_COARSE, 7 = BOOTTIME\n            CLOCK_MONOTONIC | 2 | 3 | 4 | 6 | 7 => {")
    return s
rw('syscalls/clock_gettime.rs', cg)
