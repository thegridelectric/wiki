#!/usr/bin/env bash
# session.sh — start a Claude session with the protocol file(s) for a
# session kind appended to its system prompt.
#
#   session.sh <base|executor|scada> [--include-sema] [claude args...]
#
# base      appends nothing beyond the project CLAUDE.md
# executor  appends wiki/conventions/executor-CLAUDE.md
# scada     appends wiki/conventions/scada-CLAUDE.md
# --include-sema  also appends wiki/conventions/sema-CLAUDE.md
#
# Runs claude from the umbrella directory (the parent of wiki/) with
# `--dangerously-skip-permissions`, so the session runs without permission
# prompts. The selected files are concatenated into one temp file because
# claude takes a single --append-system-prompt-file. Remaining arguments go
# to claude as given, e.g. `session.sh scada --include-sema`.
# The scripts may be symlinked from the umbrella folder; paths resolve
# through the symlink.
set -euo pipefail

wiki="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
conv="$wiki/conventions"

kind="${1:-}"; shift || true
files=()
case "$kind" in
  base) ;;
  executor) files+=("$conv/executor-CLAUDE.md") ;;
  scada) files+=("$conv/scada-CLAUDE.md") ;;
  *) echo "session.sh: kind must be base, executor or scada (got '$kind')" >&2; exit 2 ;;
esac
if [ "${1:-}" = "--include-sema" ]; then
  files+=("$conv/sema-CLAUDE.md"); shift
fi
for f in "${files[@]+"${files[@]}"}"; do
  [ -f "$f" ] || { echo "session.sh: $f not found" >&2; exit 1; }
done

cd "$wiki/.."
if [ "${#files[@]}" -eq 0 ]; then
  exec claude --dangerously-skip-permissions "$@"
fi
prompt="$(mktemp -t gw-session-prompt)"
for f in "${files[@]}"; do cat "$f"; printf '\n\n'; done > "$prompt"
exec claude --dangerously-skip-permissions --append-system-prompt-file "$prompt" "$@"
