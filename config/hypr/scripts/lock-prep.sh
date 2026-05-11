#!/usr/bin/env bash
# Prepare a lock-screen background without leaking the desktop in privacy mode.
set -euo pipefail

XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_DIR="${STATE_DIR:-$XDG_STATE_HOME/xoperator}"
LOCK_BG="${LOCK_BG:-/tmp/lock_bg.png}"
PROFILE_FILE="${PROFILE_FILE:-$HOME/.config/hypr/modes/lock_profiles.json}"
ACTIVE_AURA="$STATE_DIR/aura.json"
FORCE_PRIVACY=0
DRY_RUN=0

log() { printf '[lock-prep] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --privacy) FORCE_PRIVACY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      echo "Usage: lock-prep.sh [--privacy] [--dry-run]"
      exit 0
      ;;
    *) echo "lock-prep.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

privacy="false"
accent="#cba6f7"
profile="standard"
if [[ -f "$ACTIVE_AURA" ]] && have jq; then
  privacy="$(jq -r '(.privacy // false) or (.name == "private-red") or (.name == "blackout")' "$ACTIVE_AURA" 2>/dev/null || echo false)"
  accent="$(jq -r '.accent // "#cba6f7"' "$ACTIVE_AURA" 2>/dev/null || echo '#cba6f7')"
fi
if [[ "$FORCE_PRIVACY" -eq 1 ]]; then
  privacy="true"
fi
if [[ -f "$PROFILE_FILE" ]] && have jq; then
  profile="$(jq -r --argjson p "$privacy" 'if $p then .default_private else .default end // "standard"' "$PROFILE_FILE" 2>/dev/null || echo standard)"
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "dry-run privacy=$privacy profile=$profile target=$LOCK_BG accent=$accent"
  exit 0
fi

mkdir -p "$(dirname "$LOCK_BG")" "$XDG_CACHE_HOME/xoperator"

make_placeholder() {
  local out="$1" color="$2"
  if have magick; then
    magick -size 1920x1080 "xc:#07070d" \
      -fill "$color" -draw 'circle 960,540 960,100' \
      -blur 0x96 -fill 'rgba(0,0,0,0.58)' -draw 'rectangle 0,0 1920,1080' \
      -fill "$color" -pointsize 34 -gravity center -font DejaVu-Sans-Mono \
      -annotate +0+0 'X OPERATOR // PRIVATE LOCK' "$out"
  elif have convert; then
    convert -size 1920x1080 "xc:#07070d" "$out"
  else
    python3 - "$out" <<'PY'
import struct, zlib, sys
out=sys.argv[1]
w,h=16,16
raw=b''.join(b'\x00'+bytes([7,7,13])*w for _ in range(h))
def chunk(t,d):
    return struct.pack('>I',len(d))+t+d+struct.pack('>I',zlib.crc32(t+d)&0xffffffff)
with open(out,'wb') as f:
    f.write(b'\x89PNG\r\n\x1a\n')
    f.write(chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0)))
    f.write(chunk(b'IDAT',zlib.compress(raw)))
    f.write(chunk(b'IEND',b''))
PY
  fi
}

if [[ "$privacy" == "true" ]]; then
  make_placeholder "$LOCK_BG" "$accent"
  log "privacy background generated at $LOCK_BG (no desktop screenshot)"
  exit 0
fi

# Non-private path: prefer a screenshot if available, otherwise fall back to safe generated art.
if have grim; then
  if grim "$LOCK_BG" 2>/dev/null; then
    log "desktop screenshot captured for lock background at $LOCK_BG"
    exit 0
  fi
fi

make_placeholder "$LOCK_BG" "$accent"
log "fallback background generated at $LOCK_BG"
