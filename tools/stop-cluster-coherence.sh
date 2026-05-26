#!/bin/bash
# Stop hook: at end of each Claude turn, ensure every dirty CODE REPO
# under the umbrella has a declared topic — i.e., a pending changelog
# entry (`<!-- pending commit -->`) in its matching
# wiki/<domain>/changelog.md. If not, flag.
#
# This is the cluster-coherence rule:
# - Wiki changes are NOT cluster-checked (they're their own
#   discrete-commit register).
# - Code-repo changes MUST be aligned with a declared topic. The
#   pending changelog entry IS the topic declaration.
# - Multiple code repos dirty at once = multiple clusters in flight,
#   each needing its own pending entry.
#
# Override: if ~/.claude/.bulk-stop-override exists, the hook stays
# silent (legitimate bulk burst). Claude MUST NOT create that file
# itself; the user creates it via `bulk-on` (see
# wiki/tools/bulk-aliases.sh).

set -e

UMBRELLA=/Users/jessica/GridWorks
SCRATCH_DIR="$HOME/.claude/projects/-Users-jessica-GridWorks/scratch"

INPUT=$(cat)

# Session-aware override check. Per-session takes precedence; global is
# a rare "silence everything" fallback. See wiki/tools/bulk-aliases.sh
# for the user's `bulk-on <session-name>` / `bulk-on --global` commands.
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
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

# shellcheck source=_repo-domain-pairs.sh
. "$UMBRELLA/wiki/tools/_repo-domain-pairs.sh"

# For each code repo:domain pair, if the repo has dirty files but no
# pending changelog entry exists, flag it.
flagged=""
while IFS= read -r pair; do
  [ -z "$pair" ] && continue
  repo="${pair%%:*}"
  domain="${pair##*:}"
  repo_dir="$UMBRELLA/$repo"
  changelog="$UMBRELLA/wiki/$domain/changelog.md"
  [ -d "$repo_dir/.git" ] || continue
  dirty_count=$(git -C "$repo_dir" status --short 2>/dev/null | wc -l | tr -d ' ')
  [ "$dirty_count" = "0" ] && continue
  if [ ! -f "$changelog" ] || ! grep -q "pending commit" "$changelog" 2>/dev/null; then
    flagged="${flagged}- $repo: $dirty_count dirty files, no <!-- pending commit --> in wiki/$domain/changelog.md
"
  fi
done <<< "$REPO_DOMAIN_PAIRS"

[ -z "$flagged" ] && exit 0

ts=$(date +%Y%m%dT%H%M%S)
reason="Cluster-coherence check (Stop hook): code repos dirty without a declared topic:

$flagged
Per umbrella CLAUDE.md \"Working-tree hygiene\": every dirty code repo
MUST have a pending changelog entry (\"<!-- pending commit -->\") in its
matching wiki/<domain>/changelog.md before edits accumulate. The entry
IS the topic declaration for the cluster.

You SHALL:
1. Cache your immediate plan to a scratch note at
   $SCRATCH_DIR/pending-plan-$ts.md
   (one or two sentences naming what you were about to do/say).
2. Pivot your next response to surface the dirty-without-topic state to
   the user and offer:
   - write the pending entry now (declaring the topic), then continue
   - commit and clear the dirty state first
   - enable bulk-mode override (\`bulk-on\` in the user's own terminal;
     Claude MUST NOT create the override file)
   - abort the next action
3. Do NOT make further code-repo edits until the user decides."

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
