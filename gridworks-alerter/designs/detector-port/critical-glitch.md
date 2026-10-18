# critical-glitch — the scada's own Critical glitch relayed

Status: Draft · Pass 0 · Updated 2026-10-16

> What this is: the port of gwalert's `check_for_glitches`
> (`alert_generator.py:557`) as `CriticalGlitch`.

## gwalert today

Queries `glitch` messages from `<house>`, `.scada` and `.scada.s2` in
the last 2 hours with `type == "Critical"`, de-duplicates on
house-plus-summary for 2 hours, and alerts with the summary as the
message. The house prefix `hw1.isone.me.versant.keene` is a constant.

## The port

- **Reads:** the `glitch` word, which the alerter does not vendor yet:
  add it to the seed and a `glitches` table (or a handler that raises
  without storing, since the alert record is the storage). The glitch
  reaches the alerter on the ear exchange like everything else; the
  fleet roots say which houses.
- **Fires** on each Critical glitch, summary the glitch's; **resolves**
  after `critical_glitch_hold_s` (7200, matching gwalert's
  de-duplication) with no repeat of the same summary, since a glitch is
  a moment and the alert is the hold. The dispatch refusal
  (`AcceptsDispatch` false, OPS-392) is not this kind: it has a state to
  resolve on and gets its own kind when it is specified.
- **Layout:** none.
- **Tests:** a Critical glitch fires; a Warning does not; a repeat
  inside the hold does not re-raise; the hold expiring resolves.

## Do this next

Vendor `glitch`, then tests, rule, witness, shadow week, gwalert's
check off.
