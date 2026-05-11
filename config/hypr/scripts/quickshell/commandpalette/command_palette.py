#!/usr/bin/env python3
"""Privacy-safe command palette index for X Operator.

The palette lists app/script/project labels and safe launch commands only. It does
not read command histories, environment values, secrets, file contents, or full
paths into display labels.
"""
from __future__ import annotations

import configparser
import json
import os
import re
import shlex
import sys
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
MAX_ITEMS = 160
REDACTED = "REDACTED"

REPO_ROOT = Path(__file__).resolve().parents[5]
HYPR_ROOT = REPO_ROOT / "config" / "hypr"
SCRIPTS_ROOT = HYPR_ROOT / "scripts"
HOME = Path.home()

APP_DIRS = [
    Path("/usr/share/applications"),
    Path("/usr/local/share/applications"),
    HOME / ".local" / "share" / "applications",
    Path("/var/lib/flatpak/exports/share/applications"),
    HOME / ".local" / "share" / "flatpak" / "exports" / "share" / "applications",
    HOME / ".nix-profile" / "share" / "applications",
    Path("/run/current-system/sw/share/applications"),
]

SAFE_SCRIPT_NAMES = {
    "qs_manager.sh",
    "ricectl.sh",
    "terminal-profile.sh",
    "workspaces.sh",
}

SECRET_PATTERNS = [
    re.compile(r"token|secret|password|passwd|authorization|cookie|api[_-]?key", re.I),
    re.compile(r"-----BEGIN", re.I),
    re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"),
    re.compile(r"[A-Fa-f0-9]{32,}"),
]


def has_secretish_text(value: str) -> bool:
    return any(pattern.search(value or "") for pattern in SECRET_PATTERNS)


def safe_label(value: str, fallback: str = "Unnamed") -> str:
    text = re.sub(r"\s+", " ", value or "").strip()
    if not text or has_secretish_text(text):
        return fallback
    return text[:64]


def clean_exec(value: str) -> str:
    # Desktop Exec supports field codes like %u/%F. Strip them and reject shell
    # metacharacters that often indicate env leakage or compound commands.
    text = re.sub(r"\s+%[a-zA-Z]", "", value or "").strip()
    text = text.replace("@@u", "").replace("@@", "").strip()
    if has_secretish_text(text):
        return ""
    if any(mark in text for mark in [";", "&&", "||", "`", "$(", "<", ">"]):
        return ""
    return text[:220]


def item(item_id: str, kind: str, label: str, command: list[str], subtitle: str = "", keywords: list[str] | None = None) -> dict[str, Any]:
    return {
        "id": item_id,
        "kind": kind,
        "label": safe_label(label),
        "subtitle": safe_label(subtitle, "") if subtitle else "",
        "keywords": [safe_label(k, "") for k in (keywords or []) if safe_label(k, "")],
        "command": command,
    }


def desktop_entries() -> list[dict[str, Any]]:
    apps: dict[str, dict[str, Any]] = {}
    for directory in APP_DIRS:
        if not directory.exists():
            continue
        for desktop in sorted(directory.rglob("*.desktop")):
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            parser.optionxform = str
            try:
                parser.read(desktop, encoding="utf-8")
                entry = parser["Desktop Entry"]
            except Exception:
                continue
            if entry.get("NoDisplay", "false").lower() == "true" or entry.get("Hidden", "false").lower() == "true":
                continue
            name = safe_label(entry.get("Name", ""), "")
            exec_line = clean_exec(entry.get("Exec", ""))
            if not name or not exec_line:
                continue
            app_id = "app:" + re.sub(r"[^a-z0-9_.-]+", "-", desktop.stem.lower())[:60]
            apps.setdefault(
                name.lower(),
                item(app_id, "app", name, ["hyprctl", "dispatch", "exec", "--", exec_line], "Application", [desktop.stem]),
            )
    return sorted(apps.values(), key=lambda row: row["label"].lower())[:80]


def script_entries() -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    candidates = [SCRIPTS_ROOT / name for name in SAFE_SCRIPT_NAMES]
    for script in sorted(candidates, key=lambda p: p.name):
        if not script.exists():
            continue
        label = script.stem.replace("-", " ").replace("_", " ").title()
        command = ["bash", str(script)]
        if script.name == "terminal-profile.sh":
            label = "Launch Terminal Profile"
            command = ["bash", str(script), "launch"]
        elif script.name == "ricectl.sh":
            command = ["bash", str(script), "status"]
        rows.append(item("script:" + script.stem, "script", label, command, "Safe rice script", [script.name]))
    return rows


def project_entries() -> list[dict[str, Any]]:
    # Metadata only: expose repo display names, not absolute paths. Commands use a
    # shell with a quoted repo path because hyprctl exec accepts one command str.
    roots = [REPO_ROOT, HOME / "projects", HOME / "src"]
    seen: set[Path] = set()
    rows: list[dict[str, Any]] = []
    for root in roots:
        if not root.exists():
            continue
        candidates = [root] if (root / ".git").exists() else []
        if root.is_dir():
            try:
                candidates.extend([child for child in root.iterdir() if child.is_dir() and (child / ".git").exists()])
            except OSError:
                pass
        for repo in candidates:
            resolved = repo.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            label = safe_label(repo.name.replace("-", " ").title(), "Project")
            cmd = "kitty --working-directory " + shlex.quote(str(resolved))
            rows.append(item("project:" + re.sub(r"[^a-z0-9_.-]+", "-", repo.name.lower()), "project", label, ["hyprctl", "dispatch", "exec", "--", cmd], "Open project terminal", [repo.name]))
            if len(rows) >= 24:
                return rows
    return rows


def builtins() -> list[dict[str, Any]]:
    return [
        item("builtin:terminal-default", "terminal", "Terminal Default", ["bash", str(SCRIPTS_ROOT / "terminal-profile.sh"), "launch", "default"], "Kitty default profile", ["kitty", "shell"]),
        item("builtin:terminal-code", "terminal", "Terminal Code", ["bash", str(SCRIPTS_ROOT / "terminal-profile.sh"), "launch", "code"], "Kitty code profile", ["kitty", "code"]),
        item("builtin:terminal-private", "terminal", "Terminal Private", ["bash", str(SCRIPTS_ROOT / "terminal-profile.sh"), "launch", "private"], "Kitty privacy profile", ["kitty", "privacy"]),
        item("builtin:terminal-admin", "terminal", "Terminal Admin", ["bash", str(SCRIPTS_ROOT / "terminal-profile.sh"), "launch", "admin"], "Kitty admin profile", ["kitty", "admin"]),
        item("builtin:privacy-toggle", "mode", "Toggle Privacy Mode", ["bash", str(SCRIPTS_ROOT / "ricectl.sh"), "privacy", "toggle"], "No private values included", ["privacy"]),
    ]


def build_index() -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for source in (builtins, script_entries, project_entries, desktop_entries):
        rows.extend(source())
    deduped: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not has_secretish_text(json.dumps(row, sort_keys=True)):
            deduped.setdefault(row["id"], row)
    items = list(deduped.values())[:MAX_ITEMS]
    return {
        "schema_version": SCHEMA_VERSION,
        "kind": "command_palette",
        "privacy": {"sanitized": True, "raw_content_included": False, "safe_commands_only": True},
        "items": items,
        "counts": {"items": len(items), "apps": sum(1 for x in items if x["kind"] == "app"), "projects": sum(1 for x in items if x["kind"] == "project")},
    }


def main() -> int:
    json.dump(build_index(), sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
