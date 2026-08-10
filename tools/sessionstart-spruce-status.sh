#!/bin/bash
# sessionstart-spruce-status.sh — spruce gw108 state check at SessionStart.
# TEMPORARY: REMOVE (script + its settings.json hook entry) once the scada
# drives the gw108 relays and reports these states itself (the
# spruce-unlimbo relay port).
#
# Runs the read-only starter-scripts/spruce_status.py on the spruce pi
# (expander registers, zone holds, white-wire optos, cooling posture).
# Report only — never act on an anomaly without discussing with the user;
# the restore tool is sick_spruce.py on the box, hack services stopped.
# Fresh every session (no daily cache — a brownout can happen any hour);
# one line when healthy, full dump on anomaly. Fails soft if unreachable.

OUT=$(ssh -o BatchMode=yes -o ConnectTimeout=6 spruce \
  'cd ~/starter-scripts && venv/bin/python spruce_status.py' 2>&1)
RC=$?

if [ $RC -eq 255 ] || [ -z "$OUT" ]; then
  echo "spruce gw108: unreachable (check skipped)"
  exit 0
fi

if echo "$OUT" | grep -q "all healthy"; then
  POSTURE=$(echo "$OUT" | grep -o "posture: .*" | head -1 | sed 's/ ===$//')
  echo "spruce gw108: all healthy — holds in place; ${POSTURE:-posture unknown}"
else
  echo "spruce gw108 CHECK — ANOMALIES. Report only: never act without"
  echo "discussing with the user first (restore tool: sick_spruce.py on the"
  echo "box, hack services stopped):"
  echo "$OUT"
fi
exit 0
