# prod-4x-upgrade

Status: Draft · Pass 0 · Updated 2026-07-17 · Linear: OPS-424

**EDD: no** build-out/upgrade; verified by the broker-contract harness
(`rmqbot/rmq-docker/tests/check-broker-contract.py`, 6/6) against the green
box before the flip, plus per-consumer message-flow confirmation after it —
not a standalone experiment.

> Upgrade the prod broker `hw1__1` from RabbitMQ 3.9.13 (EOL) to 4.x by
> standing up a fresh box ("green") next to the running one ("blue"),
> proving it, and cutting the fleet over with an elastic-IP flip.

## Why

3.9.13 is at/near community EOL. Don't anchor new security-critical
auth work (mTLS, FIS) on an unsupported line. The dev-broker
upgrade-and-validate path de-risks the prod jump.

This is `gridworks-base open #6` (resolved as deferred).

## The sequence

1. **Dev first.** Stand up the new dev broker on RabbitMQ 4.x,
   GHCR-published image, new generated definitions. Validate a first
   gwbase actor end-to-end. *(The 2026-05-26 integration test — gwwf→gjk
   on `gw-dev-rabbit` — was an instance of this. 22 weather messages
   flowed cleanly. Validated.)* Dev's image base is
   `rabbitmq:4.1-management` (`gridworks-base/rabbit/Dockerfile`); prod
   pins the same line, exact patch tag chosen at execution.
2. **Then prod**, blue/green — the rest of this design.

## Blue/green, not in-place

The prod container has no data volume (`compose.yaml`: Mnesia lives in the
writable layer), so a broker "upgrade" is really a fresh boot from the
definitions file, the conf, and `.env` — there is no schema migration and
RabbitMQ's in-place upgrade-path constraints do not apply. Blue/green turns
that fact into a rehearsal: the whole stack is proven on the green box
while blue serves the fleet untouched, and the cutover is one atomic
elastic-IP re-association. Rollback is the same flip in reverse — blue
keeps running, intact, until decommission.

The same recreate-loads-everything fact is why the generated topology
(OPS-425) lands in the same flip: green boots from the generated
definitions, so the 4.x jump and the topology cutover are one event.

## The green box (settled)

- **Instance:** `m8g.medium` (~$33/mo) — the same 1 vCPU / 4 GiB shape as
  today's `m6g.medium`, current Graviton generation. Not burstable: the
  broker's CPU spike is the reconnect storm after an outage, when every
  client re-handshakes TLS at once — exactly when a t4g would be out of
  credits. Not bigger: the fleet's load is a rounding error on this shape,
  and a resize behind the elastic IP is a brief stop/start if the
  management UI ever shows pressure.
- **OS:** stock Ubuntu 26.04 LTS arm64 (Canonical AMI, latest at launch).
  Deliberately not the old custom "rmqbot 1" AMI — the box is rebuildable
  from stock image + git + 1Password, nothing baked.
- **Security group:** the existing `RabbitMQ` group
  (`sg-04ef3680050118418`) — reused, zero port-rule drift.
- **ssh:** a NEW dedicated key pair for this box (private key in
  1Password); per-person keys added after first boot. `gridworks-hybrid`
  never lands on the box — the broker leaves the one-key-opens-everything
  blast radius (OPS-448) on day one.
- **Name tag:** `hw1-1-green` during standup; tags swap at the flip (blue
  becomes `hw1-1-old-3913` until decommission — no nameless prod boxes).
- **On the box:** Docker, the `rmq-docker` checkout, certs + `.env` from
  1Password. The broker cert is the same one blue serves (it names
  `hw1-1.electricity.works`, which green becomes at the flip).

## Conf migration (3.9 → 4.x)

Dev's 4.1 conf (`gridworks-base/for_docker/dev_rabbitmq.conf`) already
demonstrates the target idioms:

- **Definitions load** moves from the compose-level
  `RABBITMQ_SERVER_ADDITIONAL_ERL_ARGS … load_definitions` (3.x mechanism)
  to `definitions.import_backend = local_filesystem` +
  `definitions.local.path` in the conf.
- **`mqtt.subscription_ttl = 86400000`** (ms) becomes
  **`mqtt.max_session_expiry_interval_seconds = 86400`** (s).
- **`mqtt.default_user` / `mqtt.default_pass`** (with
  `mqtt.allow_anonymous = false`) need their 4.x mapping checked against
  the 4.1 docs (dev uses the new `anonymous_login_user/pass` keys, but dev
  *wants* anonymous; prod wants every MQTT client authenticating). Wrong
  guesses surface on green, not on the fleet.

TLS, management-UI, and env-interpolated default-user settings carry over
unchanged from the OPS-423 conf.

## Live-consumer audit — done 2026-07-17

Run against the running broker (`rabbitmqctl list_bindings /
list_connections / list_mqtt_connections`), reconciled with the era table
in OPS-425:

- 6 house SCADAs + 6 LTNs ride `amq.topic` over MQTT with dynamic queues —
  unaffected by cutover, reconnect and recreate on green.
- ear, both journalkeepers: `ear_tx`, identical in both topology eras.
- Both web gateways: dynamic `gw.#` queues on `amq.topic`.
- The `amq.topic → ear_tx (#)` audit tap is in the generated definitions —
  the durable record survives.
- **Weather was the sole legacy-fabric consumer** (`ws_tx`) — resolved by
  retargeting, see OPS-425's cutover section.
- Runtime state to re-create on green (recipes in the rmq-docker README):
  `analytics.ear.reader`, the `debug.beech-scada` tap if still wanted.

## Cutover day

Pre-flight: green harness 6/6 (via a temporary `/etc/hosts` line on the
operator laptop pointing `hw1-1.electricity.works` at green's temp IP, so
TLS hostname verification runs exactly as prod clients run it — removed
after); runtime users re-created; weather retarget built and ready.

1. Re-associate the elastic IP (`eipalloc-0efccafe364dad685`) to green.
   Blue's established TCP connections break; every client's reconnect loop
   lands on green.
2. Watch green's log and management UI for the reconnect wave (AMQP
   services + 12 MQTT clients).
3. Confirm each consumer flowing: SCADA telemetry through the LTNs,
   ear→S3, both journalkeepers, weather (now on `weather_tx`), gateway
   realtime.
4. Restart the weather service against green with the retarget deployed.
5. Swap EC2 Name tags; remove the `/etc/hosts` pin.

Rollback at any point: flip the EIP back to blue and (if weather was
already retargeted) restart weather on the old build — blue is exactly as
it was.

## After the soak

- Terminate blue.
- Deregister the "rmqbot 1" AMI (`ami-007a1ef549064130f`) + its backing
  snapshot. No replacement AMI: the rebuild story is stock image + git +
  1Password, documented in the rmq-docker README.
- Refresh the `WorldRabbit` launch template (currently an even older AMI +
  `gridworks-main` key): 26.04 AMI, `m8g.medium`, `RabbitMQ` SG, the new
  key — a convenience shell over the documented recipe.
- The stopped "new rmqbot" instance (`i-06ef71e1ace8b7eaf`, launched from
  the old AMI) is presumed an abandoned earlier attempt — confirm its
  story, then terminate with this cleanup.

## Open — settle at execution

- Exact `rabbitmq:4.1.x-management` patch tag.
- The 4.x conf mapping for no-anonymous MQTT (verified on green).
- Restart-day timing + fleet notice — same fleet-facing event class as the
  prod-tls-fix restart.

## Sequencing & dependencies

Tracked in Linear (this design's issue), not here — they are cross-design
relationships.
