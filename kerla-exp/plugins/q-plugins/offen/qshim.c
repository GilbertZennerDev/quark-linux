/* qshim: ersetzt Systemaufrufe, die Kerla nicht kennt, durch harmlose Antworten (per LD_PRELOAD) */
struct pollfd { int fd; short events, revents; };
int poll(struct pollfd *f, unsigned long n, int t) { return 0; }
