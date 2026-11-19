#!/bin/bash
# check-patch.sh [daily|full] — patch state across the production boxes.
#
# daily (the default, run from SessionStart): prints only what a person
# must act on today, which is the automatic machinery having stopped: a
# box unreachable, unattended-upgrades missing or its timer disabled, no
# unattended run for two days, an apt list older than three days. A
# pending security update or a pending reboot is NOT reported here: the
# nightly run takes the update, and the reboot is the weekly run's act.
# Same marker shape as check-drift.sh: the day's result is cached, a
# cached clean line is free, a cached finding re-runs every session.
#
# full (step 1 of the weekly run, OPS-675): everything the run acts on,
# per box: reboot required and the packages behind it, security updates
# pending, ordinary updates pending, plus the daily findings. Not cached.
# Running it stamps the week; seven days later the daily line says the
# next run is due.
#
# Boxes are probed in parallel; an unreachable box is flagged, never
# crashed on.

MODE="${1:-daily}"
MARKER="$HOME/.cache/gw-patch-check-$(date +%Y%m%d)"
# The weekly run's prompt: `full` touches RUN, and once RUN is a week
# old the daily line says the run is due. Nothing recurs in Linear.
RUN="$HOME/.cache/gw-patch-run-last"
if [ "$MODE" = daily ]; then
  if [ ! -f "$RUN" ]; then
    echo "WEEKLY PATCH RUN DUE (never run from this laptop): wiki/tools/check-patch.sh full, then the OPS-675 recipe."
  else
    age=$(( ( $(date +%s) - $(stat -f %m "$RUN") ) / 86400 ))
    [ "$age" -lt 7 ] || echo "WEEKLY PATCH RUN DUE (last run $age days ago): wiki/tools/check-patch.sh full, then the OPS-675 recipe; close with a comment on OPS-675."
  fi
fi
if [ "$MODE" = daily ] && [ -f "$MARKER" ] && [ ! -s "$MARKER" ]; then
  echo "Patch machinery: clean (daily check ran at $(date -r "$MARKER" +%H:%M))"
  exit 0
fi
mkdir -p "$HOME/.cache"

# Platform VMs by ssh alias (gridworks-infra/platform-inventory.md), then
# the eleven house Pis. Bench Pis are not production.
VMS="certbot ear forecast gjk alerts gnr tap mm flo ltn hw2-1 rmqbot web-api2 pii"
PIS="beech beech2 oak oak2 fir fir2 maple maple2 elm elm2 spruce"

SSH="ssh -o BatchMode=yes -o ConnectTimeout=6"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

probe() {  # host mode -> writes $TMP/host (empty = nothing to say)
  local host="$1" mode="$2" r
  r=$($SSH "$host" "
    mode=$mode
    # machinery
    dpkg -s unattended-upgrades >/dev/null 2>&1 || echo 'unattended-upgrades not installed'
    [ \"\$(systemctl is-enabled apt-daily-upgrade.timer 2>/dev/null)\" = enabled ] || echo 'apt-daily-upgrade.timer not enabled'
    st=/var/lib/apt/periodic/unattended-upgrades-stamp
    if [ -f \$st ]; then
      age=\$(( (\$(date +%s) - \$(stat -c %Y \$st)) / 3600 ))
      [ \$age -le 48 ] || echo \"no unattended run for \$((age/24)) days\"
    else
      n=\$(find /var/lib/apt/lists -maxdepth 1 -name '*InRelease' -newermt '-2 days' 2>/dev/null | wc -l)
      [ \"\$n\" != 0 ] || echo 'unattended-upgrades has never run here'
    fi
    n=\$(find /var/lib/apt/lists -maxdepth 1 -name '*InRelease' -newermt '-3 days' 2>/dev/null | wc -l)
    [ \"\$n\" != 0 ] || echo 'apt lists older than 3 days'
    # the weekly run's material
    if [ \"\$mode\" = full ]; then
      if [ -f /var/run/reboot-required ]; then
        echo \"reboot required (\$(tr '\n' ' ' < /var/run/reboot-required.pkgs 2>/dev/null))\"
      fi
      u=\$(apt list --upgradable 2>/dev/null | tail -n +2)
      s=\$(printf '%s\n' \"\$u\" | grep -c -- '-security')
      t=\$(printf '%s\n' \"\$u\" | grep -c .)
      echo \"\$s security, \$((t - s)) ordinary updates pending\"
    fi
  " 2>/dev/null) || r="unreachable"
  printf '%s' "$r" > "$TMP/$host"
}

for h in $VMS $PIS; do probe "$h" "$MODE" & done
wait

OUT=""
for h in $VMS $PIS; do
  r=$(cat "$TMP/$h" 2>/dev/null)
  [ -n "$r" ] && OUT="$OUT
  $h: $(echo "$r" | paste -sd ';' - | sed 's/;/; /g')"
done

if [ "$MODE" = full ]; then
  touch "$RUN"
  echo "PATCH STATE, full (the weekly run's list):"
  echo "${OUT:-  nothing pending on any box}"
  # A single ear has an auto-delete queue: its reboot is a hole in the
  # archive. It is rebooted only once a second copy runs (OPS-676,
  # wiki/simulated-world/designs/prepare-for-kubernetes.md), or the hole is accepted
  # and written on the OPS-675 instance.
  if printf '%s' "$OUT" | grep -q '^  ear: .*reboot required'; then
    echo
    echo "  NOTE ear: do not reboot a single ear. Its queue is auto-delete, so the"
    echo "  archive loses the gap. Stand up the second ear copy first (OPS-676,"
    echo "  wiki/simulated-world/designs/prepare-for-kubernetes.md) or write the accepted hole on"
    echo "  the OPS-675 instance."
  fi
  exit 0
fi

if [ -n "$OUT" ]; then
  printf '%s\n' "$OUT" > "$MARKER"
  echo "PATCH MACHINERY STOPPED (re-checked every session until fixed)."
  echo "Claude: relay this list to the user verbatim in your FIRST response"
  echo "of the session — the hook's output is invisible to them. Report"
  echo "only; the fix is per the box's instance-README or the pi runbook"
  echo "(gridworks-infra/scada/pi-security-runbook.md):"
  echo "$OUT"
else
  : > "$MARKER"
  echo "Patch machinery: clean (checked $(date +%H:%M))"
fi
exit 0
