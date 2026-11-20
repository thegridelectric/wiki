# Spruce on Rev C

Status: Draft · Pass 0 · Updated 2026-11-20

## Build steps, either side of the bench

1. The sema commit `gw1.device.type: add Gw108RevC` goes in on
   `jm/gw108-revc`; then regenerate the scada snapshot
   (`gridworks-scada/scripts/regen_sema_snapshot.sh`) and the tlayouts
   snapshot (`tlayouts/scripts/regen_sema_snapshot.sh`), and add
   `Gw108RevC` to the scada's `gwsproto.enums.DeviceType` twin.
2. In tlayouts: `emit_thermistor_reader` resolves the record from
   `config.board_record_file`; the Nolan plant roster takes a
   function-to-silk table per board rev. Spruce's gen points at the Rev C
   record. Commit the record with those two changes once the bench has
   filled the Rev C column.

> What this is: how the Rev C facts reach the vocabulary and spruce. The
> device-type record is updated as each checklist row is seen working,
> with a sema commit and a tlayouts snapshot regen whenever the vocabulary
> moves.

## Sema

- `gw1.device.type` v000 is staging: `Gw108RevC` is appended in place with
  a value description, `created` moved forward.
- `gw1.scada.device.type.gt` v000 and every capability word it uses are
  staging. The record for Rev C fits them as they are, except the CT.
- Last: `i2c.ct.interface.capability` v000 gains optional `MuxName` and
  `MuxChannel`, and axiom 4 (MuxConsistency) of the board word extends to
  `CtAdc`. Needs its own green light before the edit.

## tlayouts

- The record `src/tlayouts/device_types/gw108.revc-gw1.scada.device.type.gt-000.json`
  is written and decodes through the snapshot: 28 relays under the Rev C
  silk names at the Rev B bits, Valve4 and Valve4Energized on native GPIO,
  Thermistors1 (0x49) and Thermistors2 (0x48), no CtAdc until the CT word
  has mux fields.
- The gens read the board record in two places that assume Rev B:
  `hardware/thermistor.py` `emit_thermistor_reader` takes the module-level
  Rev B record (`gw108_device_type`) for the ADC name and data rates, not
  the record the config names; and the Nolan plant roster in
  `nolan_sema_gen.py` hard-codes Rev B relay names. The fix for the first
  is to resolve the record from `config.board_record_file`. The second
  needs a function-to-silk table per board rev; the Rev C column is the
  bench's to confirm.
- Working hypothesis for the Rev C column, bit for bit from the Rev B
  roster (the FCM cable moved as one unit): HeatPumpEnable to HpDryContact,
  SecondaryPump to Pump3, IsoValve to Valve2 (energized by default on the
  FCM, which matches the Nolan boot posture), DischargeValve to Valve3,
  StorePump to Pump2, BufferTop to HeatingElement2, BufferBottom to
  HeatingElement1, StoreTop to HeatingElement4, StoreBottom to
  HeatingElement3. Each is confirmed by driving the relay and seeing the
  flow or the contact.
- The scada's `gwsproto.enums.DeviceType` twin gains `Gw108RevC` after the
  scada snapshot regen, in the same wave as the tlayouts snapshot regen.
- The Nolan gen's relay roster names Rev B positions (`HeatPumpEnable`,
  `IsoValve`, `DischargeValve`, `StorePump`, `SecondaryPump`, `BufferTop`
  in `nolan_sema_gen.py`). Spruce's gen points `board_record_file` at the
  Rev C record and the roster names move to the Rev C silk.
- Spruce rolls by `scripts/roll.sh` from the committed tlayouts JSON.

## Open

- Whether the simulated twin (`SimGw108`) follows Rev C or stays on the
  Rev B record.
- Which Rev C relays spruce's Nolan layout uses, and under what names.
