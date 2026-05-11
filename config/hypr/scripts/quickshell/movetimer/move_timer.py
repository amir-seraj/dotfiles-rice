#!/usr/bin/env python3
"""Backend state machine for the Quickshell L4/L5 movement timer."""
from __future__ import annotations

import json
import os
import sys
import time
from datetime import date, timedelta
from pathlib import Path
from typing import Any

CACHE = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "qs-move-timer"
STATE = CACHE / "state.json"
HEALTH_STATE = CACHE / "health.json"
DEFAULTS = {
    "interval_minutes": 45,
    "break_minutes": 5,
    "mode": "focus",  # focus | break | paused
    "previous_mode": "focus",
    "started_at": 0,
    "end_at": 0,
    "paused_remaining": 0,
    "cycles": 0,
    "daily_cycles": {},
    "daily_cycles_today": 0,
    "current_streak_days": 0,
    "best_streak_days": 0,
    "last_cycle_date": "",
    "last_done_at": 0,
    "snoozes": 0,
}


def now() -> int:
    return int(time.time())


def today_iso() -> str:
    return date.today().isoformat()


def yesterday_iso(day: str | None = None) -> str:
    base = date.fromisoformat(day) if day else date.today()
    return (base - timedelta(days=1)).isoformat()


def clamp_int(value: Any, default: int = 0, minimum: int | None = None, maximum: int | None = None) -> int:
    try:
        result = int(value)
    except (TypeError, ValueError):
        result = default
    if minimum is not None:
        result = max(minimum, result)
    if maximum is not None:
        result = min(maximum, result)
    return result


def sanitize_daily_cycles(value: Any) -> dict[str, int]:
    if not isinstance(value, dict):
        return {}
    cleaned: dict[str, int] = {}
    cutoff = date.today() - timedelta(days=370)
    for raw_day, raw_count in value.items():
        try:
            parsed = date.fromisoformat(str(raw_day))
        except ValueError:
            continue
        if parsed < cutoff:
            continue
        count = clamp_int(raw_count, 0, 0, 999)
        if count > 0:
            cleaned[parsed.isoformat()] = count
    return dict(sorted(cleaned.items()))


def recompute_streak(daily_cycles: dict[str, int], through_day: str | None = None) -> int:
    if not daily_cycles:
        return 0
    current = date.fromisoformat(through_day or max(daily_cycles.keys()))
    if daily_cycles.get(current.isoformat(), 0) <= 0:
        current -= timedelta(days=1)
    streak = 0
    while daily_cycles.get(current.isoformat(), 0) > 0:
        streak += 1
        current -= timedelta(days=1)
    return streak


def migrate(s: dict[str, Any]) -> dict[str, Any]:
    merged = DEFAULTS.copy()
    if isinstance(s, dict):
        merged.update(s)

    merged["interval_minutes"] = clamp_int(merged.get("interval_minutes"), DEFAULTS["interval_minutes"], 1, 180)
    merged["break_minutes"] = clamp_int(merged.get("break_minutes"), DEFAULTS["break_minutes"], 1, 180)
    merged["cycles"] = clamp_int(merged.get("cycles"), 0, 0)
    merged["snoozes"] = clamp_int(merged.get("snoozes"), 0, 0)
    merged["last_done_at"] = clamp_int(merged.get("last_done_at"), 0, 0)
    merged["started_at"] = clamp_int(merged.get("started_at"), 0, 0)
    merged["end_at"] = clamp_int(merged.get("end_at"), 0, 0)
    merged["paused_remaining"] = clamp_int(merged.get("paused_remaining"), 0, 0)

    if merged.get("mode") not in {"focus", "break", "paused"}:
        merged["mode"] = "focus"
    if merged.get("previous_mode") not in {"focus", "break"}:
        merged["previous_mode"] = "focus"

    merged["daily_cycles"] = sanitize_daily_cycles(merged.get("daily_cycles"))
    day = today_iso()
    merged["daily_cycles_today"] = clamp_int(merged["daily_cycles"].get(day, 0), 0, 0, 999)

    last_cycle_date = str(merged.get("last_cycle_date") or "")
    try:
        if last_cycle_date:
            date.fromisoformat(last_cycle_date)
    except ValueError:
        last_cycle_date = ""
    if not last_cycle_date and merged["daily_cycles"]:
        last_cycle_date = max(merged["daily_cycles"].keys())
    merged["last_cycle_date"] = last_cycle_date

    current_streak = clamp_int(merged.get("current_streak_days"), 0, 0, 3660)
    if last_cycle_date and last_cycle_date not in {day, yesterday_iso()}:
        current_streak = 0
    elif last_cycle_date and current_streak == 0:
        current_streak = recompute_streak(merged["daily_cycles"], day)
    merged["current_streak_days"] = current_streak
    merged["best_streak_days"] = max(clamp_int(merged.get("best_streak_days"), 0, 0, 3660), current_streak)

    if not merged.get("end_at"):
        t = now()
        merged["started_at"] = t
        merged["end_at"] = t + merged["interval_minutes"] * 60
    return merged


def load() -> dict[str, Any]:
    CACHE.mkdir(parents=True, exist_ok=True)
    if not STATE.exists():
        s = migrate(DEFAULTS.copy())
        t = now()
        s["started_at"] = t
        s["end_at"] = t + s["interval_minutes"] * 60
        save(s)
        return s
    try:
        s = json.loads(STATE.read_text())
    except Exception:
        s = DEFAULTS.copy()
    return migrate(s)


def safe_health_payload(s: dict[str, Any]) -> dict[str, Any]:
    normalized = normalize(s.copy())
    day = today_iso()
    return {
        "schema_version": 1,
        "kind": "movement-health",
        "updated_at_epoch": normalized["now"],
        "privacy": {"sanitized": True, "raw_content_included": False},
        "movement": {
            "mode": normalized.get("mode", "focus"),
            "due": normalized.get("due", False),
            "remaining_seconds": normalized.get("remaining", 0),
            "overdue_seconds": normalized.get("overdue", 0),
            "interval_minutes": normalized.get("interval_minutes", 45),
            "break_minutes": normalized.get("break_minutes", 5),
            "cycles_total": normalized.get("cycles", 0),
            "cycles_today": normalized.get("daily_cycles_today", 0),
            "current_streak_days": normalized.get("current_streak_days", 0),
            "best_streak_days": normalized.get("best_streak_days", 0),
            "last_cycle_date": normalized.get("last_cycle_date", ""),
            "today": day,
        },
        "safe_summary": "Movement timer aggregates only; no health notes or raw bodies read.",
    }


def write_health(s: dict[str, Any]) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    tmp = HEALTH_STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(safe_health_payload(s), indent=2, sort_keys=True) + "\n")
    os.chmod(tmp, 0o600)
    tmp.replace(HEALTH_STATE)


def save(s: dict[str, Any]) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    s = migrate(s)
    tmp = STATE.with_suffix(".tmp")
    tmp.write_text(json.dumps(s, indent=2, sort_keys=True) + "\n")
    tmp.replace(STATE)
    write_health(s)


def normalize(s: dict[str, Any]) -> dict[str, Any]:
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
        "daily_cycles_today": int(s.get("daily_cycles", {}).get(today_iso(), 0)),
        "health_json": str(HEALTH_STATE),
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


def start_focus(s: dict[str, Any]) -> dict[str, Any]:
    t = now()
    s["mode"] = "focus"
    s["previous_mode"] = "focus"
    s["started_at"] = t
    s["end_at"] = t + int(s["interval_minutes"]) * 60
    s["paused_remaining"] = 0
    s["snoozes"] = 0
    return s


def start_break(s: dict[str, Any]) -> dict[str, Any]:
    t = now()
    s["mode"] = "break"
    s["previous_mode"] = "break"
    s["started_at"] = t
    s["end_at"] = t + int(s["break_minutes"]) * 60
    s["paused_remaining"] = 0
    return s


def record_done(s: dict[str, Any], t: int) -> dict[str, Any]:
    day = today_iso()
    daily = sanitize_daily_cycles(s.get("daily_cycles"))
    was_first_today = daily.get(day, 0) == 0
    daily[day] = daily.get(day, 0) + 1
    s["daily_cycles"] = daily
    s["daily_cycles_today"] = daily[day]
    s["cycles"] = int(s.get("cycles", 0)) + 1
    s["last_done_at"] = t

    if was_first_today:
        previous_day = s.get("last_cycle_date") or ""
        if previous_day == yesterday_iso(day):
            s["current_streak_days"] = int(s.get("current_streak_days", 0)) + 1
        else:
            s["current_streak_days"] = 1
        s["last_cycle_date"] = day
        s["best_streak_days"] = max(int(s.get("best_streak_days", 0)), int(s.get("current_streak_days", 0)))
    return s


def main(argv: list[str]) -> int:
    cmd = argv[1] if len(argv) > 1 else "status"
    s = load()
    t = now()

    if cmd in {"status", "init"}:
        pass
    elif cmd == "health":
        save(s)
        print(json.dumps(safe_health_payload(s), separators=(",", ":")))
        return 0
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
        s = record_done(s, t)
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
