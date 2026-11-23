# The capture script in tlayouts, speaking sema

Status: Draft · Pass 0 · Updated 2026-11-21

> What this is: the fourth step of hello-gw108-ct. `starter-scripts/ct_waveform.py`
> captures a few seconds of CT conversions behind the mux while the scada
> runs, folds them at the fitted mains frequency and writes CSV. Its
> successor lives in tlayouts and emits sema.

## Open

- The output is `gw.adc.waveform` v000 instances (one burst per capture:
  chip settings, wall clock of the first conversion, host-timed offsets per
  code), written through the generated snapshot classes, filenames in the
  sema-typed JSON grammar. The folding and the summary numbers are
  analysis over the word, not part of it.
- What tlayouts' place is for a box-side tool, against starter-scripts'.
- Which of the starter script's behaviours survive: the mux check-and-
  repair every 200 reads, the prompt-for-next-capture loop, the ASCII
  trace.
