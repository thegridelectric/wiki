#!/bin/bash
# Stop hook: at end of each Claude turn, flag NEW intra-wiki broken links
# (danglers) introduced in markdown files THIS session changed. "New" means
# the dangling link text is absent from the file's HEAD version — pre-existing
# danglers (tracked in tests/test_doc_health.py KNOWN_PENDING) are NOT nagged.
#
# Shares the resolver tools/check_wiki_links.py with the pytest test, so the
# same exclusions apply: external URLs, cross-repo links, `wiki/`-prefixed
# (umbrella-relative) targets, `(Open)`/`(TBD)`-marked planned spokes, and
# links inside code spans.
#
# Override: if ~/.claude/.bulk-stop-override(.<session>) exists, stay silent
# (legitimate bulk burst). Claude MUST NOT create that file; the user does via
# `bulk-on` (see wiki/tools/bulk-aliases.sh).

set -e

UMBRELLA=/Users/jessica/GridWorks
WIKI="$UMBRELLA/wiki"
SCRATCH_DIR="$HOME/.claude/projects/-Users-jessica-GridWorks/scratch"

INPUT=$(cat)

# Session-aware bulk override (per-session takes precedence; global fallback).
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

[ -d "$WIKI/.git" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# Scope-aware: restrict to wiki files within THIS session's active-claims
# scope, so we don't flag another session's edits. No identifiable claim →
# check all changed wiki files (unclaimed sessions still protected).
ACTIVE_CLAIMS="$WIKI/active-claims.md"
SCOPE_PATHS=""
if [ -n "$SESSION_NAME" ] && [ -f "$ACTIVE_CLAIMS" ]; then
  row=$(grep "^| $SESSION_NAME " "$ACTIVE_CLAIMS" 2>/dev/null | head -1)
  if [ -n "$row" ]; then
    scope_cell=$(echo "$row" | awk -F'|' '{print $4}')
    # paths are like `wiki/<domain>/` or `wiki/<file>.md`; strip the wiki/ prefix
    SCOPE_PATHS=$(echo "$scope_cell" | sed 's|<br>|\
|g' | sed 's|^ *||;s| *$||;s|/$||;s|^wiki/||' | grep -v '^$' || true)
  fi
fi

# Changed *.md files (staged, unstaged, untracked), relative to wiki root.
changed=$(git -C "$WIKI" status --short 2>/dev/null \
  | sed 's/^...//; s/.* -> //' \
  | grep -E '\.md$' || true)
[ -z "$changed" ] && exit 0

# Apply scope filter + build absolute path list.
files=""
while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  if [ -n "$SCOPE_PATHS" ]; then
    in_scope=""
    while IFS= read -r sp; do
      [ -z "$sp" ] && continue
      case "$rel" in "$sp"|"$sp"/*) in_scope=1; break;; esac
    done <<< "$SCOPE_PATHS"
    [ -z "$in_scope" ] && continue
  fi
  [ -f "$WIKI/$rel" ] && files="$files $WIKI/$rel"
done <<< "$changed"
[ -z "$files" ] && exit 0

# shellcheck disable=SC2086
report=$(python3 "$WIKI/tools/check_wiki_links.py" "$WIKI" --new-in $files 2>/dev/null) || true
echo "$report" | grep -q '^  \[' || exit 0

ts=$(date +%Y%m%dT%H%M%S)
reason="Dangling-link check (Stop hook): markdown files you changed this turn
introduced intra-wiki links that do not resolve:

$report

These are NEW (absent from the files' HEAD versions). Pre-existing danglers
are not flagged here. You SHALL:
1. Cache your immediate plan to a scratch note at
   $SCRATCH_DIR/pending-plan-$ts.md (one or two sentences).
2. Pivot your next response to fix each link — correct the path, or if the
   target is a planned-but-unwritten spoke, mark it \`(Open)\`. If a link is
   intentionally cross-repo/external it would not be flagged; re-check the path.
3. Do NOT finish until the links resolve or the user accepts them.
(Legitimate bulk burst? The user can run \`bulk-on\` to silence this.)"

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
