#!/usr/bin/env bash
# Smoke tests for theme-switch. Run from anywhere.
# Each `assert` line prints PASS/FAIL with the test name.
set -uo pipefail

failed=0
assert() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "PASS  $name"
    else
        echo "FAIL  $name  ($*)"
        failed=$((failed + 1))
    fi
}
assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo "PASS  $name"
    else
        echo "FAIL  $name  expected=$expected got=$actual"
        failed=$((failed + 1))
    fi
}

# --- Phase 0 tests ---
assert "theme-switch on PATH" command -v theme-switch
assert "themes dir exists" test -d "$HOME/.config/themes"
assert "mono dir exists" test -d "$HOME/.config/themes/mono"
assert "darko dir exists" test -d "$HOME/.config/themes/darko"

theme-switch mono >/dev/null
active=$(basename "$(readlink "$HOME/.config/themes/active")")
assert_eq "active==mono after switch" mono "$active"

# --- Phase 1 tests ---
assert "matugen templates is a symlink" test -L "$HOME/.config/matugen/templates"

theme-switch mono >/dev/null
linked=$(readlink "$HOME/.config/matugen/templates")
assert_eq "templates -> active/matugen-templates" "$HOME/.config/themes/active/matugen-templates" "$linked"

assert "active.name file written" test -f "$HOME/.config/themes/active.name"
assert_eq "active.name == mono" "mono" "$(cat "$HOME/.config/themes/active.name" 2>/dev/null)"

# darko render produces portal-magenta active border
theme-switch darko >/dev/null
border=$(grep -E '^\$active_border' "$HOME/.config/hypr/colors.conf" 2>/dev/null | grep -oiE '[0-9a-f]{6,8}' | head -1 || true)
assert_eq "darko active border == 7a4a8aff" "7a4a8aff" "${border,,}"

# mono render produces mango active border
theme-switch mono >/dev/null
border=$(grep -E '^\$active_border' "$HOME/.config/hypr/colors.conf" 2>/dev/null | grep -oiE '[0-9a-f]{6,8}' | head -1 || true)
assert_eq "mono active border == ffae42ff" "ffae42ff" "${border,,}"

# --- summary ---
echo
if [[ $failed -eq 0 ]]; then
    echo "all passed"
    exit 0
else
    echo "$failed failed"
    exit 1
fi
