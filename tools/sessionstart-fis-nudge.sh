#!/bin/bash
# sessionstart-fis-nudge.sh — SessionStart nudge for the third lane. When
# another live session already claims gridworks-scada/, ask the user whether
# this session should take the next standing item. Read-only; silent unless
# a scada claim exists. Standing ask from 2026-09-30.
#
# Order: (1) merge the jm/remove-position-point-pii pair and close OPS-443;
# (2) only once OPS-443 is Done, Stand up FIS (OPS-422) step 9. Flip DONE_443
# to 1 when OPS-443 closes; delete this script and its hook entry when
# OPS-422 is Done too.
DONE_443=0
CLAIMS="$(dirname "$0")/../active-claims.md"
[ -f "$CLAIMS" ] || exit 0
n=$(awk -F'|' '/^\| [a-z]+-[a-z]+ · [0-9a-f]{6} \|/ && $4 ~ /gridworks-scada\//' "$CLAIMS" | wc -l | tr -d ' ')
[ "$n" -gt 0 ] || exit 0
if [ "$DONE_443" = 0 ]; then
  cat <<'MSG'
Third-lane nudge: a live session already claims gridworks-scada/. Ask the user whether this session should merge the jm/remove-position-point-pii pair and close OPS-443 (registry-projection-and-ear-capture). The pair: gridworks-data branch (1 commit, drops position_points + adds sent_at; needs merge, alembic migration on the journal DB, 0.4.0 release) then gridworks-journalkeeper branch (7edf504 forest projection + scripts/hack_reid_g_nodes.py; rebase onto main, bump the gridworks-data pin, merge, run the re-id hack in prod with --execute, deploy). Heads-up to Joe before the gridworks-data schema change. Context: the "Deployment preconditions" section of OPS-443. Scope: gridworks-journalkeeper/ + gridworks-data/ + wiki/gridworks-journalkeeper/. When OPS-443 is Done, set DONE_443=1 in wiki/tools/sessionstart-fis-nudge.sh.
MSG
else
  cat <<'MSG'
Third-lane nudge: a live session already claims gridworks-scada/. Ask the user whether this session should take Stand up FIS (OPS-422) step 9: deploy FIS colocated with the broker and run the done-when battery (wiki/gridworks-fleet-index-service/designs/stand-up-fis.md). Scope: gridworks-fleet-index-service/ + wiki/gridworks-fleet-index-service/. Delete wiki/tools/sessionstart-fis-nudge.sh and its hook entry when OPS-422 is Done.
MSG
fi
exit 0
