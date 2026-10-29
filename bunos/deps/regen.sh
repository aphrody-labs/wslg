#!/usr/bin/env bash
# Regenerate bunos/deps/*.txt from the Arch packaging PKGBUILDs (depends + makedepends, bare names).
# CI does not call this: gitlab.archlinux.org may challenge datacenter IPs, so the lists are committed.
set -euo pipefail
cd "$(dirname "$0")"
for pkg in xorg-xwayland weston hyprland aquamarine hyprcursor hyprgraphics hyprlang hyprutils hyprwayland-scanner; do
  curl -fsSL "https://gitlab.archlinux.org/archlinux/packaging/packages/${pkg}/-/raw/main/PKGBUILD" -o /tmp/PKGBUILD.$pkg
  ver=$( ( set +eu; source /tmp/PKGBUILD.$pkg >/dev/null 2>&1; echo "$pkgver-$pkgrel" ) )
  { echo "# Arch $pkg $ver depends+makedepends, $(date -u +%F)"; ../arch-deps.sh "$pkg"; } > "$pkg.txt"
  echo "$pkg $ver $(wc -l < "$pkg.txt") lines"
done
