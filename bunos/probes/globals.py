#!/usr/bin/env python3
"""Parse `wayland-info` output into {interface: version} JSON.  usage: globals.py < wayland-info.txt"""
import json, re, sys
out = {}
for line in sys.stdin:
    m = re.match(r"\s*interface:\s*'([^']+)',\s*version:\s*(\d+)", line)
    if m:
        out[m.group(1)] = int(m.group(2))
json.dump(dict(sorted(out.items())), sys.stdout, indent=1)
print()
