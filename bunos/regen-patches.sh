#!/usr/bin/env bash
# Regenerate patches/ (git format-patch series) from upstream/main..HEAD.
# Commits and hunks that only touch patches/ or the patch-queue docs are excluded, so the
# series describes the code changes only. usage: bunos/regen-patches.sh [base-ref]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
base=${1:-upstream/main}
git rev-parse --verify -q "$base" >/dev/null || { echo "missing $base; git fetch upstream main" >&2; exit 1; }
rm -rf patches
mkdir patches
git format-patch --no-signature --zero-commit -o patches "$base"..HEAD -- . \
  ':(exclude)patches' ':(exclude)docs/BUNOS-PATCHES.md' >/dev/null
( cd patches && ls -1 *.patch > series )
echo "wrote $(wc -l < patches/series) patches against $(git rev-parse --short "$base")"
cat patches/series
