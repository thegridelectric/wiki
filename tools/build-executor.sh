#!/usr/bin/env bash
# build-executor.sh — start a Claude session with the executor recipe
# appended to its system prompt.
#
# Runs `claude --append-system-prompt-file wiki/executor-CLAUDE.md` from
# the umbrella directory (the parent of wiki/), so a session whose work
# is building, checking or rebuilding from an executor has the recipe in
# context from its first turn. Any further arguments go to claude as
# given, e.g. `build-executor.sh --continue`.
set -euo pipefail

wiki="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
recipe="$wiki/executor-CLAUDE.md"
[ -f "$recipe" ] || { echo "build-executor.sh: $recipe not found" >&2; exit 1; }

cd "$wiki/.."
exec claude --append-system-prompt-file "$recipe" "$@"
