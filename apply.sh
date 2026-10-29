#!/bin/bash
# Re-applies the installed caelestia-extras patches to caelestia-shell.
# Run by the pacman hook after each caelestia-shell install/upgrade.
# Never fails the pacman transaction: a patch that no longer fits is skipped.

TARGET=${CAELESTIA_SHELL_DIR:-/etc/xdg/quickshell/caelestia}
DIR=$(dirname "$(readlink -f "$0")")

# Files a patch creates (--- /dev/null). pacman does not know them, so they
# survive an upgrade while the patched package files are reset.
created_files() {
    awk 'prev == "--- /dev/null" && /^\+\+\+ b\// { sub(/^\+\+\+ b\//, ""); sub(/\t.*/, ""); print } { prev = $0 }' "$1" |
        grep -v '\.\.'
}

for p in "$DIR"/patches/*.patch; do
    [ -e "$p" ] || continue
    name=$(basename "$p" .patch)
    if ! patch -d "$TARGET" -p1 -R --dry-run -s -f <"$p" >/dev/null 2>&1 &&
        ! patch -d "$TARGET" -p1 --dry-run -s -f <"$p" >/dev/null 2>&1; then
        # leftovers from before the upgrade block a clean re-apply
        created_files "$p" | while read -r f; do rm -f -- "$TARGET/$f"; done
    fi
    if patch -d "$TARGET" -p1 -R --dry-run -s -f <"$p" >/dev/null 2>&1; then
        echo "caelestia-extras $name: already applied"
    elif patch -d "$TARGET" -p1 --dry-run -s -f <"$p" >/dev/null 2>&1; then
        patch -d "$TARGET" -p1 -s -f --no-backup-if-mismatch <"$p" >/dev/null &&
            echo "caelestia-extras $name: applied"
    else
        echo "caelestia-extras $name: does not apply to this caelestia-shell version, skipped" >&2
    fi
done

exit 0
