#!/bin/bash
# PreToolUse hook on Bash: hard-DENY any `git commit` invocation by
# Claude. Commits are the user's exclusive purview per umbrella
# CLAUDE.md "Commit suggestions" and the feedback memory
# `git-commits-user-handles`. This hook converts that convention into
# structural enforcement: Claude can suggest the precise
# `git add` + `git commit` command, the user runs it.
#
# Matches:
# - `git commit`
# - `git commit -m "..."`
# - `git commit --amend`
# - chained forms (e.g. `git add foo && git commit -m "..."`)
#
# Does NOT match the plumbing commands `git commit-tree` /
# `git commit-graph` (different token boundary).
#
# No override file. If the user genuinely wants Claude to commit in a
# specific case, they should disable the hook locally — but this
# should be rare enough that the friction is the feature.

set -e

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // ""')

# `git[[:space:]]+commit` followed by end-of-string or whitespace.
# Word-boundary on the leading side via `(^|[^a-zA-Z0-9_-])`.
if echo "$command" | grep -Eq '(^|[^a-zA-Z0-9_-])git[[:space:]]+commit($|[[:space:]])'; then
  reason="Claude is hard-blocked from running \`git commit\` — commits are the
user's exclusive purview (umbrella CLAUDE.md \"Commit suggestions\";
memory \`git-commits-user-handles\`).

Planned command:
  $command

What to do instead:
- Suggest the exact \`git add <paths>\` (path-scoped, never \`-A\`
  while other sessions are live) and the commit subject line.
- Let the user run it."

  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
fi

exit 0
