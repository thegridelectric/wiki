#!/bin/bash
# PreToolUse hook: when a Bash call creates a new git branch, re-inject
# the umbrella CLAUDE.md's Multi-session coordination section + current
# active-claims.md so the session re-reads the protocol at the natural
# "extending into a new repo" moment.
#
# Triggers on: `git checkout -b`, `git switch -c`. Silent otherwise.

set -e

UMBRELLA=/Users/jessica/GridWorks
WIKI="$UMBRELLA/wiki"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Match `git checkout -b <name>` or `git switch -c <name>`.
# Deliberately narrow: we want the branch-creation moment, not every git call.
if ! echo "$command" | grep -Eq '(^|[[:space:]&;|])git[[:space:]]+(checkout[[:space:]]+-b|switch[[:space:]]+-c)\b'; then
  exit 0
fi

# Pull the Multi-session coordination block out of CLAUDE.md, plus the
# whole current active-claims.md. Keep the injected text tight.
claude_md_block=$(awk '/^## Multi-session coordination/,/^## [^M]/' "$UMBRELLA/CLAUDE.md" | sed '$d')
active_claims=$(cat "$WIKI/active-claims.md" 2>/dev/null || echo "(file not found)")

msg="Branch-creation detected — re-loading multi-session context before this command runs.

A new git branch is the canonical \"extending into a new path or area\" moment. Before proceeding, verify your row in active-claims.md covers the repo you're branching in; if it does not, update active-claims.md FIRST, then re-run.

--- umbrella CLAUDE.md, Multi-session coordination section ---

$claude_md_block

--- wiki/active-claims.md (current) ---

$active_claims"

jq -n --arg ctx "$msg" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
