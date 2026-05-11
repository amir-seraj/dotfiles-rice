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


def run_command(args: list[str], timeout: float = 1.5) -> str:
    try:
        result = subprocess.run(
            args,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=timeout,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout.strip()


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


def status_health() -> dict[str, Any]:
    payload = base_payload("health")
    now = int(time.time())
    payload.update(
        {
            "movement": {
                "status": "sample",
                "move_due": False,
                "next_check_epoch": now + 1800,
            },
            "focus": {
                "status": "sample",
                "session_active": False,
                "minutes_today": 0,
            },
            "safe_summary": "Sample health state only; no health notes or bodies read.",
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
            },
            "active": bool(agent_names),
            "safe_summary": "Agent status uses process names only; no transcripts, prompts, or args emitted.",
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
            "counts": {"candidate_roots_checked": checked_roots, "markdown_notes_seen": md_count},
            "recent_notes": [],
            "safe_summary": "Obsidian status is count-only; no note names or bodies emitted.",
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


def status_sentinel() -> dict[str, Any]:
    payload = base_payload("sentinel")
    payload.update(
        {
            "mode": "sample",
            "signals": {"attention": "nominal", "risk": "unknown", "privacy": "protected"},
            "safe_summary": "Sentinel placeholder contains no sensor payloads or raw observations.",
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
