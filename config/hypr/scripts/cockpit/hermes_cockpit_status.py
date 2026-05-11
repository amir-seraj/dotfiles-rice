#!/usr/bin/env python3
"""Privacy-safe X Operator cockpit status writer.

This script intentionally emits sanitized aggregate/status JSON only. It never
reads notification bodies, transcript text, Obsidian note bodies, browser text,
window titles, secrets, screenshots, or raw command-line arguments.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

CACHE_DIR = Path(os.environ.get("HERMES_COCKPIT_CACHE", str(Path.home() / ".cache" / "hermes-cockpit")))
RUNTIME_DIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hypr-rice"
REDACTED = "REDACTED"
SCHEMA_VERSION = 1
SAFE_TEXT_MAX = 48

SECRET_PATTERNS = [
    re.compile(r"token", re.I),
    re.compile(r"secret", re.I),
    re.compile(r"password", re.I),
    re.compile(r"authorization", re.I),
    re.compile(r"cookie", re.I),
    re.compile(r"api[_-]?key", re.I),
    re.compile(r"-----BEGIN", re.I),
    re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
    re.compile(r"[A-Fa-f0-9]{32,}"),
]

COMMANDS: dict[str, Callable[[], dict[str, Any]]] = {}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def safe_text(value: Any, max_len: int = SAFE_TEXT_MAX) -> str:
    text = str(value or "")
    if any(p.search(text) for p in SECRET_PATTERNS):
        return REDACTED
    text = re.sub(r"\s+", " ", text).strip()
    if len(text) > max_len:
        return text[: max_len - 1] + "…"
    return text


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(payload, indent=2, sort_keys=True) + "\n"
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=str(path.parent), delete=False) as tmp:
        tmp.write(data)
        tmp_path = Path(tmp.name)
    os.chmod(tmp_path, 0o600)
    tmp_path.replace(path)


def base_payload(kind: str) -> dict[str, Any]:
    return {
        "schema_version": SCHEMA_VERSION,
        "kind": kind,
        "updated_at": utc_now(),
        "privacy": {
            "sanitized": True,
            "raw_content_included": False,
            "redaction": "fail-closed",
        },
    }


def read_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
        if isinstance(data, dict):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return {}


def run_command(args: list[str], timeout: float = 1.5, cwd: Path | None = None) -> str:
    try:
        result = subprocess.run(
            args,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=timeout,
            cwd=str(cwd) if cwd else None,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout.strip()


def safe_int(value: Any, default: int = 0, minimum: int | None = None, maximum: int | None = None) -> int:
    try:
        result = int(value)
    except (TypeError, ValueError):
        result = default
    if minimum is not None:
        result = max(minimum, result)
    if maximum is not None:
        result = min(maximum, result)
    return result



def proc_stat_cpu() -> tuple[int, int]:
    try:
        parts = Path("/proc/stat").read_text(encoding="utf-8").splitlines()[0].split()[1:]
        nums = [int(p) for p in parts]
    except (OSError, ValueError, IndexError):
        return (0, 0)
    idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
    total = sum(nums)
    return idle, total


def cpu_percent() -> int | None:
    idle1, total1 = proc_stat_cpu()
    time.sleep(0.05)
    idle2, total2 = proc_stat_cpu()
    if total2 <= total1:
        return None
    used = 1.0 - ((idle2 - idle1) / max(1, total2 - total1))
    return max(0, min(100, round(used * 100)))


def memory_percent() -> int | None:
    values: dict[str, int] = {}
    try:
        for line in Path("/proc/meminfo").read_text(encoding="utf-8").splitlines():
            key, raw = line.split(":", 1)
            values[key] = int(raw.strip().split()[0])
    except (OSError, ValueError, IndexError):
        return None
    total = values.get("MemTotal")
    available = values.get("MemAvailable")
    if not total or available is None:
        return None
    return max(0, min(100, round((total - available) * 100 / total)))


def battery_summary() -> dict[str, Any]:
    supplies = Path("/sys/class/power_supply")
    batteries = sorted(supplies.glob("BAT*")) if supplies.exists() else []
    for bat in batteries:
        try:
            capacity = int((bat / "capacity").read_text(encoding="utf-8").strip())
            status = safe_text((bat / "status").read_text(encoding="utf-8").strip(), 16)
            return {"present": True, "percent": capacity, "status": status}
        except (OSError, ValueError):
            continue
    return {"present": False}


def status_system() -> dict[str, Any]:
    payload = base_payload("system")
    root_usage = shutil.disk_usage(str(Path.home()))
    load1, load5, load15 = os.getloadavg() if hasattr(os, "getloadavg") else (0.0, 0.0, 0.0)
    payload.update(
        {
            "metrics": {
                "cpu_percent": cpu_percent(),
                "memory_percent": memory_percent(),
                "home_disk_percent": round((root_usage.used / root_usage.total) * 100),
                "load": {"one": round(load1, 2), "five": round(load5, 2), "fifteen": round(load15, 2)},
                "battery": battery_summary(),
            },
            "safe_summary": "System metrics sanitized; no process args, IPs, or paths emitted.",
        }
    )
    return payload


def movement_timer_summary() -> dict[str, Any]:
    state = read_json(Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "qs-move-timer" / "state.json")
    now_epoch = int(time.time())
    mode = safe_text(state.get("mode", "unknown"), 16)
    interval_minutes = safe_int(state.get("interval_minutes"), 45, 1, 180)
    break_minutes = safe_int(state.get("break_minutes"), 5, 1, 180)
    end_at = safe_int(state.get("end_at"), 0, 0)
    remaining = max(0, end_at - now_epoch) if mode != "paused" else safe_int(state.get("paused_remaining"), 0, 0)
    overdue = max(0, now_epoch - end_at) if mode not in {"paused", "break"} and end_at else 0
    daily_cycles = state.get("daily_cycles") if isinstance(state.get("daily_cycles"), dict) else {}
    today = datetime.now().date().isoformat()
    return {
        "status": "ready" if state else "not-initialized",
        "mode": mode,
        "move_due": bool(overdue > 0),
        "remaining_seconds": remaining,
        "overdue_seconds": overdue,
        "next_check_epoch": end_at if end_at else None,
        "interval_minutes": interval_minutes,
        "break_minutes": break_minutes,
        "cycles_total": safe_int(state.get("cycles"), 0, 0),
        "cycles_today": safe_int(daily_cycles.get(today, state.get("daily_cycles_today") or 0), 0, 0),
        "current_streak_days": safe_int(state.get("current_streak_days"), 0, 0),
        "best_streak_days": safe_int(state.get("best_streak_days"), 0, 0),
        "last_cycle_date": safe_text(state.get("last_cycle_date", ""), 16),
    }


def focus_summary() -> dict[str, Any]:
    runtime = Path(os.environ.get("XDG_RUNTIME_DIR") or str(Path.home() / ".cache")) / "focustime_state.json"
    fallback = Path.home() / ".cache" / "focustime" / "focustime_state.json"
    state = read_json(runtime) or read_json(fallback)
    total_seconds = safe_int(state.get("total"), 0, 0)
    return {
        "status": "ready" if state else "not-initialized",
        "session_active": bool(state),
        "minutes_today": total_seconds // 60,
        "hours_today": round(total_seconds / 3600, 2),
        "tracked_apps_count": len(state.get("apps") or []) if isinstance(state.get("apps"), list) else 0,
        "peak_usage_window": REDACTED if state.get("peak_usage_str") else "",
    }


def status_health() -> dict[str, Any]:
    payload = base_payload("health")
    payload.update(
        {
            "movement": movement_timer_summary(),
            "focus": focus_summary(),
            "spine": {
                "status": "guarded",
                "reminder": "movement-cycles-only",
                "raw_notes_included": False,
            },
            "safe_summary": "Health state is aggregate-only; no health notes, bodies, window titles, or app names emitted.",
        }
    )
    return payload


def status_agents() -> dict[str, Any]:
    payload = base_payload("agents")
    # Only inspect process command names (comm), never full command-line args.
    ps_output = run_command(["ps", "-eo", "comm="], timeout=1.0)
    names = [line.strip() for line in ps_output.splitlines() if line.strip()]
    agent_names = [n for n in names if re.search(r"hermes|codex|claude|agent", n, re.I)]
    safe_counts: dict[str, int] = {}
    for name in agent_names:
        key = safe_text(name, 24)
        safe_counts[key] = safe_counts.get(key, 0) + 1
    payload.update(
        {
            "counts": {
                "matching_processes": len(agent_names),
                "by_safe_command": safe_counts,
                "safe_command_kinds": len(safe_counts),
            },
            "active": bool(agent_names),
            "project": {"status": "aggregate-only", "known_count": status_projects()["counts"]["git_repositories_seen"]},
            "cache": {"status": "writable", "path_emitted": False},
            "safe_summary": "Agent HUD uses process names and aggregate counts only; no transcripts, prompts, args, or raw client text emitted.",
        }
    )
    return payload


def status_obsidian() -> dict[str, Any]:
    payload = base_payload("obsidian")
    candidates = [Path.home() / "Documents", Path.home() / "Obsidian", Path.home() / "vaults"]
    # Metadata counts only. Do not read filenames into output or note bodies at all.
    md_count = 0
    checked_roots = 0
    for root in candidates:
        if not root.exists() or not root.is_dir():
            continue
        checked_roots += 1
        try:
            for _ in root.rglob("*.md"):
                md_count += 1
                if md_count >= 10000:
                    break
        except OSError:
            continue
    payload.update(
        {
            "counts": {
                "candidate_roots_checked": checked_roots,
                "markdown_notes_seen": md_count,
                "recent_note_bodies_included": 0,
            },
            "recent_notes": [],
            "links": [{"label": "Open Obsidian", "url": "obsidian://open"}],
            "safe_summary": "Obsidian status is count/link-only; no note names, note paths, note bodies, or excerpts emitted.",
        }
    )
    return payload


def status_projects() -> dict[str, Any]:
    payload = base_payload("projects")
    roots = [Path.home() / "dotfiles-rice", Path.home() / "projects", Path.home() / "src"]
    git_count = 0
    repo_root_present = False
    for root in roots:
        if not root.exists():
            continue
        if (root / ".git").exists():
            git_count += 1
            if root.name == "dotfiles-rice":
                repo_root_present = True
        if root.is_dir():
            try:
                for child in root.iterdir():
                    if child.is_dir() and (child / ".git").exists():
                        git_count += 1
            except OSError:
                pass
    payload.update(
        {
            "counts": {"git_repositories_seen": git_count},
            "current_repo_present": repo_root_present,
            "items": [
                {"id": "sample", "label": "Sample Project", "status": "safe-placeholder"}
            ],
            "safe_summary": "Project status avoids absolute paths and private repo names.",
        }
    )
    return payload


def status_music() -> dict[str, Any]:
    payload = base_payload("music")
    status = run_command(["playerctl", "status"], timeout=1.0) if shutil.which("playerctl") else ""
    player = run_command(["playerctl", "metadata", "--format", "{{playerName}}"], timeout=1.0) if status else ""
    payload.update(
        {
            "playback": {
                "available": bool(status),
                "status": safe_text(status or "stopped", 16),
                "player": safe_text(player or "unknown", 24),
                "track": REDACTED,
                "artist": REDACTED,
            },
            "safe_summary": "Music status omits title, artist, album, artwork URLs, and file paths.",
        }
    )
    return payload


def git_porcelain_counts(repo: Path) -> dict[str, Any]:
    output = run_command(["git", "status", "--porcelain=v1"], timeout=1.5, cwd=repo)
    changed = staged = unstaged = untracked = 0
    for line in output.splitlines():
        if not line:
            continue
        changed += 1
        x = line[0] if len(line) > 0 else " "
        y = line[1] if len(line) > 1 else " "
        if line.startswith("??"):
            untracked += 1
        else:
            if x != " ":
                staged += 1
            if y != " ":
                unstaged += 1
    return {"changed_files": changed, "staged_files": staged, "unstaged_files": unstaged, "untracked_files": untracked}


def git_ahead_behind(repo: Path) -> dict[str, Any]:
    upstream = run_command(["git", "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"], timeout=1.0, cwd=repo)
    if not upstream:
        return {"upstream_present": False, "ahead": 0, "behind": 0}
    counts = run_command(["git", "rev-list", "--left-right", "--count", "@{upstream}...HEAD"], timeout=1.5, cwd=repo).split()
    try:
        behind, ahead = int(counts[0]), int(counts[1])
    except (IndexError, ValueError):
        behind, ahead = 0, 0
    return {"upstream_present": True, "ahead": ahead, "behind": behind}


def gh_count(repo: Path, item: str) -> int | None:
    if not shutil.which("gh"):
        return None
    output = run_command(["gh", item, "list", "--state", "open", "--limit", "100", "--json", "number"], timeout=3.0, cwd=repo)
    if not output:
        return None
    try:
        data = json.loads(output)
    except json.JSONDecodeError:
        return None
    return len(data) if isinstance(data, list) else None


def status_devlab() -> dict[str, Any]:
    payload = base_payload("devlab")
    repo = Path(os.environ.get("HERMES_COCKPIT_REPO", str(Path.home() / "dotfiles-rice")))
    present = (repo / ".git").exists()
    git_counts = {"changed_files": 0, "staged_files": 0, "unstaged_files": 0, "untracked_files": 0}
    ahead_behind = {"upstream_present": False, "ahead": 0, "behind": 0}
    if present:
        git_counts = git_porcelain_counts(repo)
        ahead_behind = git_ahead_behind(repo)
    prs = gh_count(repo, "pr") if present else None
    issues = gh_count(repo, "issue") if present else None
    payload.update(
        {
            "git": {
                "present": present,
                "dirty": bool(git_counts["changed_files"]),
                **git_counts,
                **ahead_behind,
            },
            "github": {
                "status": "available" if (prs is not None or issues is not None) else ("gh-unavailable" if not shutil.which("gh") else "not-authenticated-or-no-repo"),
                "open_prs": prs,
                "open_issues": issues,
            },
            "safe_summary": "Dev Lab emits aggregate git/GitHub counts only; no filenames, diffs, branch names, issue titles, remotes, or paths emitted.",
        }
    )
    return payload


def status_sentinel() -> dict[str, Any]:
    payload = base_payload("sentinel")
    payload.update(
        {
            "mode": "sample",
            "signals": {"attention": "nominal", "risk": "unknown", "privacy": "protected"},
            "next_action": {"status": "hook-ready", "raw_text_included": False},
            "hooks": {"timekeeper": "available", "work_report": "available", "innovina_dashboard": "aggregate-only"},
            "safe_summary": "Sentinel contains coarse hook states only; no sensor payloads, raw observations, notes, transcripts, or client text emitted.",
        }
    )
    return payload


def status_ritual() -> dict[str, Any]:
    payload = base_payload("ritual")
    state = read_json(RUNTIME_DIR / "state.json")
    payload.update(
        {
            "status": "sample",
            "steps": [
                {"id": "privacy", "label": "Privacy guard", "state": "ready"},
                {"id": "state", "label": "Rice state", "state": "ready" if state else "not-initialized"},
                {"id": "cockpit", "label": "Cockpit cache", "state": "ready"},
            ],
            "safe_summary": "Boot ritual placeholder emits only coarse step states.",
        }
    )
    return payload


COMMANDS.update(
    {
        "system": status_system,
        "health": status_health,
        "agents": status_agents,
        "obsidian": status_obsidian,
        "projects": status_projects,
        "devlab": status_devlab,
        "music": status_music,
        "sentinel": status_sentinel,
        "ritual": status_ritual,
    }
)


def write_status(name: str) -> dict[str, Any]:
    payload = COMMANDS[name]()
    atomic_write_json(CACHE_DIR / f"{name}.json", payload)
    return payload


def write_all() -> dict[str, Any]:
    written: dict[str, Any] = {}
    for name in COMMANDS:
        written[name] = write_status(name)
    index = base_payload("index")
    index.update(
        {
            "files": {name: str(CACHE_DIR / f"{name}.json") for name in COMMANDS},
            "safe_summary": "Index of sanitized cockpit cache files.",
        }
    )
    atomic_write_json(CACHE_DIR / "index.json", index)
    return {"ok": True, "cache_dir": str(CACHE_DIR), "written": sorted([*COMMANDS.keys(), "index"])}


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Write privacy-safe Hermes cockpit status JSON.")
    parser.add_argument("command", choices=["all", *COMMANDS.keys()], help="status file to write")
    parser.add_argument("--print-json", action="store_true", help="print generated payload instead of compact summary")
    args = parser.parse_args(argv)

    if args.command == "all":
        result = write_all()
    else:
        result = write_status(args.command)

    if args.print_json:
        print(json.dumps(result, indent=2, sort_keys=True))
    elif args.command == "all":
        print(json.dumps(result, sort_keys=True))
    else:
        print(json.dumps({"ok": True, "file": str(CACHE_DIR / f"{args.command}.json")}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
