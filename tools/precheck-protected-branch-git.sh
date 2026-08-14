#!/bin/bash
# PreToolUse on Bash: HARD-BLOCK history-mutating git commands (commit, merge,
# rebase, cherry-pick, revert, reset --hard, branch -f, push --force) run
# against a CODE repo currently on a protected branch (dev/main/master). Second
# layer behind precheck-protected-branch.sh: no commits/merges/resets land
# directly on a code repo's dev/main.
#
# Repo is resolved best-effort from (in precedence): an explicit `git -C <path>`,
# a leading/embedded `cd <path>`, else $PWD. The WIKI is exempt.
#
# Absolute guard: no override. Switch to a topic branch first.
set -e

UMBRELLA="$(cd "$(dirname "$0")/../.." && pwd)"
PROTECTED="dev main master"

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Only history-mutating git verbs. Narrow on purpose: read-only git is allowed.
if ! echo "$command" | grep -Eq \
  'git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(commit|merge|rebase|cherry-pick|revert)\b|git[[:space:]].*(reset[[:space:]]+--hard|branch[[:space:]]+-(f|-force)|push[[:space:]].*--force)'; then
  exit 0
fi

# Resolve target repo dir: explicit `git -C` wins, then a `cd <path>`, then $PWD.
target_dir=$(echo "$command" | grep -oE 'git[[:space:]]+-C[[:space:]]+[^[:space:]]+' | head -1 | awk '{print $3}')
if [ -z "$target_dir" ]; then
  target_dir=$(echo "$command" | grep -oE '(^|[[:space:]&;|])cd[[:space:]]+[^[:space:]&;|]+' | head -1 | awk '{print $NF}')
fi
[ -n "$target_dir" ] || target_dir="$PWD"
# Expand a leading ~ and make relative paths absolute.
case "$target_dir" in
  "~"*) target_dir="${target_dir/#\~/$HOME}" ;;
esac
case "$target_dir" in
  /*) ;;
  *)  target_dir="$PWD/$target_dir" ;;
esac

repo_root=$(git -C "$target_dir" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -n "$repo_root" ] || exit 0

# Exempt the wiki; only guard known code repos.
[ "$repo_root" = "$UMBRELLA/wiki" ] && exit 0
# shellcheck source=_repo-domain-pairs.sh
. "$UMBRELLA/wiki/tools/_repo-domain-pairs.sh"
is_code=""
while IFS= read -r pair; do
  [ -z "$pair" ] && continue
  repo="${pair%%:*}"
  [ "$repo_root" = "$UMBRELLA/$repo" ] && { is_code=1; break; }
done <<< "$REPO_DOMAIN_PAIRS"
[ -n "$is_code" ] || exit 0

branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
for p in $PROTECTED; do
  [ "$branch" = "$p" ] || continue
  reason="BLOCKED: history-mutating git on ${repo_root##*/} while on protected branch '$branch'.

Command: $command

Code repos take no commits/merges/resets directly on dev/main/master. Switch to
a topic branch first:
    git -C $repo_root switch -c jm/<topic>

This guard is absolute — there is no override. (The wiki is exempt.)"
  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
done

exit 0
