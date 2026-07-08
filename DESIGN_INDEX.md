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
- **grid-node-registry** — [`designs/stand-up-grid-node-registry.md`](grid-node-registry/designs/stand-up-grid-node-registry.md) (stand up the GNode registry FIS consults: dev Postgres + alembic schema → invariants → lifecycle → FastAPI query API → deploy; 2026-summer; Linear OPS-419)
- **gridworks-admin** — [`designs/stand-up-web-admin.md`](gridworks-admin/designs/stand-up-web-admin.md) (stand up web admin: prod-broker mTLS+FIS migration + web gateway; a web login alone is not enough to drive relays — WebAuthn/passkey + step-up; depends on mtls-fis-auth; Linear OPS-429)
- **gridworks-base** — [`designs/decouple-amq-topic.md`](gridworks-base/designs/decouple-amq-topic.md)
- **gridworks-base** — [`designs/log-sema-round-trip.md`](gridworks-base/designs/log-sema-round-trip.md)
- **gridworks-base** — [`designs/mock-transport-for-tests.md`](gridworks-base/designs/mock-transport-for-tests.md)
- **gridworks-base** — [`designs/neutral-message-metadata.md`](gridworks-base/designs/neutral-message-metadata.md)
- **gridworks-base** — [`designs/publish-backpressure.md`](gridworks-base/designs/publish-backpressure.md) (bound the marshaled-send queue; backlog follow-up to OPS-383; Linear OPS-384)
- **gridworks-data** — [`designs/dev-branch-and-pr-gate.md`](gridworks-data/designs/dev-branch-and-pr-gate.md)
- **gridworks-data** — [`designs/gw-data-analytics-deployment.md`](gridworks-data/designs/gw-data-analytics-deployment.md)
- **gridworks-fleet-index-service** — [`designs/stand-up-fis.md`](gridworks-fleet-index-service/designs/stand-up-fis.md) (build + deploy the FIS auth service: FastAPI `/auth/*` + single-writer instance lease; reads grid-node-registry; 2026-summer; Linear OPS-422)
- **gridworks-homeassistant** — [`designs/btu-meter-integration.md`](gridworks-homeassistant/designs/btu-meter-integration.md) (BTU meter → HA via HACS integration; Linear OPS-47)
- **gridworks-journalkeeper** — [`designs/integrate-gwbase-sema-updates/primary.md`](gridworks-journalkeeper/designs/integrate-gwbase-sema-updates/primary.md) (integrate gwbase 0.5.x + sema updates into JK; hub; folds ex-upgrade-gjk-sema-snapshot; Linear OPS-386)
- **gridworks-journalkeeper** — [`designs/layered-test-harness.md`](gridworks-journalkeeper/designs/layered-test-harness.md)
- **gridworks-journalkeeper** — [`designs/s3-importer-improvements.md`](gridworks-journalkeeper/designs/s3-importer-improvements.md)
- **gridworks-ltn** — [`designs/stand-up-ltn-on-gwbase.md`](gridworks-ltn/designs/stand-up-ltn-on-gwbase.md) (stand up the LTN as a gwbase-native cloud service, extracted from gridworks-scada — dispatch contract + LTN↔fleet protocol + FLO-as-dependency; big refactor; 2026-summer; Linear OPS-435)
- **gridworks-marketmaker** — [`designs/broadcast-latest-price.md`](gridworks-marketmaker/designs/broadcast-latest-price.md) (maker broadcasts latest.price for persistence + retire deprecated EnergyInstruction; bite-size; Linear OPS-289)
- **gridworks-marketmaker** — [`designs/launch-new-simple-marketmaker/primary.md`](gridworks-marketmaker/designs/launch-new-simple-marketmaker/primary.md) (launch a new simple MarketMaker; hub + `evaluate-existing-repo` spoke; 2026-summer; Linear OPS-431)
- **gridworks-pico** — [`designs/pico-overhaul.md`](gridworks-pico/designs/pico-overhaul.md) (the consolidating pico design, before Sept 2026: PicoW/wifi + reject Wiznet, littlefs-corruption-driven flash-write discipline, self-heal reconnect, common net.py, keep-now/remove-at-scale code download, provisioning cleanup; Linear OPS-402)
- **gridworks-price-forecast** — [`designs/stand-up-price-forecast.md`](gridworks-price-forecast/designs/stand-up-price-forecast.md) (stub — stand up the price / LMP-forecast service as a gwbase-native cloud GNode; TODO build with Jessica; 2026-summer; Linear OPS-437)
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
- **gridworks-weather-forecast** — [`designs/stand-up-weather-forecast.md`](gridworks-weather-forecast/designs/stand-up-weather-forecast.md) (stub — stand up the weather-forecast service as a gwbase-native cloud GNode; TODO build with Jessica; 2026-summer; Linear OPS-436)
- **observability** — [`designs/consolidate-from-infra-scada-jk.md`](observability/designs/consolidate-from-infra-scada-jk.md)
- **rmqbot** — [`designs/analytics-broker-shovel.md`](rmqbot/designs/analytics-broker-shovel.md)
- **rmqbot** — [`designs/broker-topology-canonical-in-gwbase.md`](rmqbot/designs/broker-topology-canonical-in-gwbase.md) (vhosts/exchanges/queues/bindings declared as code in gwbase → generated definitions; retires hand-edited rabbit_definitions.json; absorbs the topology half of the retired identities-in-definitions)
- **rmqbot** — [`designs/prod-4x-upgrade.md`](rmqbot/designs/prod-4x-upgrade.md)
- **rmqbot** — [`designs/prod-tls-fix.md`](rmqbot/designs/prod-tls-fix.md)
- **sema** — [`designs/example-runtime-validation.md`](sema/designs/example-runtime-validation.md) (the main sema suite must decode every type's examples through the generated runtime, not just structurally — catches examples that go stale when a referenced type is reshaped in place; stash the stale layout example it surfaces; Accepted, OPS-442)
- **sema** — [`designs/spaceheat-naming-vocabulary.md`](sema/designs/spaceheat-naming-vocabulary.md) (encode the node/channel naming vocabulary in sema — closed name sets as additive enums, zone/tank/flow derivation patterns as a naming word, relay event/state vocabularies as enum words; deletes the tlayouts names mirror and pre-empts a third copy in gridworks-terminalasset; Draft, OPS-444)
- **sema** — [`designs/staging-word-status.md`](sema/designs/staging-word-status.md) (add the `staging` word status — status required on every registry entry, staging = mutable + dev-brokers-only, published = immutable + hash-pinned; initial partition derived from broker-crossing wire words + $ref closure; snapshot builder defaults published-only with `--allow-staged`; Draft, OPS-445)
- **sema** — [`designs/practice-erb-pair-programming.md`](sema/designs/practice-erb-pair-programming.md)
- **sema** — [`designs/web-app-words-to-types.md`](sema/designs/web-app-words-to-types.md)
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
- **gridworks-fleet-index-service** — [`explorations/principal-model.md`](gridworks-fleet-index-service/explorations/principal-model.md)
- **gridworks-journalkeeper** — [`explorations/scale-strategy-starter.md`](gridworks-journalkeeper/explorations/scale-strategy-starter.md)
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
- **sema** — [`explorations/two-claudes.md`](sema/explorations/two-claudes.md)
