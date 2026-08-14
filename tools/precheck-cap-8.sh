#!/bin/bash
# precheck-cap-8.sh — surface the personal WIP cap from
# designs/linear-integration.md "Cap-8 = my started issues".
#
# cap-8 = the number of issues assigned to ME (jmillar) in a `started` state
# (In Progress + In Review), across design AND operational work alike — the
# scarce resource is my attention, not a design slot. Warn at 7, stop at 8.
#
# Trigger: UserPromptSubmit (warn early, every turn while at/over the line).
#
# Two modes:
#   - LINEAR mode (when $LINEAR_API_KEY is set): query the live count via the
#     Linear GraphQL API (the MCP is Claude-facing, not shell-callable).
#   - NO-LINEAR mode: a once-per-session honor-system reminder (the count is
#     then maintained by Claude/the human via the MCP when starting an issue).
#
# This hook is advisory (additionalContext), not a hard block: blocking every
# prompt at 8 would wedge the session. The HARD "stop at 8" belongs at the
# moment an action would start a 9th issue — a future PreToolUse gate on the
# Linear `save_issue` call that sets a started state. Here we keep the count
# in view so that moment is never a surprise.
#
# Override: ~/.claude/.bulk-stop-override(.<session>) silences this hook.

set -e

UMBRELLA="$(cd "$(dirname "$0")/../.." && pwd)"
WIKI="$UMBRELLA/wiki"
SCRATCH_DIR="$HOME/.claude/projects/$(printf '%s' "$UMBRELLA" | tr '/' '-')/scratch"

input=$(cat)

# --- session-aware bulk override (per-session, then global) ----------------
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
SESSION_NAME=""
if [ -n "$SESSION_ID" ] && [ -f "$HOME/.claude/.session-by-id/$SESSION_ID" ]; then
  SESSION_NAME=$(cat "$HOME/.claude/.session-by-id/$SESSION_ID")
fi
if [ -n "$SESSION_NAME" ] && [ -f "$HOME/.claude/.bulk-stop-override.$SESSION_NAME" ]; then
  exit 0
fi
if [ -f "$HOME/.claude/.bulk-stop-override" ]; then
  exit 0
fi

command -v jq >/dev/null 2>&1 || exit 0

emit() {  # $1 = context message
  jq -n --arg ctx "$1" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
}

# --- LINEAR mode -----------------------------------------------------------
if [ -n "${LINEAR_API_KEY:-}" ] && command -v curl >/dev/null 2>&1; then
  q='{"query":"{ issues(filter:{assignee:{isMe:{eq:true}}, state:{type:{eq:\"started\"}}}, first:50){ nodes{ identifier title } } }"}'
  resp="$(curl -s --max-time 8 -X POST https://api.linear.app/graphql \
            -H "Authorization: $LINEAR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$q" 2>/dev/null || true)"
  if echo "$resp" | jq -e '.data.issues.nodes' >/dev/null 2>&1; then
    count="$(echo "$resp" | jq -r '.data.issues.nodes | length')"
    list="$(echo "$resp" | jq -r '.data.issues.nodes[] | "  - \(.identifier)  \(.title)"')"
    if [ "$count" -ge 8 ]; then
      emit "cap-8 REACHED: $count/8 of your issues are in a started state (In Progress + In Review). Do NOT move another issue into a started state until one is closed or moved back. Your started issues:
$list
(Personal WIP cap — see designs/linear-integration.md \"Cap-8\".)"
    elif [ "$count" -ge 7 ]; then
      emit "cap-8 WARNING: $count/8 of your issues are in a started state. One more reaches the cap. Your started issues:
$list"
    fi
    exit 0
  fi
  # fall through to no-Linear reminder if the query failed.
fi

# --- NO-LINEAR mode: once-per-session honor reminder -----------------------
marker=""
if [ -n "$SESSION_NAME" ]; then
  marker="$SCRATCH_DIR/.cap8-reminded.$SESSION_NAME"
elif [ -n "$SESSION_ID" ]; then
  marker="$SCRATCH_DIR/.cap8-reminded.$SESSION_ID"
fi
[ -n "$marker" ] && [ -f "$marker" ] && exit 0
if [ -n "$marker" ]; then
  mkdir -p "$SCRATCH_DIR" 2>/dev/null || true
  : > "$marker" 2>/dev/null || true
fi

emit "cap-8 (honor-system, no LINEAR_API_KEY wired): cap-8 = at most 8 issues assigned to you in a started state (In Progress + In Review), design and operational alike. Warn at 7, stop at 8. When you move one of your issues into a started state this turn, check the live count via the Linear MCP (assignee=me, state.type=started) and surface it. See designs/linear-integration.md \"Cap-8\"."
