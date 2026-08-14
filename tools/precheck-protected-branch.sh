#!/bin/bash
# PreToolUse on Edit/Write/NotebookEdit: HARD-BLOCK any edit whose target is in
# a CODE repo currently on a protected branch (dev/main/master). Code repos are
# never edited locally on dev or main — cut a jm/<topic> branch first.
#
# The WIKI is exempt: editing wiki on main is normal and allowed. Only the code
# repos in _repo-domain-pairs.sh are guarded.
#
# Absolute guard: no bulk override. The only way past is to switch the repo to a
# non-protected branch.
set -e

UMBRELLA="$(cd "$(dirname "$0")/../.." && pwd)"
PROTECTED="dev main master"

input=$(cat)

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

# Resolve the target to a known CODE repo root. The wiki is deliberately NOT in
# this map, so wiki edits fall through to "allow".
# shellcheck source=_repo-domain-pairs.sh
. "$UMBRELLA/wiki/tools/_repo-domain-pairs.sh"

repo_root=""
while IFS= read -r pair; do
  [ -z "$pair" ] && continue
  repo="${pair%%:*}"
  case "$abs" in
    "$UMBRELLA/$repo/"*)
      repo_root="$UMBRELLA/$repo"
      break
      ;;
  esac
done <<< "$REPO_DOMAIN_PAIRS"

# Not a known code repo (wiki, scratch dirs, anything else) → allow.
[ -n "$repo_root" ] || exit 0

branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
for p in $PROTECTED; do
  [ "$branch" = "$p" ] || continue
  reason="BLOCKED: ${repo_root##*/} is on protected branch '$branch'.

Code repos are NEVER edited locally on dev/main/master. Create a topic branch
before editing:
    git -C $repo_root switch -c jm/<topic>

then retry the edit. This guard is absolute — there is no override. (The wiki is
exempt; editing wiki on main is fine. Code repos are not.)"
  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
done

exit 0
