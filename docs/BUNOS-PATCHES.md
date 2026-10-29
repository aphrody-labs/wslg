# BunOS patch queue for WSLg

This fork (`aphrody-labs/wslg`) tracks `microsoft/wslg` `main` (base `6942bb534b53`, 2026-10-29,
identical to upstream when the queue was started). Everything BunOS adds sits on top as a
small, ordered set of commits, exported as `git format-patch` files in [`patches/`](../patches).
Nothing here was run on WSL; WSL was never started. Evidence comes from source reading and from
containers on `ubuntu-latest` (workflow `.github/workflows/bunos-wslg.yml`).

## Patch queue

`patches/series` lists the files in apply order. Regenerate with `bunos/regen-patches.sh`.

| # | Subject | Touches | Why |
|---|---|---|---|
| 1 | WSLGd: `WSL2_COMPOSITOR` switch | `WSLGd/main.cpp`, `WSLGd/Compositor.h`, `WSLGd/tests/`, `WSLGd/meson.build`, `config/hyprland-*.lua`, `Dockerfile` (two COPY lines) | `weston` (default, upstream behaviour) \| `hyprland-nested` \| `hyprland-headless` |
| 2 | bunos: source stack and probes | `bunos/**`, `.gitattributes` | Weston 16.0.2, Xwayland 24.1.14, Hyprland 0.57.0 chain from source on Arch; headless probes; aquamarine patch; static protocol evidence |
| 3 | build-and-export.sh | `build-and-export.sh` | `BUILDER=docker\|podman`; PulseAudio `.tarball-version` (observed failure of the stock recipe) |
| 4 | ci workflow | `.github/workflows/bunos-wslg.yml` | unit test, source-stack probes, system distro tar + VHD |

Not in the queue on purpose: any change to the vendored Weston/FreeRDP/PulseAudio/Mesa trees.
They are cloned at build time from Microsoft's `*-mirror` `working` branches (see
`CONTRIBUTING.md`) and are untouched, so the queue never conflicts with them.

## Rebase procedure (mechanical)

```sh
git remote add upstream https://github.com/microsoft/wslg   # once
git fetch upstream main
git rebase upstream/main            # conflicts can only be in Dockerfile (2 lines), WSLGd/main.cpp, build-and-export.sh
bunos/check-versions.sh             # every pin in bunos/versions.env still resolves to its recorded SHA
bunos/regen-patches.sh              # rewrites patches/ and patches/series from upstream/main..HEAD
git push origin main                # normal push, never force
```

Bumping a pin: edit `bunos/versions.env` (tag and peeled SHA together), run
`bunos/check-versions.sh`, then the workflow. The aquamarine patch
(`bunos/patches/aquamarine-0001-*.patch`) is applied with `git apply` in `bunos/Dockerfile`; a
failed apply on a new aquamarine tag is the signal to re-read `src/backend/Wayland.cpp`.

## Component pins (verified 2026-10-29)

| Component | Pin | Source of the pin |
|---|---|---|
| Weston (modern, probes) | 16.0.2 `530ae6c769d2` | `git ls-remote` gitlab.freedesktop.org/wayland/weston |
| Xwayland | xwayland-24.1.14 `d958b4e84c90` | `git ls-remote` gitlab.freedesktop.org/xorg/xserver (stable line; 26.0.99.90x are release candidates) |
| Hyprland | v0.57.0 `0aa6745f705f` | `gh api releases/latest`, published 2026-10-28 |
| aquamarine | v0.15.1 `f31c47a1b9d3` | releases/latest, 2026-09-17 |
| hyprutils / hyprlang / hyprcursor / hyprgraphics | v0.14.3 / v0.6.8 / v0.1.13 / v0.5.1 | tags, and Hyprland `CMakeLists.txt` minimums |
| hyprwayland-scanner / hyprland-protocols | v0.4.6 / v0.8.0 | tags |
| Stock WSLg Weston | `microsoft/weston-mirror` `working` `7fbf69314f8a` (version string 9.0.0, 2026-09-10) | `gh api` |
| Not bumped | FreeRDP-mirror `working` `f31f15e7cc3d` (FreeRDP 2.x API), mesa-23.1.0, PulseAudio-mirror `c33051f2296a` | upstream newest seen: FreeRDP 3.32.2, mesa-26.2.6 |

Note: the task brief asked for "weston 14/15"; the newest tag is 16.0.2 (15.0.x and 16.0.0 to
16.0.2 exist). 16.0.2 is what is pinned.

## Compositor switch

`WSL2_COMPOSITOR` is read by WSLGd after `.wslgconfig` `[system-distro-env]` is applied, so it
can be set from Windows in `%USERPROFILE%\.wslgconfig`:

```ini
[system-distro-env]
WSL2_COMPOSITOR=hyprland-nested
```

* `weston` (default or unset): unchanged upstream behaviour.
* `hyprland-nested`: Weston RDP/RAIL starts exactly as before (it owns the RDP connection,
  PulseAudio sinks and the app list). Then `dbus-run-session -- Hyprland --config
  /etc/wslg/hyprland-nested.lua` starts as user `wslg` with `WAYLAND_DISPLAY=wayland-0`, listens
  on `wayland-1`.
* `hyprland-headless`: same, but `WAYLAND_DISPLAY` is removed from Hyprland's environment so
  aquamarine does not select its Wayland backend, and the config creates a headless output.
  There is no RDP bridge: the output is reachable only through screencopy from inside the
  system distro.
* Anything else: logged, falls back to `weston`. A Hyprland mode also falls back to `weston`,
  with a log line, when `/usr/bin/Hyprland` is missing or `/dev/dri` has no `renderD*` node.

The stock system-distro image has no Hyprland binary, so in it the Hyprland modes fall back
to `weston` at start. Hyprland ships in the `bunos` source-stack image only.

## Unverified / not built

See the "Status" section at the bottom of `docs/WSLG.md` in `aphrody-labs/bun-os` for the
dated, evidence-backed list. In short: no run on WSL, no `bunos` Arch system distro, no Weston
RAIL port, no RDP bridge for Hyprland.
