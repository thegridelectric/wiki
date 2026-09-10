# Report all machine states (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10

> What this is: one rule that turns every command node's
> `machine.states` row into a journal channel, replacing the
> journalkeeper's hand-kept map; and an evaluation of which state and
> channel changes are worth reporting the moment they happen rather
> than at the next periodic report. After the spruce launch.

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

## The rule

**Every `machine.states` row a node reports becomes a channel named
`<node>-state` whose unit type is the row's `StateEnum`.** No per-enum
or per-handle listing. The journalkeeper vendors the enum words it
meets (its snapshot seed grows with the vocabulary) and creates the
channel from the layout, the way it already does for relays
(`relay.closed.or.open`) and for the pico roster.

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

Naming: `<node>-state`, keyed by the node name (the handle's last
segment, which `Scada.process_machine_states` already uses), not the
handle. Relays keep their existing channel names; the rule adds, it
does not rename. The pico roster's `<node>-pico-state` is the one
case where the reporting node (the cycler) is not the node the state
is about; the rule's key is the row's `MachineHandle` last segment,
which the cycler sets to the pico-backed actor's handle, so it fits
without a special case.

Sema: `machine.states` already carries `StateEnum` as the enum word
name, which is what the channel's unit type needs; no word change is
expected. Open: whether the layout word should declare the channels
(so `layout.lite` carries them and `pull_readings.py` stops dropping
them as undeclared pseudo channels) or the journalkeeper keeps
deriving them from the node list.

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
- The `journalkeeper-pico-states` item on the `../spruce-unlimbo/
  sh-node-actor-partition/` queue (vendor the four enum words) is the
  first step of the rule above; the rule retires the per-word vendoring
  as a manual step.

## Done when

- The journalkeeper creates `<node>-state` channels for every state
  row in a spruce report, with no per-node listing in its code;
  `STATE_CHANNELS` is gone.
- The spruce journal shows the pico-cycler's cycle beside the roster
  rows (a witnessed cycle, from a commanded `reboot.picos`).
- The asynchronous set above is decided (grilled, then Accepted) and
  the adopted transitions arrive in the journal within seconds of the
  scada log line, witnessed on spruce.
- Dropped-reading lines appear in the journalkeeper log at debug.
