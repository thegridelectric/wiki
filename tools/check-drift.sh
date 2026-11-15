#!/bin/bash
# check-drift.sh — daily platform-drift check, run from SessionStart.
# Does what's RUNNING match what's PUSHED? The day's marker file caches
# the RESULT (empty = clean): the first session of the day pays ~5s and
# writes it; a later session prints the cached clean line for free, but
# re-runs the full check whenever the cache holds drift — so drift
# re-reports in every session until fixed, and clears itself once the
# boxes are pulled. Every session prints a status line; there is no
# silent outcome. Fails silent on unreachable boxes (they get flagged
# as unreachable, not crashed on).
#
# Checks per platform box: checkout == origin/main and clean; every
# service process started AFTER the checkout's last commit landed (the
# 2026-07-24 stale-write-loop lesson); ear retry caches empty; each box's
# ~/README.md the same bytes as its instance-README.md in gridworks-infra.
# Per house: every scada pi on the same code SHA, layout and operational
# params as the house's LTN.

MARKER="$HOME/.cache/gw-drift-check-$(date +%Y%m%d)"
if [ -f "$MARKER" ] && [ ! -s "$MARKER" ]; then
  echo "Platform drift: none (daily check ran clean at $(date -r "$MARKER" +%H:%M))"
  exit 0
fi
mkdir -p "$HOME/.cache"

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
check_box forecast gridworks-weather-forecast weather-rabbit weather-api
# alert-manager.service on the alerts box is stopped on purpose, so it is
# not checked.
check_box alerts gridworks-alerts gridworks-alerts

# Broker definitions: the mounted boot file must match gwbase main's
# committed artifact (definitions-are-law; drift here means the next
# broker restart silently changes topology).
MAIN_SHA=$(curl -s --max-time 8 https://raw.githubusercontent.com/thegridelectric/gridworks-base/main/rabbit/rabbitconfig/hybrid_definitions.json | shasum -a 256 | cut -d" " -f1)
BOX_SHA=$($SSH rmqbot 'shasum -a 256 ~/rmq-docker/config/rabbit_definitions.json 2>/dev/null | cut -d" " -f1' 2>/dev/null)
if [ -n "$MAIN_SHA" ] && [ -n "$BOX_SHA" ] && [ "$MAIN_SHA" != "$BOX_SHA" ]; then
  OUT="$OUT
  rmqbot: mounted rabbit_definitions.json differs from gwbase main (update per rmqbot instance-README before any broker restart)"
fi

# Broker CRL: past nextUpdate, crl_check=peer refuses every client cert on
# 5671 and 8883 (mtls); every mint/revoke re-signs it for a year, so a
# near expiry means nobody has minted in ~10 months. Warn 60 days out;
# a missing file is the louder fault (every client cert refused).
CRL_NEXT=$($SSH rmqbot 'f=$(ls ~/rmq-certs-2026/crl/*.r0 2>/dev/null | head -1); [ -n "$f" ] && openssl crl -in "$f" -noout -nextupdate | cut -d= -f2' 2>/dev/null)
if [ -n "$CRL_NEXT" ]; then
  CRL_EPOCH=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$CRL_NEXT" +%s 2>/dev/null)
  if [ -n "$CRL_EPOCH" ] && [ "$CRL_EPOCH" -lt $(( $(date +%s) + 60*86400 )) ]; then
    OUT="$OUT
  rmqbot: broker CRL nextUpdate is $CRL_NEXT (under 60 days; re-sign with authority/certbot/mint-client-cert.py crl)"
  fi
fi

# Witness retry caches (drains should leave them empty).
for h in ear gnr-ear; do
  n=$($SSH "$h" 'ls ~/.local/share/gridworks/ear/output/need_to_put/*/ 2>/dev/null | wc -l | tr -d " "' 2>/dev/null)
  [ -n "$n" ] && [ "$n" != 0 ] && OUT="$OUT
  $h: $n messages parked in need_to_put (store trouble?)"
done

# House params: a scada writes its own operational-params.json (the cold
# latch that refuses dispatch), so a box's copy can differ from the tlayouts
# source. Report the difference; a person decides which side is right. A
# house that does not answer, or holds no params file, is not drift.
UMBRELLA="$(cd "$(dirname "$0")/../.." && pwd)"
check_house_params() {  # house source-file boxes...
  local house="$1" src="$UMBRELLA/tlayouts/output/$1/$2" want got box dir
  shift 2
  [ -f "$src" ] || return 0
  want=$(shasum -a 256 "$src" | cut -d' ' -f1)
  for box in "$@"; do
    for dir in scada; do
      got=$($SSH "$box" "sha256sum .config/gridworks/$dir/operational-params.json 2>/dev/null | cut -d' ' -f1" 2>/dev/null)
      [ -z "$got" ] || [ "$got" = "$want" ] || OUT="$OUT
  $box: $dir/operational-params.json differs from tlayouts output/$house/${src##*/} (not a pull + restart: compare the two and decide which side is right)"
    done
  done
}
check_house_params spruce gw.nolan.operational.params.json spruce
check_house_params beech gw.house0.operational.params.json beech beech2
check_house_params maple gw.house0.operational.params.json maple maple2

# Box READMEs: a box's ~/README.md is a copy of its instance-README.md in
# gridworks-infra, and only this check notices when one side moves on.
# The fix is a copy after a person has compared the two; the repo file is
# the record. A box with no ~/README.md is not drift.
check_readme() {  # host infra-dir
  local src="$UMBRELLA/gridworks-infra/$2/instance-README.md" want got
  [ -f "$src" ] || return 0
  want=$(shasum -a 256 "$src" | cut -d' ' -f1)
  got=$($SSH "$1" 'sha256sum ~/README.md 2>/dev/null | cut -d" " -f1' 2>/dev/null)
  [ -z "$got" ] || [ "$got" = "$want" ] || OUT="$OUT
  $1: ~/README.md differs from gridworks-infra/$2/instance-README.md (compare the two, then copy the repo file to the box)"
}
check_readme gnr gnr
check_readme rmqbot rmqbot
check_readme ltn ltn

# House lines: a house's scada pis and its LTN run one line, the same code
# SHA, layout and operational params on every box, which roll.sh moves
# together and verifies. Hand pulls between rolls split them (oak's scada
# sat six commits behind its LTN in 2026-10). Each pi is compared with the
# LTN; the ops files are compared byte for byte, so a cold latch the scada
# wrote shows here too and a person reads it with roll_compare.py. A pi
# that does not answer is not drift.
LTN_HOUSES="beech elm fir maple oak spruce"
line_of() {  # host repo-dir config-dir -> "sha layout-hash ops-hash"
  $SSH "$1" "h() { if [ -f \"\$1\" ]; then sha256sum \"\$1\" | cut -c1-12; else echo none; fi; }
    echo \$(git -C $2 rev-parse --short HEAD 2>/dev/null || echo none) \
      \$(h $3/hardware-layout.json) \$(h $3/operational-params.json)" 2>/dev/null
}
check_house_line() {  # house pis...
  local house="$1" ltn pi cdir got l_sha l_lay l_ops p_sha p_lay p_ops
  shift
  ltn=$(line_of ltn "~/ltn-$house/gridworks-scada" "~/ltn-$house/.config/gridworks/ltn")
  [ -n "$ltn" ] || return 0
  read -r l_sha l_lay l_ops <<< "$ltn"
  for pi in "$@"; do
    if [ "$pi" = "${pi%2}" ]; then cdir='~/.config/gridworks/scada'; else cdir='~/.config/gridworks/scada2'; fi
    got=$(line_of "$pi" '~/gridworks-scada' "$cdir")
    [ -n "$got" ] || continue
    read -r p_sha p_lay p_ops <<< "$got"
    [ "$p_sha" = "$l_sha" ] || OUT="$OUT
  $pi: scada at $p_sha, its LTN (ltn-$house) at $l_sha (roll.sh $house check)"
    [ "$p_lay" = "$l_lay" ] || OUT="$OUT
  $pi: hardware-layout.json differs from ltn-$house's (roll.sh $house check)"
    [ "$p_ops" = "$l_ops" ] || OUT="$OUT
  $pi: operational-params.json differs from ltn-$house's (a cold latch, or a hand edit; roll_compare.py ops shows the paths)"
  done
}
for h in $LTN_HOUSES; do
  case "$h" in
    spruce) check_house_line spruce spruce ;;
    *) check_house_line "$h" "$h" "${h}2" ;;
  esac
done

# Unfit load model: the regression half of HeatingCurve (AlphaEx6..EtaEx6,
# RhoTimes100, DdRoomTempF, MassFlowKgH) is read only by the LTN's FLO
# request, so a house can run on the fleet placeholder set without local
# control noticing. The tlayouts gens give every unfit house the one
# placeholder set below; a house whose OperatorHold is false SHALL have its
# own fit. A params file on the older word (no regression fields) is not
# drift, and neither is a box that does not answer.
fit_of() {  # host params-file -> "hold=<True|False> fit=<yes|no|na>"
  $SSH "$1" "python3 - $2" 2>/dev/null <<'PY'
import json, sys
try:
    p = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
hc = p.get("HeatingCurve", {})
keys = ["AlphaEx6", "BetaEx6", "GammaEx6", "DeltaEx6", "EpsilonEx6",
        "ZetaEx6", "EtaEx6", "RhoTimes100", "DdRoomTempF", "MassFlowKgH"]
placeholder = [-450000, 30000, -1000, -500, 6000, 300000, 500000, 120, 68, 480]
hold = p.get("DispatchHold", {}).get("OperatorHold")
if any(k not in hc for k in keys):
    fit = "na"
else:
    fit = "no" if [hc[k] for k in keys] == placeholder else "yes"
print(f"hold={hold} fit={fit}")
PY
}
check_house_fit() {  # house pis...
  local house="$1" box path got
  shift
  for box in "$@" ltn; do
    case "$box" in
      ltn) path="~/ltn-$house/.config/gridworks/ltn/operational-params.json" ;;
      *2)  path='~/.config/gridworks/scada2/operational-params.json' ;;
      *)   path='~/.config/gridworks/scada/operational-params.json' ;;
    esac
    got=$(fit_of "$box" "$path")
    [ "$got" = "hold=False fit=no" ] || continue
    [ "$box" = ltn ] && box="ltn-$house"
    OUT="$OUT
  $box: OperatorHold is false but HeatingCurve is the fleet placeholder regression (fit $house in tlayouts/${house}_gen.py, or set operator_hold=True, then roll)"
  done
}
for h in $LTN_HOUSES; do
  case "$h" in
    spruce) check_house_fit spruce spruce ;;
    *) check_house_fit "$h" "$h" "${h}2" ;;
  esac
done

if [ -n "$OUT" ]; then
  printf '%s\n' "$OUT" > "$MARKER"
  # The reading Claude is told below to relay this to the user in its
  # first response — that is the operator-visible channel.
  echo "PLATFORM DRIFT (re-checked every session until fixed)."
  echo "Claude: you MUST relay this drift list to the user verbatim in your"
  echo "FIRST response of the session — the hook's output is invisible to"
  echo "them. Report only — never act on it without discussing with the"
  echo "user first; the fix, when agreed, is per the box's instance-README"
  echo "(usually pull + restart):"
  echo "$OUT"
else
  : > "$MARKER"
  echo "Platform drift: none (checked $(date +%H:%M))"
fi
exit 0
