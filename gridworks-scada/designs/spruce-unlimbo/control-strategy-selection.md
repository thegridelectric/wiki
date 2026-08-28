# Control strategy selection (spoke)

Status: Draft · Pass 0 · Updated 2026-08-27 · Linear: OPS-392

> What this is: spruce-unlimbo spoke settling how the scada chooses which
> LeafAlly and LocalControl machines run, who owns a machine's starting
> state, and what replaces `SeasonalStorageMode`. Decisions taken with
> Jessica 2026-08-27; the sema edits are gated below.

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
3. **Both loaders read ops for the strategy.** `local_control_loader.py`
   today selects on `layout.hydronic.Strategy == "Nolan"` first, then ops
   (`ActuationAuthority`, `SeasonalStorageMode`); `leaf_ally_loader.py`
   selects on `layout.layout_type_name`, then ops. After this spoke each
   ops word carries an explicit selector per control role, and
   `Hydronic.Strategy` stays what it is — a manifold variant, a plumbing
   fact — and selects no code.
4. **The LTN needs the selected strategy** for multi-tank homes, and
   whether the sieg loop is in use (so it can set the heat-pump leaving
   water temperature). Both ride in the two words the scada will send in
   place of `layout.lite`: the layout word and the ops word
   (`operational-params-cleanup.md` "Retire `layout.lite`"). Until those
   words settle, the scada keeps sending `layout.lite` and the raw-word
   send is gated off the `hw1` broker — by an explicit gate (settings flag
   or universe check), not a commented-out block.

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

Search the registry for existing strategy vocabulary, then open the
word-gate discussion for the selector fields on both ops words.
