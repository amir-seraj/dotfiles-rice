#!/usr/bin/env bash
# Launch the Quickshell lockscreen, exporting darko theme info so Lock.qml
# can render its theme-specific widgets.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export DARKO_THEME="$(cat ~/.config/themes/active.name 2>/dev/null || echo mono)"
if [[ "$DARKO_THEME" == "darko" ]]; then
    export DARKO_COUNTDOWN_END="$(jq -r '.countdown_end // "2026-05-28T06:42:12+02:00"' ~/.config/themes/active/manifest.json 2>/dev/null)"
fi

# Phase 9: prepare /tmp/lock_bg.png before Lock.qml reads it. lock-prep.sh
# refuses to capture the current desktop when the active aura/profile is private.
"$SCRIPT_DIR/lock-prep.sh" || true

quickshell -p ~/.config/hypr/scripts/quickshell/Lock.qml
