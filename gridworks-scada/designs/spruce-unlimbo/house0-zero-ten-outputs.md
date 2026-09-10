# House0 0-10V per-output components (spoke)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-392

> What this is: House0's three `*-010v` outputs onto per-output
> components, the shape the gw108 DAC output already has
> (`i2c.dac.output.component.gt` + `dac.output.config`,
> `executor/hardware-layout.md` "The 0-10V output actuator"), and the
> `zero-ten-multiplexer` actor retired. Carved out of the relay
> decommission (`krida-retirement.md` rung 3) on 2026-09-10; it follows
> that rung because both retire a multiplexer actor and the relay one
> sets the shape. Slug is provisional.

## The shift (decided 2026-09-04)

**The House0 010v nodes migrate to per-output components here.** Two
0-10V mechanisms exist and only the gw108 one has code: the DFR modules
are driven through the `zero-ten-multiplexer` node holding one
`dfr.component.gt` with all three outputs in its ConfigList. Per-output
components there need the outputer to resolve its own module and the
multiplexer actor retired, the same shape as the relay side, so the
per-output word (vendor-free name, `zero.ten.output.component.gt`
proposed, linking field `ModuleComponentId`), the parent rename off the
vendor name, the fixture surgery, House0 axiom 10's ComponentId clause
and House0's ComponentBinding all land in this shift together (decided
2026-09-04). Not needed for the command-tree matrix: House0's shape
already puts the nodes in the tree.

## Where it stands

- Two 0-10V mechanisms exist; only the gw108 one has code on the
  per-output pattern. House0's three outputs are driven through the
  `zero-ten-multiplexer` node holding one `dfr.component.gt` with all
  three in its ConfigList (`tests/config/gw.house0.layout.json`;
  `gw_spaceheat/actors/i2c_zero_ten_multiplexer.py`).
- Sema side is change-controlled: a new word and a House0 layout word
  edit (`gw.house0.layout` is at 000; check its status before deciding
  in-place vs new version). Claims `sema/` and `tlayouts/` when it
  starts.

## Do this next

1. The per-output word, vendor-free (`zero.ten.output.component.gt`
   proposed, linking field `ModuleComponentId`), and the parent word
   renamed off the vendor name.
2. The outputer resolves its own module; the multiplexer actor goes.
3. Fixture surgery for the three nodes through the House0 gen
   (`correct-house0-tlayouts.md`); House0 axiom 10's ComponentId clause
   and House0's ComponentBinding (`layout-word-axioms.md` items 6 and
   7a; the binding test is skipped until then).
