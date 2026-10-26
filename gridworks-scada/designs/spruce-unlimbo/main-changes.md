# main-changes

Status: Draft · Pass 0 · Updated 2026-10-26 · Linear: OPS-392

> What this is: a spoke of [`primary.md`](primary.md): the commits
> `main` took after `jm/spruce-unlimbo` branched, each with a verdict,
> and the gates for the swap that makes the branch `main`. The swap is
> one move; rolling a House0 house onto the new `main` is a separate
> per-house move (`deployment.md`), with its own gates listed here.

The boxes run `main`, so anything that went in there after the branch
point (`8a0e1689`, 2026-06-10) is a fix the fleet relies on. Each commit
below was read against the branch on 2026-10-25: present in another
form, superseded by the renovation, or to take now. None is to take
now.

## The commits on `main`, with verdicts

Eleven non-merge commits, none on the branch by patch-id
(`git cherry jm/spruce-unlimbo origin/main 8a0e1689`).

| commit | what | verdict |
|---|---|---|
| `3d83bfdc` 05-07 | Debug failed transition to BufferOnly (#560): the AllyGivesUp handler sends a terminating heartbeat only when a contract is held, and stores and flushes it | present: `scada.py` `end_contract` has the same guard, store and flush, for every decider of the end (ally, cold watch, restart refusal) |
| `2ed4466a` 06-09 | Fixing Standby mode (#567): the standby posture energizes the failsafe and aquastat relays and turns the heat pump off through the sieg path when the house has a loop; docs added | superseded: the branch's `local_control/standby.py` takes the energized set from the ops word (`EnergizedStandbyRelays`) and always tells hp-boss TurnOff, so the posture is data and the sieg case needs no flag. The three docs (`editor-setup`, `provisioning`, `tls`) come across with the merge, no conflict |
| `310509a3` 09-04 | Adding WifiOrEthernet to TankModuleParams | superseded by `4d5375a7` below (the field became the board variant) |
| `a02a7c4b`, `cc360e37` 09-04 | Minor | superseded, same series |
| `4d5375a7` 09-07 | `tank.module.params` 200: pico reports its board and MicroPython version | present: the branch's twin is version 200 with `PicoBoardVariant` and `MicropythonVersion` |
| `f83a0b77` 09-14 | Updates for new Pico codes (#575): `async.btu.params` 100 and `baseurl.failure.alert` 100 | present: both twins at 100 with the same fields |
| `ce05fcd5` 09-23 | patch small bug in layout gen (`layout_gen/flow.py`) | superseded: `layout_gen/` is gone from the branch, tlayouts generates every layout |
| `95ed3027` 10-02 | minor tweak for beech, throwaway: silences the derived generator's "only expects from tanks" info | superseded: the branch's derived generator has no such line |
| `55b2dc29` 10-08 | Proactor pin to `v4.1.13+jm3` | present: same pin in every requirements file |
| `e0768309` 10-14 | pico liveness gets the nyquist margin (2.1 × the post period) and reports a missing pico once a minute | superseded: `actors/pico_liveness.py` is the one liveness definition, 2.5 × the expected post period and one report a minute while the silence lasts, with a liveness per channel on top (`sensor-freshness.md`) |

The dry-run merge (`git merge-tree`) conflicts in eleven files, every
one inside the present-or-superseded set: `api_tank_module.py`,
`derived_generator.py`, `layout_gen/flow.py` (deleted on the branch),
the gwsproto enums `__init__` and `pico_board_variant`, the three
twins above, and the two named-types tests plus `test_layout_gen.py`.
Each resolves to the branch's side.

## The other two lines

**`actual-spruce` is not merged.** It is spruce's roll-back line and
nothing else: the winter hack with the fixes spruce needed while it
ran. Its five commits absent from the branch by patch-id (`30fc7f59`,
`69d5d6ec`, `02702522`, `ccfa18c5`, `cda464ba`) are the params-200,
pico-roster, pico-codes, proactor-pin and liveness changes, each
present on the branch in the forms above (the roster is the branch's
`SinglePicoState` enum and the cycler's per-pico states). The line
stays as it is until spruce has run `main` through a heating-season
stretch (`deployment.md` "Rollback").

**`jm/spruce`** (the old spruce layout line) has nothing absent from
the branch.

## The swap

`main` cannot fast-forward to the branch, because `main` moved. The
order:

1. `git branch legacy origin/main` and push it: the old `main` keeps
   its name as a line boxes can roll back to.
2. Merge `origin/main` into `jm/spruce-unlimbo`, each conflict to the
   branch's side per the table; the suite green on the merged tip.
3. Push the branch tip as `main` (now a fast-forward, since the branch
   contains `main`). A box on `main` fast-forwards at its next pull;
   none pulls on its own.
4. `td/generalized-flo` takes the new `main` by a merge, so its history
   stays its author's and oak's checkout fast-forwards. The real
   conflicts are in the LTN: `actors/ltn/ltn.py` (the FLO parameter
   build and the weather read), `ltn/config.py`, `ltn_app.py` and
   `tests/actors/test_ltn.py`, which both sides rewrote. That is a
   working session with the branch's author (`ltns-ready.md` "The FLO
   boundary"), prepared on a topic branch off the new `main`.

### Gates for the swap itself

- The table above complete (done 2026-10-25).
- The suite green on the branch tip before the merge (2026-10-25,
  `8251eb89`: 1668 passed, 5 skipped) and again on the merged tip.
- A roll-back line named per family: `legacy` for the House0 houses,
  `actual-spruce` for spruce, and `roll.sh back` knowing both.

### Gates for rolling a House0 house onto the new `main`

Not gates for the swap: a House0 house keeps running `legacy` or
`td/generalized-flo` until these hold.

- **OPS-619 fixed.** The sieg loop's own atomic report for a
  strategy-chosen move has no event, the journal's runtime enforces
  the axiom and refuses the whole five-minute report; the twin's two
  axioms are empty stubs. Seen on oak and maple on 2026-10-23. Every
  House0 house on the branch loses the report in which its valve
  finished such a move, so none boots the branch again before the fix.
- **fir repaired.** On 2026-10-25 fir's two pis sat at different SHAs
  (`12b882f4` and `a70c10ea`) and the LTN's layout differed from the
  tlayouts `main` output, so `roll.sh fir check` fails. The pis on one
  SHA and the LTN's layout matching the committed pair come first;
  the roll refuses otherwise.
- Beech waits while sick; elm is not in the rollout (`deployment.md`).

## Open

- Whether `roll.sh back` reads the roll-back line per family from one
  table in the script, so `legacy` and `actual-spruce` are not typed at
  the prompt.
