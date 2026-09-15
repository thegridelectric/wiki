# Control strategy selection (spoke)

Status: Draft · Pass 0 · Updated 2026-09-15 · Linear: OPS-392

> What this is: spruce-unlimbo spoke on how the LTN and the scada
> select the correct control strategy for each different house: which
> LeafAlly and LocalControl machines run, who owns a machine's starting
> state, and what replaces `SeasonalStorageMode`. The scada-side
> decisions of 2026-08-27 are below and on the branch; the design still
> needs work, the LTN side above all, and stays a launch item.

## Decisions (2026-08-27)

1. **Ops chooses the machine; the machine owns its state.** The
   operational-params word selects which LeafAlly and which LocalControl
   implementation runs. The starting state is a constant of the machine
   (every ally starts `Dormant`, every local control starts at its own
   `initial=`), so no artifact carries it and the scada never seeds another
   actor's row: each machine announces its state in `start()` with the
   same `SingleMachineState` it sends on transitions. Landed on the branch
   (`scada.py` `initialize_hierarchical_state_data` seeds only the scada's
   own TopState; the six impls announce; `tests/actors/test_machine_state_announce.py`
   covers both families).
   Why the seed existed: a snapshot's `LatestStateList` is
   `latest_machine_state.values()`, and the allies only reported on a
   transition, so a snapshot before the first transition had no ally row
   at all. The seed (2025-03-03) fixed that; the 2026-01-14 rename grew it
   a `SeasonalStorageMode` branch, which is how strategy knowledge got into
   `scada.py`. The seed also misreported: `Standby` local control speaks
   `LocalControlStandbyTopState`, and `tou_base` can start in `Monitor`.
2. **`SeasonalStorageMode` is retired.** Two strikes: it conflated the
   top-level strategy with the starting state, and it is not family-neutral
   (a coming layout has no buffer tank). Its consumers today: both loaders,
   `scada.py:1284-1294` (dormant-state comparison — goes with decision 1;
   the scada can compare `la.state` against the ally's own dormant value
   or ask the ally), `scada.py` LayoutLite builder, the LTN, the derived
   generator and `sh_node_actor` (`operational-params-cleanup.md` lists the
   `.ops` reads).
3. **Both loaders read ops for the strategy.** Family first, then ops:
   `local_control_loader.py` selects on `isinstance(layout.sema_layout,
   NolanLayout)`, then `ActuationAuthority.Standby`, then
   `SeasonalStorageMode`; `leaf_ally_loader.py` on the string
   `"gw.nolan.layout"`, then `SeasonalStorageMode` (`gw.hydronic` carries
   no `Strategy` field). After this spoke each ops word carries an
   explicit selector per control role, the two family discriminators
   become one, and an authority value selects no machine.
4. **The LTN needs the selected strategy** for multi-tank homes, and
   whether the sieg loop is in use (so it can set the heat-pump leaving
   water temperature). Both ride in the two words the scada will send in
   place of `layout.lite`: the layout word and the ops word
   (`operational-params-cleanup.md` "Retire `layout.lite`"). Until those
   words settle, the scada keeps sending `layout.lite` and the raw-word
   send is gated off the `hw1` broker — by an explicit gate (settings flag
   or universe check), not a commented-out block.

## What `SeasonalStorageMode` answers today

Its readers split into two kinds, and the selector shape has to serve
both:

- **Machine selection**: the two loaders, and `scada.py`
  `enforce_auto_state_consistency`, which picks the ally's Dormant value
  by mode (decision 1 retires that comparison).
- **Store participation**: which tank layers the energy math counts.
  `derived_generator.py` (ordered tank layers, max storage,
  `evaluate_strategy`), `tou_base.py`, `hydronic/house0.py`, the two
  House0 TOU controls and the all-tanks ally read it as "buffer only, or
  every tank". The LTN reads the same fact off `layout.lite` for its tank
  count and channel filter, and also carries its own
  `LtnSettings.seasonal_storage_mode` defaulting to AllTanks, a second
  source that the `layout.lite` arrival overwrites.

The House0 selector values (AllTanks, BufferOnly) are one-to-one with
participation today, so one function off the selected ally strategy can
answer the participation readers, on the scada and on the LTN. Whether
participation stays a derived fact or becomes its own House0-only field is
the decision to take with the selector shape.

## Sequencing with `layout.lite`

`layout.lite` carries `SeasonalStorageMode` and `BufferShortCycling`.
Retiring the field changes the wire shape: free while `layout.lite/013`
is staging, a `014` once `finalize-layout-lite-13.md` promotes it. Either
retire before that promote or let 013 carry the field until the raw
words replace `layout.lite` (decision 4).

## Open

- **Selector shape.** One selector per role per family: e.g. a
  `LeafAllyStrategy` and `LocalControlStrategy` field on each ops word,
  each a family-specific enum (House0 ally: `AllTanks | BufferOnly`;
  Nolan: the variants this fall brings). Per-family enums are the first
  intended divergence between the two ops words. Names are provisional
  until the registry is searched (`sema/definitions/`) — the sema
  word-gate applies before any authoring.
- **Live ops updates.** Ops values must change without a reboot (capture
  tuning above all). A changed strategy selector means swapping the actor
  implementation, which is an actor lifecycle, not a field update. Start
  with: the update path applies every field live except the selectors,
  which it refuses as restart-required; add a swap path only when a real
  need shows up. The update machinery itself (message → validate through
  the word → write the local JSON → replace `ScadaData.ops`) is its own
  item.

## ▶ Do this next

The registry has no strategy vocabulary beyond the per-machine state
enums (`gw1.leaf.ally.all.tanks.state`, `gw1.local.control.*.state`) and
`gw1.seasonal.storage.mode`; the selector enums are new words. Open the
word-gate discussion for the selector fields on both ops words, deciding
the participation question above in the same sitting. Then, in order:
the two loaders and the single family discriminator; the Dormant
comparison in `scada.py`; the participation function and its readers on
the scada; `layout.lite` and the LTN, with the LTN's settings duplicate
deleted; the loader tests on both fixture pairs.
- **Resistive elements bring new control frameworks.** Once a house
  runs its resistive elements under control (maple's new FLO is the
  first), the strategy space is no longer "which stores participate":
  element-versus-heat-pump dispatch is its own mental framework, and
  the selector vocabulary should leave room for it rather than
  enumerate today's two House0 modes as if they were the set.
