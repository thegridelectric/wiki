# Startup announcements (spoke)

Status: Draft · Pass 0 · Updated 2026-09-19 · Linear: OPS-392

> What this is: what a scada says about itself once per run, and the one
> method that sends it when the broker link can first carry a publish. The
> first two announcements are the home's `ta.deed` and a warning when
> there is none.

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
- The callback interface (`gwproactor/callbacks.py`) offers only
  `recv_activated` and `recv_deactivated`. Nothing calls the prime actor
  when a link reaches `awaiting_peer`.
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
- `ta.deed/000` and its gwsproto twin exist. No sema change.

## Change

Pseudocode first: this is a comm path.

```python
# actors/scada.py

STARTUP_ANNOUNCE_GIVE_UP_S = 120   # a names constant, not a default
STARTUP_ANNOUNCE_POLL_S = 1

async def announce_at_first_broker_link(self) -> None:
    """Once per scada run: wait until the upstream link can carry a
    publish, then send the startup announcements. Gives up after
    STARTUP_ANNOUNCE_GIVE_UP_S; a scada that starts with its broker
    unreachable says nothing late, because a late announcement would read
    as a fresh start."""
    deadline = now + STARTUP_ANNOUNCE_GIVE_UP_S
    while now < deadline:
        if state_is_active_for_send(upstream link state):
            self.send_startup_announcements()
            return
        await sleep(STARTUP_ANNOUNCE_POLL_S)
    self.log("no broker link within ...; startup announcements not sent")

def send_startup_announcements(self) -> None:
    deed = self.services.ta_deed
    if deed is None:
        self.send_warning("no-ta-deed", details=<the path looked at; UnValidated>)
    else:
        self._send_to(self.ltn, deed)
```

- `ScadaAppInterface.ta_deed` returns the deed or `None`;
  `validation_state` derives from it, so the file is read in one place.
- `announce_at_first_broker_link` is one more task in `Scada.start_tasks`.
- Invariants: at most one send per scada run; nothing is sent before the
  link is send-capable; link flaps after the send cause no resend; the
  announcements need no ack and demand none.
- `layout.lite` stays on `recv_activated` in this step. Whether it moves
  here is Open below: an LTN that starts after the scada learns the layout
  only from the re-activation send or from its own `SendLayout`.

Polling the link state is chosen over a new proactor callback because it
touches one repo and the wait is short and bounded. A callback for
"send-capable" in `gwproactor` is the better shape if a second user
appears.

## Tests

Each shown red with the change reverted.

- `ta_deed` is `None` with no file and the deed with one;
  `validation_state` agrees on both (Nolan pair, with and without
  `gw.nolan.ta.deed.json`).
- `send_startup_announcements` with a deed sends exactly that deed and no
  warning; with none, one `no-ta-deed` Warning and no deed.
- `announce_at_first_broker_link` on the in-process rig: nothing is sent
  while the upstream link is below `awaiting_peer`; one send when it gets
  there; none on a later deactivate / activate; with the link held down
  past the give-up bound, nothing is sent and the log line appears (the
  bound patched short).

## Witness

EDD, in dev first: `./house_window.sh dev on 3 --debug` with no LTN. The
broker capture holds one `ta.deed` from the sim scada within seconds of
`fully.subscribed`, and none after. Rerun with the test deed moved aside:
one `no-ta-deed` Warning instead. Then the next beta field window: spruce
sends its deed, beech sends the warning.

## Do this next

1. Pass this spoke with the human (the two Open items first).
2. Build `ta_deed`, the two methods and the task, with the tests above, in
   a fresh session.
3. Run the dev witness and record it in
   `experiments/2026-09-18-beta-field-windows/`.

## Open

- Does `layout.lite` move into the startup announcements as well as its
  `recv_activated` send, so a window with no LTN still records the layout
  the scada booted on?
- The LTN drops a `ta.deed` today (`actors/ltn/ltn.py`
  `process_mqtt_message`, `case _`). What it does with one, and whether
  its codec decodes it, is unverified.
- A beech deed is a validator's act and is not part of this spoke.
