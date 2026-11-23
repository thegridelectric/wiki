# Scada reads a CT behind the mux

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: the first step of hello-gw108-ct. On the Gw108 Rev C the
> CT ADS1115 (0x48) sits behind channel 4 of the TCA9548A mux (0x70). The
> scada's I2C bus actor selects a mux channel only for the DACs, from the
> device record's `Dacs[].MuxName` and `MuxChannel`; the CT capability word
> `i2c.ct.interface.capability` v000 has no mux fields, so a CT cannot be
> placed behind a mux in a layout and the scada cannot read one.

## Do this next

Read the sema change-control protocol (`sema-CLAUDE.md`), then propose the
word edit: `i2c.ct.interface.capability` gains optional `MuxName` and
`MuxChannel`, and the board word's MuxConsistency axiom extends to `CtAdc`.
The Gw108 Rev C design's `spruce-layout.md` already names this edit as its
last item and asks for its own green light. Get the green light here.

## Then

- The I2C bus actor (`gridworks-scada/gw_spaceheat/actors/i2c_bus.py`,
  backend selection around line 121) learns the CT ADC's mux channel from
  the record alongside the DAC channels.
- The ADS1115 driver (`gw_spaceheat/drivers/ads1115.py`) reads the CT
  channel through the selected mux channel with the mux select restored
  for the DAC writes that follow.
- The Rev C device record in tlayouts states the CT ADC's mux placement.
- Witness: on spruce under the running scada, the scada's own CT1 and CT2
  readings match `ct_waveform.py`'s DC level and RMS within the bench
  noise floor, and the DAC writes keep working through a capture.

## Open

- Whether the shared mux select wants a lock in the bus actor or the
  check-and-repair pattern the starter script uses.
