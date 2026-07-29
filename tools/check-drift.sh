#!/bin/bash
# check-drift.sh — daily platform-drift check, run from SessionStart.
# Does what's RUNNING match what's PUSHED? Self-throttles to once per
# calendar day (first session of the day pays ~5s; the rest skip free).
# Prints ONLY problems; silence = no drift. Fails silent on unreachable
# boxes (they get flagged as unreachable, not crashed on).
#
# Checks per platform box: checkout == origin/main and clean; every
# service process started AFTER the checkout's last commit landed (the
# 2026-07-24 stale-write-loop lesson); ear retry caches empty.

MARKER="$HOME/.cache/gw-drift-check-$(date +%Y%m%d)"
[ -f "$MARKER" ] && exit 0
mkdir -p "$HOME/.cache" && touch "$MARKER"

SSH="ssh -o BatchMode=yes -o ConnectTimeout=6"
OUT=""

check_box() {  # host repo units...
  local host="$1" repo="$2"; shift 2
  local r
  r=$($SSH "$host" "
    cd ~/$repo 2>/dev/null || { echo 'NO CHECKOUT'; exit 0; }
    git fetch -q 2>/dev/null
    s=\$(git status -sb | head -1); d=\$(git status -s | wc -l | tr -d ' ')
    [ \"\$s\" = '## main...origin/main' ] || echo \"branch/sync: \$s\"
    [ \"\$d\" = 0 ] || echo \"dirty tree: \$d files\"
    ct=\$(git log -1 --format=%ct)
    for u in $*; do
      st=\$(systemctl show \"\$u\" -p ActiveEnterTimestamp --value 2>/dev/null)
      se=\$(date -d \"\$st\" +%s 2>/dev/null || echo 0)
      sa=\$(systemctl is-active \"\$u\" 2>/dev/null)
      [ \"\$sa\" = active ] || echo \"\$u: \$sa\"
      [ \"\$se\" -ge \"\$ct\" ] || echo \"\$u: process older than checkout (restart needed)\"
    done
  " 2>/dev/null) || r="unreachable"
  [ -n "$r" ] && OUT="$OUT
  $host:
$(echo "$r" | sed 's/^/    /')"
}

check_box gnr grid-node-registry gnr-rabbit gnr-api
check_box ear gridworks-ear ear@ear
check_box gnr-ear gridworks-ear ear@gnr-ear
check_box gjk gridworks-journalkeeper journalkeeper

# Broker definitions: the mounted boot file must match gwbase main's
# committed artifact (definitions-are-law; drift here means the next
# broker restart silently changes topology).
MAIN_SHA=$(curl -s --max-time 8 https://raw.githubusercontent.com/thegridelectric/gridworks-base/main/rabbit/rabbitconfig/hybrid_definitions.json | shasum -a 256 | cut -d" " -f1)
BOX_SHA=$($SSH rmqbot 'shasum -a 256 ~/rmq-docker/config/rabbit_definitions.json 2>/dev/null | cut -d" " -f1' 2>/dev/null)
if [ -n "$MAIN_SHA" ] && [ -n "$BOX_SHA" ] && [ "$MAIN_SHA" != "$BOX_SHA" ]; then
  OUT="$OUT
  rmqbot: mounted rabbit_definitions.json differs from gwbase main (update per rmqbot instance-README before any broker restart)"
fi

# Witness retry caches (drains should leave them empty).
for h in ear gnr-ear; do
  n=$($SSH "$h" 'ls ~/.local/share/gridworks/ear/output/need_to_put/*/ 2>/dev/null | wc -l | tr -d " "' 2>/dev/null)
  [ -n "$n" ] && [ "$n" != 0 ] && OUT="$OUT
  $h: $n messages parked in need_to_put (store trouble?)"
done

if [ -n "$OUT" ]; then
  echo "PLATFORM DRIFT (daily check — fix per the box's instance-README;"
  echo "pull + restart is almost always the whole fix):"
  echo "$OUT"
fi
exit 0
