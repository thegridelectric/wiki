#!/usr/bin/env bash
# UserPromptSubmit hook: when THIS session's active-claims row has a Scope that
# includes a sema path (`sema/` or `wiki/sema/`), inject the sema MUSTs + a hard
# "read the spec" directive — ONCE per session.
#
# Why claim-scoped (not edit-gated): the failure mode this guards against is
# *reasoning* about sema conventions (casing, TypeName, versions) during design
# without having read the canon — which happens well before any sema code edit,
# so a PreToolUse block on sema edits would fire too late. Keying off the claim
# covers the whole sema-focused session, design phase included.
#
# Self-locating: lives at <umbrella>/wiki/tools/<this-file>.
# GW_ACTIVE_CLAIMS overrides the active-claims path (tests).
set -uo pipefail

GW="$(cd "$(dirname "$0")/../.." && pwd)"
ACTIVE_CLAIMS="${GW_ACTIVE_CLAIMS:-$GW/wiki/active-claims.md}"

input=$(cat 2>/dev/null || true)

# Resolve this session's id (stdin JSON first, then env), then first-6 hash.
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$sid" ] && exit 0
hash="${sid:0:6}"

# Fire at most once per session.
marker="$HOME/.claude/.sema-claim-context.$sid"
[ -f "$marker" ] && exit 0

[ -f "$ACTIVE_CLAIMS" ] || exit 0

# This session's row, matched by "· <hash> |" in the Session cell.
row=$(grep -F "· ${hash} |" "$ACTIVE_CLAIMS" 2>/dev/null | head -1)
[ -z "$row" ] && exit 0

# Scope is the 3rd table cell. Does it name a sema path?
scope=$(printf '%s' "$row" | awk -F'|' '{print $4}')
echo "$scope" | grep -Eq '(^|[^a-z])(wiki/)?sema/' || exit 0

mkdir -p "$HOME/.claude" && : > "$marker"

CTX="Your active-claims Scope includes sema. Before reasoning about or editing anything sema, you MUST read the sema canon — do not answer sema questions (casing, TypeName/Version, formats, enums, versioning) from memory or by grepping for an answer the spec already fixes:

  1. Read \`sema/spec/primary.md\` (the contract), plus the relevant \`sema/spec/{registry,authoring}/\` spoke for the kind of work.
  2. READ-RECEIPT — before any other sema work this session, post the user a 3-5 line summary of \`sema/spec/primary.md\`'s core principles (in your own words). This is mandatory: it both forces a real read (you cannot summarize what you did not open) and gives the user a visible confirmation the canon was loaded. Do not skip or defer it.

Settled rules to anchor on now:
  - Serialized JSON field names use CamelCase/PascalCase, recursively (spec Principle 2).
  - Vocabulary names are \`left.right.dot\`; a message's \`TypeName\` VALUE is that dotted name, versioned types carry \`Version\` (\"000\") (Principles 1, 3).
  - Preserve TypeName/Version semantics; formats are immutable; enums are additive-only; historical versions are immutable; bump versions per spec.
  - Adding/modifying a vocabulary word → read the spec spokes for its kind, summarize that kind's rules to the user, and WAIT for confirmation before editing (GridWorks_CLAUDE.md \"Domain protocol files\").

(This reminder fires once per session while a sema claim is active.)"

jq -n --arg c "$CTX" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
