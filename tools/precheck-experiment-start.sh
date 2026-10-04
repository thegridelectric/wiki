#!/usr/bin/env bash
# PreToolUse (Bash) hook: the moment an experiment actually starts — a
# deployed service stopped or restarted over ssh, a spruce window opened,
# a harness launched from a box's ~/experiments clone — inject the
# run-first guidance ONCE per session and drop a marker. The Stop hook
# stop-experiment-record.sh reads the marker and holds the turn end until
# the experiment's record exists (README, evidence, instances, logbook).
#
# Why: the claim-keyed reminder (experiments-claim-context.sh) fires only
# when a session has claimed experiments/; on 2026-09-16 a session stopped
# spruce's scada with no such claim, and nothing prompted the write-up.
# The act, not the claim, is the reliable trigger.
#
# Self-locating: lives at <umbrella>/wiki/tools/<this-file>.
set -uo pipefail

input=$(cat 2>/dev/null || true)
command=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)
[ -z "$command" ] && exit 0

# The acts that mean "an experiment is running on the fleet".
pattern='ssh [^|;&]*systemctl (stop|restart)|spruce_window\.sh +on|setsid +nohup|timeout +[0-9]+[smh]? .*~/experiments'
printf '%s' "$command" | grep -Eq "$pattern" || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$sid" ] && exit 0

marker="$HOME/.claude/.experiment-started.$sid"
[ -f "$marker" ] && exit 0
mkdir -p "$HOME/.claude" && date +%s > "$marker"

CTX="EXPERIMENT STARTING (this command stops or drives a deployed service). Run it quickly and natively: note the wall clock at each step, keep the commands you actually ran, capture logs to files and report verdicts. Do NOT stop to write a README or sema structure first. The one thing that IS decided before the act is the pre-flight, two questions answered in a line to the user: what could make this run prove nothing (an already-open alert that would swallow the page, a window too short for the detector's cycle), and what could make it unsafe or self-undoing (a restart watchdog to stop with the service, a house that needs heat, a bus the deployed service also reads).

The record comes right after the run, before anything else, and the Stop hook will hold the turn end until it exists: a folder \`experiments/<today>-<slug>/\` with a README from \`experiments/experiment-README-template.md\` (Why, Setup, Protocol as run, Found with the verdict, Timeline, Folder contents), evidence files with provenance headers, \`instances/\` sema results (a \`gw.experiment.run\` at minimum, emitted through the snapshot), one logbook line, and the executor claim the run verifies updated with a pointer to the folder. Conventions: \`experiments/README.md\`. If this is a routine deploy restart (pull, sync, restart per an instance-README) and not an experiment, say so to the user and, before ending the turn, write one line naming why to \`~/.claude/.experiment-dismissed.<session-id>\`; the Stop hook echoes it and lets the turn end."

jq -n --arg ctx "$CTX" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
