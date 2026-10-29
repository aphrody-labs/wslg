#!/usr/bin/env python3
"""Generate docs/BUNOS-PATCHES.md from the committed evidence. usage: gen-doc.py <matrix.md> <out.md>
The probe table and run ids are written by hand in TEMPLATE below when new CI evidence exists."""
import sys

matrix = open(sys.argv[1]).read()
cls = open('bunos/evidence/rail-port-classification.tsv').read().splitlines()
rows = [l.split('\t') for l in cls if l and not l.startswith('#')]
exists = [r[0] for r in rows if 'PATH EXISTS' in r[2]]
absent = [r[0] for r in rows if 'absent' in r[2]]
gone = [r[0] for r in rows if 'gone' in r[2]]
mod = [r for r in rows if r[1] == 'modified' and 'hunks' in r[2]]


def fr(r):
    a, b = r[2].split()[0].split('/')
    return int(a), int(b)


ok = sum(fr(r)[0] for r in mod)
tot = sum(fr(r)[1] for r in mod)
clean = [r[0] for r in mod if fr(r)[0] == fr(r)[1]]
heavy = sorted(mod, key=lambda r: -(fr(r)[1] - fr(r)[0]))[:6]
heavy_s = ', '.join('%s (%s)' % (r[0], r[2].split()[0]) for r in heavy)

tpl = open('bunos/evidence/BUNOS-PATCHES.template.md').read()
out = (tpl.replace('@MATRIX@', matrix)
       .replace('@ABSENT_N@', str(len(absent))).replace('@ABSENT@', ', '.join(absent))
       .replace('@EXISTS_N@', str(len(exists))).replace('@EXISTS@', ', '.join(exists))
       .replace('@GONE_N@', str(len(gone))).replace('@GONE@', ', '.join(gone))
       .replace('@HUNKS_OK@', str(ok)).replace('@HUNKS_TOT@', str(tot))
       .replace('@HEAVY@', heavy_s).replace('@CLEAN@', ', '.join(clean)))
open(sys.argv[2], 'w', newline='\n').write(out)
print('wrote', sys.argv[2], len(out))
