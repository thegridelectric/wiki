#!/usr/bin/env bash
# build-executor.sh — start a Claude session with the executor recipe
# appended to its system prompt.
#
# Runs claude from the umbrella directory (the parent of wiki/) with
# `--append-system-prompt-file wiki/conventions/executor-CLAUDE.md`, so a
# session whose work is building, checking or rebuilding from an executor
# has the recipe in context from its first turn, and with
# `--dangerously-skip-permissions`, so the session runs without permission
# prompts. Any further arguments go to claude as given, e.g.
# `build-executor.sh --continue`.
set -euo pipefail

wiki="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
recipe="$wiki/conventions/executor-CLAUDE.md"
[ -f "$recipe" ] || { echo "build-executor.sh: $recipe not found" >&2; exit 1; }

cd "$wiki/.."
exec claude --dangerously-skip-permissions --append-system-prompt-file "$recipe" "$@"
