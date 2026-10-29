#!/usr/bin/env python3
"""Compare a globals JSON (globals.py output) with a requirements/checklist JSON.
usage: compat.py aquamarine <globals.json> <aquamarine-requirements.json>
       compat.py checklist  <globals.json> <checklist.json>
Prints a TSV of name, required, offered, verdict. Exit 0 always; verdicts are data."""
import json, sys
mode, gpath, rpath = sys.argv[1:4]
g = json.load(open(gpath))
r = json.load(open(rpath))
want = r["required"] if mode == "aquamarine" else r["globals"]
fails = 0
for name, v in want.items():
    got = g.get(name, 0)
    ok = got >= v
    fails += 0 if ok else 1
    print(f"{name}\t{v}\t{got if got else '-'}\t{'ok' if ok else 'MISSING' if not got else 'TOO_OLD'}")
print(f"#missing_or_old\t{fails}\t{len(want)}")
