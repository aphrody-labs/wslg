#!/usr/bin/env bash
# Print the depends + makedepends of Arch packages (bare names, no version operators),
# read from the packaging repo's PKGBUILD. Packages named on the command line that start
# with an excluded prefix are dropped so the pinned source builds replace them.
# usage: arch-deps.sh hyprland aquamarine ...
set -euo pipefail
for pkg in "$@"; do
  f=$(mktemp)
  curl -fsSL "https://gitlab.archlinux.org/archlinux/packaging/packages/${pkg}/-/raw/main/PKGBUILD" -o "$f"
  # Sourcing in a subshell: PKGBUILDs only define arrays/functions at top level.
  ( set +eu; source "$f" >/dev/null 2>&1; printf '%s\n' "${depends[@]}" "${makedepends[@]}" )
  rm -f "$f"
done | sed -E 's/[<>=:].*$//' | grep -vE '^(hypr|aquamarine$|xorg-xwayland$|weston$)' | grep -v '^$' | sort -u
