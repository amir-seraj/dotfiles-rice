#!/usr/bin/env python3
"""Phase 9 boot ritual backend.

Dry-run is the default. This script never sends reports/messages. It only prints a
local launch plan unless --write-state is explicitly requested, and even then it
writes a local JSON summary under XDG_STATE_HOME.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import pathlib
import subprocess
from typing import Any


def xdg_state_home() -> pathlib.Path:
    return pathlib.Path(os.environ.get("XDG_STATE_HOME", pathlib.Path.home() / ".local" / "state"))


def read_json(path: pathlib.Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text())
    except Exception:
        return default


def git_summary(repo: pathlib.Path) -> dict[str, Any]:
    if not (repo / ".git").exists():
        return {"repo": str(repo), "available": False}
    try:
        proc = subprocess.run(
            ["git", "status", "--short"],
            cwd=repo,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=4,
            check=False,
        )
        lines = [line for line in proc.stdout.splitlines() if line.strip()]
        return {"repo": str(repo), "available": True, "dirty_count": len(lines), "dirty_preview": lines[:8]}
    except Exception as exc:
        return {"repo": str(repo), "available": False, "error": str(exc)}


def build_plan(args: argparse.Namespace) -> dict[str, Any]:
    state_dir = xdg_state_home() / "xoperator"
    aura = read_json(state_dir / "aura.json", {"name": "noir-purple", "label": "Noir Purple"})
    theme = read_json(state_dir / "theme.json", {"name": "noir-purple", "label": "Noir Purple", "accent": "#cba6f7"})
    now = dt.datetime.now().astimezone().isoformat(timespec="seconds")
    repo = pathlib.Path(args.repo).expanduser().resolve() if args.repo else pathlib.Path.home() / "dotfiles-rice"
    return {
        "schema_version": 1,
        "generated_at": now,
        "mode": "dry-run" if args.dry_run else "local-plan",
        "aura": {"name": aura.get("name"), "label": aura.get("label"), "privacy": bool(aura.get("privacy", False))},
        "theme": {"name": theme.get("name"), "label": theme.get("label"), "accent": theme.get("accent")},
        "checks": {
            "git": git_summary(repo),
            "network_actions": "disabled",
            "messages_reports": "never_auto_send",
        },
        "suggested_sequence": [
            "review dashboard widgets",
            "review local git status",
            "choose focus block",
            "optionally launch work apps manually",
        ],
        "guardrails": [
            "dry-run by default",
            "no live sync",
            "no commit or push",
            "no reports/messages sent automatically",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Build a safe local boot ritual plan.")
    parser.add_argument("--dry-run", action="store_true", default=True, help="Print plan only (default).")
    parser.add_argument("--write-state", action="store_true", help="Also write local state JSON; no network/send actions.")
    parser.add_argument("--repo", default="", help="Repository to summarize, default ~/dotfiles-rice.")
    args = parser.parse_args()

    plan = build_plan(args)
    print(json.dumps(plan, indent=2, sort_keys=True))

    if args.write_state:
        out_dir = xdg_state_home() / "xoperator"
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "boot_ritual_last.json").write_text(json.dumps(plan, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
