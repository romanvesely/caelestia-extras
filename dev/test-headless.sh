#!/bin/bash
# Tests a patched shell module in an invisible headless sway, so nothing pops up
# on the real monitors. The test QML must load only the module, e.g.
#   import "modules/cheatsheet"; import Quickshell; ShellRoot { Cheatsheet {} }
# Global shortcuts don't exist under sway, so the test copy can't steal any.
#
# usage: test-headless.sh <test.qml> <out-dir> <WxH> <scale> <step>...
# steps: open | close | toggle | search:<text> | sleep:<s> | shot:<name>
# example (DP-1): test-headless.sh copy/cstest.qml /tmp/out 2560x1440 1.25 open sleep:1.5 shot:dp1

set -euo pipefail

QML=$1 OUT=$2 MODE=$3 SCALE=$4
shift 4
mkdir -p "$OUT"
RUN=$(mktemp -d "$OUT/run.XXXX")
SOCK=$RUN/sway.sock
printf 'output * bg #202020 solid_color\n' >"$RUN/sway.conf"

env -u DISPLAY WLR_BACKENDS=headless WLR_LIBINPUT_NO_DEVICES=1 SWAYSOCK="$SOCK" \
    sway -c "$RUN/sway.conf" >"$RUN/sway.log" 2>&1 &
SWAY=$!
QS=
cleanup() {
    [ -n "$QS" ] && kill "$QS" 2>/dev/null
    kill "$SWAY" 2>/dev/null
    wait 2>/dev/null
    rm -rf "$RUN"
}
trap cleanup EXIT

for _ in $(seq 50); do [ -S "$SOCK" ] && break; sleep 0.1; done
DISP=$(swaymsg -s "$SOCK" -r -t get_outputs >/dev/null && ls -t "$XDG_RUNTIME_DIR" | grep -m1 -x 'wayland-[0-9]*')
# the socket sway created last is ours
export WAYLAND_DISPLAY=$DISP
swaymsg -s "$SOCK" -- output HEADLESS-1 mode --custom "${MODE}@60Hz" scale "$SCALE" >/dev/null

qs -p "$QML" >"$OUT/qs.log" 2>&1 &
QS=$!
sleep 3

ipc() { qs -p "$QML" ipc call cheatsheet "$@"; }
for step in "$@"; do
    case $step in
    open | close | toggle) ipc "$step" ;;
    search:*) ipc search "${step#search:}" ;;
    sleep:*) sleep "${step#sleep:}" ;;
    shot:*) grim -o HEADLESS-1 "$OUT/${step#shot:}.png" ;;
    *) echo "unknown step: $step" >&2; exit 1 ;;
    esac
done

grep -av -e DEBUG -e INFO -e 'GlobalShortcut' -e 'global_shortcuts' -e 'toplevel-mapping' "$OUT/qs.log" || true
