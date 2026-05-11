#!/usr/bin/env python3
"""Backend state machine for the Quickshell L4/L5 movement timer."""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "qs-move-timer"
STATE = CACHE / "state.json"
DEFAULTS = {
    "interval_minutes": 45,
    "break_minutes": 5,
    "mode": "focus",  # focus | break | paused
    "previous_mode": "focus",
    "started_at": 0,
    "end_at": 0,
    "paused_remaining": 0,
    "cycles": 0,
    "last_done_at": 0,
    "snoozes": 0,
}


def now() -> int:
    return int(time.time())


def load() -> dict:
    CACHE.mkdir(parents=True, exist_ok=True)
    if not STATE.exists():
        s = DEFAULTS.copy()
        t = now()
        s["started_at"] = t
        s["end_at"] = t + s["interval_minutes"] * 60
        save(s)
        return s
    try:
        s = json.loads(STATE.read_text())
    except Exception:
        s = DEFAULTS.copy()
    for k, v in DEFAULTS.items():
        s.setdefault(k, v)
    if not s.get("end_at"):
        t = now()
        s["started_at"] = t
        s["end_at"] = t + int(s["interval_minutes"]) * 60
    return s


def save(s: dict) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(s, indent=2, sort_keys=True) + "\n")
    tmp.replace(STATE)


def normalize(s: dict) -> dict:
    t = now()
    rem = int(s.get("end_at", t) - t)
    due = False
    overdue = 0
    if s.get("mode") != "paused" and rem <= 0:
        due = True
        overdue = abs(rem)
        rem = 0
    total = (int(s["break_minutes"]) if s.get("mode") == "break" else int(s["interval_minutes"])) * 60
    if s.get("mode") == "paused":
        rem = max(0, int(s.get("paused_remaining", 0)))
        due = False
        overdue = 0
    progress = 1.0 - (rem / total) if total > 0 else 0.0
    progress = min(1.0, max(0.0, progress))
    s.update({
        "now": t,
        "remaining": rem,
        "due": due,
        "overdue": overdue,
        "progress": progress,
        "label": fmt(rem),
        "overdue_label": fmt(overdue),
        "phase_label": phase_label(s.get("mode", "focus"), due),
    })
    return s


def fmt(seconds: int) -> str:
    seconds = max(0, int(seconds))
    m, sec = divmod(seconds, 60)
    if m >= 60:
        h, m = divmod(m, 60)
        return f"{h}:{m:02d}:{sec:02d}"
    return f"{m:02d}:{sec:02d}"


def phase_label(mode: str, due: bool) -> str:
    if mode == "paused":
        return "Paused"
    if mode == "break":
        return "Move / stretch"
    if due:
        return "Stand up now"
    return "Focus posture"


def start_focus(s: dict) -> dict:
    t = now()
    s["mode"] = "focus"
    s["previous_mode"] = "focus"
    s["started_at"] = t
    s["end_at"] = t + int(s["interval_minutes"]) * 60
    s["paused_remaining"] = 0
    s["snoozes"] = 0
    return s


def start_break(s: dict) -> dict:
    t = now()
    s["mode"] = "break"
    s["previous_mode"] = "break"
    s["started_at"] = t
    s["end_at"] = t + int(s["break_minutes"]) * 60
    s["paused_remaining"] = 0
    return s


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "status"
    s = load()
    t = now()

    if cmd in {"status", "init"}:
        pass
    elif cmd == "reset":
        s = start_focus(s)
    elif cmd == "pause":
        if s.get("mode") != "paused":
            s["previous_mode"] = s.get("mode", "focus")
            s["paused_remaining"] = max(0, int(s.get("end_at", t) - t))
            s["mode"] = "paused"
    elif cmd == "resume":
        if s.get("mode") == "paused":
            mode = s.get("previous_mode") or "focus"
            s["mode"] = mode
            s["end_at"] = t + max(1, int(s.get("paused_remaining", int(s["interval_minutes"]) * 60)))
            s["paused_remaining"] = 0
    elif cmd == "toggle":
        if s.get("mode") == "paused":
            mode = s.get("previous_mode") or "focus"
            s["mode"] = mode
            s["end_at"] = t + max(1, int(s.get("paused_remaining", int(s["interval_minutes"]) * 60)))
            s["paused_remaining"] = 0
        else:
            s["previous_mode"] = s.get("mode", "focus")
            s["paused_remaining"] = max(0, int(s.get("end_at", t) - t))
            s["mode"] = "paused"
    elif cmd == "done":
        # User confirmed the L4/L5 movement/reset is done; go back to work/focus mode.
        s["cycles"] = int(s.get("cycles", 0)) + 1
        s["last_done_at"] = t
        s = start_focus(s)
    elif cmd == "skip-break":
        s = start_focus(s)
    elif cmd == "snooze":
        minutes = int(argv[2]) if len(argv) > 2 and argv[2].isdigit() else 5
        s["mode"] = "focus"
        s["previous_mode"] = "focus"
        s["started_at"] = t
        s["end_at"] = t + minutes * 60
        s["snoozes"] = int(s.get("snoozes", 0)) + 1
    elif cmd == "set":
        if len(argv) < 4 or argv[2] not in {"interval", "break"}:
            raise SystemExit("usage: move_timer.py set interval|break MINUTES")
        mins = max(1, min(180, int(argv[3])))
        if argv[2] == "interval":
            s["interval_minutes"] = mins
        else:
            s["break_minutes"] = mins
        # restart current phase with new duration for predictability
        s = start_break(s) if s.get("mode") == "break" else start_focus(s)
    else:
        raise SystemExit(f"unknown command: {cmd}")

    # If break finished, automatically go back to focus. If focus expires, stay due until user confirms.
    if s.get("mode") == "break" and int(s.get("end_at", t)) <= t and cmd == "status":
        s = start_focus(s)

    save(s)
    print(json.dumps(normalize(s), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
