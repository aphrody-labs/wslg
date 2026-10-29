#!/usr/bin/env bash
# Verify that every pin in versions.env still resolves to the recorded SHA on its upstream.
# Network needed. Exit 1 on any mismatch.  usage: bunos/check-versions.sh
set -euo pipefail
cd "$(dirname "$0")"
. ./versions.env
declare -A URL=(
  [WESTON]=https://gitlab.freedesktop.org/wayland/weston.git
  [XWAYLAND]=https://gitlab.freedesktop.org/xorg/xserver.git
  [HYPRLAND]=https://github.com/hyprwm/Hyprland.git
  [AQUAMARINE]=https://github.com/hyprwm/aquamarine.git
  [HYPRUTILS]=https://github.com/hyprwm/hyprutils.git
  [HYPRLANG]=https://github.com/hyprwm/hyprlang.git
  [HYPRCURSOR]=https://github.com/hyprwm/hyprcursor.git
  [HYPRGRAPHICS]=https://github.com/hyprwm/hyprgraphics.git
  [HYPRWAYLAND_SCANNER]=https://github.com/hyprwm/hyprwayland-scanner.git
  [HYPRLAND_PROTOCOLS]=https://github.com/hyprwm/hyprland-protocols.git
  [WAYLAND]=https://gitlab.freedesktop.org/wayland/wayland.git
  [WAYLAND_PROTOCOLS]=https://gitlab.freedesktop.org/wayland/wayland-protocols.git
  [XWAYLAND_CANDIDATE]=https://gitlab.freedesktop.org/xorg/xserver.git
)
rc=0
for k in "${!URL[@]}"; do
  tag=${k}_TAG; sha=${k}_SHA
  got=$(git ls-remote "${URL[$k]}" "refs/tags/${!tag}^{}" "refs/tags/${!tag}" | tail -1 | cut -f1)
  if [ "$got" = "${!sha}" ]; then echo "ok   $k ${!tag} ${got:0:12}"; else echo "FAIL $k ${!tag} expected ${!sha} got ${got:-none}"; rc=1; fi
done
exit $rc
