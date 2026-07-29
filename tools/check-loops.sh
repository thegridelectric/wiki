#!/bin/bash
# check-loops.sh — surface unclaimed loop instances into session context.
# Linear's recurrence mints copies of `loop`-labeled templates; an
# UNSTARTED loop issue is minted-but-unclaimed. Sessions should OFFER to
# run it; claiming = move it to In Progress (which silences this).
# Key: $LINEAR_API_KEY — the same gridworks-hooks key the bijection hook
# already uses (.claude/settings.local.json env). Unset ⇒ silent no-op.
# Register under SessionStart in .claude/settings.json. Fails silent.

[ -n "${LINEAR_API_KEY:-}" ] || exit 0

RESP=$(curl -s --max-time 5 https://api.linear.app/graphql \
  -H "Authorization: $LINEAR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"query":"{ issues(filter: { labels: { name: { eq: \"loop\" } }, state: { type: { in: [\"backlog\", \"unstarted\"] } } }) { nodes { identifier title dueDate } } }"}' \
  2>/dev/null) || exit 0

echo "$RESP" | python3 -c '
import json, sys
try:
    nodes = json.load(sys.stdin)["data"]["issues"]["nodes"]
except Exception:
    sys.exit(0)
if nodes:
    print("OPEN LOOP INSTANCES (recurring ops work, minted by Linear,")
    print("unclaimed — offer to run each this session; claiming = move it")
    print("to In Progress):")
    for n in nodes:
        due = f" (due {n[\"dueDate\"]})" if n.get("dueDate") else ""
        print(f"  - {n[\"identifier\"]}: {n[\"title\"]}{due}")
' 2>/dev/null
exit 0
