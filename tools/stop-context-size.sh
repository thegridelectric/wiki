#!/bin/bash
# Stop hook: at end of each turn, measure this session's context size
# (via context-sizes.sh) and nudge toward the design-loop close.
#
# Levels (numbers live in context-sizes.sh):
#   >= CTX_WARN   once per CTX_BAND crossed: block once so Claude reads
#                 "wrap at the next re-orient"; otherwise a user-facing
#                 systemMessage each turn.
#   >= CTX_CLOSE  same mechanism, message says "close now".
#   delta >= DELTA_NOTE  user-facing note that one turn grew context by
#                 that much (big read / fan-out dump).
#   every CTX_TIER (25K) crossed: a user-facing systemMessage naming the
#                 boundary, no recommendation attached; a turn that crosses
#                 several boundaries names them all. State:
#                 ~/.claude/.context-band/<session-id>.tier = last tier.
#
# Never blocks while stop_hook_active is set, and never blocks twice in
# the same band: Claude cannot shrink its context, so a repeated block
# would loop. State: ~/.claude/.context-band/<session-id> = last band.

set -e
UMBRELLA=/Users/jessica/GridWorks
TOOLS="$UMBRELLA/wiki/tools"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
[ -n "$SESSION_ID" ] && [ -f "$TRANSCRIPT" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Thresholds, without running the table.
eval "$(grep -E '^(CTX_WARN|CTX_BAND|CTX_CLOSE|DELTA_NOTE)=' "$TOOLS/context-sizes.sh")"
read -r turns ctx delta peak <<< "$("$TOOLS/context-sizes.sh" --file "$TRANSCRIPT" 2>/dev/null)" || exit 0
[ -n "$ctx" ] || exit 0

fmt() { printf '%dK' $(( $1 / 1000 )); }

STATE_DIR="$HOME/.claude/.context-band"
mkdir -p "$STATE_DIR"
STATE="$STATE_DIR/$SESSION_ID"
last_band=$(cat "$STATE" 2>/dev/null || echo 0)

# The running tab: report each CTX_TIER boundary crossed since last turn.
CTX_TIER=25000
TIER_STATE="$STATE.tier"
last_tier=$(cat "$TIER_STATE" 2>/dev/null || echo 0)
tier=$(( ctx / CTX_TIER ))
tier_note=""
if [ "$tier" -gt "$last_tier" ]; then
  echo "$tier" > "$TIER_STATE"
  crossed=""
  for t in $(seq $(( last_tier + 1 )) "$tier"); do
    crossed="$crossed${crossed:+, }$(fmt $(( t * CTX_TIER )))"
  done
  tier_note="Context crossed $crossed (now $(fmt "$ctx"), turn $turns)."
fi

band=0
[ "$ctx" -ge "$CTX_WARN" ] && band=$(( (ctx - CTX_WARN) / CTX_BAND + 1 ))

delta_note=""
if [ "$delta" -ge "$DELTA_NOTE" ]; then
  delta_note="Last turn grew context by $(fmt "$delta") (a big read or a fan-out dump). Prefer a targeted read or a subagent for the next one."
fi

if [ "$band" -gt 0 ]; then
  if [ "$ctx" -ge "$CTX_CLOSE" ]; then
    level="Context is $(fmt "$ctx") (turn $turns), past the close level $(fmt "$CTX_CLOSE"). Close now: rewrite the active spoke's next-move line so a fresh session starts cold from the file, clear Scope in active-claims, log hours."
  else
    level="Context is $(fmt "$ctx") (turn $turns), past $(fmt "$CTX_WARN"). Wrap at the next re-orient: finish the move in flight, rewrite the active spoke's next-move line, then close; do not start a new move in this session."
  fi
  if [ "$band" -gt "$last_band" ] && [ "$HOOK_ACTIVE" != "true" ]; then
    echo "$band" > "$STATE"
    reason="Context-size check (Stop hook): ${tier_note:+$tier_note }$level
${delta_note:+
$delta_note
}
This note repeats once per $(fmt "$CTX_BAND") of growth. Acknowledge in one line and carry on; no other action is required this turn."
    jq -n --arg r "$reason" '{decision: "block", reason: $r}'
    exit 0
  fi
  jq -n --arg m "${tier_note:+$tier_note }$level${delta_note:+ $delta_note}" '{systemMessage: $m}'
  exit 0
fi

if [ -n "$tier_note" ] || [ -n "$delta_note" ]; then
  jq -n --arg m "${tier_note:-Context $(fmt "$ctx").}${delta_note:+ $delta_note}" '{systemMessage: $m}'
fi
exit 0
