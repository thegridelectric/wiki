# rotate-hubitat-tokens

Status: Draft · Pass 0 · Updated 2026-10-19
**EDD: no** build-out; verified by the suite plus a check at each house:
its scada polls its thermostats with the new token from the box, and the
hub refuses the old one.

> What this is: take the Hubitat Maker API tokens out of the layout and out
> of every repo, then rotate the five tokens that are in public git history.

## Why

A House0 house's scada polls its Honeywell thermostats through the Maker
API app on the house's Hubitat hub, with that app's access token. The
token reads the devices the app exposes and commands them, setpoints
included. The scada uses it over the house LAN; a Maker API app with cloud
access on also answers it through Hubitat's cloud with the hub's id.

`AccessToken` is a required field of `hubitat.gt`, so the credential is
part of the layout, and every copy of a layout is a copy of it: the gens,
the committed tlayouts output, each box, and the registry's record once it
exists. The tokens of beech, maple, oak, fir and elm, with each hub's LAN
address and MAC, are in public history:

| Repo (public) | What | Since |
|---|---|---|
| gridworks-scada | all five, in history (removed from the tree) | beech `0f19cbf5`, on `main`; the other four `640a0d33`, on `jm/spruce-unlimbo` |
| sema | beech and maple, in the current tree of `dev` (`definitions/types/gw.house0.layout/stash_axioms.md`, `tests/runtime/gw_house0_layout/fixtures/vanilla.json`) | beech `3422ca9`, maple `2aabe87` |

tlayouts has them in its gens, the old gens and the committed output.
Public history cannot be recalled, so rotation is the remedy; scrubbing the
trees only stops new copies. Decided 2026-10-19: keep the current tokens
until the token has left the layout, so a rotated token never enters a
repo.

## The plan

1. **The token leaves the word.** A new `hubitat.gt` version and a new
   `hubitat.component.gt` version without `AccessToken`; the gwsproto
   twins follow; the scada reads each hub's token from the box's `.env`
   under the scada's own settings prefix, keyed by the hub's node name, and
   a hub with no token is a boot failure that names the hub. The gens drop
   `hubitat_access_token`. The registry holds no credentials: a line in the
   registry's source-of-truth model (OPS-471), distilled into the
   registry executor when it is written.
2. **Each box gets its current token in its `.env`**, recorded in the box's
   `gridworks-infra/<box>/instance-README.md`, before the box runs a layout
   without the field. Both pis of a two-pi house get it.
3. **Rotate, one house at a time.** In the hub's Maker API app, create a
   new access token (the old one stops working), put the new one in each of
   the house's box `.env` files, restart, and check that both thermostats
   report fresh setpoints and temperatures and that a request with the old
   token is refused. Turn off cloud access in the app unless something we
   run needs it.
4. **Scrub the trees.** Replace the real tokens in sema's two files with
   placeholders, and delete `old_gen_beech.py` / `old_gen_maple.py` if
   nothing reads them.

## Do this next

Write the sema change for step 1 (read `sema-CLAUDE.md` first): the two
word versions, and whether the hub's other LAN facts (host, MAC) stay in
the layout.

## Open

- Whether any scada log line prints a poller URL with the token in it.
- Which hubs have Maker API cloud access on.
- The order against the beta windows: a box that takes a window layout
  without the field needs step 2 first.
