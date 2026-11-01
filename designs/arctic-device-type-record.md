# Arctic device-type record

Status: Draft · Pass 0 · Updated 2026-10-29 · Linear: OPS-643

**EDD: no** a sema record and a traits row from measured numbers;
verified by the suite and hp-boss loading the row at elm.

> What this is: the sema `hp.device.type.gt` record for the Arctic
> MAHRW030ZA and the scada's `HP_TRAITS` row, authored from the start
> signature measured at elm. Split out of OPS-628.

## The record

- The unit is a monobloc with two compressors, so the start signature
  has two steps and `CompressorRatedAmps` is a nameplate total.
- No field says monobloc or counts compressors, and none is added: the
  layout's `hp_parts` (odu alone) and the traits row state those facts.
- The settings, the dry-contact behavior and the bench questions are
  in the scada executor's heat-pump-comms note for the unit.

## Depends on

- The start signature measured by the field harness under OPS-628.
- The Modbus reads of OPS-638 where they confirm the signature.

## Open

- What the traits row needs for a two-step start: whether hp-watch's
  on-threshold is the first step or the total.
