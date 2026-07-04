#!/usr/bin/env bash
# UserPromptSubmit hook: when THIS session's active-claims row has a Scope that
# includes a gridworks-scada path (`gridworks-scada/` or `wiki/gridworks-scada/`),
# inject the scada protocol pointer + anchor rules — ONCE per session.
#
# Why claim-scoped (not edit-gated): the lazy-load gap this closes is a session
# doing scada design/wiki work that never touches the code repo, so no
# code-repo CLAUDE.md (there deliberately is none — LLM-facing material lives
# in the wiki) and no PreToolUse edit gate would ever fire. Keying off the
# claim covers the whole scada-focused session. Mirrors sema-claim-context.sh.
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
marker="$HOME/.claude/.scada-claim-context.$sid"
[ -f "$marker" ] && exit 0

[ -f "$ACTIVE_CLAIMS" ] || exit 0

# This session's row, matched by "· <hash> |" in the Session cell.
row=$(grep -F "· ${hash} |" "$ACTIVE_CLAIMS" 2>/dev/null | head -1)
[ -z "$row" ] && exit 0

# Scope is the 3rd table cell. Does it name a gridworks-scada path?
scope=$(printf '%s' "$row" | awk -F'|' '{print $4}')
echo "$scope" | grep -Eq '(^|[^a-z-])(wiki/)?gridworks-scada/' || exit 0

mkdir -p "$HOME/.claude" && : > "$marker"

CTX="Your active-claims Scope includes gridworks-scada. Before editing the scada repo (gwsproto above all), you MUST read \`wiki/gridworks-scada/CLAUDE.md\` and follow it — the code repo carries no CLAUDE.md; the protocol lives in the wiki.

Anchor rules (the file is authoritative):
  - Serialize gwsproto named-types with \`model_dump(by_alias=True)\` (snake-field types emit snake_case otherwise; decode tolerance hides the mistake).
  - gwsproto sema-type docstrings are exactly \`Sema: <schema_url>\` — nothing else.
  - Mirror sema axioms as \`check_axiom_<n>\` @model_validator methods; never capture a bound with a \`Literal\` (it silently drops the axiom).
  - Validate hand-written gwsproto types via \`sema validate <payload.json>\` against the canonical runtime.
  - Branch discipline: scada layout work lands on \`jm/spruce-unlimbo\`; check the temporary directives at the top of the file before cutting any branch.

(This reminder fires once per session while a gridworks-scada claim is active.)"

jq -n --arg c "$CTX" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
