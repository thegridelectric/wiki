# Admin today: the link, the conversation, the tree

Status: Draft · Pass 0 · Updated 2026-09-05

> What this is: how the `gwa` admin client and a scada actually talk
> today, on the local MQTT path. The hub (`primary.md`) holds the
> trust model and the migration off this path; this spoke holds the
> running mechanism, so that work on the command tree (admin
> dispatching hp-boss and the pico cycler) starts from what is. Code
> pins are into `gridworks-scada/gw_spaceheat/actors/scada.py` unless
> named otherwise.

## The two ends of the link

**Scada side.** The scada holds a third MQTT link named `admin`
(`Scada.ADMIN_MQTT`, `scada.py:84`), off by default and enabled by the
`SCADA_ADMIN__*` settings (`actors/config.py:110`, `AdminLinkSettings`:
`enabled`, host, port, username, `password`, TLS, and
`max_timeout_seconds`, default one day). Every message received on that
link has its `Src` rewritten to the `admin` node before dispatch
(`process_mqtt_message`, `scada.py:1515`); a message on the link while
`enabled` is false is dropped. Replies to the admin node publish on the
same link at QOS 0 (`_send_to`, `scada.py:1449`).

**Client side.** `gwadmin` (`packages/gridworks-admin`) opens one paho
connection per selected scada with the credentials in its
`admin-config.json` (`gwa add-scada`), subscribes to the single topic
`<scada alias>` to `admin`, all message types, and publishes every
command as a `Message` with `Src admin` and `Dst <scada alias>`
(`watch/clients/admin_client.py`). The node name `admin` is shared
vocabulary on both ends.

## The conversation

1. **Link-up.** When the client's connection goes active it publishes
   `SendControlCapabilities`; on receiving `scada.control.capabilities`
   it publishes `SendSnap`. A background task re-requests whichever is
   still missing every 60 s. The scada answers each request with
   `control_capabilities` (`scada.py:1647`) and a fresh snapshot
   (`scada.py:363-378`). `SendLayout` is also answered (`layout_lite`),
   but the client never asks for it.
2. **Steady state.** Every `single.reading` a relay or 0-10V actor
   reports is forwarded to the admin link when it is enabled
   (`_forward_single_reading`, `scada.py:1558`), and the periodic
   snapshot carries the same channels in `LatestReadingList`. The client
   keys a reading to a row by channel name, then to the node by the
   channel's `AboutNodeName`; `CapturedByNodeName` is never read.
3. **Commands.** Four types, all handled in `process_scada_message` and
   all ignored from any `Src` other than the admin node:
   - `AdminDispatch` (`scada.py:448`): wraps an `FsmEvent` with
     `FromHandle admin`, `ToHandle admin.<node name>`, and the relay's
     event type and name from its config. The scada takes the last
     handle segment as the target name and calls that communicator's
     `process_message` directly.
   - `AdminAnalogDispatch` (`scada.py:497`): wraps an `AnalogDispatch`
     with `ToHandle admin.<node name>` and `Value` volts times ten,
     0-100. The scada rebuilds the dispatch from the node's CURRENT
     handle (`process_analog_dispatch`, `scada.py:578`), so the
     `FromHandle` the outputer sees is its boss at that moment.
   - `AdminKeepAlive` (`scada.py:531`): renews the timeout.
   - `AdminReleaseControl` (`scada.py:508`): Admin to Auto, cancels the
     timeout, wakes Auto.

   Every dispatch and keep-alive carries an optional `TimeoutSeconds`.

## TopState and the timeout

The first dispatch or keep-alive while TopState is Auto calls
`admin_wakes_up` (`scada.py:924`): TopState Auto to Admin, then the auto
state machine's `AutoGoesDormant` (`scada.py:1003`). Each command renews
one asyncio task (`_renew_admin_timeout`, `scada.py:1551`) that sleeps
for the requested seconds, capped at `max_timeout_seconds` (a missing
value means the cap), then calls `admin_times_out` (`scada.py:937`):
Admin to Auto, wake Auto. Release does the same without waiting. The
client's default request is five minutes (`gwadmin/config.py`,
`DEFAULT_ADMIN_TIMEOUT`); its keep-alive button sends the entered
minutes, or no value for the scada's cap.

## The tree under admin

`AutoGoesDormant` calls `set_command_tree(admin)` (`scada.py:1213`) and
sends `GoDormant` to LeafAlly, LocalControl and the pico cycler. Under
the admin boss EVERY actuator's handle becomes `admin.<name>`,
including the vdc relay, which under every other boss stays at
`auto.pico-cycler.vdc-relay`; on a sieg-loop House0 layout hp-boss and
sieg-loop keep their subtrees (`admin.hp-boss.hp-scada-ops-relay`,
`admin.sieg-loop.<relay>`). The rewritten tree goes to the LTN as
`new.command.tree`. On release or timeout `AutoWakesUp` rebuilds the
LocalControl tree and wakes LocalControl and the pico cycler.

## The relays admin does not address directly

- **hp-scada-ops-relay.** Owned by hp-boss under every root. The panel's
  hp-boss row sends `TurnHpOnOff` events to `admin.hp-boss`, and hp-boss
  commands the relay at `admin.hp-boss.hp-scada-ops-relay`.
- **vdc-relay.** Owned by the pico-cycler under five-v-boss. The panel's
  five-v-boss row sends `RebootPicos`, forwarded to the cycler, and the
  5 V hold, which five-v-boss runs on the relay itself.
- **secondary-pump-relay** is the one owned relay admin takes: its row
  offers the relay pair, and the first event moves it from under hp-boss
  to `admin.secondary-pump-relay` for the session, with hp-boss `HpOff`
  as the gate. The hp-boss row's `TurnOn` hands it back before the heat
  pump starts; release and timeout return it too (scada executor
  `control-hierarchy.md` "Fixed sub-trees vs floating actuators").

## Tests

- `tests/test_misc/test_admin.py`: the CLI and config surface; the two
  end-to-end relay and DAC tests are commented out until the
  capabilities word describes a Nolan layout (see the hub's
  capabilities contract).
- `tests/actors/test_admin_on_nolan.py`: an `AdminAnalogDispatch` in
  the client's wire shape against a live Nolan scada reaches the
  `ZeroTenOutputer` under the admin tree; the capabilities projection
  on Nolan is a strict xfail on the same blocker.
