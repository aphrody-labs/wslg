#!/usr/bin/env bash
# BunOS protocol / compositor probes. Runs headless in the bunos image, needs no WSL and no GPU.
# Writes $OUT/report.tsv (name<TAB>status<TAB>detail), logs and JSON next to it.
# status is one of: pass, fail, skipped. Nothing is reported as pass unless the command ran.
set -u
OUT=${OUT:-/out}
mkdir -p "$OUT"
HERE=$(cd "$(dirname "$0")" && pwd)
REPORT=$OUT/report.tsv
: >"$REPORT"
rec() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" | tee -a "$REPORT" >&2; }

export XDG_RUNTIME_DIR=$(mktemp -d); chmod 700 "$XDG_RUNTIME_DIR"
unset WAYLAND_DISPLAY DISPLAY
PIDS=()
cleanup() {
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done
  pkill -u "$(id -u)" Xwayland 2>/dev/null
  true
}
trap cleanup EXIT

wait_socket() { # name seconds
  local i
  for ((i = 0; i < $2 * 10; i++)); do
    [ -S "$XDG_RUNTIME_DIR/$1" ] && return 0
    sleep 0.1
  done
  return 1
}
globals_of() { # display name
  WAYLAND_DISPLAY=$1 wayland-info 2>"$OUT/$2.err" | tee "$OUT/$2.txt" | python3 "$HERE/globals.py" >"$OUT/$2.json"
}
json_has() { python3 -c "import json,sys; sys.exit(0 if sys.argv[2] in json.load(open(sys.argv[1])) else 1)" "$1" "$2"; }

# ---- P0 versions -----------------------------------------------------------------------
{
  echo "weston: $(weston --version 2>&1)"
  echo "Xwayland: $(Xwayland -version 2>&1 | head -1) path=$(command -v Xwayland)"
  echo "Hyprland: $(Hyprland --version 2>&1 | head -2 | tr '\n' ' ')"
  for m in aquamarine hyprutils hyprlang hyprcursor hyprgraphics wayland-server wayland-protocols freerdp3 egl; do
    echo "$m: $(pkg-config --modversion $m 2>&1)"
  done
  echo "kernel: $(uname -sr)"
} >"$OUT/versions.txt" 2>&1
if command -v weston >/dev/null; then rec versions pass "see versions.txt"; else rec versions fail "weston missing"; fi

# ---- P1 weston 16 headless, pixman renderer, Xwayland ----------------------------------
weston --backend=headless --renderer=pixman --socket=bunos-pixman --width=1280 --height=720 \
  --xwayland --log="$OUT/weston-pixman.log" >"$OUT/weston-pixman.stdout" 2>&1 &
WPID=$!
PIDS+=("$WPID")
if wait_socket bunos-pixman 20; then
  globals_of bunos-pixman wayland-info-weston16-pixman
  n=$(python3 -c "import json;print(len(json.load(open('$OUT/wayland-info-weston16-pixman.json'))))")
  if [ "$n" -gt 5 ]; then rec weston16-headless-pixman pass "$n globals"; else rec weston16-headless-pixman fail "only $n globals"; fi
  command -v weston-info >"$OUT/weston-info-path.txt" 2>&1 || ls /usr/local/bin | grep -i info >>"$OUT/weston-info-path.txt"
  if WAYLAND_DISPLAY=bunos-pixman timeout 10 weston-info >"$OUT/weston-info.txt" 2>&1 && [ -s "$OUT/weston-info.txt" ]; then
    rec weston-info pass "$(grep -c 'interface:' "$OUT/weston-info.txt") interface lines"
  else
    rec weston-info fail "weston-info failed or empty: $(head -c 200 "$OUT/weston-info.txt" 2>/dev/null) path=$(tr "
" " " <"$OUT/weston-info-path.txt")"
  fi
else
  rec weston16-headless-pixman fail "socket never appeared; see weston-pixman.log"
fi

# ---- P2 Xwayland rootless + xwayland-shell ---------------------------------------------
disp=$(grep -o 'xserver listening on display :[0-9]*' "$OUT/weston-pixman.log" 2>/dev/null | grep -o ':[0-9]*$' | head -1)
if [ -n "${disp:-}" ]; then
  timeout 20 xdpyinfo -display "$disp" >"$OUT/xdpyinfo.txt" 2>&1
  rc=$?
  if [ $rc -eq 0 ]; then
    rec xwayland-xdpyinfo pass "display $disp: $(grep -m1 'vendor release number' "$OUT/xdpyinfo.txt" | tr -s ' ')"
  else
    rec xwayland-xdpyinfo fail "xdpyinfo rc=$rc"
  fi
  args=$(pgrep -u "$(id -u)" -a Xwayland | head -1)
  echo "$args" >"$OUT/xwayland-cmdline.txt"
  case "$args" in
    *-rootless*) rec xwayland-rootless pass "$args" ;;
    *) rec xwayland-rootless fail "${args:-no Xwayland process}" ;;
  esac
  globals_of bunos-pixman wayland-info-weston16-pixman-after-x
  if json_has "$OUT/wayland-info-weston16-pixman-after-x.json" xwayland_shell_v1; then
    rec xwayland-shell-v1 pass "global offered after Xwayland started"
  else
    rec xwayland-shell-v1 fail "xwayland_shell_v1 not offered"
  fi
else
  rec xwayland-xdpyinfo fail "weston did not log an X display"
  rec xwayland-rootless skipped "no X display"
  rec xwayland-shell-v1 skipped "no X display"
fi

# ---- P3 client: weston-simple-shm ------------------------------------------------------
WAYLAND_DISPLAY=bunos-pixman timeout 4 weston-simple-shm >"$OUT/simple-shm.log" 2>&1
rc=$?
if [ $rc -eq 124 ]; then rec weston-simple-shm pass "client stayed connected for 4 s"; else rec weston-simple-shm fail "rc=$rc: $(head -c 200 "$OUT/simple-shm.log")"; fi

# ---- P4 compat tables (data, computed from the live globals) ---------------------------
f=wayland-info-weston16-pixman-after-x
if [ -s "$OUT/$f.json" ]; then
  python3 "$HERE/compat.py" aquamarine "$OUT/$f.json" "$HERE/aquamarine-requirements.json" >"$OUT/aquamarine-compat-weston16.tsv"
  python3 "$HERE/compat.py" checklist "$OUT/$f.json" "$HERE/checklist.json" >"$OUT/checklist-weston16.tsv"
  rec compat-tables pass "tables written; $(tail -1 "$OUT/aquamarine-compat-weston16.tsv" | tr '\t' ' ') (aquamarine)"
else
  rec compat-tables fail "no globals JSON"
fi
kill "$WPID" 2>/dev/null
wait "$WPID" 2>/dev/null
pkill -u "$(id -u)" Xwayland 2>/dev/null

# ---- P5 weston 16 headless, GL renderer (EGL surfaceless) ------------------------------
weston --backend=headless --renderer=gl --socket=bunos-gl --width=1280 --height=720 \
  --log="$OUT/weston-gl.log" >"$OUT/weston-gl.stdout" 2>&1 &
GPID=$!
PIDS+=("$GPID")
if wait_socket bunos-gl 20; then
  globals_of bunos-gl wayland-info-weston16-gl
  dv=$(python3 -c "import json;print(json.load(open('$OUT/wayland-info-weston16-gl.json')).get('zwp_linux_dmabuf_v1','-'))")
  rec weston16-headless-gl pass "zwp_linux_dmabuf_v1 version $dv"
else
  rec weston16-headless-gl fail "$(grep -h -m1 -i 'error\|fail' "$OUT/weston-gl.log" "$OUT/weston-gl.stdout" 2>/dev/null | head -1)"
fi

# ---- P6 upstream rdp-backend smoke (full desktop, no RAIL) -----------------------------
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$OUT/rdp.key" -out "$OUT/rdp.crt" -days 1 -subj /CN=bunos >/dev/null 2>&1
weston --backend=rdp --renderer=pixman --socket=bunos-rdp --port=33890 \
  --rdp-tls-key="$OUT/rdp.key" --rdp-tls-cert="$OUT/rdp.crt" \
  --log="$OUT/weston-rdp.log" >"$OUT/weston-rdp.stdout" 2>&1 &
RPID=$!
PIDS+=("$RPID")
sleep 3
if (exec 3<>/dev/tcp/127.0.0.1/33890) 2>/dev/null; then
  rec weston16-rdp-backend pass "listens on 127.0.0.1:33890 (FreeRDP $(pkg-config --modversion freerdp3 2>/dev/null))"
else
  rec weston16-rdp-backend fail "port 33890 closed; $(grep -h -m1 -i 'error\|fail' "$OUT/weston-rdp.log" "$OUT/weston-rdp.stdout" 2>/dev/null | head -1)"
fi
kill "$RPID" 2>/dev/null
rm -f "$OUT/rdp.key" "$OUT/rdp.crt"

# ---- P7 Hyprland binaries --------------------------------------------------------------
if out=$(Hyprland --version 2>&1) && [ -n "$out" ]; then rec hyprland-binary pass "$(echo "$out" | head -1)"; else rec hyprland-binary fail "Hyprland --version failed"; fi
if command -v hyprctl >/dev/null && hyprctl --help >"$OUT/hyprctl-help.txt" 2>&1 && grep -qi "usage" "$OUT/hyprctl-help.txt"; then rec hyprctl-binary pass "$(command -v hyprctl); help printed"; else rec hyprctl-binary fail "hyprctl missing or no usage text: $(head -c 150 "$OUT/hyprctl-help.txt" 2>/dev/null)"; fi

# ---- P8 Hyprland nested on Weston 16 (observed; aquamarine clamp patch applied) --------
ls -l /dev/dri >"$OUT/dev-dri.txt" 2>&1
if [ -S "$XDG_RUNTIME_DIR/bunos-gl" ]; then
  WAYLAND_DISPLAY=bunos-gl timeout 25 Hyprland --config /etc/wslg/hyprland-nested.lua >"$OUT/hyprland-nested.stdout" 2>&1
  hrc=$?
  cp "$XDG_RUNTIME_DIR"/hypr/*/hyprland.log "$OUT/hyprland-nested.log" 2>/dev/null
  # 124 = still running when timeout fired: the compositor started and stayed up.
  if [ $hrc -eq 124 ]; then
    rec hyprland-nested-on-weston16 pass "Hyprland ran 25 s against host bunos-gl"
  else
    rec hyprland-nested-on-weston16 fail "rc=$hrc: $(grep -h -m2 -i 'cannot\|fail\|error\|missing\|invalid' "$OUT/hyprland-nested.stdout" "$OUT/hyprland-nested.log" 2>/dev/null | head -2 | tr '\n' ' ')"
  fi
else
  rec hyprland-nested-on-weston16 skipped "weston GL host did not start"
fi
kill "$GPID" 2>/dev/null

# ---- P9 Hyprland headless (needs a DRM render node) ------------------------------------
if ls /dev/dri/renderD* >/dev/null 2>&1; then
  (
    unset WAYLAND_DISPLAY
    timeout 25 Hyprland --config /etc/wslg/hyprland-headless.lua >"$OUT/hyprland-headless.stdout" 2>&1
  ) &
  HP=$!
  PIDS+=("$HP")
  ok=0
  sig=""
  for i in $(seq 1 100); do
    sig=$(ls "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
    if [ -n "$sig" ] && HYPRLAND_INSTANCE_SIGNATURE=$sig hyprctl version >"$OUT/hyprctl-version.txt" 2>&1; then
      ok=1
      break
    fi
    sleep 0.2
  done
  if [ $ok -eq 1 ]; then
    export HYPRLAND_INSTANCE_SIGNATURE=$sig
    hyprctl monitors >"$OUT/hyprctl-monitors.txt" 2>&1
    sock=$(ls "$XDG_RUNTIME_DIR" | grep -m1 '^wayland-[0-9]*$')
    globals_of "$sock" wayland-info-hyprland
    wlr-randr >"$OUT/wlr-randr.txt" 2>&1
    python3 "$HERE/compat.py" checklist "$OUT/wayland-info-hyprland.json" "$HERE/checklist.json" >"$OUT/checklist-hyprland.tsv"
    rec hyprland-headless pass "hyprctl answered: $(head -1 "$OUT/hyprctl-version.txt"); wlr-randr output $(grep -c . "$OUT/wlr-randr.txt") lines"
  else
    rec hyprland-headless fail "no hyprctl answer in 20 s; $(grep -h -m2 -i 'cannot\|fail\|critical' "$OUT/hyprland-headless.stdout" | head -2 | tr '\n' ' ')"
  fi
else
  rec hyprland-headless skipped "no /dev/dri/renderD* in this container (aquamarine needs a DRM render node for its GBM allocator)"
fi

echo "---- report ----" >&2
cat "$REPORT" >&2
fails=$(awk -F'\t' '$2=="fail"' "$REPORT" | wc -l)
# Probe failures are findings, not harness errors: exit non-zero only if the harness itself broke.
[ -s "$REPORT" ] || exit 2
exit 0
