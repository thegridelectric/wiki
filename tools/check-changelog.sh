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

UMBRELLA="$(cd "$(dirname "$0")/../.." && pwd)"
WIKI="$UMBRELLA/wiki"

INPUT=$(cat 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)

# shellcheck source=_repo-domain-pairs.sh
. "$UMBRELLA/wiki/tools/_repo-domain-pairs.sh"
PAIRS="$REPO_DOMAIN_PAIRS"

# Scope-aware (via _session-scope.sh): a pending marker or unreconciled
# HEAD is dispositionable only by the session claiming that domain —
# nagging every other session is pure noise. Unidentified session ⇒
# umbrella-wide fallback.
# shellcheck source=_session-scope.sh
. "$UMBRELLA/wiki/tools/_session-scope.sh"
resolve_session_scope "$SESSION_ID"

domain_in_scope() {  # $1 = wiki domain, $2 = repo dir ("" if unknown)
  [ -z "$SCOPE_PATHS" ] && return 0
  echo "$SCOPE_PATHS" | grep -qx "wiki/$1" && return 0
  [ -n "$2" ] && echo "$SCOPE_PATHS" | grep -qx "$2" && return 0
  return 1
}

repo_for_domain() {  # reverse lookup in PAIRS
  for p in $PAIRS; do
    [ "${p##*:}" = "$1" ] && printf '%s' "${p%%:*}" && return 0
  done
  return 0
}

flags=""

# (1) Pending markers (scoped to this session's claimed domains)
pending=$(grep -l '<!-- pending commit -->' "$WIKI"/*/changelog.md 2>/dev/null || true)
scoped_pending=""
for f in $pending; do
  d=$(basename "$(dirname "$f")")
  if domain_in_scope "$d" "$(repo_for_domain "$d")"; then
    scoped_pending="${scoped_pending}${f}
"
  fi
done
if [ -n "$scoped_pending" ]; then
  flags="${flags}Pending changelog markers (reconcile or remove):
$(printf '%s' "$scoped_pending" | sed 's|^|  - |')

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
  domain_in_scope "$domain" "$repo" || continue

  hash=$(git -C "$repo_path" log -1 --pretty=format:'%h' 2>/dev/null || true)
  subject=$(git -C "$repo_path" log -1 --pretty=format:'%s' 2>/dev/null || true)
  [ -z "$hash" ] && continue

  # Exempt PR / branch merge commits (2+ parents): the substantive commit they
  # merge carries its own changelog entry, so the merge commit itself is noise.
  # A squash-merge (single parent) IS the change and is still checked.
  parents=$(git -C "$repo_path" log -1 --pretty=format:'%P' 2>/dev/null || true)
  case "$parents" in
    *' '*) continue ;;
  esac

  # Exempt mechanical / tooling commits — pure formatting, lint, lockfile,
  # whitespace, etc. carry no narrative worth a changelog entry. Matched by
  # subject prefix (case-insensitive). NOTE: `version …` is deliberately NOT
  # here — release bumps still get an entry (the release rationale).
  subj_lc=$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]')
  case "$subj_lc" in
    lint*|ruff*|format*|fmt*|style*|chore*|pyupgrade*|pre-commit*|precommit*|\
    relock*|whitespace*|typo*|"fix lint"*|"fix linting"*|"fix format"*|\
    "fix style"*|"fix whitespace"*|"fix typo"*|"fix imports"*) continue ;;
  esac

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
