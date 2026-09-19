# Required energy from the tariff

Status: Draft · Pass 0 · Updated 2026-09-18 · Linear: [OPS-551](https://linear.app/gridworks/issue/OPS-551)

**EDD: no** a change to a calculation, verified by the suite plus tests that
pin today's numbers on the present tariff and show a second tariff moving
them.

> What this is: the required-energy calculation has carried the House0 homes
> through two winters on one tariff, with that tariff's hours written into
> the code. The on-peak windows now live in the operational-params word. This
> design settles what the calculation should read from the word, so the
> store is sized against the same windows the on-peak control runs on. How
> the calculation works today is `../executor/required-energy.md`.

## Do this next

Answer the four questions under "What to settle". They are about intent,
and the person who wrote the logic holds it. Code follows the answers.

## Where the tariff is written into the code

All in `gw_spaceheat/actors/derived_generator.py`; both methods carry a
docstring note saying so.

`compute_required_energy_wh`:

- the three load sums: `7<=t.hour<=11`, `12<=t.hour<=15`, `16<=t.hour<=19`;
- the evening-before case:
  `(weekday<4 or weekday==6) and hour>=20`, or `weekday<5 and hour<=6`;
- the midday case: `weekday<5 and 12<=hour<16`;
- the midday recharge: `0.8*4*HpMaxKwEl*midday_cop`, the `4` being the gap's
  hours, and the midday COP taken over `12<=t.hour<=15`.

`rwt_f`:

- which forecast hours count is read from the word (`in_onpeak_window`);
- "the morning window is still ahead" is `hour > 19 or hour < 12`;
- "afternoon only" is `t.hour >= 16`.

What already reads the word: `is_onpeak`, `just_before_onpeak`, and the
`rwt_f` hour test. Every home today is on weekdays 07:00 to 12:00 and 16:00
to 20:00, which is what the literals say, so nothing misbehaves now.

## What to settle

1. **Is this the rule?** Before each upcoming on-peak window, the store
   needs that window's forecast load, less what the heat pump can put back
   in the gap before the window; for the first window there is no gap. The
   present code is that rule for two windows and one gap. If the intent was
   something else (the 80 %, the cap at maximum storage applying to one case
   and not the other), say what.
2. **How far ahead does it look?** Today: from 20:00 the evening before, and
   from 12:00 for the afternoon. In terms of windows: all windows in the
   next N hours, the next two, or the windows of the coming tariff day?
3. **What does `rwt_f` mean by its two cases?** "The hardest on-peak hour
   still ahead" would replace both clock tests with one question of the
   forecast and the windows. Is that the intent, or does the afternoon-only
   case mean something more specific?
4. **What is out of scope for the word?** A tariff with no gap long enough
   to recharge, a weekend window, a single window: which of these should the
   calculation handle, and which should it refuse loudly?

## Plan, once settled

1. Tests first, on both House0 sim pairs: today's required-energy numbers
   pinned at the evening-before, early-morning, midday and on-peak clock
   points under the present tariff.
2. The calculation rewritten over `Tariff.OnPeakWindows`; the pinned numbers
   hold.
3. A second tariff in a test (one window; shifted windows) showing the
   numbers move with the word.
4. `../executor/required-energy.md` rewritten to the general rule, its
   "The tariff is assumed, not read" section deleted.

## Nearby

[OPS-210](https://linear.app/gridworks/issue/OPS-210) (a greedy algorithm
for required energy) and
[OPS-223](https://linear.app/gridworks/issue/OPS-223) (exposing the
required-SWT derivations) touch the same code with different questions.
