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

# --- summary ---
echo
if [[ $failed -eq 0 ]]; then
    echo "all passed"
    exit 0
else
    echo "$failed failed"
    exit 1
fi
