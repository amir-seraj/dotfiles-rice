#!/usr/bin/env bash
# Pre-lock dim sequence triggered by hypridle 5s before the actual lock.
# Only fires under the darko rice — exits silently on mono.
# Uses Hyprland's decoration:dim layer so no extra daemon is needed.

set -uo pipefail

ACTIVE="$(cat ~/.config/themes/active.name 2>/dev/null || echo mono)"
[[ "$ACTIVE" == "darko" ]] || exit 0

case "${1:-start}" in
    start)
        # Step the dim from 0 → 0.5 over 5 seconds (10 frames @ 500ms)
        hyprctl keyword decoration:dim_inactive true >/dev/null 2>&1 || true
        for i in 0 1 2 3 4 5 6 7 8 9; do
            strength=$(awk -v i=$i 'BEGIN{printf "%.2f", i*0.05}')
            hyprctl keyword decoration:dim_strength "$strength" >/dev/null 2>&1 || true
            sleep 0.5
        done
        ;;
    stop)
        hyprctl keyword decoration:dim_strength 0.0 >/dev/null 2>&1 || true
        hyprctl keyword decoration:dim_inactive false >/dev/null 2>&1 || true
        ;;
esac
