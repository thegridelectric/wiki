#!/bin/bash
# PreToolUse hook on Edit / Write / NotebookEdit targeting
# wiki/active-claims.md.  When the change adds a code-repo path to a
# Scope cell, verify that repo is clean (no uncommitted changes). If
# dirty, inject permissionDecision: "ask" so Claude pauses and surfaces
# the state to the user.
#
# Rationale (umbrella CLAUDE.md "Multi-session coordination"): when
# first claiming a repo, the working tree SHOULD be clean — dirty state
# usually means another session's WIP or forgotten work that you'd
# accidentally edit over.
#
# Override: ~/.claude/.bulk-stop-override(.<session>) silences this too.

set -e

UMBRELLA=/Users/jessica/GridWorks

input=$(cat)

# Session-aware override (per-session, then global).
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

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
case "$tool_name" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
[ -n "$file_path" ] || exit 0
case "$file_path" in
  /*) abs="$file_path" ;;
  *)  abs="$PWD/$file_path" ;;
esac

# Only inspect edits to wiki/active-claims.md
[ "$abs" = "$UMBRELLA/wiki/active-claims.md" ] || exit 0

# Extract old vs new content based on tool
case "$tool_name" in
  Edit)
    old_content=$(echo "$input" | jq -r '.tool_input.old_string // ""')
    new_content=$(echo "$input" | jq -r '.tool_input.new_string // ""')
    ;;
  Write)
    old_content=$(cat "$abs" 2>/dev/null || echo "")
    new_content=$(echo "$input" | jq -r '.tool_input.content // ""')
    ;;
  NotebookEdit)
    # Active-claims is markdown, not a notebook — unlikely path; bail.
    exit 0
    ;;
esac

# shellcheck source=_repo-domain-pairs.sh
. "$UMBRELLA/wiki/tools/_repo-domain-pairs.sh"

# Repos mentioned in content (only known code repos via REPO_DOMAIN_PAIRS).
mentions_repos() {
  local content="$1"
  while IFS= read -r pair; do
    [ -z "$pair" ] && continue
    local repo="${pair%%:*}"
    # Match `<repo>/` as a whole token: preceded by non-alnum-or-hyphen and
    # followed by slash.
    if echo "$content" | grep -qE "(^|[^a-zA-Z0-9_-])${repo}/" 2>/dev/null; then
      echo "$repo"
    fi
  done <<< "$REPO_DOMAIN_PAIRS"
}

old_repos=$(mentions_repos "$old_content")
new_repos=$(mentions_repos "$new_content")

flagged=""
while IFS= read -r repo; do
  [ -z "$repo" ] && continue
  # Skip if repo was already in the cell pre-change (re-arrangements, not
  # new additions).
  echo "$old_repos" | grep -qxF "$repo" && continue
  repo_dir="$UMBRELLA/$repo"
  [ -d "$repo_dir/.git" ] || continue
  count=$(git -C "$repo_dir" status --short 2>/dev/null | wc -l | tr -d ' ')
  if [ "$count" -gt 0 ]; then
    flagged="${flagged}- $repo: $count uncommitted files (\`git -C $repo_dir status --short\` to inspect)
"
  fi
done <<< "$new_repos"

[ -z "$flagged" ] && exit 0

reason="Active-claim adding repo(s) with uncommitted changes:

$flagged
Per umbrella CLAUDE.md \"Multi-session coordination\": when first claiming a
repo, the working tree SHOULD be clean (no foreign WIP). Stop and ask the
user to:
- review the dirty state (could be their own WIP, another session's, or
  forgotten work)
- decide whether to claim anyway (rare; user override), clean first, or
  back off the claim
Do NOT extend the claim into a dirty repo silently."

jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
