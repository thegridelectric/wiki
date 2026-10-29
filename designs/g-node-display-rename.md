# A command that changes a GNode's display name

Status: Draft · Pass 0 · Updated 2026-10-29

**EDD: yes** the verification is one real change on the production
registry: the command sets beech's TerminalAsset display name, the
journal's `g_nodes` row shows the new name within a second, the
dashboard's Houses table shows it within 36 s, and `gnr rebuild` replays
the captured command with no mismatch.

> What this is: the plan for the registry's missing write, a command
> that sets an existing GNode's display name, from the sema word through
> gnr's handler and operator CLI to the projections that follow it. The
> trace of how a display name reaches the dashboard today is here too,
> since it is the design's evidence and the verification's checklist.

## Why

The dashboard's Houses table shows the registry's display name for each
TerminalAsset, and six of them read "Beech TerminalAsset" and the like.
The gnr's own default-name rule says a TerminalAsset reads as the house
alone ("Beech"); the names were typed in when the registry was
repopulated on 2026-08-27, before the rule. The gnr executor calls
`display_name` mutable, but the write loop accepts only
`g.node.create.cmd` and `g.node.reparent.cmd`: no word, handler or CLI
changes a display name. A hand `UPDATE` on the box would reach the
dashboard, since every hop after gnr handles an update, but it writes no
command, so the next captured forest disagrees with the command log and
`gnr rebuild` exits non-zero. The registry's memory is its command log;
a change the log does not have is a change the registry cannot replay.

So the fix is a command. The names stay as they are until it exists.

## The word

`g.node.display.rename.cmd` 000, draft, on the pattern of
`g.node.reparent.cmd`:

| Field | Word | Meaning |
|---|---|---|
| `GNodeId` | `uuid4.str` | The node whose display name changes. Identity is the id; the alias is routing. |
| `DisplayName` | `string` | The new display name. |
| `Proof` | `string`, optional | The authorization artifact, opaque to the contract as in the create and re-parent commands. |

The name says "display" so it cannot be read as an alias change: the
alias changes only through re-parent. Whether `DisplayName` wants a
format (non-empty, a length bound) is open below; `g.node.gt` declares
it as a plain string today and the command should agree with the node
word it updates.

The reply is the existing `g.node.cmd.ack` / `g.node.cmd.nack`.

## The gnr change

- **Handler.** An `AuthoritySource` method on the create and re-parent
  pattern: authorize, append the command to `command_log`, update the
  row, validate, one transaction. No ledger claim, since no alias moves.
- **Change event.** A one-node `g.node.forest` on the node's parent
  channel, as a re-parent broadcasts the affected subtree, so the
  journal sees the change at once rather than at the daily snapshot.
- **Rebuild.** The word joins the replay types in `rebuild.py`, so a
  captured display-name command replays into the same row the captured
  forest shows.
- **Operator CLI.** A subcommand on the `gnr create` pattern
  (`operator.env`, Proof, wait for the verdict) that takes the alias,
  resolves the id through the read façade, and sends the command. The
  verb is open below.

## How a display name reaches the dashboard

Traced 2026-10-29 by reading each hop; every line was checked against
the file. Hop 0 is the gap this design fills. Hops 1 to 8 need no change.

| # | Hop | Trigger | Word | Where | Update? |
|---|---|---|---|---|---|
| 0 | gnr `g_nodes` row | `g.node.create.cmd` only; the default name from `default_display_name` when none is typed | `g.node.create.cmd` | `grid-node-registry/src/gnr/cli.py:209-241`, `src/gnr/display_name.py:22-30` | No: no update command |
| 1 | gnr emits a forest | after every applied command, the affected subtree; and a snapshot 300 s after start, then every `GNR_SNAPSHOT_INTERVAL_S` (86400 on the box) | `g.node.forest` 002 | `src/gnr/gnr_rabbit.py:101-190` | Yes: the snapshot reads current rows |
| 2 | Broker | `gnrmic_tx` on vhost `hw1__1`, key `rjb.hw1-gnr.gnr.g-node-forest.hw1.isone`; `gnrmic_tx` is bound to `ear_tx` | same | `gridworks-base/src/gwbase/topology.py:152-155` | Yes, best-effort broadcast |
| 3 | journalkeeper consumes | live only; an S3 backfill does not touch the projection | same, decoded without upgrade | `gridworks-journalkeeper/src/gjk/journal_keeper.py:224-231`, `g_node_forest_persistor.py:39` | Yes |
| 4 | `gridworks.g_nodes` row | only from `hw1.gnr`; skipped when the forest is older than the row's `sent_at` | — | `g_node_forest_persistor.py:110-137`, `display_name` at `:135` | Yes: upsert by GNodeId on the existing row |
| 5 | Backend summaries query | every request, no cache | reads `ta.display_name` | `gridworks-web-backend/api/v2/routers/installation_summaries.py:43` | Yes |
| 6 | The summary word | built per row | `gw.house.summary`, `DisplayName` | `installation_summaries.py:155` | Yes |
| 7 | Browser session | on load, every 36 s while the tab is visible, and when it comes back into view | parsed as the zod `HouseSummary` | `gridworks-web-frontend/src/App.tsx:40-63`, `src/_util/useTimer.ts` | Yes, within 36 s |
| 8 | Houses table cell | render | — | `src/_shared/HousesTableCard.tsx:350` | Yes |

Live evidence, read-only through the analyst login on 2026-10-29: all
six TerminalAsset rows read "House TerminalAsset" with `sent_at`
06:32:24Z, the newest forest from `hw1.gnr` is the same instant, and
`gnr-rabbit` has been up since 2026-10-23. The table has no `updated_at`
column; `sent_at` does that job.

## The names to set once the command exists

- The six TerminalAssets: "Beech", "Elm", "Fir", "Maple", "Oak",
  "Spruce", per the default rule.
- `fir.scada` reads "Scada Fir" where the rule gives "Fir Scada".
- The six LTNs read "House Ltn" where the rule gives "House LTN".

Each is one command, run from a dev machine with `source operator.env`,
and each shows up on the dashboard within 36 s.

## Verification

1. On the dev universe first: create a node, change its display name,
   watch the journal row and the dashboard against the dev stack
   (`experiments/dev-stack-recipe.md`).
2. On production: beech's TerminalAsset, with the three observables in
   the EDD clause above, then the rest of the list.
3. `gnr rebuild --seedstore` after the production change, exit zero.

The journalkeeper side gets a replay case in its executor's traces once
the production window exists: the forest before, the command, the forest
after, and the row the projection must show.

## Open

- The word's name: `g.node.display.rename.cmd` as above, or
  `g.node.display.name.cmd`, since the command sets a name.
- The CLI verb, which should not read as an alias change either:
  `gnr set-display-name <alias> "<name>"` is the candidate.
- Whether `DisplayName` takes a format, and if so whether `g.node.gt`
  takes the same one at its next version.
- Whether the command is open to any operator principal that may create
  nodes, or narrower.

## On completion

- The command and its change event go into the gnr executor's
  "Mutability & change model" and "Write path & egress" sections.
- The hop table becomes a short section in the web-backend executor,
  which already names `display_name` as the house's name.
- The journalkeeper replay case goes into its executor's traces.
- This file is deleted and the Linear issue finalized.

## Do this next

Settle the four Open items with the human, then the sema word as a
draft under the sema protocol (spec read-receipt first), on its own
sema branch.
