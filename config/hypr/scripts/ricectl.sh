#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HYPR_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
MODES_DIR="$HYPR_DIR/modes"
RUNTIME_BASE="${XDG_RUNTIME_DIR:-/tmp}/hypr-rice"
STATE_FILE="$RUNTIME_BASE/state.json"
POLICY_FILE="$RUNTIME_BASE/notification_policy.json"

usage() {
  cat <<'USAGE'
ricectl.sh - X Operator rice state controller

Commands:
  state                         Print current state JSON, creating defaults if needed
  mode normal|focus|privacy|presentation|personal
                                Set global rice mode
  privacy on|off|toggle         Control privacy flag (fail-closed UI signal)
  workspace-enter <1-10>        Apply safe workspace personality metadata
  aura <name>                   Set current aura from modes/wallpaper_auras.json
  theme <name>                  Set current theme from modes/themes.json
  help                          Show this help

Writes only sanitized state:
  ${XDG_RUNTIME_DIR:-/tmp}/hypr-rice/state.json
  ${XDG_RUNTIME_DIR:-/tmp}/hypr-rice/notification_policy.json
USAGE
}

need_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "ricectl.sh requires jq" >&2
    exit 127
  fi
}

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

atomic_write() {
  local target="$1"
  local tmp
  mkdir -p "$(dirname -- "$target")"
  tmp="$(mktemp "${target}.tmp.XXXXXX")"
  cat > "$tmp"
  chmod 0600 "$tmp"
  mv -f "$tmp" "$target"
}

json_get_default() {
  local file="$1" filter="$2" fallback="$3"
  jq -er "$filter // empty" "$file" 2>/dev/null || printf '%s\n' "$fallback"
}

valid_key() {
  [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]]
}

ensure_state() {
  need_jq
  mkdir -p "$RUNTIME_BASE"
  if [[ ! -s "$STATE_FILE" ]] || ! jq empty "$STATE_FILE" >/dev/null 2>&1; then
    local default_aura default_theme now
    default_aura="$(json_get_default "$MODES_DIR/wallpaper_auras.json" '.default_aura' 'noir')"
    default_theme="$(json_get_default "$MODES_DIR/themes.json" '.default_theme' 'xoperator')"
    now="$(now_utc)"
    jq -n \
      --arg now "$now" \
      --arg aura "$default_aura" \
      --arg theme "$default_theme" \
      '{schema_version:1, updated_at:$now, mode:"normal", privacy_enabled:false, workspace:1, workspace_personality_id:"ops", workspace_personality_label:"Ops Deck", workspace_personality_icon:"󰣇", workspace_privacy:"inherit", focus_level:"balanced", aura:$aura, theme:$theme, notification_policy:"normal", flags:{focus:false,presentation:false,personal:false}}' \
      | atomic_write "$STATE_FILE"
  fi
  update_policy >/dev/null
}

read_state() {
  ensure_state
  jq . "$STATE_FILE"
}

write_state_filter() {
  local filter="$1"
  local now
  ensure_state
  now="$(now_utc)"
  jq --arg now "$now" "$filter | .updated_at = \$now" "$STATE_FILE" | atomic_write "$STATE_FILE"
  update_policy >/dev/null
}

update_policy() {
  need_jq
  mkdir -p "$RUNTIME_BASE"
  local mode policy privacy
  mode="$(jq -r '.mode // "normal"' "$STATE_FILE" 2>/dev/null || printf normal)"
  privacy="$(jq -r '.privacy_enabled // false' "$STATE_FILE" 2>/dev/null || printf false)"
  if [[ "$privacy" == "true" ]]; then
    policy="privacy"
  else
    policy="$mode"
  fi
  if ! jq -e --arg p "$policy" '.policies[$p]' "$MODES_DIR/notification_rules.json" >/dev/null; then
    policy="normal"
  fi
  jq -n \
    --arg now "$(now_utc)" \
    --arg policy "$policy" \
    --slurpfile rules "$MODES_DIR/notification_rules.json" \
    '{schema_version:1, updated_at:$now, active_policy:$policy, policy:$rules[0].policies[$policy], safe_event_shape:$rules[0].safe_event_shape}' \
    | atomic_write "$POLICY_FILE"
}

set_mode() {
  local mode="$1"
  case "$mode" in
    normal|focus|privacy|presentation|personal) ;;
    *) echo "invalid mode: $mode" >&2; exit 2 ;;
  esac
  local privacy=false
  [[ "$mode" == "privacy" || "$mode" == "presentation" ]] && privacy=true
  write_state_filter ".mode = \"$mode\" | .privacy_enabled = $privacy | .notification_policy = (if .privacy_enabled then \"privacy\" else \"$mode\" end) | .flags.focus = (\"$mode\" == \"focus\") | .flags.presentation = (\"$mode\" == \"presentation\") | .flags.personal = (\"$mode\" == \"personal\")"
  read_state
}

set_privacy() {
  local action="$1" current next
  ensure_state
  current="$(jq -r '.privacy_enabled // false' "$STATE_FILE")"
  case "$action" in
    on) next=true ;;
    off) next=false ;;
    toggle) [[ "$current" == "true" ]] && next=false || next=true ;;
    *) echo "invalid privacy action: $action" >&2; exit 2 ;;
  esac
  write_state_filter ".privacy_enabled = $next | .mode = (if $next then \"privacy\" elif .mode == \"privacy\" then \"normal\" else .mode end) | .notification_policy = (if $next then \"privacy\" else .mode end)"
  read_state
}

workspace_enter() {
  local n="$1"
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "workspace must be numeric" >&2; exit 2; }
  jq -e --arg n "$n" '.personalities[$n]' "$MODES_DIR/personalities.json" >/dev/null || { echo "unknown workspace personality: $n" >&2; exit 2; }
  local entry privacy_expr
  entry="$(jq -c --arg n "$n" '.personalities[$n]' "$MODES_DIR/personalities.json")"
  privacy_expr='.privacy_enabled'
  case "$(jq -r '.privacy' <<<"$entry")" in
    force_on) privacy_expr='true' ;;
    force_off) privacy_expr='false' ;;
  esac
  ensure_state
  jq \
    --argjson n "$n" \
    --argjson entry "$entry" \
    --arg now "$(now_utc)" \
    ".workspace = \$n | .workspace_personality_id = \$entry.id | .workspace_personality_label = \$entry.label | .workspace_personality_icon = \$entry.icon | .workspace_privacy = \$entry.privacy | .focus_level = \$entry.focus_level | .terminal_profile = \$entry.terminal_profile | .aura = \$entry.aura | .theme = \$entry.theme | .privacy_enabled = $privacy_expr | .updated_at = \$now | .notification_policy = (if .privacy_enabled then \"privacy\" else .mode end)" \
    "$STATE_FILE" | atomic_write "$STATE_FILE"
  update_policy >/dev/null
  read_state
}

set_aura() {
  local aura="$1"
  valid_key "$aura" || { echo "invalid aura name" >&2; exit 2; }
  jq -e --arg a "$aura" '.auras[$a]' "$MODES_DIR/wallpaper_auras.json" >/dev/null || { echo "unknown aura: $aura" >&2; exit 2; }
  write_state_filter ".aura = \"$aura\""
  read_state
}

set_theme() {
  local theme="$1"
  valid_key "$theme" || { echo "invalid theme name" >&2; exit 2; }
  jq -e --arg t "$theme" '.themes[$t]' "$MODES_DIR/themes.json" >/dev/null || { echo "unknown theme: $theme" >&2; exit 2; }
  write_state_filter ".theme = \"$theme\""
  read_state
}

main() {
  need_jq
  local cmd="${1:-help}"
  case "$cmd" in
    state) read_state ;;
    mode) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; set_mode "$2" ;;
    privacy) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; set_privacy "$2" ;;
    workspace-enter) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; workspace_enter "$2" ;;
    aura) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; set_aura "$2" ;;
    theme) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; set_theme "$2" ;;
    help|-h|--help) usage ;;
    *) echo "unknown command: $cmd" >&2; usage >&2; exit 2 ;;
  esac
}

main "$@"
