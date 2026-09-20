# Startup announcements (spoke)

Status: Accepted · Pass 1 · Updated 2026-09-19 · Linear: OPS-392

> What this is: what a scada says about itself once per run, and the one
> method that sends it when the broker link can first carry a publish. The
> announcements are `layout.lite`, the home's `ta.deed`, and a warning
> when there is no deed.

## Problem

A scada has things to say once per run that do not depend on an LTN being
there: which deed it holds, and that it holds none. Today nothing sends
either. The validation state is read only when a `Created` offer arrives
(`actors/scada.py` `process_slow_contract_heartbeat`), so a house with no
`ta-deed.json` looks the same as a validated one until someone offers it a
contract. Beech holds no deed in either config dir and round one of the
beta field windows did not show it.

The scada has no "the broker link is up" moment to hang such a send on.
`layout.lite` goes up from `recv_activated`, which fires when the upstream
link reaches `active`, and `active` needs a message from the peer. With no
LTN running the link rests in `awaiting_peer` and `layout.lite` is never
sent; with an LTN that comes and goes it is sent again at every
re-activation. Both are side effects of using peer activation as a stand-in
for "a publish will reach the broker".

Facts this rests on:

- The proactor already names the condition.
  `gwproactor/links/link_state.py` `state_is_active_for_send` is true in
  `active` and in `awaiting_peer`: connected and fully subscribed, peer or
  no peer.
- The callback interface (`gwproactor/callbacks.py`) has two link
  callbacks, `recv_activated` and `recv_deactivated`. Nothing calls the
  prime actor when a link reaches `awaiting_peer`.
- The proactor's own `gridworks.event.startup` does not cover this. It
  rides the acked event path: `links/link_manager.py` `generate_event`
  publishes only when the upstream link is `active` and persists the
  event otherwise, so with no LTN it stays on the box.
- A message published in `awaiting_peer` reaches the broker. A dev window
  with no LTN put three Warning glitches and the snapshots on
  `gw-dev-rabbit` (`experiments/capture_broker.py` capture, 2026-09-19).

## Decision: the deed goes up as its own word

The scada sends the `ta.deed` instance it holds, as it is. It is not a
field of the hardware layout or of `layout.lite`.

- The layout is authored by the house gen; the deed is a TaValidator's
  attestation. `executor/scada-ltn-link-state.md` "The trading gate" has
  the state read from a `ta.deed` instance, never from the layout.
- The validator's signature goes over the deed. Kept whole, the deed is
  checked as the bytes that were issued.
- The two change on different clocks: a gen rerun replaces the layout, a
  re-attestation replaces the deed, and neither should be able to drop or
  stale the other.
- `ta.deed/000` and its gwsproto twin exist
  (`gwsproto/named_types/ta_deed.py`), and both the scada and LTN codecs
  decode it. No sema change. The word is `staging`.

## Change

Pseudocode first: this is a comm path.

```python
# scada_app_interface.py
class ScadaAppInterface:
    @abstractmethod
    def upstream_is_send_capable(self) -> bool:
        """The upstream link can carry a publish: active or awaiting_peer."""
        # ScadaApp: self.proactor.links.upstream_link.active_for_send()

    @property
    def ta_deed(self) -> TaDeed | None: ...   # the one read of the deed file

# actors/scada.py
class Scada:
    STARTUP_ANNOUNCE_POLL_S = 1

    async def announce_at_first_broker_link(self) -> None:
        """Once per scada run: wait until the upstream link can carry a
        publish, then send the startup announcements."""
        while not self.services.upstream_is_send_capable():
            await sleep(self.STARTUP_ANNOUNCE_POLL_S)
        self.send_startup_announcements()

    def send_startup_announcements(self) -> None:
        self._send_to(self.ltn, self.layout_lite)
        deed = self.services.ta_deed
        if deed is None:
            self._send_to(self.ltn, Glitch(Type=LogLevel.Warning,
                Summary="no-ta-deed", Details=<the path looked at>, ...))
        else:
            self._send_to(self.ltn, deed)
```

- `ScadaAppInterface.ta_deed` returns the deed or `None`;
  `validation_state` derives from it, so the file is read in one place.
- The link manager is on the concrete app's proactor, not on
  `AppInterface`, so the scada reads send-capability through one abstract
  method on `ScadaAppInterface` that the scada app implements.
- The wait has no bound. A scada whose broker comes back an hour into the
  run still says which deed it holds, once.
- The no-deed warning is a `Glitch` built in `Scada`; `send_warning` is an
  `ShNodeActor` method and the prime actor is not one.
- `announce_at_first_broker_link` is one more task in `Scada.start_tasks`.
- Invariants: at most one send per scada run; nothing is sent before the
  link is send-capable; link flaps after the send cause no resend; the
  announcements need no ack and demand none.
- The LTN decodes the `ta.deed` it receives and drops it
  (`actors/ltn/ltn.py` `process_mqtt_message`, `case _`). The deed goes up for the record and
  for whoever reads the broker; an LTN that acts on it is later work.
- `layout.lite` is a startup announcement, so a window with no LTN still
  records the layout the scada booted on. Its `recv_activated` send stays
  as well: an LTN that starts after the scada learns the layout from that
  send or from its own `SendLayout`, and removing it is a separate
  decision about the LTN.

Polling the link state is chosen over a new proactor callback because it
touches one repo and a one-second poll costs nothing. A callback for
"send-capable" in `gwproactor` is the better shape if a second user
appears.

## Tests

Each shown red with the change reverted.

- `ta_deed` is `None` with no file and the deed with one;
  `validation_state` agrees on both (Nolan pair, with and without
  `gw.nolan.ta.deed.json`).
- `send_startup_announcements` sends `layout.lite` either way; with a deed
  it sends exactly that deed and no warning; with none, one `no-ta-deed`
  Warning and no deed.
- `announce_at_first_broker_link` on the in-process rig: nothing is sent
  while the app reports the link not send-capable; with no LTN started,
  one send while the link is not `active`; none when the LTN then
  activates the link. The task returns after its one send, so a later
  flap has nothing to resend from.

Built in `tests/actors/test_startup_announcements.py`; the two task tests
shown red with the task taken out of `start_tasks`.

## Witness

EDD, in dev first: `./house_window.sh dev on 1 --debug` with no LTN.

- ✅ Dev, 2026-09-19 (`experiments/2026-09-18-beta-field-windows/README.md`
  round two). With no deed in the dev config dir the capture holds one
  `layout-lite` and one `no-ta-deed` Warning, both 1.0 s after boot, and
  none after. With `SCADA_PATHS__TADEED` pointed at the test deed it holds
  one `layout-lite` and one `ta-deed`, and no warning.
- The next beta field window: spruce sends its deed, beech sends the
  warning.

## Do this next

The field witness, from the laptop in `experiments/`. The scada change is
`dfc35644` on `jm/spruce-unlimbo`. An Opus subagent runs the windows and
returns a verdict; the session that spawns it says go and reads the
verdict.

1. Push `jm/spruce-unlimbo` and the experiments repo, then pull both on
   spruce and on beech: `~/gridworks-scada-unlimbo` to the pushed scada
   head, `~/experiments` to its pushed head. `on` refuses until the box's
   checkout and window pair match the laptop's.
2. Spruce: `./spruce_window.sh status`, then `./spruce_window.sh on 3
   --debug`. In the heating season the winter hack is the plant
   controller, so the window is bounded and no longer than 3 minutes.
   When it ends, `status` shows `spruce-winter-hack`, `gwspaceheat` and
   the restart timer running again; a window that leaves any of them
   down is the first thing reported.
3. Beech: `./beech_window.sh on 3 --debug`, then `status` the same way.
4. Read each capture (`../scratch/broker-capture-*.jsonl`) for routing
   keys ending `ltn.layout-lite`, `ltn.ta-deed` and glitches with Summary
   `no-ta-deed`. Spruce holds a deed and beech holds none, so the claim is
   one `layout-lite` and one `ta-deed` from spruce, one `layout-lite` and
   one `no-ta-deed` Warning from beech, each once per run. The spruce
   `--debug` window is also the witness for `pico-identity-matches`
   (`7e8c53e2`): one Debug glitch per pico whose post matches the layout.
5. Record the round in
   `experiments/2026-09-18-beta-field-windows/README.md` and mark the
   field line under Witness here.
6. Then distill into `executor/scada-ltn-link-state.md`: the startup
   announcements beside "The trading gate".

## Open

- `ta.deed/000` and `ta.validation.state/000` are `staging`. Whether the
  deed joins the `finalize-layout-lite-13.md` promote before a house sends
  it on the production broker.
- A `scada.startup.report` word (run start time, send time, commit) is a
  later startup announcement, one more send in
  `send_startup_announcements`; it is post-launch work under OPS-532.
- A beech deed is a validator's act and is not part of this spoke.
