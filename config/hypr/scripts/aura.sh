#!/usr/bin/env bash
# Phase 9 aura/theme switcher for the X Operator rice.
# Repo-safe by default: writes small state files and optionally invokes local theming tools
# only when explicitly requested.
set -euo pipefail

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
HYPR_DIR="${HYPR_DIR:-$XDG_CONFIG_HOME/hypr}"
MODE_DIR="${MODE_DIR:-$HYPR_DIR/modes}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
STATE_DIR="${STATE_DIR:-$XDG_STATE_HOME/xoperator}"
AURA_FILE="$MODE_DIR/wallpaper_auras.json"
THEME_FILE="$MODE_DIR/themes.json"
ACTIVE_AURA="$STATE_DIR/aura.json"
ACTIVE_THEME="$STATE_DIR/theme.json"
DRY_RUN=0
APPLY_WALLPAPER=0
RELOAD_QS=0
AURA=""
THEME=""
LIST=0

usage() {
  cat <<'USAGE'
Usage: aura.sh [--aura NAME] [--theme NAME] [--apply-wallpaper] [--reload-qs] [--dry-run] [--list]

Switches Phase 9 aura/theme state safely. By default this writes only:
  $XDG_STATE_HOME/xoperator/aura.json
  $XDG_STATE_HOME/xoperator/theme.json
  $XDG_STATE_HOME/xoperator/env

No live sync, commit, push, report, or message is sent.
USAGE
}

log() { printf '[aura] %s\n' "$*"; }
fail() { printf '[aura] ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

json_get() {
  local file="$1" expr="$2"
  jq -er "$expr" "$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aura) AURA="${2:-}"; shift 2 ;;
    --theme) THEME="${2:-}"; shift 2 ;;
    --apply-wallpaper) APPLY_WALLPAPER=1; shift ;;
    --reload-qs) RELOAD_QS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --list) LIST=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument: $1" ;;
  esac
done

[[ -f "$AURA_FILE" ]] || fail "missing $AURA_FILE"
[[ -f "$THEME_FILE" ]] || fail "missing $THEME_FILE"
have jq || fail "jq is required"

if [[ "$LIST" -eq 1 ]]; then
  echo 'Auras:'
  jq -r '.auras | keys[]' "$AURA_FILE" | sed 's/^/  - /'
  echo 'Themes:'
  jq -r '.themes | keys[]' "$THEME_FILE" | sed 's/^/  - /'
  exit 0
fi

if [[ -z "$AURA" ]]; then
  AURA="$(json_get "$AURA_FILE" '.default_aura')"
fi
if [[ -z "$THEME" ]]; then
  THEME="$(json_get "$THEME_FILE" '.default_theme')"
fi

json_get "$AURA_FILE" ".auras[\"$AURA\"]" >/dev/null || fail "unknown aura: $AURA"
json_get "$THEME_FILE" ".themes[\"$THEME\"]" >/dev/null || fail "unknown theme: $THEME"

aura_json="$(jq -c --arg name "$AURA" '.auras[$name] + {name: $name}' "$AURA_FILE")"
theme_json="$(jq -c --arg name "$THEME" '.themes[$name] + {name: $name}' "$THEME_FILE")"
accent="$(jq -r '.accent' <<<"$theme_json")"
wallpaper="$(jq -r '.wallpaper // empty' <<<"$aura_json")"
privacy="$(jq -r '(.privacy // false) or (.name == "private-red") or (.name == "blackout")' <<<"$aura_json")"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run aura=$AURA theme=$THEME accent=$accent privacy=$privacy wallpaper=${wallpaper:-none}"
  exit 0
fi

mkdir -p "$STATE_DIR"
printf '%s\n' "$aura_json" | jq . > "$ACTIVE_AURA"
printf '%s\n' "$theme_json" | jq . > "$ACTIVE_THEME"
cat > "$STATE_DIR/env" <<EOF
XOPERATOR_AURA=$AURA
XOPERATOR_THEME=$THEME
XOPERATOR_ACCENT=$accent
XOPERATOR_PRIVACY=$privacy
XOPERATOR_WALLPAPER=$wallpaper
EOF

log "selected aura=$AURA theme=$THEME"

if [[ "$APPLY_WALLPAPER" -eq 1 && -n "$wallpaper" && "$privacy" != "true" ]]; then
  if have swww; then
    swww img "$wallpaper" --transition-type wipe --transition-duration 1 || log "swww failed; state still updated"
  else
    log "swww not found; wallpaper apply skipped"
  fi
elif [[ "$APPLY_WALLPAPER" -eq 1 && "$privacy" == "true" ]]; then
  log "privacy aura active; wallpaper apply skipped"
fi

if [[ "$RELOAD_QS" -eq 1 ]]; then
  if have qs; then
    qs -p "$HYPR_DIR/scripts/quickshell/Main.qml" ipc call main forceReload || log "quickshell reload failed"
  else
    log "qs not found; quickshell reload skipped"
  fi
fi
