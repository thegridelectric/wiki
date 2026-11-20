# Gw108 Rev C (hub)

Status: Draft · Pass 0 · Updated 2026-11-20 · Linear: OPS-701

**EDD: yes** every component is witnessed on the spruce bench through the
starter script before its facts go into the device record and the layout.

**▶ Active spoke: [`bench-checklist.md`](bench-checklist.md)**

> What this is: the hub for bringing the Gw108 Rev C board into the
> vocabulary and onto spruce. Spruce is wired to a Rev C in place of its
> Rev B. The work runs component class by component class: see it work in
> the starter script, state it in the Rev C device-type record, use it in
> the spruce layout.

## Spokes

Reference: [`board-facts.md`](board-facts.md), what Rev C has, what
changed from Rev B, Joe's errata. The checklist tests it.

- ✅ DONE [`starter-script.md`](starter-script.md): archive the Rev B
  script, write the Rev C one.
- **[`bench-checklist.md`](bench-checklist.md)**: one table per component
  class, three columns each: starter script, device record, spruce layout.
- [`spruce-layout.md`](spruce-layout.md): the sema edits, the Rev C record
  in tlayouts, the spruce gen on Rev C, the roll.

## Notes

- Joe's README for Rev C is [`gw108-revc-readme-joe.pdf`](gw108-revc-readme-joe.pdf);
  the Rev B wiring before the swap and the Rev C after are in
  [`images/`](images/).
- Joe's bench code for Rev C is
  `gridworks-hardware/PCBs/KiCad/FullScada1/test_code/app.py`; the Rev B
  device-type record is
  `tlayouts/src/tlayouts/device_types/gw108.revb-gw1.scada.device.type.gt-000.json`.
- Bench windows are recorded under
  `experiments/2026-11-20-spruce-gw108-revc-bench/`; the first window
  read every input and ADC and actuated nothing.
- The CT ADC moved behind the mux on Rev C and the CT capability word has
  no mux fields. That sema edit comes last; the CT is the least important
  component to get right now.
