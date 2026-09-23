# flow-module catch-up (design)

Status: Draft · Pass 0 · Updated 2026-09-17 · Linear: OPS-549

**EDD: yes** a flow-hall pico flashed with the new code, reporting to a
scada that reads and echoes its params, is the verification; the spruce
window at the end of the correct-house0 spoke (OPS-539) is where it runs.

> What this is: bring the flow-meter pico firmware to the same shape the
> tank module and the BTU meter reached in September 2026, so a flow pico
> reports its board and MicroPython version, reconnects on its own, writes
> flash atomically, and speaks a registered sema params word.

## Where the flow firmware stands

The tank module (`tank_module/tank_module_3_main.py`) and the BTU meter
(`btu_meter/async_btu_main.py`) were reworked together (gridworks-pico PR
15 with the shared `net.py`; scada PRs 574 and 575 for the params words
and their twins). The flow-hall firmware was not: the only flow code in
the repo is `archive/flow_hall/flow_hall_main.py` (posts
`flow.hall.params` 101 and `ticklist.hall` 101, with its own wifi and
ethernet connect code) and the older `archive/flow_reed/`. The scada
reads it through `actors/api_flow_module.py`, whose `FlowHallParams` and
`FlowReedParams` are hand-built pydantic classes; neither word is in the
sema registry.

Field flow-hall picos run whatever was flashed at provisioning, so the
archived file is the deployed code until this design ships.

## The change set (mirror the other two modules)

Each item is what the tank module and BTU meter already have.

1. **Un-archive into a module folder.** `flow_module/flow_hall_main.py`
   beside `tank_module/` and `btu_meter/`, with its `comms_config.json`
   and `app_config.json` templates, and `provisioner_generator.py`
   covering it. Flow stays a module of its own and does not become a
   mode of the BTU meter, so the field units can be updated on their
   own.
2. **Shared `net.py`.** Replace the file's own `connect_to_wifi` /
   `connect_to_ethernet` with the `net` module and its `HttpClient`;
   posts go through `post` / `post_fire_and_forget`.
3. **Reconnect on its own.** `needs_reconnect` set on any post failure,
   `try_to_reconnect` with the 30 s cooldown, wifi or ethernet chosen by
   the comms config.
4. **Flash-write discipline.** `_atomic_write` for every file write;
   `app_config.json` written only when the scada's answer changes a
   value; `main_update.py` staged atomically.
5. **Board and version.** `PicoBoardVariant` read from `comms_config.json`
   and derived from `os.uname().machine` plus the link type when absent;
   `MicropythonVersion` from `os.uname().release`; both in every params
   post.
6. **The params word.** `flow.hall.params` registered in sema: 101 as
   shipped, then a new version that requires `PicoBoardVariant` and
   `MicropythonVersion` (the sema side is in the correct-house0 spoke,
   OPS-539). The firmware posts the new version; the scada's twin moves
   to it and, as with the other two, a post at the old version fails
   construction and is answered empty. Un-upgraded flow picos are
   rejected on purpose.
7. **Alert words at 100.** `baseurl.failure.alert` 100 and `new.code` 100,
   as the other two post.

## Field roll-out

- A flow pico is reflashed in the field the same way the tank modules
  were on 2026-09-15 at spruce; each house's hardware layout carries the
  provisioned `PicoBoardVariant` and `MicropythonVersion` for it, and the
  scada alerts when a post disagrees with the layout (OPS-539 sets that
  mechanism).
- Order: bench (honeysuckle) first, then spruce inside the OPS-539 spruce
  window, then the House0 houses with flow picos.

## Open

- Which houses still have a flow-hall pico rather than a BTU meter on the
  flow channel, and whether any reed pico is still deployed (decides
  whether `flow.reed.params` is registered or the class is deleted).
- The `os.uname().machine` string for the flow picos' boards, read from
  one unit before the derivation is trusted.
