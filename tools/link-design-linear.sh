#!/usr/bin/env bash
# link-design-linear.sh — connect a wiki design to its Linear issue (the
# bijection from designs/linear-integration.md).
#
# A design ↔ Linear is a 1:1 bijection. Both sides must cross-reference:
#   - Linear issue body  → the design's GitHub URL (the "Design:" line)
#   - wiki design Status: → "· Linear: OPS-NNN"
#   - the Linear issue is tagged `design` and its title === the slug.
#
# This helper validates the wiki side and prints exactly what to paste into
# the Linear issue, so the connection is obvious and consistent. It does NOT
# call Linear (the MCP is Claude-facing, not a shell API); the Linear-side
# write is done by Claude/the human. Once a Linear API token is wired, the
# query half (does an OPS-NNN issue exist + is it tagged `design`?) can be
# added here.
#
# Usage:
#   wiki/tools/link-design-linear.sh <design-path-relative-to-wiki> <OPS-id>
# Example:
#   wiki/tools/link-design-linear.sh \
#     gridworks-scada/designs/circulator-pump-0-10v-models.md OPS-27

set -euo pipefail

GH_BASE="https://github.com/thegridelectric/wiki/blob/main"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  echo "usage: $0 <design-path-relative-to-wiki> <OPS-id>" >&2
  echo "  e.g. $0 gridworks-scada/designs/circulator-pump-0-10v-models.md OPS-27" >&2
  exit 2
}

[ $# -eq 2 ] || usage
REL="$1"
OPS="$2"
ABS="$WIKI_ROOT/$REL"

# --- validate the design file ---------------------------------------------
case "$REL" in
  */designs/*.md|designs/*.md) : ;;
  *) echo "✗ '$REL' is not under a designs/ folder" >&2; exit 1 ;;
esac
[ -f "$ABS" ] || { echo "✗ design file not found: $ABS" >&2; exit 1; }

case "$OPS" in
  OPS-[0-9]*|GRI-[0-9]*) : ;;
  *) echo "✗ '$OPS' does not look like a Linear id (e.g. OPS-27)" >&2; exit 1 ;;
esac

SLUG="$(basename "$REL" .md)"
GH_URL="$GH_BASE/$REL"

# --- check the wiki → Linear back-link (Status line) ----------------------
STATUS_LINE="$(grep -m1 '^Status:' "$ABS" || true)"
if [ -z "$STATUS_LINE" ]; then
  echo "⚠  no 'Status:' line in $REL — add one (Draft · Pass 0 · Updated <date> · Linear: $OPS)"
elif printf '%s' "$STATUS_LINE" | grep -q "Linear: *$OPS"; then
  echo "✓ wiki → Linear back-link present: $STATUS_LINE"
else
  echo "⚠  Status line does not reference $OPS — append '· Linear: $OPS' to it:"
  echo "     $STATUS_LINE"
fi

# --- emit the Linear → wiki link to paste ---------------------------------
cat <<EOF

Paste this as the TOP line of the Linear issue $OPS body
(hyperlinked design link — the Linear → wiki half of the bijection):

  **Design:** [$REL]($GH_URL)

Then confirm on $OPS:
  • label  : design
  • title  : normalizes to the slug "$SLUG"
EOF
