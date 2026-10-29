#!/bin/bash
# Installs caelestia-extras features into caelestia-shell.
#
# usage: ./install.sh --list
#        sudo ./install.sh [--hook] <feature>...   install exactly these features
#        sudo ./install.sh --uninstall             remove all features again
#
# --hook also installs a pacman hook that re-applies the features after every
# caelestia-shell upgrade (Arch-based systems).
# Every change is tried on a copy of the shell first, so a feature that does not
# fit this shell version leaves the installed shell untouched.

set -euo pipefail

TARGET=${CAELESTIA_SHELL_DIR:-/etc/xdg/quickshell/caelestia}
DEST=${CAELESTIA_EXTRAS_DIR:-/usr/local/share/caelestia-extras}
HOOKS=${PACMAN_HOOKS_DIR:-/etc/pacman.d/hooks}
HOOK=$HOOKS/caelestia-extras.hook
SRC=$(dirname "$(readlink -f "$0")")

die() {
    echo "error: $*" >&2
    exit 1
}

describe() {
    case $1 in
    cheatsheet) echo "searchable keybind overview (needs a key bind, see README)" ;;
    bar-focused-workspace) echo "bar highlights the focused workspace across monitors (perMonitor off)" ;;
    bar-leftmost-only) echo "bar only on the leftmost screen" ;;
    lock-leftmost-only) echo "lock screen clock and password only on the leftmost screen" ;;
    *) echo "" ;;
    esac
}

shell_version() {
    pacman -Q caelestia-shell 2>/dev/null | cut -d' ' -f2 || echo "unknown"
}

created_files() {
    awk 'prev == "--- /dev/null" && /^\+\+\+ b\// { sub(/^\+\+\+ b\//, ""); sub(/\t.*/, ""); print } { prev = $0 }' "$1" |
        grep -v '\.\.'
}

# undo the installed features in <dir>; after a shell upgrade they may be gone already
revert_installed() {
    local dir=$1 p i
    local patches=("$DEST"/patches/*.patch)
    for ((i = ${#patches[@]} - 1; i >= 0; i--)); do
        p=${patches[i]}
        [ -e "$p" ] || continue
        if patch -d "$dir" -p1 -R --dry-run -s -f <"$p" >/dev/null 2>&1; then
            patch -d "$dir" -p1 -R -s -f --no-backup-if-mismatch <"$p" >/dev/null
        elif ! patch -d "$dir" -p1 --dry-run -s -f <"$p" >/dev/null 2>&1; then
            # upgraded package files, but the files the patch created are left over
            created_files "$p" | while read -r f; do rm -f -- "$dir/$f"; done
            patch -d "$dir" -p1 --dry-run -s -f <"$p" >/dev/null 2>&1 ||
                die "installed feature $(basename "$p" .patch) is in an unknown state in $dir"
        fi
    done
}

# apply <feature>... to <dir>; prints the first feature that does not fit
apply_features() {
    local dir=$1 f
    shift
    for f in "$@"; do
        patch -d "$dir" -p1 --dry-run -s -f <"$SRC/patches/$f.patch" >/dev/null 2>&1 || {
            echo "$f"
            return 1
        }
        patch -d "$dir" -p1 -s -f --no-backup-if-mismatch <"$SRC/patches/$f.patch" >/dev/null
    done
}

MODE=install HOOK_WANTED=0
FEATURES=()
for arg in "$@"; do
    case $arg in
    --list) MODE=list ;;
    --uninstall) MODE=uninstall ;;
    --hook) HOOK_WANTED=1 ;;
    -h | --help)
        sed -n '2,11s/^# \{0,1\}//p' "$0"
        exit 0
        ;;
    -*) die "unknown option $arg" ;;
    *)
        [ -f "$SRC/patches/$arg.patch" ] || die "unknown feature '$arg', see ./install.sh --list"
        FEATURES+=("$arg")
        ;;
    esac
done

if [ "$MODE" = list ]; then
    for p in "$SRC"/patches/*.patch; do
        f=$(basename "$p" .patch)
        state=" "
        [ -f "$DEST/patches/$f.patch" ] && state="*"
        printf '%s %-22s %s\n' "$state" "$f" "$(describe "$f")"
    done
    echo "(* = installed)"
    exit 0
fi

[ -d "$TARGET" ] || die "caelestia-shell not found in $TARGET"
[ -w "$TARGET" ] || die "no write access to $TARGET, run with sudo"
[ "$MODE" = uninstall ] || [ ${#FEATURES[@]} -gt 0 ] || die "no features given, see ./install.sh --list"
mapfile -t FEATURES < <(printf '%s\n' "${FEATURES[@]}" | sort -u | sed '/^$/d')

# dry run on a copy, so nothing is touched if a feature does not fit
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -a "$TARGET" "$TMP/shell"
revert_installed "$TMP/shell"
if ! bad=$(apply_features "$TMP/shell" "${FEATURES[@]}"); then
    die "feature '$bad' does not fit caelestia-shell $(shell_version), nothing was changed"
fi

revert_installed "$TARGET"
apply_features "$TARGET" "${FEATURES[@]}" >/dev/null
rm -rf "$DEST" "$HOOK"

if [ "$MODE" = uninstall ]; then
    echo "caelestia-extras removed"
else
    install -d -m755 "$DEST/patches"
    for f in "${FEATURES[@]}"; do
        install -m644 "$SRC/patches/$f.patch" "$DEST/patches/"
        echo "installed: $f"
    done
    install -m755 "$SRC/apply.sh" "$DEST/apply.sh"
    if [ "$HOOK_WANTED" = 1 ]; then
        install -d -m755 "$HOOKS"
        cat >"$HOOK" <<EOF
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = caelestia-shell

[Action]
Description = Re-applying caelestia-extras...
When = PostTransaction
Exec = $DEST/apply.sh
EOF
        echo "installed: pacman hook $HOOK"
    fi
fi
echo "Restart the shell to see the changes: caelestia shell -r"
