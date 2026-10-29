#!/usr/bin/env python3
"""Static extraction of the wl_global_create() interfaces and versions of a Weston source tree.
usage: extract-weston-globals.py <weston-checkout> <label> > globals.json
Versions are resolved when they are an integer literal, a #define in the same file or
MIN(x.version, N). Anything else is reported as a string (e.g. "max_version" = runtime choice)."""
import json, os, re, subprocess, sys

root, label = sys.argv[1], sys.argv[2]
call = re.compile(r'wl_global_create\s*\(\s*[\w>\-\.]+\s*,\s*&(\w+)_interface\s*,\s*((?:MIN\s*\([^)]*\)|[\w]+))', re.S)
out = {}
for d, _, files in os.walk(root):
    parts = d.split(os.sep)
    if '.git' in parts or 'tests' in parts:
        continue
    for f in files:
        if not f.endswith('.c'):
            continue
        p = os.path.join(d, f)
        s = open(p, errors='ignore').read()
        defs = dict(re.findall(r'#\s*define\s+(\w+)\s+(\d+)\b', s))
        for m in call.finditer(s):
            iface, v = m.group(1), re.sub(r'\s+', ' ', m.group(2))
            mm = re.match(r'MIN\s*\(.*,\s*(\d+)\s*\)', v)
            if mm:
                v = mm.group(1)
            v = defs.get(v, v)
            out[iface] = int(v) if v.isdigit() else v
sha = subprocess.run(['git', '-C', root, 'rev-parse', 'HEAD'], capture_output=True, text=True).stdout.strip()
json.dump({'label': label, 'commit': sha, 'globals': dict(sorted(out.items()))}, sys.stdout, indent=1)
print()
