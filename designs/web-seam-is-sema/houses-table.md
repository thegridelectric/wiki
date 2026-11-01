# The Houses table

Status: Draft · Pass 0 · Updated 2026-10-29

> What this is: the dashboard's Houses card (`HousesTableCard.tsx`, the
> `/installations/` route) read against the seam rules, and the build of
> its commit column. Each house row is one `gw.house.summary`.

**▶ Do this next.** Three branches built and green. Sema `jm/commit-standing`
(committed `9efdacf`): `gw.commit.standing` 000 and `gw.house.summary`
002, both staging. Backend `jm/house-summary-001` (uncommitted): the api
snapshot built `--allow-staged`, the summaries route filling
`ScadaCommit` and `ScadaCommitStanding` from a GitHub compare per
distinct commit, cached; `BACKEND_SCADA_REPO` is a new required
setting; 37 tests pass, the published-only snapshot test skips off
`main`. Frontend `jm/houses-table-commit` (uncommitted): 002 schema, the
union over 000/001/002, the check-or-hash cell; 81 tests, typecheck
clean, lint unchanged from the base. Next, in order: the page check the
hub's EDD line asks for, the Houses card in the dev browser against the
backend on `tsdb_tap` (`experiments/dev-stack-recipe.md`), a house on
main's head showing the check and a legacy-code house an empty cell;
commit backend and frontend; a promotion-only sema turn for the enum and
002 (`sema promote`, bottom-up) and a published-only regen of the api
snapshot before the backend merges to `main`; `BACKEND_SCADA_REPO` in the
box's `.env` per its instance-README before the deploy.

## The commit column's standing

The browser does not compare hashes. The backend asks GitHub where each
announced commit stands against main's head and sends the answer as
`gw.commit.standing`: OnMainHead renders as a green check with no hash,
every other standing renders the short hash (Dirty in red), Unknown and
a summary with no standing render the hash plain. The enum's default is
Unknown because a standing this version does not know asserts nothing.
GitHub's compare is asked once per distinct commit across the fleet and
cached five minutes, so main moving is seen within that; the repo is
public, so the call is unauthenticated and the per-IP rate limit is far
above a fleet's distinct commits.

## Seam findings on this card

- **The first column is the registry's display name**, copied verbatim
  through the journal's `g_nodes` projection. "Beech TerminalAsset" is a
  registry data fact; changing it is the top-level design
  `g-node-display-rename` (no gnr command sets a display name today).
  The header "Alias" is wrong on its face, since the cell is a display
  name; "House" is the candidate.
- **The heat-call cell is name matching at both ends.** The backend finds
  active calls with `name like '%heat-call%'` and sends the channel name
  as `LongestRunningZoneName`; the browser strips `-heat-call`. On elm
  the result is "zone2-bedrooms" while the layout's ZoneList says
  "bedrooms". The fix is the zone-call circuit in `gw.hydronic` naming
  the heat-call channel per zone, after the layout words publish.
- **The Status label is a browser projection**: `<control mode> /
  <SeasonalStorageMode>`, the mode derived from TopState and
  LtnDispatching in the words of `gw.house.control.mode`. The protocol
  puts that derivation in the backend: the next `gw.house.operating.status`
  version carries the enum and the browser reads it. Standby no longer
  shows in the label; whether it returns is open.
- **The green/red badge** is "reported within the last minute", computed
  in the browser from `LatestSnapshotTime`. Left until Status settles.
- **Provenance of the status**: the scada's own `gw.house.operating.status`,
  kept newest-per-house by the journalkeeper, which also writes a
  `derived` row for a house whose scada does not send the word yet. The
  summary does not say which; the browser cannot tell.
