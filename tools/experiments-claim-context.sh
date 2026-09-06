#!/usr/bin/env bash
# UserPromptSubmit hook: when THIS session's active-claims row has a Scope that
# includes an experiments path (`experiments/` or `experiments/<rung>/`),
# inject the experiments conventions pointer — ONCE per session.
#
# Why: experiments kept starting without a proper README (Why / Setup /
# Protocol written before the first run) and kept leaving files on pi home
# dirs. Keying off the claim catches the session at the moment it takes an
# experiment folder, before any file is written. Mirrors scada-claim-context.sh.
#
# Self-locating: lives at <umbrella>/wiki/tools/<this-file>.
# GW_ACTIVE_CLAIMS overrides the active-claims path (tests).
set -uo pipefail

GW="$(cd "$(dirname "$0")/../.." && pwd)"
ACTIVE_CLAIMS="${GW_ACTIVE_CLAIMS:-$GW/wiki/active-claims.md}"

input=$(cat 2>/dev/null || true)

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$sid" ] && exit 0
hash="${sid:0:6}"

marker="$HOME/.claude/.experiments-claim-context.$sid"
[ -f "$marker" ] && exit 0

[ -f "$ACTIVE_CLAIMS" ] || exit 0

row=$(grep -F "· ${hash} |" "$ACTIVE_CLAIMS" 2>/dev/null | head -1)
[ -z "$row" ] && exit 0

scope=$(printf '%s' "$row" | awk -F'|' '{print $4}')
echo "$scope" | grep -Eq '(^|[^a-z-])experiments/' || exit 0

mkdir -p "$HOME/.claude" && : > "$marker"

CTX="Your active-claims Scope includes experiments/. Before creating or editing an experiment folder you MUST read \`experiments/README.md\` (\"Layout\" and \"Conventions\") and \`experiments/experiment-README-template.md\`, and start the folder's README from the template with Why, Setup and Protocol written BEFORE the first run.

Anchor rules (the README is authoritative):
  - One folder per experiment, \`<first-run-date>-<slug>/\`; queued work lives in \`future/<slug>/\` and moves on first run; the logbook gets one line.
  - Running on a pi: the box holds ONE clone of the experiments repo at a pushed SHA (\`~/experiments\`, pulled, never scp'd) and the harness runs from it. Nothing else is placed in the pi's home dir; whatever a window puts there, its restore step removes. What must stay is recorded in the box's \`~/README.md\` in the same window.
  - Wire-encoded data files are the evidence and stay untouched; results are sema instances under \`instances/\`.

(This reminder fires once per session while an experiments claim is active.)"

jq -n --arg c "$CTX" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
