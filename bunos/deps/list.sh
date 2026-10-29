#!/usr/bin/env bash
# Print the package names of the committed dependency lists (comments and ambiguous virtuals dropped).
set -eu
cd "$(dirname "$0")"
for p in "$@"; do cat "$p.txt"; done | grep -v '^#' | grep -vx 'opengl-driver' | sort -u
