#!/usr/bin/env bash
# linear-snapshot.sh — token-cheap Linear sync for Claude sessions.
#
# Pulls the OPEN Ops issues via the Linear GraphQL API and writes a compact,
# gitignored CSV so a session greps one small file instead of paying for MCP
# JSON. "Open" = every state whose type is NOT completed/canceled (so Done,
# Canceled, and Duplicate are excluded; Backlog/Todo/In Progress/In Review
# stay). The hand-maintained triage table in designs/linear-integration.md is
# meant to lean on this: the script refreshes the FACTS, sessions add judgment.
#
# The MCP is Claude-facing, not shell-callable — so, like the other Linear
# hooks, this calls Linear's web API directly and needs $LINEAR_API_KEY in the
# environment (a personal API key from Linear settings). No key → it refuses
# and says so; there is no wiki-side fallback for a data pull.
#
# Output columns (one issue per row, @csv-quoted):
#   id,title,state,priority,labels,started_age_d,updated_age_d,design
#     id            OPS-NNN identifier
#     title         issue title
#     state         workflow state NAME (Backlog / Todo / In Progress / …)
#     priority      Linear priority label (Urgent / High / … / No priority)
#     labels        pipe-joined label names ("design|scada|Bug")
#     started_age_d whole days since startedAt (empty if never started)
#     updated_age_d whole days since updatedAt
#     design        the wiki designs/ path scanned out of the body (design
#                   issues only; empty otherwise)
#
# Usage:
#   wiki/tools/linear-snapshot.sh [output-csv]
# Default output: wiki/.linear-snapshot.csv (gitignored).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIKI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="${1:-$WIKI_ROOT/.linear-snapshot.csv}"

command -v jq   >/dev/null 2>&1 || { echo "✗ jq not found"   >&2; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "✗ curl not found" >&2; exit 1; }

if [ -z "${LINEAR_API_KEY:-}" ]; then
  cat >&2 <<'EOF'
✗ LINEAR_API_KEY is not set — this script pulls live data from Linear's web API.
  Create a personal API key in Linear settings (Security & access → API) and
  export LINEAR_API_KEY=<key>, then re-run. (Optional wiring is tracked in
  designs/linear-integration.md.)
EOF
  exit 1
fi

# Open Ops issues = team OPS, state type not completed/canceled. Paginated.
read -r -d '' QUERY <<'GQL' || true
query($after: String) {
  issues(
    first: 250
    after: $after
    filter: {
      team: { key: { eq: "OPS" } }
      state: { type: { nin: ["completed", "canceled"] } }
    }
  ) {
    pageInfo { hasNextPage endCursor }
    nodes {
      identifier
      title
      priorityLabel
      startedAt
      updatedAt
      state { name }
      labels { nodes { name } }
      description
    }
  }
}
GQL

nodes_file="$(mktemp)"
trap 'rm -f "$nodes_file"' EXIT

after=""
page=0
while :; do
  payload="$(jq -n --arg query "$QUERY" --arg after "$after" \
    'if $after == "" then {query: $query}
     else {query: $query, variables: {after: $after}} end')"

  resp="$(curl -s --max-time 20 -X POST https://api.linear.app/graphql \
            -H "Authorization: $LINEAR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$payload" || true)"

  if ! echo "$resp" | jq -e '.data.issues.nodes' >/dev/null 2>&1; then
    echo "✗ Linear query failed (page $page):" >&2
    echo "$resp" | jq -r '.errors[]?.message // empty' >&2 || true
    [ -z "$resp" ] && echo "  (empty response — network or timeout?)" >&2
    exit 1
  fi

  echo "$resp" | jq -c '.data.issues.nodes[]' >> "$nodes_file"
  page=$((page + 1))

  [ "$(echo "$resp" | jq -r '.data.issues.pageInfo.hasNextPage')" = "true" ] || break
  after="$(echo "$resp" | jq -r '.data.issues.pageInfo.endCursor')"
done

# Render the accumulated nodes to CSV. Ages are whole days from the ISO
# timestamps (strip fractional seconds before fromdateiso8601, which wants
# exactly %Y-%m-%dT%H:%M:%SZ). The design path is scanned out of the body so
# it survives whether the link is bare or markdown-hyperlinked.
{
  echo "id,title,state,priority,labels,started_age_d,updated_age_d,design"
  jq -r -s '
    def age($d): if ($d // null) == null then ""
      else ((now - (($d[:19]) + "Z" | fromdateiso8601)) / 86400 | floor) end;
    sort_by(.identifier)
    | .[]
    | [ .identifier,
        .title,
        .state.name,
        .priorityLabel,
        ([.labels.nodes[].name] | join("|")),
        age(.startedAt),
        age(.updatedAt),
        ((.description // "") | [scan("[A-Za-z0-9_./-]*designs/[A-Za-z0-9_./-]+\\.md")] | first // "")
      ]
    | @csv
  ' "$nodes_file"
} > "$OUT"

count="$(wc -l < "$OUT" | tr -d ' ')"
echo "✓ wrote $((count - 1)) open Ops issues → $OUT"
