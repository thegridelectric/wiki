#!/bin/bash
# Stop hook: once precheck-experiment-start.sh has marked this session as
# having run an experiment, hold the turn end until the experiment's
# record exists — a README under experiments/<date>-<slug>/ written after
# the marker. Then clear the marker.
#
# Escape hatches (user-controlled, Claude MUST NOT create them): the
# bulk-stop override files (see wiki/tools/bulk-aliases.sh), or deleting
# ~/.claude/.experiment-started.<session-id>.
#
# Dismissal (Claude MAY write it): the start pattern also matches a routine
# deploy restart (pull, sync, systemctl restart per an instance-README),
# which owes no record. Claude writes one line naming why to
# ~/.claude/.experiment-dismissed.<session-id>; this hook echoes that line
# to the user as it lets the turn end, so a dismissal is visible in the
# transcript, never silent. A block that can only be cleared by the user
# loops: a Stop rejection re-invokes Claude with no user turn between.
set -e
UMBRELLA="$(cd "$(dirname "$0")/../.." && pwd)"
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
[ -z "$SESSION_ID" ] && exit 0
marker="$HOME/.claude/.experiment-started.$SESSION_ID"
[ -f "$marker" ] || exit 0

# shellcheck source=_session-scope.sh
. "$UMBRELLA/wiki/tools/_session-scope.sh"
resolve_session_scope "$SESSION_ID"
if [ -n "${SESSION_NAME:-}" ] && [ -f "$HOME/.claude/.bulk-stop-override.$SESSION_NAME" ]; then exit 0; fi
[ -f "$HOME/.claude/.bulk-stop-override" ] && exit 0

dismissed="$HOME/.claude/.experiment-dismissed.$SESSION_ID"
if [ -f "$dismissed" ] && [ "$dismissed" -nt "$marker" ]; then
  why=$(head -1 "$dismissed")
  rm -f "$marker" "$dismissed"
  jq -n --arg m "Experiment record check: dismissed as routine, no record written — $why" \
    '{systemMessage: $m}'
  exit 0
fi

# A README in a dated experiment folder, written after the run started —
# or the field-window record, which experiments/field-window-recipe.md keeps
# in the undated beta-field-windows/ folder (only the last run is kept).
newer=$(find "$UMBRELLA/experiments" -maxdepth 2 \( -path '*/20[0-9][0-9]-*' -o -path '*/beta-field-windows/*' \) -name README.md -newer "$marker" 2>/dev/null | head -1)
if [ -n "$newer" ]; then
  rm -f "$marker"
  exit 0
fi

started=$(date -r "$(cat "$marker")" '+%Y-%m-%d %H:%M' 2>/dev/null || cat "$marker")
reason="Experiment record check (Stop hook): this session ran an experiment (marker set $started) and no experiments/<date>-<slug>/README.md has been written since.

Before ending the turn, write the record (conventions: experiments/README.md):
1. experiments/<first-run-date>-<slug>/README.md from experiment-README-template.md: Why, Setup, Protocol as actually run, Found with the verdict, Timeline (ET), Analysis notes, Folder contents & experimental method.
2. The commands that ran, as a re-runnable runbook in the folder.
3. Evidence files with provenance headers (journald slices, API responses); wire data untouched.
4. instances/: sema results emitted through the gwexp snapshot, a gw.experiment.run at minimum, read back through the codec.
5. One line in experiments/logbook.md.
6. The executor claim this run verifies, updated with a pointer to the folder.

If the command only looked like an experiment (a routine deploy restart per an instance-README, no claim tested), write ONE line saying why to $dismissed — the hook echoes it to the user and lets the turn end. Never dismiss a run that tested a claim."
jq -n --arg r "$reason" '{decision: "block", reason: $r}'
