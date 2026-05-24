#!/bin/bash
# Hook: enforce changelog discipline (UserPromptSubmit).
#
# Two checks:
# (1) Scan all wiki/<domain>/changelog.md for `<!-- pending commit -->` markers
#     left by the marker-protocol — flag them for reconciliation.
# (2) For each tracked sub-repo that has a matching wiki domain with a
#     changelog.md, check whether the repo's HEAD commit (short hash OR
#     subject) appears in the changelog. If not, flag it.
#
# Emits JSON on stdout with hookSpecificOutput.additionalContext when any
# discipline gap is detected. Silent on success.

set -e

UMBRELLA=/Users/jessica/GridWorks
WIKI="$UMBRELLA/wiki"

# repo-dir : wiki-domain pairs (only those that have a changelog.md).
# Add new pairs here as wiki domains gain changelogs.
PAIRS="
sema:sema
gridworks-base:gridworks-base
gridworks-data:gridworks-data
gridworks-scada:gridworks-scada
gridworks-fleet-index-service:gridworks-fleet-index-service
gridworks-ear:ear
"

flags=""

# (1) Pending markers
pending=$(grep -l '<!-- pending commit -->' "$WIKI"/*/changelog.md 2>/dev/null || true)
if [ -n "$pending" ]; then
  flags="${flags}Pending changelog markers (reconcile or remove):
$(echo "$pending" | sed 's|^|  - |')

"
fi

# (2) HEAD commit not reflected in matching wiki/<domain>/changelog.md
for pair in $PAIRS; do
  [ -z "$pair" ] && continue
  repo="${pair%%:*}"
  domain="${pair##*:}"
  repo_path="$UMBRELLA/$repo"
  changelog="$WIKI/$domain/changelog.md"
  [ -d "$repo_path/.git" ] || continue
  [ -f "$changelog" ] || continue

  hash=$(git -C "$repo_path" log -1 --pretty=format:'%h' 2>/dev/null || true)
  subject=$(git -C "$repo_path" log -1 --pretty=format:'%s' 2>/dev/null || true)
  [ -z "$hash" ] && continue

  if ! grep -qF "$hash" "$changelog" 2>/dev/null \
     && ! grep -qF "$subject" "$changelog" 2>/dev/null; then
    flags="${flags}- $repo HEAD ($hash \"$subject\") not in wiki/$domain/changelog.md
"
  fi
done

# Wiki commits are intentionally not checked: wiki content is self-documenting
# (the wiki page IS the why), so wiki commits don't need separate changelog
# entries.

[ -z "$flags" ] && exit 0

msg="Changelog discipline check found gaps:

${flags}
Per wiki/GridWorks_CLAUDE.md (living-spec discipline): when the user lands a commit you MUST add the matching wiki/<domain>/changelog.md entry before considering the work done. Handle this BEFORE responding to the user's message. If a flagged commit genuinely does not warrant a changelog entry (e.g., pre-convention or unrelated to a wiki domain), say so explicitly to the user and move on."

jq -n --arg ctx "$msg" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
