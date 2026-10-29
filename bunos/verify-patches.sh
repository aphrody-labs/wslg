#!/usr/bin/env bash
# Apply patches/ with `git am` on top of the current microsoft/wslg main in a scratch clone.
# A failure means upstream moved and the queue needs a rebase (docs/BUNOS-PATCHES.md).
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
git clone -q --depth 1 https://github.com/microsoft/wslg "$tmp"
git -C "$tmp" log -1 --format='upstream main: %H'
git -C "$tmp" -c user.name=ci -c user.email=ci@invalid am --quiet "$here"/patches/*.patch
echo "all $(wc -l < "$here/patches/series") patches apply"
