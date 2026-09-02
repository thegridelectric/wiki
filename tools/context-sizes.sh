#!/bin/bash
# context-sizes.sh — context size of live Claude sessions, from their
# transcripts. Each assistant turn in
# ~/.claude/projects/-Users-jessica-GridWorks/<session-id>.jsonl carries
# a usage block; input + cache_read + cache_creation on a turn is the
# context that turn was run with. The active-claims hash is the first six
# characters of the session id, so every claims row maps to a transcript.
#
# Usage:
#   context-sizes.sh                 table for every active-claims row
#   context-sizes.sh --file <jsonl>  one transcript, machine-readable:
#                                    "<turns> <context> <delta> <peak>"
#
# Thresholds (read by stop-context-size.sh; tune here, not in the hook):
CTX_WARN=250000     # wrap at the next re-orient
CTX_BAND=50000      # repeat the wrap note once per band above CTX_WARN
CTX_CLOSE=400000    # close now
DELTA_NOTE=40000    # single-turn growth worth a note (big read / fan-out)

PROJECTS="$HOME/.claude/projects/-Users-jessica-GridWorks"
CLAIMS="/Users/jessica/GridWorks/wiki/active-claims.md"

measure() {  # <jsonl> → "turns context delta peak"
  python3 - "$1" <<'PY'
import json, sys
turns = 0; peak = 0; ctx = 0; prev = 0
for line in open(sys.argv[1], encoding="utf-8"):
    try:
        d = json.loads(line)
    except ValueError:
        continue
    m = d.get("message")
    u = m.get("usage") if isinstance(m, dict) else None
    if not u:
        continue
    turns += 1
    prev = ctx
    ctx = (u.get("input_tokens", 0) + u.get("cache_read_input_tokens", 0)
           + u.get("cache_creation_input_tokens", 0))
    peak = max(peak, ctx)
print(turns, ctx, ctx - prev, peak)
PY
}

if [ "$1" = "--file" ]; then
  [ -f "$2" ] || { echo "no transcript: $2" >&2; exit 1; }
  measure "$2"
  exit 0
fi

printf '%-24s %-26s %6s %9s %8s %9s\n' SESSION FOCUS TURNS CONTEXT DELTA PEAK
grep -E '^\| [a-z-]+ · [0-9a-f]{6} ' "$CLAIMS" | while IFS= read -r row; do
  name=$(echo "$row" | awk -F'[| ]+' '{print $2}')
  hash=$(echo "$row" | awk -F'[| ]+' '{print $4}')
  focus=$(echo "$row" | awk -F'|' '{print $3}' | sed 's/^ *//;s/ *$//')
  f=$(ls "$PROJECTS"/"$hash"*.jsonl 2>/dev/null | head -1)
  if [ -z "$f" ]; then
    printf '%-24s %-26s %s\n' "$name · $hash" "$focus" "(no transcript)"
    continue
  fi
  read -r turns ctx delta peak <<< "$(measure "$f")"
  printf '%-24s %-26s %6d %9d %8d %9d\n' "$name · $hash" "${focus:0:26}" "$turns" "$ctx" "$delta" "$peak"
done
