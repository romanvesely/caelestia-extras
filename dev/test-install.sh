#!/bin/bash
# Tests install.sh and apply.sh against a copy of an unpatched caelestia-shell.
# Nothing outside <work-dir> is touched and no root is needed.
#
# usage: dev/test-install.sh <unpatched-shell-dir> <work-dir>

set -uo pipefail

PRISTINE=$(readlink -f "$1")
WORK=$2
REPO=$(dirname "$(dirname "$(readlink -f "$0")")")
rm -rf "$WORK"
mkdir -p "$WORK"
export CAELESTIA_SHELL_DIR=$WORK/shell
export CAELESTIA_EXTRAS_DIR=$WORK/extras
export PACMAN_HOOKS_DIR=$WORK/hooks

FAILS=0
ok() { echo "ok:   $*"; }
fail() {
    echo "FAIL: $*"
    FAILS=$((FAILS + 1))
}
check() {
    local name=$1
    shift
    if "$@" >/dev/null 2>&1; then ok "$name"; else fail "$name"; fi
}
# shellcheck disable=SC2329 # same_as and applied are run through check
same_as() { diff -r "$1" "$CAELESTIA_SHELL_DIR"; }
fresh() {
    rm -rf "$CAELESTIA_SHELL_DIR" "$CAELESTIA_EXTRAS_DIR" "$PACMAN_HOOKS_DIR"
    cp -a "$PRISTINE" "$CAELESTIA_SHELL_DIR"
}
# shellcheck disable=SC2329
applied() { patch -d "$CAELESTIA_SHELL_DIR" -p1 -R --dry-run -s -f <"$REPO/patches/$1.patch"; }
install() { "$REPO/install.sh" "$@"; }

ALL=()
for p in "$REPO"/patches/*.patch; do ALL+=("$(basename "$p" .patch)"); done

check "--list" install --list

for f in "${ALL[@]}"; do
    fresh
    check "$f: install" install "$f"
    check "$f: applied" applied "$f"
    check "$f: uninstall" install --uninstall
    check "$f: shell back to original" same_as "$PRISTINE"
done

fresh
check "all: install with hook" install --hook "${ALL[@]}"
for f in "${ALL[@]}"; do check "all: $f applied" applied "$f"; done
check "all: hook written" test -f "$PACMAN_HOOKS_DIR/caelestia-extras.hook"
check "all: reinstall same selection" install --hook "${ALL[@]}"
cp -a "$CAELESTIA_SHELL_DIR" "$WORK/expected-all"

# upgrade: the package resets its own files, files the patches created stay
cp -a "$PRISTINE"/. "$CAELESTIA_SHELL_DIR"/
check "upgrade: apply.sh restores all features" "$CAELESTIA_EXTRAS_DIR/apply.sh"
check "upgrade: same as before the upgrade" same_as "$WORK/expected-all"

check "change selection to 2 features" install bar-leftmost-only lock-leftmost-only
check "change: cheatsheet removed" test ! -d "$CAELESTIA_SHELL_DIR/modules/cheatsheet"
check "change: hook removed without --hook" test ! -f "$PACMAN_HOOKS_DIR/caelestia-extras.hook"
check "change: bar-leftmost-only applied" applied bar-leftmost-only
check "uninstall after change" install --uninstall
check "uninstall: shell back to original" same_as "$PRISTINE"
check "uninstall: extras dir gone" test ! -e "$CAELESTIA_EXTRAS_DIR"

# a feature that does not fit must not change anything
fresh
check "install bar-leftmost-only" install bar-leftmost-only
sed -i "s/^    Shortcuts {}$/    ShortcutsV2 {}/" "$CAELESTIA_SHELL_DIR/shell.qml"
cp -a "$CAELESTIA_SHELL_DIR" "$WORK/before-misfit"
if install cheatsheet lock-leftmost-only >"$WORK/misfit.log" 2>&1; then
    fail "misfit: install should fail"
else
    ok "misfit: install fails"
fi
check "misfit: error names the feature" grep -q "feature 'cheatsheet' does not fit" "$WORK/misfit.log"
check "misfit: shell unchanged" same_as "$WORK/before-misfit"
check "misfit: previous selection kept" test -f "$CAELESTIA_EXTRAS_DIR/patches/bar-leftmost-only.patch"

check "unknown feature is rejected" sh -c "! '$REPO/install.sh' nope"

echo
[ "$FAILS" = 0 ] && echo "all tests passed" || echo "$FAILS test(s) failed"
exit "$FAILS"
