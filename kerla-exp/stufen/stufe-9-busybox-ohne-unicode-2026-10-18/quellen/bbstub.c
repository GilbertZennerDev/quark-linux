/* Schlanke Ersatzteile fuer musl: nur ASCII. Sie schlagen beim Linken die libc-Versionen
   und verhindern, dass fnmatch die Unicode-Tabellen (iswctype/towctrans) und strtod die
   Kommazahl-Maschine (floatscan) nachzieht. */
#include <fnmatch.h>
#include <stdlib.h>
#include <string.h>

static int cls(const char **pp, int c) {           /* [:alpha:] usw., *pp zeigt hinter "[:" */
	const char *p = *pp, *e = strstr(p, ":]");
	if (!e) return -1;
	size_t n = e - p; *pp = e + 2;
	int a = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z'), d = c >= '0' && c <= '9';
	if (n == 5 && !strncmp(p, "alpha", 5)) return a;
	if (n == 5 && !strncmp(p, "digit", 5)) return d;
	if (n == 5 && !strncmp(p, "alnum", 5)) return a || d;
	if (n == 5 && !strncmp(p, "upper", 5)) return c >= 'A' && c <= 'Z';
	if (n == 5 && !strncmp(p, "lower", 5)) return c >= 'a' && c <= 'z';
	if (n == 5 && !strncmp(p, "space", 5)) return c == ' ' || (c >= 9 && c <= 13);
	if (n == 5 && !strncmp(p, "punct", 5)) return c > 32 && c < 127 && !a && !d;
	if (n == 6 && !strncmp(p, "xdigit", 6)) return d || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
	return 0;
}

int fnmatch(const char *p, const char *s, int flags) {
	for (; *p; p++, s++) {
		if (*p == '*') {
			while (*p == '*') p++;
			if (!*p) return 0;
			for (; *s; s++) if (!fnmatch(p, s, flags)) return 0;
			return FNM_NOMATCH;
		}
		if (!*s) return FNM_NOMATCH;
		if (*p == '?') continue;
		if (*p == '[') {
			const char *q = p + 1; int neg = 0, ok = 0, c = (unsigned char)*s, first = 1;
			if (*q == '!' || *q == '^') { neg = 1; q++; }
			for (; *q && (*q != ']' || first); first = 0) {
				if (q[0] == '[' && q[1] == ':') { q += 2; int r = cls(&q, c); if (r < 0) return FNM_NOMATCH; ok |= r; continue; }
				int lo = (unsigned char)*q++;
				if (*q == '-' && q[1] && q[1] != ']') { int hi = (unsigned char)q[1]; q += 2; if (c >= lo && c <= hi) ok = 1; }
				else if (c == lo) ok = 1;
			}
			if (*q != ']') return FNM_NOMATCH;
			if (ok == neg) return FNM_NOMATCH;
			p = q; continue;
		}
		if (*p == 92 && !(flags & FNM_NOESCAPE) && p[1]) p++;
		if (*p != *s) return FNM_NOMATCH;
	}
	return *s ? FNM_NOMATCH : 0;
}

double strtod(const char *s, char **e) { return (double)strtol(s, e, 10); }
