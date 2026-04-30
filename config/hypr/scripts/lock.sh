#!/usr/bin/env bash
# Launch the Quickshell lockscreen, exporting darko theme info so Lock.qml
# can render its theme-specific widgets.

export DARKO_THEME="$(cat ~/.config/themes/active.name 2>/dev/null || echo mono)"
if [[ "$DARKO_THEME" == "darko" ]]; then
    export DARKO_COUNTDOWN_END="$(jq -r '.countdown_end // "2026-05-28T06:42:12+02:00"' ~/.config/themes/active/manifest.json 2>/dev/null)"
fi

quickshell -p ~/.config/hypr/scripts/quickshell/Lock.qml
