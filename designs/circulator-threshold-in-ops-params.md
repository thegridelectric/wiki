# Circulator threshold in the operational params

Status: Draft · Pass 0 · Updated 2026-10-29 · Linear: OPS-641

**EDD: no** a field moves from one word to another; verified by the
suite, the three layout fixtures and one house rolled to the new pair
with its running channels still reporting.

> What this is: the running threshold of a circulator leaves the
> `<pump>-running` derived channel's `Parameters` and becomes an
> operational-params value, one per input kind. The split out of
> OPS-628 that finishes the circulator work.

## Why

A running threshold is an operating choice about a pump, not a fact
about the channel that reports it. Today it is `ThresholdW: 4` in the
`Parameters` of every `circulator-running` DerivedChannel, which puts an
operator-tunable number in the hardware layout and makes the derived
generator read it off a channel. The circulator word exists so a
consumer reads the pumps off a list; the threshold belongs with the
other operating numbers about the pump.

## The change

- `gw.operational.params` gains a per-circulator tuning keyed by the
  pump node: the running threshold in the unit of the declared input,
  watts for a `PowerChannelName`, the CT's own unit for a
  `CtChannelName`. One value per circulator; a layout circulator with
  no tuning fails assembly.
- The `CirculatorRunningChannels` axiom on the three layout words loses
  nothing; the `circulator-running` channel simply has no `Parameters`.
- The derived generator reads the threshold from the ops word at
  assembly, so `handle_circulator_running` compares against a value the
  actor was given, not one it looks up on the channel.
- sema, the gwsproto twins, the snapshot and tlayouts move in one wave,
  as the circulator word did.

## Open

- Whether the threshold is one number per circulator or one per input
  kind per house. The fleet table on OPS-636 says 4 W separates the
  slowest running pump from off jitter everywhere measured so far.
- Whether a debounce joins it. Off jitter is −1..1 W with rare single
  samples near 5 W, and dist at elm dips to 5 W for a second several
  times an hour (2026-10-29), so the margin is 1 W.
