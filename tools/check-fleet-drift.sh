#!/bin/bash
# check-fleet-drift.sh — weekly fleet-drift check, run from SessionStart.
# Does what each house and LTN RUNS match what's PUSHED? The week's
# marker file caches the RESULT (empty = clean): the first session of
# the ISO week pays the probe and writes it; a later session prints the
# cached clean line for free, but re-runs the full check whenever the
# cache holds drift — so drift re-reports in every session until fixed,
# and clears itself once the boxes are pulled. Sibling of check-drift.sh
# (daily, the platform boxes). Boxes are probed in parallel; an
# unreachable box is flagged, not crashed on.
#
# Checks per checkout: on its expected branch and even with origin
# (fetches first), clean tree, and the running process started AFTER the
# checkout's last commit (a pull without a restart runs the old code).
# A first pi is also checked for the event sets roll.sh puts aside at
# each roll (~/.local/share/gridworks/scada/event.*-pre-roll-to-*/):
# more than SET_ASIDE_MAX of them, or more than SET_ASIDE_MB in all, is
# flagged so they get pruned by hand.
# Houses: repo ~/gridworks-scada, systemd unit gwspaceheat on the first
# pi. A second pi (SECOND_PIS names the houses that have one) is checked
# only for reachability and an active gwspaceheat2: its checkout is not
# rolled with the house, so its commit is not drift. LTNs: ~/ltn-<house>/
# gridworks-scada on the one LTN box, process = the python whose
# working directory is under that folder (the tmux REPL).

MARKER="$HOME/.cache/gw-fleet-drift-check-$(date +%G-W%V)"
if [ -f "$MARKER" ] && [ ! -s "$MARKER" ]; then
  echo "Fleet drift: none (weekly check ran clean $(date -r "$MARKER" '+%a %H:%M'))"
  exit 0
fi
mkdir -p "$HOME/.cache"

SSH="ssh -o BatchMode=yes -o ConnectTimeout=8"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Expected branch per checkout (gridworks-infra/fleet-inventory.md).
# Spruce's pi and LTN run actual-spruce; oak's pi and LTN run
# td/generalized-flo (the FLO work). All LTNs run on the one box, ltn.
# elm and elm2 are offline; add elm back to HOUSES and SECOND_PIS when they return.
HOUSES="beech:main oak:td/generalized-flo fir:main maple:main spruce:actual-spruce"
SECOND_PIS="beech oak fir maple"
SET_ASIDE_MAX=2
SET_ASIDE_MB=20
LTN_BOXES="ltn:beech:main,elm:main,fir:main,maple:main,oak:td/generalized-flo,spruce:actual-spruce"

# The remote fragment: prints one line per finding, nothing when clean.
# $1 repo dir, $2 expected branch, $3 process start epoch (0 = not running).
GIT_CHECK='
  check_repo() {
    cd "$1" 2>/dev/null || { echo "no checkout at $1"; return; }
    git fetch -q 2>/dev/null || echo "fetch failed (no GitHub reach?)"
    s=$(git status -sb | head -1); d=$(git status -s | wc -l | tr -d " ")
    [ "$s" = "## $2...origin/$2" ] || echo "branch/sync: $s"
    [ "$d" = 0 ] || echo "dirty tree: $d files"
    ct=$(git log -1 --format=%ct)
    [ "$3" = 0 ] && { echo "process: not running"; return; }
    [ "$3" -ge "$ct" ] || echo "process older than checkout (restart needed)"
  }'

check_pi() {  # host unit branch
  local host="$1" unit="$2" branch="$3" r
  r=$($SSH "$host" "$GIT_CHECK
    st=\$(systemctl show $unit -p ActiveEnterTimestamp --value 2>/dev/null)
    se=\$(date -d \"\$st\" +%s 2>/dev/null || echo 0)
    sa=\$(systemctl is-active $unit 2>/dev/null)
    [ \"\$sa\" = active ] || echo \"$unit: \$sa\"
    check_repo ~/gridworks-scada $branch \$se
    cd ~/.local/share/gridworks/scada 2>/dev/null && {
      n=\$(ls -d event.*-pre-roll-to-* 2>/dev/null | wc -l | tr -d ' ')
      mb=\$(du -sm event.*-pre-roll-to-* 2>/dev/null | awk '{s+=\$1} END {print s+0}')
      [ \"\$n\" -le $SET_ASIDE_MAX ] && [ \"\$mb\" -le $SET_ASIDE_MB ] || echo \"set-aside events: \$n folders, \$mb MB (prune the old event.*-pre-roll-to-* folders)\"
    }
  " 2>/dev/null) || r="unreachable"
  [ -n "$r" ] && printf '%s\n' "$r" | sed "s/^/    /;1s/^/  $host:\n/" > "$TMP/$host"
}

check_pi2() {  # host unit
  local host="$1" unit="$2" r
  r=$($SSH "$host" "sa=\$(systemctl is-active $unit 2>/dev/null); [ \"\$sa\" = active ] || echo \"$unit: \$sa\"" 2>/dev/null) || r="unreachable"
  [ -n "$r" ] && printf '%s\n' "$r" | sed "s/^/    /;1s/^/  $host:\n/" > "$TMP/$host"
}

check_ltn_box() {  # host house:branch,...
  local host="$1" spec="$2" r
  r=$($SSH "$host" "$GIT_CHECK
    now=\$(date +%s)
    for hb in \$(echo '$spec' | tr , ' '); do
      h=\${hb%%:*}; b=\${hb#*:}; se=0
      for p in \$(pgrep -u \$USER python); do
        case \$(readlink /proc/\$p/cwd 2>/dev/null) in \$HOME/ltn-\$h/*)
          se=\$((now - \$(ps -o etimes= -p \$p | tr -d ' '))); break;; esac
      done
      check_repo ~/ltn-\$h/gridworks-scada \$b \$se | sed \"s/^/\$h: /\"
    done
  " 2>/dev/null) || r="unreachable"
  [ -n "$r" ] && printf '%s\n' "$r" | sed "s/^/    /;1s/^/  $host:\n/" > "$TMP/$host"
}

for hb in $HOUSES; do
  h=${hb%%:*}; b=${hb#*:}
  check_pi "$h" gwspaceheat "$b" &
  case " $SECOND_PIS " in *" $h "*) check_pi2 "${h}2" gwspaceheat2 & ;; esac
done
for bs in $LTN_BOXES; do
  check_ltn_box "${bs%%:*}" "${bs#*:}" &
done
wait

OUT=""
for hb in $HOUSES; do
  h=${hb%%:*}
  for f in "$TMP/$h" "$TMP/${h}2"; do [ -f "$f" ] && OUT="$OUT
$(cat "$f")"; done
done
for bs in $LTN_BOXES; do
  f="$TMP/${bs%%:*}"; [ -f "$f" ] && OUT="$OUT
$(cat "$f")"
done

if [ -n "$OUT" ]; then
  printf '%s\n' "$OUT" > "$MARKER"
  echo "FLEET DRIFT (weekly; re-checked every session until fixed)."
  echo "Claude: you MUST relay this drift list to the user verbatim in your"
  echo "FIRST response of the session — the hook's output is invisible to"
  echo "them. Report only — never act on it without discussing with the"
  echo "user first; the fix, when agreed, is a pull + restart on the box"
  echo "(gridworks-infra scada/README.md and ltn/README.md):"
  echo "$OUT"
else
  : > "$MARKER"
  echo "Fleet drift: none (weekly check ran $(date '+%a %H:%M'))"
fi
exit 0
