# GridWorks designs + explorations index


> Flat directory of every file under any `designs/` or `explorations/`
> folder across the wiki. Maturity / workflow state are NOT encoded
> here — each file's own `Status:` line carries maturity; Linear
> carries workflow (status / owner / priority). For the lifecycle
> convention, see [`designs-process.md`](designs-process.md). For
> "what lives where" across designs / explorations / executor / Linear,
> see [`glossary.md`](glossary.md) "Where content lives".

## Designs

_(every file under a `designs/` folder, anywhere in the wiki)_

- (cross-cutting) [`designs/substrate-fit.md`](designs/substrate-fit.md) (parked brainstorm: blockchain/substrate fit for crypto / validation / market-running layers; focus AFTER the launch; Linear OPS-391)
- (cross-cutting) [`designs/mtls-fis-auth.md`](designs/mtls-fis-auth.md) (password → cert-based mutual TLS with FIS as the auth authority; spans rmqbot + FIS + provisioning; 2026-summer; Linear OPS-420)
- (cross-cutting) [`designs/proactor-makeover.md`](designs/proactor-makeover.md) (replace the gridworks-proactor link mechanism + gwproto types with a gwbase/Sema-native scada transport — AllyLink + the `gw` envelope + standard Sema codegen; retires the proactor and gwproto packages; Linear OPS-428)
- (cross-cutting) [`designs/ltn-brokered-app-comms.md`](designs/ltn-brokered-app-comms.md) (web→LTN→SCADA application comms — mode/params/preferences brokered through the LTN, in Auto, SLA-preserving; the admin/direct-relay half is separate (stand-up-web-admin, OPS-429, mtls-dependent); Linear OPS-408)
- (cross-cutting) [`designs/ec2-security-group-cleanup.md`](designs/ec2-security-group-cleanup.md) (remediate AWS security groups + launch templates — internet-open Postgres ×5, the ssh-inbound kitchen-sink SG, the broker's non-TLS surface, orphans; tiered, may impact running services; Linear OPS-447)
- (cross-cutting) [`designs/registry-projection-and-ear-capture.md`](designs/registry-projection-and-ear-capture.md) (the two audit taps catch up with the registry surface: gjk projects g.node.forest into gw_data + a durable ear raw-capture consumer; the seam is the decision; Linear OPS-443)
- (cross-cutting) [`designs/harmonize-units.md`](designs/harmonize-units.md) (retire TelemetryName → gw1.unit + gw1.quantity, affine `{quantity, scale, offset}` metadata on unit values → generated convert/display, ConfigList revamp rides the same cascade; Linear OPS-489)
- (cross-cutting) [`designs/position-point-lifecycle.md`](designs/position-point-lifecycle.md) (position-point presence becomes an activation invariant; gnr position_points → encrypted shape + real FK, gw_data drops its projection table; one g.node.gt/006 referrer sweep, forest/002 also makes SendTimeMs required; Draft, OPS-488)
- (cross-cutting) [`designs/message-identity.md`](designs/message-identity.md) (every scada-originated message journals exactly once across live + S3 paths: gwproto Header.MessageId always set + a gw_data message_ids identity table; after the OPS-498 load; Draft, OPS-502)
- **cross-cutting** — [`designs/rehome-alerting.md`](designs/rehome-alerting.md) (gwalert + alert-manager off the legacy journaldb EC2 box onto Hetzner `alerts` (cx23, Helsinki), reading `tsdb` as gw_analyst, both under systemd; alert-manager into the org; unblocks retiring journaldb/journalmaker; owner Thomas; Draft, OPS-506)
- **gridworks-journalkeeper** — [`designs/eventstore-version-reconstruction.md`](gridworks-journalkeeper/designs/eventstore-version-reconstruction.md) (author the pre-sema message versions the S3 eventstore carries — wire evidence is truth — so JK can load the archive back to Sept 2024; per-version loop + timestamp-backdating ledger; layout.lite:006 done, v005←v003 next; Draft, OPS-498)
- **grid-node-registry** — [`designs/rebuild-from-persistent-store.md`](grid-node-registry/designs/rebuild-from-persistent-store.md) (gnr rebuild consumes the ear's S3 eventstore — the true persistent store — replacing the proven-but-provisional JSONL feed; gated on the store's durable backup (OPS-443 strand 2) + TaValidator activation making positions rebuildable; the JSONL rebuild stays off dev until this lands; Draft, OPS-457)
- **gridworks-admin** — [`designs/stand-up-web-admin.md`](gridworks-admin/designs/stand-up-web-admin.md) (stand up web admin: prod-broker mTLS+FIS migration + web gateway; a web login alone is not enough to drive relays — WebAuthn/passkey + step-up; depends on mtls-fis-auth; Linear OPS-429)
- **gridworks-base** — [`designs/decouple-amq-topic.md`](gridworks-base/designs/decouple-amq-topic.md)
- **gridworks-base** — [`designs/log-sema-round-trip.md`](gridworks-base/designs/log-sema-round-trip.md)
- **gridworks-base** — [`designs/mock-transport-for-tests.md`](gridworks-base/designs/mock-transport-for-tests.md)
- **gridworks-base** — [`designs/neutral-message-metadata.md`](gridworks-base/designs/neutral-message-metadata.md)
- **gridworks-base** — [`designs/publish-backpressure.md`](gridworks-base/designs/publish-backpressure.md) (bound the marshaled-send queue; backlog follow-up to OPS-383; Linear OPS-384)
- **gridworks-fleet-index-service** — [`designs/stand-up-fis.md`](gridworks-fleet-index-service/designs/stand-up-fis.md) (build + deploy the FIS auth service: FastAPI `/auth/*` + single-writer instance lease; reads grid-node-registry; 2026-summer; Linear OPS-422)
- **gridworks-homeassistant** — [`designs/btu-meter-integration.md`](gridworks-homeassistant/designs/btu-meter-integration.md) (BTU meter → HA via HACS integration; Linear OPS-47)
- **gridworks-data** — [`designs/disentangle-installations.md`](gridworks-data/designs/disentangle-installations.md) (split installations' four data kinds — registry-owned identity, sema-owned layout/params, PII to a new remote customer db by opaque id, auth to web-backend; retire the JSONB copies; Draft, OPS-473)
- **gridworks-data** — [`designs/g-node-alias-scoping/`](gridworks-data/designs/g-node-alias-scoping/primary.md) (JK weather data-shape: reading_channels scoping — terminal_asset_alias misnomer → About/MadeBy split following the pseudo-channel word — plus the one-time legacy weather fill with the wire sample; coordinated reader sweep across web-backend/gjk/experiments; rides the JK table-shape conversation; Draft, OPS-494)
- **gridworks-data** — [`designs/retention-and-refill.md`](gridworks-data/designs/retention-and-refill.md) (gw_data as a rolling window over the S3 eventstore: snapshots to their own 2h-retention hypertable, compression + ~180d retention on messages with JK refill, a write-ceiling ramp experiment; Draft, OPS-503)
- **gridworks-data** — [`designs/journaldb-health.md`](gridworks-data/designs/journaldb-health.md) (health checks + server-side guards for the journal DB: idle/statement timeouts as migrations, a read-only checker run by a gjk timer and a laptop SessionStart hook, backup restore test, console access; Draft, OPS-504)
- **gridworks-journalkeeper** — [`designs/integrate-gwbase-sema-updates/primary.md`](gridworks-journalkeeper/designs/integrate-gwbase-sema-updates/primary.md) (integrate gwbase 0.5.x + sema updates into JK; hub; folds ex-upgrade-gjk-sema-snapshot; Linear OPS-386)
- **gridworks-journalkeeper** — [`designs/layered-test-harness.md`](gridworks-journalkeeper/designs/layered-test-harness.md)
- **gridworks-journalkeeper** — [`designs/s3-importer-improvements.md`](gridworks-journalkeeper/designs/s3-importer-improvements.md)
- **gridworks-ltn** — [`designs/five-minute-flos.md`](gridworks-ltn/designs/five-minute-flos.md) (move the LTN's FLO from hourly to every 5 minutes; weather + price forecast freshness ride along — the first consumer of non-uniform forecast time slices; EDD; Draft, OPS-491)
- **gridworks-ltn** — [`designs/stand-up-ltn-on-gwbase.md`](gridworks-ltn/designs/stand-up-ltn-on-gwbase.md) (stand up the LTN as a gwbase-native cloud service, extracted from gridworks-scada — dispatch contract + LTN↔fleet protocol + FLO-as-dependency; big refactor; 2026-summer; Linear OPS-435)
- **gridworks-marketmaker** — [`designs/broadcast-latest-price.md`](gridworks-marketmaker/designs/broadcast-latest-price.md) (maker broadcasts latest.price for persistence + retire deprecated EnergyInstruction; bite-size; Linear OPS-289)
- **gridworks-marketmaker** — [`designs/launch-new-simple-marketmaker/primary.md`](gridworks-marketmaker/designs/launch-new-simple-marketmaker/primary.md) (launch a new simple MarketMaker; hub + `evaluate-existing-repo` spoke; 2026-summer; Linear OPS-431)
- **gridworks-marketmaker** — [`designs/umpire-service.md`](gridworks-marketmaker/designs/umpire-service.md) (neutral gwbase service holding the record of authority for contract state — bids/acks, slow contract heartbeat, ally liveness; gw_data is a projection, not an authority; Draft, OPS-501)
- **gridworks-pico** — [`designs/pico-overhaul.md`](gridworks-pico/designs/pico-overhaul.md) (the consolidating pico design, before Sept 2026: PicoW/wifi + reject Wiznet, littlefs-corruption-driven flash-write discipline, self-heal reconnect, common net.py, keep-now/remove-at-scale code download, provisioning cleanup; Linear OPS-402)
- **gridworks-price-forecast** — [`designs/stand-up-price-forecast/`](gridworks-price-forecast/designs/stand-up-price-forecast/primary.md) (scaffolded 2026-08-13 from the weather standup — deployment posture/create-cmd/GNode-registration/JK-capture pattern port directly; vocabulary, FIS auth posture, and source are open; TODO build with Jessica; Linear OPS-437)
- **gridworks-scada** — [`designs/capability-protocol-and-verify.md`](gridworks-scada/designs/capability-protocol-and-verify.md) (ShNodeActor capability surface as the protocol between states and layouts; loud refusals + closed-loop verify; from the maple post-mortem; Linear OPS-394)
- **gridworks-scada** — [`designs/circulator-pump-0-10v-models.md`](gridworks-scada/designs/circulator-pump-0-10v-models.md) (pump make/model + 0–10 V response representation; Linear OPS-27)
- **gridworks-scada** — [`designs/code-update.md`](gridworks-scada/designs/code-update.md) (fleet code update: pull handshake + supervisor A/B flip + store epoch gate; NO BACK DOOR at scale; picos/OS out by posture; fully ratified, queued; Linear OPS-401)
- **gridworks-scada** — [`designs/harden-dfr-i2c-recovery.md`](gridworks-scada/designs/harden-dfr-i2c-recovery.md) (harden the dfr i2c path against a wedged bus; recovery in the post-unlimbo I2cBus; gated by spruce-unlimbo; Linear OPS-59)
- **gridworks-scada** — [`designs/harden-mqtt-half-open.md`](gridworks-scada/designs/harden-mqtt-half-open.md) (bite-size EDD: cap the 1024 s outer reconnect backoff + wire the dead keepalive in gwproactor's MQTT client so a half-open blackhole recovers in <90 s not ~15 min; interim ahead of proactor-makeover; Linear OPS-304)
- **gridworks-scada** — [`designs/hardware-layout-pass-one/primary.md`](gridworks-scada/designs/hardware-layout-pass-one/primary.md) (first critical pass on the hardware-layout/components model: sema is the authored source of truth, dc generated via `sema_to_dc`; drop UUID cac_ids → `gw1.device.type` enum + `DeviceType`, complete house0+nolan axioms, regenerate fleet layouts from sema; hub-and-spoke; shared dependency of simulated-test-environment + spruce-unlimbo Chunk B; Linear OPS-407)
- **gridworks-scada** — [`designs/non-electric-backup-doctor.md`](gridworks-scada/designs/non-electric-backup-doctor.md) (BoilerDoctor probe + don't-strand-the-house failsafe; folds OPS-258; Linear OPS-215)
- **gridworks-scada** — [`designs/poison-messages.md`](gridworks-scada/designs/poison-messages.md) (dead-letter the reupload loop; report via glitch, not ack-required — if it flaps, skip the acks; ack-timeout loosening rides along; Linear OPS-432)
- **gridworks-scada** — [`designs/report-event-v004.md`](gridworks-scada/designs/report-event-v004.md) (re-enforce report.event identity/time axioms via the scada emitter — propagate Report.Id/MessageCreatedMs into the event wrapper + bump to v004; bite-size; Linear OPS-329)
- **gridworks-scada** — [`designs/scada-health-diagnostics.md`](gridworks-scada/designs/scada-health-diagnostics.md) (make a scada-down fast to detect + observe — emit live ally.inactive/ally.active AND persist the liveness signal set for a JK referee; folds ally-inactive OPS-410; ex-OPS-386 #3; Linear OPS-317)
- **gridworks-scada** — [`designs/scada-owned-admin-hold.md`](gridworks-scada/designs/scada-owned-admin-hold.md) (scada-owned admin hold that survives the panel dropping + reports remaining time; Linear OPS-194)
- **gridworks-scada** — [`designs/sieg-semantic-harmonization.md`](gridworks-scada/designs/sieg-semantic-harmonization.md) (sieg valve defaults OPEN in summer/Standby, reversing heating-season HP-off-closed; valve posture semantics + telemetry; Linear OPS-400)
- **gridworks-scada** — [`designs/sieg-valve-exercise.md`](gridworks-scada/designs/sieg-valve-exercise.md) (stub: scheduled valve motion over summer against seizure; actors/procedural family; Linear OPS-396)
- **gridworks-scada** — [`designs/simulated-test-environment/primary.md`](gridworks-scada/designs/simulated-test-environment/primary.md) (hub: simulated terminal assets + drivers over dev Rabbit — harness elevated to top, comms-first; spokes simulated-actors.md, experimentation-tools.md, sim-sensor-words.md, sim-time.md; Linear OPS-40)
- **gridworks-scada** — [`designs/spruce-unlimbo/primary.md`](gridworks-scada/designs/spruce-unlimbo/primary.md) (seed: un-limbo spruce scada integration — i2c relays, layout pipeline, branch merge, Nolan control, July-15 AC path)
- **observability** — [`designs/consolidate-from-infra-scada-jk.md`](observability/designs/consolidate-from-infra-scada-jk.md)
- **rmqbot** — [`designs/analytics-broker-shovel.md`](rmqbot/designs/analytics-broker-shovel.md)
- **sema** — [`designs/sender-time.md`](sema/designs/sender-time.md) (one standard name for the sender's clock — optional `SendTimeMs`, simulated or real; applied as words naturally version; first adopter g.node.forest/001, gnr stamping wall-clock; Draft, OPS-472)
- **sema** — [`designs/spaceheat-naming-vocabulary.md`](sema/designs/spaceheat-naming-vocabulary.md) (encode the node/channel naming vocabulary in sema — closed name sets as additive enums, zone/tank/flow derivation patterns as a naming word, relay event/state vocabularies as enum words; deletes the tlayouts names mirror and pre-empts a third copy in gridworks-terminalasset; Draft, OPS-444)
- **sema** — [`designs/practice-erb-pair-programming.md`](sema/designs/practice-erb-pair-programming.md)
- **terminalasset-registry** — [`designs/stand-up-terminalasset-registry.md`](terminalasset-registry/designs/stand-up-terminalasset-registry.md) (stand up the Sema-correct seed DB + independent repo holding each terminal asset's hardware layout + operational-params — the durable source of truth provisioning/LTN/web/analytics consume; layout/params sibling of GNR, without the blockchain requirement; Draft, no Linear yet)

## Explorations

_(every file under an `explorations/` folder, anywhere in the wiki)_

- (cross-cutting) [`explorations/aris-collaboration.md`](explorations/aris-collaboration.md)
- (cross-cutting) [`explorations/fleet-planes-pets-to-livestock.md`](explorations/fleet-planes-pets-to-livestock.md) (pets→livestock: Authority/Control/Observability plane separation; rehomed from gridworks-infra 2026-06-10)
- (cross-cutting) [`explorations/home-assistant-ltn.md`](explorations/home-assistant-ltn.md)
- (cross-cutting) [`explorations/primary.md`](explorations/primary.md)
- **gridworks-admin** — [`explorations/admin-gateway-service.md`](gridworks-admin/explorations/admin-gateway-service.md)
- **gridworks-admin** — [`explorations/when-to-add-grpc.md`](gridworks-admin/explorations/when-to-add-grpc.md)
- **gridworks-base** — [`explorations/logging-for-observability.md`](gridworks-base/explorations/logging-for-observability.md)
- **grid-node-registry** — [`explorations/content-address-and-deterministic-ids.md`](grid-node-registry/explorations/content-address-and-deterministic-ids.md) (why the command content-address stays gnr-internal, not a Sema format)
- **grid-node-registry** — [`explorations/create-words-and-validation-stubs.md`](grid-node-registry/explorations/create-words-and-validation-stubs.md) (how GNodes enter the registry: legacy g-node-factory ceremony review, the registrar-word split, guard-rail stubs, TaOwner sovereignty)
- **grid-node-registry** — [`explorations/position-point-semantics.md`](grid-node-registry/explorations/position-point-semantics.md) (why gnr enforces nothing about positions; location trust is TaValidation's)
- **grid-node-registry** — [`explorations/positions-staging-and-encryption.md`](grid-node-registry/explorations/positions-staging-and-encryption.md) (open API + private positions: opaque identity now, encrypted TaValidator-owned data later)
- **grid-node-registry** — [`explorations/root-keyed-forest-broadcasts.md`](grid-node-registry/explorations/root-keyed-forest-broadcasts.md) (radio_channel rule for forest broadcasts + why TimeCoordinators earn registry rows)
- **grid-node-registry** — [`explorations/scale-story.md`](grid-node-registry/explorations/scale-story.md) (what happens at a million homes — the copper tree is the sharding key)
- **gridworks-fleet-index-service** — [`explorations/g-node-instance-and-liveness.md`](gridworks-fleet-index-service/explorations/g-node-instance-and-liveness.md)
- **gridworks-fleet-index-service** — [`explorations/principal-model.md`](gridworks-fleet-index-service/explorations/principal-model.md)
- **gridworks-marketmaker** — [`explorations/bid-axioms-and-self-scaling.md`](gridworks-marketmaker/explorations/bid-axioms-and-self-scaling.md) (self-scaling bid axioms digest; feeds the MM launch design)
- **gridworks-marketmaker** — [`explorations/launch-intentions.md`](gridworks-marketmaker/explorations/launch-intentions.md)
- **gridworks-marketmaker** — [`explorations/market-product-and-uniform-bids.md`](gridworks-marketmaker/explorations/market-product-and-uniform-bids.md)
- **gridworks-provisioning** — [`explorations/principal-kinds-extension.md`](gridworks-provisioning/explorations/principal-kinds-extension.md)
- **gridworks-scada** — [`explorations/deeds-and-trading-rights.md`](gridworks-scada/explorations/deeds-and-trading-rights.md)
- **gridworks-scada** — [`explorations/layout-axiom-complexity.md`](gridworks-scada/explorations/layout-axiom-complexity.md)
- **gridworks-scada** — [`explorations/liveness-and-sla.md`](gridworks-scada/explorations/liveness-and-sla.md)
- **gridworks-scada** — [`explorations/metering.md`](gridworks-scada/explorations/metering.md) (how the transactive measurement is defined in a layout + how its veracity is established; cryptographic-veracity / distributed-trust)
- **gridworks-scada** — [`explorations/non-gnode-interfaces.md`](gridworks-scada/explorations/non-gnode-interfaces.md)
- **gridworks-scada** — [`explorations/sema-style.md`](gridworks-scada/explorations/sema-style.md)
- **rmqbot** — [`explorations/granular-permissions-and-web-admin.md`](rmqbot/explorations/granular-permissions-and-web-admin.md)
- **sema** — [`explorations/dashboard-vocabulary-modeling.md`](sema/explorations/dashboard-vocabulary-modeling.md)
- **sema** — [`explorations/rulebook-source-drift.md`](sema/explorations/rulebook-source-drift.md)
- **terminalasset-registry** — [`explorations/deeds-and-trading-rights.md`](terminalasset-registry/explorations/deeds-and-trading-rights.md) (TaDeed + TaTradingRights as validator-signed sema records — two-plane split from the connection cert, homeowner clawback, FIS/MarketMaker enforcement, deeds-attest-reality invariant; extends the gridworks-scada origin capture)
