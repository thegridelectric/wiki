# LTNs ready (spoke)

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-532

> What this is: the spruce-settled spoke that gets a maple LTN and a
> spruce LTN running on the new code, each with a FLO and the parameters
> it needs, and then settles what the LTN takes from the scada. Opens
> after the fleet runs under local control; the second segment of
> spruce-unlimbo's `layout.lite/013` work transfers here when its first
> segment closes (the transfer note is in that spoke).

## The two FLOs

- **Maple.** A new FLO that uses the house's resistive elements and
  accounts for the wider COP variation of the Mitsubishi heat pump (last
  season maple ran a two-stage Samsung). Its parameters are not the
  current `flo.params.house0/007` shape; expect a `008` or a new word.
- **Spruce.** A FLO and a parameter word for the Nolan house; none
  exists today. What it optimizes over (the buffer-less plant, the
  time-of-use windows already on `gw.nolan.operational.params`) is the
  design question.

## What the LTN takes from the scada

Owned here once the two LTNs run, not before, because each question is
answered by what the running LTN actually reads:

- What each LTN needs that the layout and ops words do not carry, and
  whether `flo.params.house0` gets a new version for the House0 fleet or
  a Nolan twin for spruce.
- The strategy selector and sieg-loop facts the LTN reads
  (`../spruce-unlimbo/control-strategy-selection.md` decision 4).
- Whether `layout.lite` is reshaped once more or replaced by the raw
  layout + ops words (`publish-layouts-and-operational-params.md`).
  Today the LTN reads `SeasonalStorageMode`, `BufferShortCycling`,
  `TotalStoreTanks` and `Ha1Params` off it, and carries its own settings
  default for the storage mode that the `layout.lite` arrival overwrites.

## Open

- Sequencing against `publish-layouts-and-operational-params.md`: the
  ops words freeze after the fleet runs them, and a FLO parameter word
  may want fields the ops words should own instead.
