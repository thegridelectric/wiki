#!/bin/bash
# precheck-linear-issue-meta.sh — PreToolUse gate on the Linear MCP
# `save_issue` call. When **creating** a `design`-labeled issue, require the
# metadata a design issue must carry (assignee, initial state, priority) — so a
# design issue never lands half-configured (the OPS-380 failure mode).
#
# Only gates CREATES of design issues:
#   - `id` present  → an update, not a create → pass.
#   - labels lacks `design` → not a design issue → pass.
#   - design create missing assignee / state / priority → permissionDecision
#     "ask", listing what to set (assignee default: me; state Todo, or In
#     Progress if starting now; priority e.g. Medium).
#
# The matcher in settings.json is the MCP tool name `mcp__linear__save_issue`.
# See wiki/linear.md "Design lifecycle in Linear".
#
# Override: ~/.claude/.bulk-stop-override(.<session>) silences this hook.

set -e

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

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "mcp__linear__save_issue" ] || exit 0

# Update (has id) → not our concern.
issue_id=$(echo "$input" | jq -r '.tool_input.id // ""')
[ -n "$issue_id" ] && exit 0

# Only gate design-labeled creates.
echo "$input" | jq -e '(.tool_input.labels // []) | index("design")' >/dev/null 2>&1 || exit 0

missing=""
assignee=$(echo "$input" | jq -r '.tool_input.assignee // ""')
[ -z "$assignee" ] && missing="${missing} assignee"
state=$(echo "$input" | jq -r '.tool_input.state // ""')
[ -z "$state" ] && missing="${missing} state"
echo "$input" | jq -e '.tool_input | has("priority")' >/dev/null 2>&1 || missing="${missing} priority"

[ -z "$missing" ] && exit 0

reason="Creating a \`design\` issue without:${missing}. A design issue MUST land
fully configured (the OPS-380 failure mode). Set on this create:
  • assignee  — default: me (jmillar)
  • state     — Todo (ratified + queued) or In Progress (starting now;
                a started state counts against cap-8)
  • priority  — Linear's Urgent/High/Medium/Low/No-priority (don't leave unset)
See wiki/linear.md \"Design lifecycle in Linear\"."

jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
