# Report all machine states (spoke)

Status: Draft · Pass 0 · Updated 2026-10-01 · Linear: OPS-392

> What this is: the layout declares every machine the scada reports, and
> one rule turns each declared machine's `machine.states` rows into a
> journal channel, replacing the journalkeeper's hand-kept map; plus an
> evaluation of which state and channel changes are worth reporting the
> moment they happen rather than at the next periodic report. A
> before-merge spoke: the declaration rides `layout.lite`, which publishes
> ahead of the layout and ops words, so the new code reports every
> machine up to rabbit while those words stay staging.

## The gap, as seen on spruce (2026-09-10)

The per-pico roster reaches the journal (`<node>-pico-state`, unit
type `single.pico.state`), so the journal shows who flatlined and when.
The pico-cycler's own state (`pico.cycler.state`: PicosLive,
RelayOpening, PicosRebooting, AllZombies, …) reaches the journal only
inside the `report.event` payload and projects to no channel, so what
the cycler did about a flatline, and when, is invisible without
opening the report JSON. Today's rows made the gap concrete: five
tank modules went Flatlined then Zombie and the cycles in between are
not in any channel (`experiments/2026-09-10-pico-state-reported/`).

## Channels or machine states: the rule

A **channel** carries a value sampled over time. A reading is a time and
a value with no cause; it is captured on a cadence or on a delta, it has
an age, and a consumer reasons about its value and its freshness. A
**derived channel** is a channel whose value is a function of other
channels' readings by a strategy the layout declares (a sum, a threshold,
a difference), with no memory beyond its inputs: no latch, no timer, no
hysteresis. `primary-flow` as the sieg sum and `heat-call` as whitewire
power over a line are derived channels.

A **machine state** carries a judgment with memory. It is entered by a
transition with a trigger and a cause, it holds until the next
transition, it can carry hysteresis, a blind state and a timer, and
consumers (the command tree, the panel, the LTN, alerting) react to the
transition as much as to the state. The scada reports it as a
`machine.states` row and the layout declares it ("The declaration"
below).

The test: if the value now is a pure function of other readings now, or
of a declared window of them, it is a derived channel; if telling it
requires remembering what it was, a latch, a timer, a cause, it is a
machine. Everything the scada commands is a machine. Something the scada
observes is either, by the test, and "observation" alone does not make
it a channel.

**hp-boss sensing supplies both; the power meter owns power.** The
unit's state, Off, Charging, Defrost, Unknown while blind, is a machine:
it holds across the draw's noise with a running-above / stopped-below
pair, a defrost is told by the draw falling while the state is Charging,
and blind is a timer on the inputs' age. hp-boss's derived channels are
the water side: lift (hp-lwt minus hp-ewt) and heat output (primary flow
times lift), published as soon as the channels exist; sensor trust
decides whether the machine acts on them, not whether they are derived. Every power channel, and every channel
derived from power (the unit's total draw, idu plus odu, among them),
is the power meter's to provide: transactive power is the whole
electrical load, the resistive elements as much as the heat pump, and
one actor owns it. The unit's machine reads the power meter's channels
and does not make them. The derivation rules live in
`actors/hp_boss/sensing.py`, the channels and the machine both appear in
the layout, and the journal receives both: channels directly, the
machine through the declared list.

## The declaration: the layout lists its machines

The layout words (`gw.house0.layout`, `gw.nolan.layout`) and `layout.lite`
carry a list of the machines the scada reports, one entry per machine:
the node that runs it, the state enum word (`StateEnum`, the name the
`machine.states` row already carries), and the channel name the journal
gives it. The list is what the channel registry is for physical
channels: the layout names what exists, with its node and its type, and
the scada derives the value. Three facts decide its shape:

- **One node can run two machines.** Local control reports a top state
  and a strategy state; the Nolan actor reports a top state and a call
  state. A per-node rule cannot name both, so the key is node plus state
  enum, and the declared channel name separates them (`<node>-state` for
  a node's one machine; a node with two names each).
- **`layout.lite` is what the data side reads.** The journalkeeper and
  `pull_readings.py` take their channel set from it, so the list has to
  be on the lite as well as the layout words.
- **The lite publishes first.** `layout.lite/013` is staging and goes to
  published with its closure (`finalize-layout-lite-13.md`); the layout
  words and `gw.operational.params` stay staging through the launch.
  `report.event/004` is published. So with the list on the lite, the
  new code reports every machine to rabbit on the production broker, and
  the journal creates the channels, while the words the box actually
  runs on stay mutable. That is the point of putting it on the lite.

The first machine declared under the rule that has no channel today is
the heat pump's sensed state on hp-boss (`executor/control-hierarchy.md`
"The heat-pump surface"); every machine the scada already runs (hp-boss,
the sieg valve, five-v-boss, the pico-cycler, the relays, the zone
circuits, the Nolan machines) is declared with it.

The field is a sema change to three staging words, edited in place; the
`sema/spec` change-control applies, so it starts with discussion, not an
edit. Mirror in gwsproto, the tlayouts generators and fixtures, and the
snapshots in the same wave, with the axiom that every declared node
exists in `ShNodes` and the conformance check that the declared machines
are the ones the layout's actor classes run.

## The rule

**Every declared machine's `machine.states` rows become readings on the
declared channel, whose unit type is the row's `StateEnum`.** No per-enum
or per-handle listing in the journalkeeper: it reads the list from
`layout.lite`, vendors the enum words it meets (its snapshot seed grows
with the vocabulary) and creates the channels, the way it already
creates the pico roster's. A reported row whose node and enum are not
declared is a defect at the boundary: counted and logged, never silently
dropped.

What this replaces: `gjk/report_event_persistor.py` `STATE_CHANNELS`,
a hand-kept map from machine HANDLE to pseudo channel (`"auto"`,
`"auto.lc"`, `"auto.lc.n"`, …). Two defects in that shape, both of
which the rule removes:

- it is keyed by handle, and handles move when the command tree is
  rewritten (admin takes the tree, five-v-boss reparents the cycler),
  so a state row can stop projecting after a reparent while the node
  is the same;
- every new state machine (hp-boss, five-v-boss, the circuit FSMs)
  needs a journalkeeper edit before its state is a channel, which is
  the "channel-name string in a data service" antipattern the standing
  team rule names.

Naming: keyed by the node name (the handle's last segment, which
`Scada.process_machine_states` already uses), not the handle. Relays
keep their existing channel names; the rule adds, it does not rename.
The pico roster's `<node>-pico-state` is the one case where the
reporting node (the cycler) is not the node the state is about; the
rule's key is the row's `MachineHandle` last segment, which the cycler
sets to the pico-backed actor's handle, so it fits without a special
case.

## What earns an asynchronous report

How reporting works today, for the evaluation's footing. Readings and
state rows accumulate in the scada and go upstream in the periodic
`report.event` (`seconds_per_report`, 60 s on spruce). Two things
already move faster: `PowerWatts` is forwarded to the LTN the moment
it arrives ("highest priority of scada"), and a commandable node's
`single.machine.state` is forwarded live to the admin link so the
panel row flips with the node. Neither of those live paths is
journaled; the journalkeeper reads `report.event` only, so the
journal's time resolution for everything is the report period, and
the timestamps inside a report are the scada's own, so ordering within
a period is preserved.

So the question is not "does the journal see it" (it does, a minute
later, with the right timestamp) but "who needs to know inside the
minute". Two consumers do: the LTN, for anything that changes what it
can bid or must settle; and alerting, for anything a person should
act on before the next report. Against that bar:

**Report asynchronously (send on the transition, the report still
carries the row):**

- **Top-state transitions** (`auto` Admin ↔ Auto, LocalControl ↔
  LeafAlly / Dormant): the LTN's contract standing changes with them,
  and an admin takeover during a contract is something the LTN should
  learn now, not at the next report.
- **The heat pump's commanded state** (hp-boss HpOn ↔ HpOff) and the
  power step that follows: `PowerWatts` already goes live; the state
  that explains the power step should ride with it, so the LTN and
  the journal see cause and effect in one place.
- **Pico roster flips to Flatlined or Zombie, and the cycler entering
  AllZombies:** these are the alerting cases. A single Flatlined is
  the cycler's business; five at once, or AllZombies, is a path
  failure (the router replacement) and a person should hear inside
  the minute.
- **Any comm-path or watchdog event** the scada already emits as an
  event (`peer.active`, shutdown): unchanged, they are events, not
  readings.

**Leave to the periodic report:**

- Relay and valve state changes in the ordinary course of control
  (zone relays following heat calls, the store charge/discharge
  valves): high-rate, expected, and nothing upstream acts on one
  inside a minute. The panel already gets them live.
- Pico cycler cycle steps (RelayOpening → RelayOpen → …): the journal
  channel from the rule above records them with the scada's
  timestamps; the person cares about AllZombies, not each step.
- Readings on async-capture channels (a temperature moving past its
  delta): the capture already fires the reading into the next report;
  moving it earlier changes nothing a consumer does.
- Pico roster returning to Alive: the recovery is worth a row, not an
  alert.

**Mechanism, if adopted:** one path, not many. A `report.event` with
a single row sent on the transition is the least new machinery (the
journalkeeper already persists it and orders by the row's timestamp);
the alternative, journaling `single.machine.state` messages directly,
means a second persist path in the journalkeeper for the same fact.
The LTN-facing forwards (`PowerWatts`, and top state if adopted) stay
what they are: they are control-path messages, not journal messages.

## Journal side

- **Log dropped readings.** The journalkeeper counts readings it has
  no channel for but never prints the count on the live path. Add a
  per-reading line at debug level (terminal asset, channel name,
  from alias) and the running count in the periodic summary at info,
  so "was anything dropped" is readable from the log. Small change in
  gridworks-journalkeeper, its own commit.
- The `journalkeeper-pico-states` item (vendor the four
  enum words) is the
  first step of the rule above; the rule retires the per-word vendoring
  as a manual step.

## Done when

- `layout.lite/013`, `gw.house0.layout` and `gw.nolan.layout` carry the
  machine list, mirrored in gwsproto and emitted by every tlayouts gen;
  a boot test per layout asserts the declared machines are the ones its
  actors run.
- The journalkeeper creates the declared channels for every state row
  in a spruce report, with no per-node listing in its code;
  `STATE_CHANNELS` is gone.
- The spruce journal shows the pico-cycler's cycle beside the roster
  rows (a witnessed cycle, from a commanded `reboot.picos`).
- The asynchronous set above is decided (grilled, then Accepted) and
  the adopted transitions arrive in the journal within seconds of the
  scada log line, witnessed on spruce.
- Dropped-reading lines appear in the journalkeeper log at debug.

## ▶ Do this next

The sema discussion of the machine-list field: its name, the entry's
three fields, and the axioms, on `layout.lite/013` and the two layout
words, all staging and edited in place. Then the gwsproto mirror, the
gens, the snapshots, and the journalkeeper reading the list.
