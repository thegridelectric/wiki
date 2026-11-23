# Spruce on Rev C

Status: Draft · Pass 0 · Updated 2026-11-20

## Build steps, either side of the bench

1. Done 2026-11-20: the sema commit `gw1.device.type: add Gw108RevC`
   (`3b24e54` on `jm/gw108-revc`, based on `cfa2b66`); the scada snapshot
   regenerated from it and `Gw108RevC` added to the `gwsproto.enums.DeviceType`
   twin (scada `jm/gw108-revc`). The tlayouts snapshot does not seed
   `gw1.device.type` (DeviceType is an open string there), so it needs no
   regen; the Rev C record decodes through it as is.
2. In tlayouts: `emit_thermistor_reader` resolves the record from
   `config.board_record_file`; the Nolan plant roster takes a
   function-to-silk table per board rev. Spruce's gen points at the Rev C
   record. Commit the record now; the gen changes once the roster below
   is confirmed to the last entry.

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
  `CtAdc`. Needs its own green light before the edit. The CT comes after
  the roll: the store pump on CT1 is where the scada's CT reading is
  proven on a Pi with a Gw108 Rev C, with the bench numbers of
  2026-11-20 (27 mV RMS on, 0.6 mV off, one turn, a pulsed waveform
  that a sampled RMS detects but does not meter). The secondary pump's
  power stays on the eGauge and the BTU pico's CT entry is a
  placeholder. Long run, pump detection moves to Gw101 boards.

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
  roster. The FCM end of the DB25 is rewired to Joe's Rev C pinout, one
  load at a time, and the Zones 24 VAC is bridged to AUX (Rev C feeds
  every non-zone output from AUX). Confirmed by the load responding on
  2026-11-20: HeatPumpEnable to HpDryContact, SecondaryPump to Pump3,
  StorePump to Pump2, the charge valve to Valve1 (the Rev B
  DischargeValve position moves to Valve1, not Valve3), and the iso
  valve to Valve3 (George's wiring, 16:42; Valve2 took under admin and
  nothing moved in the store loop). The element relays are untested. The
  secondary pump's 0-10 V is Dac3 channel C through DB25 pins 24 and 12,
  so the spruce gen's DAC output spec moves off the Rev B Z1/Z6
  deviation (`tlayouts/spruce_gen.py:212-214`, the `DacOutputSpec` on
  `Dac2` `C` and the comment above it). The original bit-for-bit list: HeatPumpEnable to HpDryContact,
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
