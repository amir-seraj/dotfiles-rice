#!/usr/bin/env bash
set -euo pipefail

QS_ROOT="${QS_ROOT:-$HOME/.config/hypr/scripts/quickshell}"
MOVE_TIMER="$QS_ROOT/movetimer/move_timer.py"
FOCUS_DAEMON="$QS_ROOT/focustime/focus_daemon.py"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-$HOME/.cache}/hypr-rice"
STATE_FILE="$RUNTIME_DIR/focus_mode.json"
mkdir -p "$RUNTIME_DIR"

if [[ -x "$MOVE_TIMER" || -f "$MOVE_TIMER" ]]; then
  python3 "$MOVE_TIMER" reset >/dev/null
fi

if [[ -f "$FOCUS_DAEMON" ]] && ! pgrep -f "python3 .*focustime/focus_daemon.py" >/dev/null 2>&1; then
  nohup python3 "$FOCUS_DAEMON" >/dev/null 2>&1 &
fi

python3 - "$STATE_FILE" <<'PY'
import json
import os
import tempfile
import time
from pathlib import Path

path = Path(os.sys.argv[1])
payload = {
    "schema_version": 1,
    "mode": "work",
    "movement_timer": "reset-to-focus",
    "focus_tracking": "requested",
    "started_at_epoch": int(time.time()),
    "privacy": {"sanitized": True, "raw_content_included": False},
}
with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(path.parent), delete=False) as tmp:
    json.dump(payload, tmp, indent=2, sort_keys=True)
    tmp.write("\n")
    tmp_path = Path(tmp.name)
os.chmod(tmp_path, 0o600)
tmp_path.replace(path)
PY

printf '{"ok":true,"mode":"work","movement_timer":"focus"}\n'
