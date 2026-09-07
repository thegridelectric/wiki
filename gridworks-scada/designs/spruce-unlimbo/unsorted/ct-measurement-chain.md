# ct-measurement-chain (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md).

**CT measurement chain for the gw108** (from a conversation with Joe,
2026-09-02). Three levers set what a CT channel can measure:
the CT's winding ratio, how many times the power wire loops through
the CT, and the burden resistor (470 Ω is built into the board; any
resistor can be connected at the terminals). Encapsulate as
**`CurrentTransformerMeasurementScale` = resistor × loops / ratio**
(today: 470 × 1 / 2000 = 0.235; the 2000:1 CT + built-in burden
measures up to ~540 W — far above our sub-100 W pumps, hence the
interest in rescaling). Vocabulary this implies:
- **`BoardBurdenResistors`** — built-in burden resistors, a fact of
  the board record (belongs in the gw108 rev B json).
- **`AddedBurdenResistors`** — per-instance: what's actually
  connected at the terminals in a given home.
- A mechanism for attaching WHICH CT is used (specifically including
  its winding ratio) — the MakeModel head-fake for CTs carries
  neither ratio nor type today.
- A way of capturing HOW it is installed (loop count — e.g. the
  power wire looped twice through the CT).
- From all of that, the derived `CurrentTransformerMeasurementScale`
  the reading pipeline uses.
