#!/usr/bin/env bash

# ============================================================================
# Quickshell workspace feed
# - Emits sanitized workspace/personality metadata to /tmp/qs_workspaces.json.
# - On workspace changes, updates ricectl state via workspace-enter when safe.
# - --once prints one JSON snapshot for validation/tests and exits.
# ============================================================================

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
HYPR_DIR="$(cd -- "$SCRIPTS_DIR/.." && pwd)"
SETTINGS_FILE="$HYPR_DIR/settings.json"
PERSONALITIES_FILE="$HYPR_DIR/modes/personalities.json"
RICECTL="$SCRIPTS_DIR/ricectl.sh"
OUTPUT_FILE="/tmp/qs_workspaces.json"
ONCE=false
[[ "${1:-}" == "--once" ]] && ONCE=true

# ============================================================================
# 1. ZOMBIE PREVENTION
# Kills any older daemon instances of this script. Skip in --once mode so tests
# do not disturb a running desktop listener.
# ============================================================================
if ! $ONCE; then
    for pid in $(pgrep -f "quickshell/workspaces.sh" || true); do
        if [ "$pid" != "$$" ] && [ "$pid" != "$PPID" ]; then
            kill -9 "$pid" 2>/dev/null || true
        fi
    done
fi

cleanup() {
    pkill -P $$ 2>/dev/null || true
}
trap cleanup EXIT SIGTERM SIGINT

# --- Special Cleanup for Network/Bluetooth ---
BT_PID_FILE="$HOME/.cache/bt_scan_pid"
if ! $ONCE && [ -f "$BT_PID_FILE" ]; then
    kill "$(cat "$BT_PID_FILE")" 2>/dev/null || true
    rm -f "$BT_PID_FILE"
fi
if ! $ONCE; then
    (timeout 2 bluetoothctl scan off > /dev/null 2>&1) &
fi
# ---------------------------------------------

read_workspace_count() {
    local count
    count=$(jq -r '.workspaceCount // 10' "$SETTINGS_FILE" 2>/dev/null || printf '10')
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
        count=10
    fi
    printf '%s\n' "$count"
}

apply_workspace_personality() {
    local active="$1"
    [[ "$active" =~ ^[0-9]+$ ]] || return 0
    [ -x "$RICECTL" ] || return 0
    [ -r "$PERSONALITIES_FILE" ] || return 0
    jq -e --arg n "$active" '.personalities[$n]' "$PERSONALITIES_FILE" >/dev/null 2>&1 || return 0
    "$RICECTL" workspace-enter "$active" >/dev/null 2>&1 || true
}

print_workspaces() {
    local seq_end spaces active result
    seq_end=$(read_workspace_count)

    spaces=$(timeout 2 hyprctl workspaces -j 2>/dev/null || true)
    active=$(timeout 2 hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // 1' 2>/dev/null || printf '1')

    # Failsafe for validation or non-Hyprland shells: still emit the configured
    # personality map, with workspace 1 active and no window-title leakage.
    if [ -z "$spaces" ] || ! jq empty >/dev/null 2>&1 <<<"$spaces" || ! [[ "$active" =~ ^[0-9]+$ ]]; then
        spaces='[]'
        active=1
    fi

    result=$(jq --unbuffered \
        --argjson a "$active" \
        --arg end "$seq_end" \
        --slurpfile personalities "$PERSONALITIES_FILE" \
        -c '
        ($personalities[0].personalities // {}) as $p |
        (map( { (.id|tostring): . } ) | add // {}) as $s |
        [range(1; ($end|tonumber) + 1)] | map(
            . as $i |
            ($p[$i|tostring] // {}) as $personality |
            (if $i == $a then "active"
             elif ($s[$i|tostring] != null and ($s[$i|tostring].windows // 0) > 0) then "occupied"
             else "empty" end) as $state |
            {
                id: $i,
                state: $state,
                tooltip: (if $state == "empty" then "Empty" else (($personality.label // ("Workspace " + ($i|tostring))) + " · " + (($s[$i|tostring].windows // 0)|tostring) + " windows") end),
                personality_id: ($personality.id // ("workspace-" + ($i|tostring))),
                label: ($personality.label // ("Workspace " + ($i|tostring))),
                icon: ($personality.icon // ($i|tostring)),
                aura: ($personality.aura // "noir"),
                theme: ($personality.theme // "xoperator"),
                privacy: ($personality.privacy // "inherit"),
                focus_level: ($personality.focus_level // "balanced")
            }
        )
    ' <<<"$spaces")

    apply_workspace_personality "$active"

    if $ONCE; then
        printf '%s\n' "$result"
    else
        printf '%s\n' "$result" > /tmp/qs_workspaces.tmp
        mv /tmp/qs_workspaces.tmp "$OUTPUT_FILE"
    fi
}

print_workspaces
$ONCE && exit 0

# ============================================================================
# 2. THE EVENT DEBOUNCER
# Listen to Hyprland socket wrapped in an infinite loop
# ============================================================================
while true; do
    if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        sleep 2
        print_workspaces
        continue
    fi

    socat -u UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" - | while read -r line; do
        case "$line" in
            workspace*|focusedmon*|activewindow*|createwindow*|closewindow*|movewindow*|destroyworkspace*)
                while read -t 0.05 -r _extra_line; do
                    continue
                done
                print_workspaces
                ;;
        esac
    done
    sleep 1
done
