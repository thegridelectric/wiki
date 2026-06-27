#!/usr/bin/env bash
# linear-snapshot.sh — token-cheap Linear sync for Claude sessions.
#
# Pulls the OPEN Ops issues via the Linear GraphQL API and writes a compact,
# gitignored CSV so a session greps one small file instead of paying for MCP
# JSON. "Open" = every state whose type is NOT completed/canceled/duplicate (so
# Done, Canceled, and Duplicate are excluded; Triage/Backlog/Todo/In Progress/
# In Review stay). The hand-maintained triage table in designs/linear-integration.md is
# meant to lean on this: the script refreshes the FACTS, sessions add judgment.
#
# It also evaluates a personal triage invariant (see the block below the CSV
# write): every OPEN issue assigned to me must carry exactly one of the
# `design` / `parked` labels — and prints the discrepancies.
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

# Open Ops issues = team OPS, state type not completed/canceled/duplicate. Paginated.
read -r -d '' QUERY <<'GQL' || true
query($after: String) {
  issues(
    first: 250
    after: $after
    filter: {
      team: { key: { eq: "OPS" } }
      state: { type: { nin: ["completed", "canceled", "duplicate"] } }
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

# ── personal triage invariant ───────────────────────────────────────────────
# Every issue assigned to me sits in ONE bucket:
#   (1) closed  — state type completed/canceled/duplicate (Done/Cancelled/Duplicate)
#   (2) design  — open, carrying the `design` label
#   (3) parked  — open, carrying the `parked` label
#   (4) nit     — open, carrying the `nit` label (sub-threshold cleanup not worth
#                 a design; an active nit is legitimately neither parked nor design)
# "Closed dominates": a closed issue is exempt. So the live check reduces to:
# every OPEN issue of mine carries AT LEAST ONE of {design, parked, nit}. A
# violation is an open issue with NONE (untriaged — design it, park it, or mark a
# nit), or the contradictory combo `design` + (`parked`|`nit`) — `design` is
# mutually exclusive with both.
echo
echo "── personal triage invariant: every OPEN issue of mine carries one of {design, parked, nit} (or a hardware/ops tag) ──"
inv_q='{"query":"{ issues(filter:{assignee:{isMe:{eq:true}}, state:{type:{nin:[\"completed\",\"canceled\",\"duplicate\"]}}}, first:250){ pageInfo{hasNextPage} nodes{ identifier title state{name} labels{nodes{name}} } } }"}'
inv_resp="$(curl -s --max-time 20 -X POST https://api.linear.app/graphql \
              -H "Authorization: $LINEAR_API_KEY" \
              -H "Content-Type: application/json" \
              -d "$inv_q" || true)"
if ! echo "$inv_resp" | jq -e '.data.issues.nodes' >/dev/null 2>&1; then
  echo "⚠  invariant check skipped — my-open-issues query failed" >&2
else
  [ "$(echo "$inv_resp" | jq -r '.data.issues.pageInfo.hasNextPage')" = "true" ] && \
    echo "⚠  >250 open issues assigned to me — list truncated; paginate before relying" >&2
  echo "$inv_resp" | jq -r '
    def has($l): any(.labels.nodes[]?.name; . == $l);
    .data.issues.nodes
    | map({ id: .identifier, st: .state.name, title: .title,
            d: has("design"), p: has("parked"), n: has("nit"),
            hw: (has("electronics") or has("hardware") or has("fcm") or has("ops-automate") or has("alerts")) })
    | map(. + { none: ((.d or .p or .n or .hw) | not),
                contra: (.d and (.p or .n)) })
    | ([.[] | select(.none)]) as $none
    | ([.[] | select(.contra)]) as $contra
    | "  open: \(length)   ok: \(map(select((.none or .contra) | not)) | length)   discrepancies: \(($none + $contra) | length)",
      ( if (($none + $contra) | length) == 0 then
          "  ✓ invariant holds"
        else
          ( if ($none | length) > 0 then
              "  ✗ NEITHER design/parked/nit (\($none | length)) — design it, park it, or mark a nit:",
              ($none | sort_by(.st, .id)[] | "    - \(.id)  [\(.st)]  \(.title[0:60])")
            else empty end ),
          ( if ($contra | length) > 0 then
              "  ✗ `design` + parked/nit (\($contra | length)) — contradictory, pick one:",
              ($contra | sort_by(.st, .id)[] | "    - \(.id)  [\(.st)]  \(.title[0:60])")
            else empty end )
        end )
  '
fi
