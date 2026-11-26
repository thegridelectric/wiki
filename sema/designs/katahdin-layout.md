# Katahdin layout: the relay roster the plant actually has

Status: Accepted · Pass 1 · Updated 2026-11-25 · Linear: OPS-711

**EDD: no** verified by the sema round-trip (`./ci.sh`, the mutation tests
of the new axiom clauses), the tlayouts fixture tests, and the
terminalasset Katahdin tests on a fixture copied from the gen.

> What this is: the fix for `gw.katahdin.layout` 000, which inherits a
> House0 boiler relay (a heat pump failsafe that hands the heat pump to a
> buffer-tank aquastat) that a Katahdin plant does not have, and the
> generator that then authors the first Katahdin layouts. The word is the
> decisive change; the tlayouts gen, the terminalasset fixture and the
> scada boot check follow it.

## Facts

From the plumbing design (D1116, 2026-11-04, `gw111/`) and the install
(2026-11-23):

1. The boiler has its own aquastat on a small internal tank. When that
   water is cold enough the boiler fires. No scada relay is in that call.
2. The FCM Misc relay (DB25 pins 21 to 23) switches nothing. Spare.
3. The zone thermostats reach the boiler through the plumbing: a heat call
   runs the distribution pump and opens the zone valve, the boiler's tank
   cools, its aquastat fires.
4. With the scada dead the heat pump cannot heat the house.
   `hp-scada-ops-relay` de-energized means heat pump off and nothing else.
5. The failsafe kind (boiler or elements) is set by a hand toggle on the
   Gw108 Rev C board.
6. D1116 "Operating Modes" gives the valve posture of each failsafe.
   Oil boiler failsafe: V1 C, V2 O, V3 C, V4 C, V5 O. Element failsafe:
   V1 C, V2 O, V3 C, V4 O, V5 C.

From the Gw108 Rev C README and schematic (facts restated in the
gw108-rev-c design's board facts):

- The Valve 2 output is powered by default; its relay removes power.
- The toggle (`SW1`, a DPDT drawn as two units) sets which of Valve 4 and
  Valve 5 is powered by default: Valve 5 in one position, Valve 4 in the
  other. The silk labels are reversed. The middle position powers
  neither and is never used.
- Valve 4 and Valve 5 are separate SPDT relays (Valve 4 on native GPIO
  13, Valve 5 on expander 0x21 bit 3). On Rev B one SPDT relay fed the
  boiler valve on one throw and the buffer valve on the other; Rev C
  split it.
- GPIO 19 reads whether the Valve 4 output is powered: 0 = powered,
  1 = not. Erratum: with no load on Valve 4 it always reads 0. The Rev C
  device-type record lists it as `NativeGpioInputs` `Valve4Energized`.

## Decisions

**Every valve is power-to-open.** The board's rest state (Valve 2 and one
of Valve 4 / Valve 5 powered, everything else not) matches both D1116
failsafe rows exactly when an unpowered valve is closed, which is what
the D1116 legend's "Motorized valve (zone valve)" means. The toggle
position for a boiler house is the one that powers Valve 5 by default.
The terminalasset Katahdin adapter's contact table has the same
orientation. To confirm against the install.

**The boiler intercept is wired.** The Gw108 `BoilerIntercept` relay is
NC with the aquastat signal passing to the boiler at rest, so it never
touches the failsafe. It costs two wires on the boiler's TT terminals,
and without it the boiler burns oil all winter keeping its internal tank
warm behind a closed V5. `gw.boiler.backup` names it `InterceptRelayName`
in every family, since "aquastat control" described the House0
buffer-tank aquastat that a Katahdin does not have. Node name
`boiler-intercept-relay` at a Katahdin; House0 and Nolan keep
`aquastat-ctrl-relay`. Axiom 35 InterceptPassesAtRest requires the
relay's de-energized state to be `Boiler`. The wiring is confirmed: the
install runs the two wires to the boiler.

**A Katahdin has no heat pump failsafe relay** (facts 1 and 4). So
`gw.boiler.backup` 000 makes `FailsafeRelayName` optional and each
family word says whether it is present. No new backup kind, no change to
`gw.hydronic`.

**The relay configs that follow.** EnergizedState and DeEnergizedState in
each valve relay's `relay.control.config`:

| Relay | Energized | De-energized | Wiring |
|---|---|---|---|
| v1-hx-house-relay, v3-store-cold-relay | open | closed | NormallyOpen |
| v2-store-hot-relay | closed | open | NormallyClosed |
| v4-house-return-relay (boiler house) | open | closed | NormallyOpen |
| v5-boiler-relay (boiler house) | closed | open | NormallyClosed |
| v4, v5 (element house) | reversed | | |

The roster with a boiler: vdc-relay, hp-scada-ops-relay,
secondary-pump-relay, the five valve relays, aquastat-ctrl-relay, and
each zone circuit's failsafe and ops relays. With elements:
v5-boiler-relay goes, the element relays from `gw.element.backup` come in.

## The word edits (staging, in place)

`gw.boiler.backup` 000: `FailsafeRelayName` leaves `required`; its
description stays. Axiom 1 DistinctRelays becomes "where FailsafeRelayName
is present, it SHALL NOT equal InterceptRelayName".

`gw.house0.layout`, `gw.house0.no.sieg`, `gw.nolan.layout`: the
BackupRelays axiom gains a clause: where Hydronic.Backup is a
gw.boiler.backup, FailsafeRelayName SHALL be present.

`gw.katahdin.layout` 000:

- BackupRelays (axiom 32), boiler half: FailsafeRelayName SHALL be absent;
  InterceptRelayName SHALL name a Relay ShNode. Element half unchanged.
- New axiom ValveDefaultsFollowBackup: where Hydronic.Backup is a
  gw.boiler.backup, the relay.control.config of v4-house-return-relay
  SHALL state the valve open as EnergizedState and v5-boiler-relay closed
  as EnergizedState; where it is a gw.element.backup, the reverse. Spelled
  as the House0 valve axioms spell relay states.
- Each new clause gets a mutation test.

Registry summaries and `last_updated` follow; indexes and runtime
regenerated; `./ci.sh` green; scada, tlayouts and terminalasset snapshots
regenerated in the same wave.

## The gen and the fixtures

`tlayouts/katahdin_sema_gen.py`, a family gen; drivers `cedar_gen.py`
(the first real Katahdin house; its pico census is already stubbed) and
`larch_sim_gen.py` (the simulated Katahdin). Hydronic.Backup is a
gw.boiler.backup with InterceptRelayName and InService. Valve relay
configs per the table. The terminalasset Katahdin fixture is a byte copy
of the larch output; the repo's House0-to-Katahdin derivation
(`ta-katahdin-layout`) goes, and with it the adapter's hardcoded failsafe
relay (`katahdin.py:136` on terminalasset PR 6).

## The boot check

The layout states the backup kind; the scada reads `Valve4Energized`
before any relay actuates. With the Valve 4 relay not driven, 0 means the
toggle says boiler and 1 means element or the unused middle. A reading
that disagrees with the layout fails the boot. The check applies only
where the layout has a valve on Valve 4 (every Katahdin), because of the
no-load erratum. Witnessing the pin with a driven Valve 4 is a row on the
gw108-rev-c bench checklist; the scada code is its own later change.

## Do this next

The word edits are on sema dev (`5ccb2dc`); the gen and the larch driver
are on tlayouts `jm/katahdin-layout` with the larch layout validating.
Next: copy `tlayouts/output/larch-sim/gw.katahdin.layout.json` into the
terminalasset tests as the Katahdin fixture (the round-1 ask on PR 6),
and write the Katahdin mutation tests in sema
(`tests/runtime/gw_katahdin_layout/`) on a copy of it, one per clause of
axioms 32 and 34. Open: a `gw.katahdin.family.params` word, without which
no Katahdin operational-params artifact can exist.

## On completion

The roster and valve orientation distill into the words' axioms and into
the scada executor's `hardware-layout.md` "The three layout families" (four
with Katahdin). The toggle facts distill into the Rev C device-type record
through the gw108-rev-c design. This file goes.
