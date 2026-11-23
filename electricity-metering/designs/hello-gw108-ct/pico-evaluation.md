# Will this run on a pico or pico2 on a Gw101

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: the fifth step of hello-gw108-ct. Long run, pump detection
> moves to Gw101 boards. This spoke evaluates whether the CT read and the
> indicator from the first two steps run on a pico or a pico2 on a Gw101.

## Open

- What the Gw101's CT input is (its own ADC, or the pico's ADC) and what
  sample rate it reaches against the 860 SPS the ADS1115 gives.
- Whether the sampled-RMS indicator fits the pico's MicroPython budget
  beside its flow and thermistor duties.
- Whether the pico2 changes the answer.
