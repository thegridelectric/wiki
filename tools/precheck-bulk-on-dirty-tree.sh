#!/bin/bash
# PreToolUse hook: when a Bash call invokes a bulk-transform tool (regen
# script, formatter, codemod, pre-commit run, etc.), check whether the
# repo containing cwd has uncommitted changes. If yes, inject a
# STOP-AND-ASK reminder so Claude doesn't bury in-flight focused work
# inside a large bulk diff.
#
# The trigger is structural (dirty tree + bulk op); the disposition
# (commit / stash / branch / abort) is the user's call, not Claude's.
# See umbrella CLAUDE.md "Working-tree hygiene" and the feedback memory
# `feedback_branch_per_topic_before_bulk_changes.md`.
#
# Complements stop-bulk-on-dirty-tree.sh (Stop hook) which catches the
# other failure mode: cumulative drift across many small edits within a
# turn that pushes the working tree past the file-count threshold even
# without any single bulk-transform command.

set -e

input=$(cat)

SESSION_ID=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || true)

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Match common bulk-transform invocations. Conservative: false positives
# are cheap (the assistant just sees a warning and proceeds with
# context); false negatives are the failure mode this hook exists to
# prevent. Add patterns over time as more tools surface.
bulk_re='(ruff[[:space:]]+(format|check[^|;&]*--fix)|pre-commit[[:space:]]+run|regenerate_runtime|snapshot[[:space:]]+build|runtime\.sh|pyupgrade|^black[[:space:]]|^isort[[:space:]])'

if ! echo "$command" | grep -Eq "$bulk_re"; then
  exit 0
fi

# Pick the repo to check. cwd is provided in tool_input.cwd when Claude
# sets it (rare); otherwise fall back to the hook's own working directory.
cwd=$(echo "$input" | jq -r '.tool_input.cwd // empty')
[ -n "$cwd" ] || cwd="$PWD"

repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || true)
[ -n "$repo_root" ] || exit 0

# The wiki repo is exempt: wiki changes are not cluster-checked (umbrella
# CLAUDE.md "Working-tree hygiene"), and its tree is the multi-session
# coordination surface — practically always dirty with several sessions'
# in-flight prose. Burial protection there is the claims protocol's job.
[ "$(basename "$repo_root")" = "wiki" ] && exit 0

status_short=$(git -C "$repo_root" status --short 2>/dev/null || true)
[ -z "$status_short" ] && exit 0

# Claim-aware disposition (via _session-scope.sh). Three tiers:
#   1. Own-scoped + declared cluster (pending changelog marker for the
#      repo's domain): the dirt IS the declared in-flight work — a bulk
#      op over it is the work continuing, not burial. Silent.
#   2. Own-scoped, undeclared: stop (topic-less accumulation), unless
#      the user's bulk-on override is set.
#   3. Foreign or unclaimed dirt: ALWAYS stop — the bulk-on override
#      never silences this case (bulk-on is a volume knob for a
#      session's own sweeps, not a license over others' WIP).
# Unidentified session: scope unknown — honor the override, else stop.
TOOLS_DIR="/Users/jessica/GridWorks/wiki/tools"
# shellcheck source=_session-scope.sh
. "$TOOLS_DIR/_session-scope.sh"
# shellcheck source=_repo-domain-pairs.sh
. "$TOOLS_DIR/_repo-domain-pairs.sh"
resolve_session_scope "$SESSION_ID"

repo_name=$(basename "$repo_root")
own_scoped=""
if [ -n "$SCOPE_PATHS" ] && echo "$SCOPE_PATHS" | grep -qx "$repo_name"; then
  own_scoped="yes"
fi

if [ "$own_scoped" = "yes" ]; then
  domain=""
  for pair in $REPO_DOMAIN_PAIRS; do
    [ -z "$pair" ] && continue
    [ "${pair%%:*}" = "$repo_name" ] && domain="${pair##*:}"
  done
  if [ -n "$domain" ] \
     && grep -q "pending commit" "/Users/jessica/GridWorks/wiki/$domain/changelog.md" 2>/dev/null; then
    exit 0
  fi
fi

if [ "$own_scoped" = "yes" ] || [ -z "$SCOPE_PATHS" ]; then
  if [ -n "$SESSION_NAME" ] && [ -f "$HOME/.claude/.bulk-stop-override.$SESSION_NAME" ]; then
    exit 0
  fi
  if [ -f "$HOME/.claude/.bulk-stop-override" ]; then
    exit 0
  fi
fi

msg="Bulk-transform command on a dirty working tree.

Per umbrella CLAUDE.md (\"Working-tree hygiene\"): you SHALL NOT decide
what to do with the in-flight uncommitted work yourself. STOP AND ASK
the user before proceeding.

Repo: $repo_root
Planned command: $command

git status --short:
$status_short

Surface this to the user with the obvious dispositions:
- commit the in-flight work first (suggest a focused subject line),
- stash and pop after the bulk op,
- leave on this branch and checkout fresh from the merge target,
- abort the bulk op.

Then wait for the user to decide."

jq -n --arg ctx "$msg" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
