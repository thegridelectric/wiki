#!/bin/bash
# sessionstart-spruce-status.sh — spruce plant liveness at SessionStart.
# TEMPORARY: REMOVE (script + its settings.json hook entry) once the scada
# drives the gw108 relays and reports these states itself (the
# spruce-unlimbo relay port).
#
# Two checks, both read-only, no i2c reads and no second process on the
# expanders (the winter hack owns them and logs every enforce pass):
#   1. spruce-winter-hack.service on the box: active, heartbeat age (the
#      ZONE OPTOS line logs every enforce pass, 300 s), last pump / hp-call
#      decision, CRITICAL lines in the last hour, the latest zone opto line.
#   2. Journal DB: any zone heat-call channel (every house) that has read 1
#      for the whole of the last LONG_CALL_H hours — a thermostat calling
#      with nothing answering. Uses DB_ANALYST_URL from experiments/.env.
#   3. Journal DB: the spruce living-room air temperature
#      (zone2-living-rm-gw-temp, CelsiusTimes100); alert below COLD_F.
# Report only — never act on an anomaly without discussing with the user.
# Fresh every session (no daily cache); one line each when healthy; fails
# soft if the box or the DB is unreachable.

LOG=/home/pi/.local/state/gridworks/starter/spruce-winter-hack.log
SERVICE=spruce-winter-hack
HEARTBEAT_STALE_S=900
LONG_CALL_H=12
COLD_F=64
LIVING_ROOM_TA=hw1.isone.me.versant.keene.spruce.ta
LIVING_ROOM_CH=zone2-living-rm-gw-temp
ENV_FILE="$(dirname "$0")/../../experiments/.env"

OUT=$(ssh -o BatchMode=yes -o ConnectTimeout=6 spruce "
  systemctl is-active $SERVICE;
  date +%s;
  date -d \"\$(grep -a ' ZONE OPTOS ' $LOG | tail -1 | cut -c1-19)\" +%s 2>/dev/null || echo 0;
  grep -a ' ZONE OPTOS ' $LOG | tail -1 | sed -E 's/,[0-9]{3} INFO ZONE OPTOS \(whitewire sense, read-only\)/ optos/';
  grep -a 'SECONDARY PUMP ->\|HP CALL ->' $LOG | tail -2 | sed -E 's/,[0-9]{3} INFO / /';
  grep -a ' CRITICAL ' $LOG | awk -v since=\"\$(date -d '1 hour ago' '+%Y-%m-%d %H:%M:%S')\" '\$1\" \"\$2 >= since' | tail -3 | cut -c1-160
" 2>&1)
RC=$?

if [ $RC -eq 255 ] || [ -z "$OUT" ]; then
  echo "spruce winter hack: box unreachable (check skipped)"
else
  ACTIVE=$(echo "$OUT" | sed -n 1p)
  NOW=$(echo "$OUT" | sed -n 2p)
  HB=$(echo "$OUT" | sed -n 3p)
  OPTOS=$(echo "$OUT" | sed -n 4p)
  REST=$(echo "$OUT" | sed -n '5,$p')
  AGE=$(( NOW - HB ))
  CRIT=$(echo "$REST" | grep -c ' CRITICAL ')
  if [ "$ACTIVE" = "active" ] && [ "$HB" -gt 0 ] && [ "$AGE" -le "$HEARTBEAT_STALE_S" ] && [ "$CRIT" -eq 0 ]; then
    echo "spruce winter hack: active, heartbeat ${AGE}s ago, no CRITICAL in the last hour"
    echo "  $OPTOS"
    echo "$REST" | grep 'PUMP\|HP CALL' | sed 's/^/  /'
  else
    echo "spruce winter hack CHECK — ANOMALIES. Report only: never act without"
    echo "discussing with the user first:"
    echo "  service: $ACTIVE; heartbeat: ${AGE}s ago (stale > ${HEARTBEAT_STALE_S}s); CRITICAL in last hour: $CRIT"
    echo "  $OPTOS"
    echo "$REST" | sed 's/^/  /'
  fi
fi

# --- long-running heat calls, every house ---
DB_URL=$(grep -o '^DB_ANALYST_URL=[^ ]*' "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
if [ -z "$DB_URL" ] || ! command -v psql >/dev/null; then
  echo "long heat calls: DB_ANALYST_URL or psql missing (check skipped)"
  exit 0
fi
CALLS=$(psql "$DB_URL" -At -F' ' -c "SET statement_timeout='20s';
  SELECT rc.terminal_asset_alias, rc.name, count(*),
         to_char(max(r.timestamp) AT TIME ZONE 'America/New_York', 'HH24:MI')
  FROM gridworks.reading_channels rc
  JOIN gridworks.readings r ON r.channel_id = rc.id
  WHERE rc.name LIKE '%heat-call' AND r.timestamp > now() - interval '$LONG_CALL_H hours'
  GROUP BY 1, 2 HAVING min(r.value) = 1 ORDER BY 1, 2;" 2>&1)
if echo "$CALLS" | grep -q 'ERROR\|could not\|timeout'; then
  echo "long heat calls: DB query failed (check skipped): $(echo "$CALLS" | head -1)"
elif [ -z "$CALLS" ]; then
  echo "long heat calls: none (no zone calling for the whole of the last ${LONG_CALL_H}h)"
else
  echo "LONG HEAT CALLS — zones calling for the whole of the last ${LONG_CALL_H}h (ta zone readings last-ET):"
  echo "$CALLS" | sed 's/^/  /'
fi

# --- spruce living-room temperature ---
LR=$(psql "$DB_URL" -At -F' ' -c "SET statement_timeout='20s';
  SELECT round((r.value / 100.0) * 9 / 5 + 32, 1),
         to_char(r.timestamp AT TIME ZONE 'America/New_York', 'MM-DD_HH24:MI'),
         extract(epoch from now() - r.timestamp)::int
  FROM gridworks.readings r
  JOIN gridworks.reading_channels rc ON r.channel_id = rc.id
  WHERE rc.terminal_asset_alias = '$LIVING_ROOM_TA' AND rc.name = '$LIVING_ROOM_CH'
  ORDER BY r.timestamp DESC LIMIT 1;" 2>&1)
if echo "$LR" | grep -q 'ERROR\|could not\|timeout'; then
  echo "spruce living room: DB query failed (check skipped): $(echo "$LR" | head -1)"
elif [ -z "$LR" ]; then
  echo "spruce living room: no $LIVING_ROOM_CH reading in the journal (check skipped)"
else
  TEMP_F=$(echo "$LR" | cut -d' ' -f1)
  SEEN=$(echo "$LR" | cut -d' ' -f2)
  AGE_S=$(echo "$LR" | cut -d' ' -f3)
  STALE=""
  [ "$AGE_S" -gt 3600 ] && STALE=" (STALE: last reading ${SEEN} ET)"
  if [ "$(echo "$TEMP_F < $COLD_F" | bc)" -eq 1 ]; then
    echo "SPRUCE LIVING ROOM COLD: ${TEMP_F} F at ${SEEN} ET, below ${COLD_F} F — raise with the user${STALE}"
  else
    echo "spruce living room: ${TEMP_F} F at ${SEEN} ET (alert below ${COLD_F} F)${STALE}"
  fi
fi
exit 0
