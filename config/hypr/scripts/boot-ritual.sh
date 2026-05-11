#!/usr/bin/env bash
# Safe Phase 9 boot ritual launcher. Dry-run by default; never sends reports/messages.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$SCRIPT_DIR/cockpit/boot_to_work.py"
DRY_RUN=1
WRITE_STATE=0
REPO="${XOPERATOR_REPO:-$HOME/dotfiles-rice}"

usage() {
  cat <<'USAGE'
Usage: boot-ritual.sh [--dry-run] [--write-state] [--repo PATH]

Builds a local boot ritual plan. Dry-run is default. This script never performs
live sync, commit, push, report sending, or messaging.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --write-state) WRITE_STATE=1; shift ;;
    --repo) REPO="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "boot-ritual.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -x "$BACKEND" || -f "$BACKEND" ]] || { echo "missing backend: $BACKEND" >&2; exit 1; }

args=("$BACKEND" "--dry-run" "--repo" "$REPO")
if [[ "$WRITE_STATE" -eq 1 ]]; then
  args+=("--write-state")
fi

python3 "${args[@]}"
