#!/usr/bin/env bash
set -euo pipefail

repo_root="${HERMES_RICE_REPO:-$HOME/dotfiles-rice}"
hypr_root="$repo_root/config/hypr"
profiles_json="$hypr_root/modes/terminal_profiles.json"
kitty_root="$repo_root/config/kitty"
state_file="${XDG_RUNTIME_DIR:-/tmp}/hypr-rice/state.json"

usage() {
  cat <<'EOF'
usage: terminal-profile.sh launch [profile] [--dry-run] [-- command ...]
       terminal-profile.sh list

Launch kitty with a configured profile. If profile is omitted, the launcher uses
privacy/workspace state and terminal_profiles.json defaults. Dry-run prints the
single command that would be launched and never starts kitty.
EOF
}

json_get() {
  local expr="$1" file="$2" fallback="$3"
  python3 - "$expr" "$file" "$fallback" <<'PY'
import json, sys
expr, path, fallback = sys.argv[1:4]
try:
    data = json.load(open(path, encoding='utf-8'))
    cur = data
    for part in expr.split('.'):
        if not part:
            continue
        cur = cur[part]
    if cur is None:
        print(fallback)
    elif isinstance(cur, bool):
        print('true' if cur else 'false')
    else:
        print(cur)
except Exception:
    print(fallback)
PY
}

profile_exists() {
  local profile="$1"
  python3 - "$profiles_json" "$profile" <<'PY'
import json, sys
try:
    data = json.load(open(sys.argv[1], encoding='utf-8'))
    raise SystemExit(0 if sys.argv[2] in data.get('profiles', {}) else 1)
except Exception:
    raise SystemExit(1)
PY
}

resolve_profile() {
  local requested="${1:-}"
  if [[ -n "$requested" ]]; then
    if profile_exists "$requested"; then
      printf '%s\n' "$requested"
      return 0
    fi
    printf 'unknown terminal profile: %s\n' "$requested" >&2
    return 2
  fi

  local default_profile privacy state_profile
  default_profile="$(json_get 'default_profile' "$profiles_json" 'default')"
  privacy="$(json_get 'privacy_enabled' "$state_file" 'false')"
  [[ "$privacy" == "false" ]] && privacy="$(json_get 'privacy' "$state_file" 'false')"
  state_profile="$(json_get 'terminal_profile' "$state_file" '')"
  [[ -z "$state_profile" ]] && state_profile="$(json_get 'workspace_personality.terminal_profile' "$state_file" '')"

  if [[ "$privacy" == "true" ]] && profile_exists private; then
    printf 'private\n'
  elif [[ -n "$state_profile" ]] && profile_exists "$state_profile"; then
    printf '%s\n' "$state_profile"
  else
    printf '%s\n' "$default_profile"
  fi
}

print_list() {
  python3 - "$profiles_json" <<'PY'
import json, sys
with open(sys.argv[1], encoding='utf-8') as fh:
    data = json.load(fh)
for key, val in sorted(data.get('profiles', {}).items()):
    print(f"{key}\t{val.get('label', key)}")
PY
}

main() {
  local action="${1:-launch}"
  case "$action" in
    -h|--help|help) usage; return 0 ;;
    list) print_list; return 0 ;;
    launch) shift || true ;;
    *) printf 'unknown action: %s\n' "$action" >&2; usage >&2; return 2 ;;
  esac

  local requested="" dry_run=0
  local -a passthrough=()
  while (($#)); do
    case "$1" in
      --dry-run) dry_run=1; shift ;;
      --) shift; passthrough=("$@"); break ;;
      -h|--help) usage; return 0 ;;
      *) if [[ -z "$requested" ]]; then requested="$1"; shift; else passthrough+=("$1"); shift; fi ;;
    esac
  done

  local profile label kitty_config profile_path
  profile="$(resolve_profile "$requested")"
  label="$(json_get "profiles.$profile.label" "$profiles_json" "$profile")"
  kitty_config="$(json_get "profiles.$profile.kitty_config" "$profiles_json" '')"

  local -a cmd=(kitty --title "Hermes ${label}")
  if [[ -n "$kitty_config" && "$kitty_config" != "None" && "$kitty_config" != "null" ]]; then
    profile_path="$kitty_root/$kitty_config"
    cmd+=(--config "$profile_path")
  fi
  cmd+=(--override "env=RICE_TERMINAL_PROFILE=$profile")
  if [[ "$profile" == "private" ]]; then
    cmd+=(--override "env=RICE_PRIVACY=1")
  fi
  if ((${#passthrough[@]})); then
    cmd+=("${passthrough[@]}")
  fi

  if ((dry_run)); then
    printf '{"dry_run":true,"profile":"%s","argv":[' "$profile"
    local first=1 encoded
    for arg in "${cmd[@]}"; do
      encoded="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$arg")"
      if ((first)); then first=0; else printf ','; fi
      printf '%s' "$encoded"
    done
    printf ']}\n'
  else
    exec "${cmd[@]}"
  fi
}

main "$@"
