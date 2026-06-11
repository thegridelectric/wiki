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

- (cross-cutting) [`designs/linear-integration.md`](designs/linear-integration.md)
- (cross-cutting) [`designs/substrate-fit.md`](designs/substrate-fit.md) (parked brainstorm: blockchain/substrate fit for crypto / validation / market-running layers; focus AFTER the launch; Linear OPS-391)
- **gridworks-base** — [`designs/decouple-amq-topic.md`](gridworks-base/designs/decouple-amq-topic.md)
- **gridworks-base** — [`designs/log-sema-round-trip.md`](gridworks-base/designs/log-sema-round-trip.md)
- **gridworks-base** — [`designs/mock-transport-for-tests.md`](gridworks-base/designs/mock-transport-for-tests.md)
- **gridworks-base** — [`designs/neutral-message-metadata.md`](gridworks-base/designs/neutral-message-metadata.md)
- **gridworks-base** — [`designs/publish-backpressure.md`](gridworks-base/designs/publish-backpressure.md) (bound the marshaled-send queue; backlog follow-up to OPS-383; Linear OPS-384)
- **gridworks-data** — [`designs/dev-branch-and-pr-gate.md`](gridworks-data/designs/dev-branch-and-pr-gate.md)
- **gridworks-data** — [`designs/gw-data-analytics-deployment.md`](gridworks-data/designs/gw-data-analytics-deployment.md)
- **gridworks-homeassistant** — [`designs/btu-meter-integration.md`](gridworks-homeassistant/designs/btu-meter-integration.md) (BTU meter → HA via HACS integration; Linear OPS-47)
- **gridworks-journalkeeper** — [`designs/integrate-gwbase-sema-updates/primary.md`](gridworks-journalkeeper/designs/integrate-gwbase-sema-updates/primary.md) (integrate gwbase 0.5.x + sema updates into JK; hub; folds ex-upgrade-gjk-sema-snapshot; Linear OPS-386)
- **gridworks-journalkeeper** — [`designs/layered-test-harness.md`](gridworks-journalkeeper/designs/layered-test-harness.md)
- **gridworks-journalkeeper** — [`designs/s3-importer-improvements.md`](gridworks-journalkeeper/designs/s3-importer-improvements.md)
- **gridworks-marketmaker** — [`designs/launch-new-simple-marketmaker/primary.md`](gridworks-marketmaker/designs/launch-new-simple-marketmaker/primary.md) (launch a new simple MarketMaker; hub + `evaluate-existing-repo` spoke)
- **gridworks-pico** — [`designs/pico-overhaul.md`](gridworks-pico/designs/pico-overhaul.md) (placeholder: the one large pico overhaul; NEEDED FOR SCALING, before Sept 2026 — provisioning even one new pico is now confusing; no field firmware downloads, flash-write audit; Linear OPS-402)
- **gridworks-protocol** — [`designs/gwproto-shrink.md`](gridworks-protocol/designs/gwproto-shrink.md)
- **gridworks-scada** — [`designs/capability-protocol-and-verify.md`](gridworks-scada/designs/capability-protocol-and-verify.md) (ShNodeActor capability surface as the protocol between states and layouts; loud refusals + closed-loop verify; from the maple post-mortem; Linear OPS-394)
- **gridworks-scada** — [`designs/circulator-pump-0-10v-models.md`](gridworks-scada/designs/circulator-pump-0-10v-models.md) (pump make/model + 0–10 V response representation; Linear OPS-27)
- **gridworks-scada** — [`designs/code-update.md`](gridworks-scada/designs/code-update.md) (fleet code update: pull handshake + supervisor A/B flip + store epoch gate; NO BACK DOOR at scale; picos/OS out by posture; fully ratified, queued; Linear OPS-401)
- **gridworks-scada** — [`designs/ally-inactive.md`](gridworks-scada/designs/ally-inactive.md) (fire-and-forget ally.inactive/ally.active — live outage announcement for third-party observers; change-now item from the link-state findings)
- **gridworks-scada** — [`designs/poison-messages.md`](gridworks-scada/designs/poison-messages.md) (dead-letter the reupload loop; report via glitch, not ack-required — if it flaps, skip the acks; ack-timeout loosening rides along)
- **gridworks-scada** — [`designs/sieg-semantic-harmonization.md`](gridworks-scada/designs/sieg-semantic-harmonization.md) (sieg valve defaults OPEN in summer/Standby, reversing heating-season HP-off-closed; valve posture semantics + telemetry; Linear OPS-400)
- **gridworks-scada** — [`designs/sieg-valve-exercise.md`](gridworks-scada/designs/sieg-valve-exercise.md) (stub: scheduled valve motion over summer against seizure; actors/procedural family; Linear OPS-396)
- **gridworks-scada** — [`designs/simulated-test-environment/primary.md`](gridworks-scada/designs/simulated-test-environment/primary.md) (hub: simulated terminal assets + drivers over dev Rabbit — harness elevated to top, comms-first; spokes simulated-actors.md, experimentation-tools.md, sim-sensor-words.md, sim-time.md; Linear OPS-40)
- **gridworks-timecoordinator** — [`designs/hello-world.md`](gridworks-timecoordinator/designs/hello-world.md) (bite-size: rebuild fresh as uv project on gwbase; tc-hello broadcasts sim.timestep, witnessed by observer; legacy branch mined for Ready-barrier intent)
- **gridworks-scada** — [`designs/spruce-unlimbo/primary.md`](gridworks-scada/designs/spruce-unlimbo/primary.md) (seed: un-limbo spruce scada integration — i2c relays, layout pipeline, branch merge, Nolan control, July-15 AC path)
- **observability** — [`designs/consolidate-from-infra-scada-jk.md`](observability/designs/consolidate-from-infra-scada-jk.md)
- **rmqbot** — [`designs/analytics-broker-shovel.md`](rmqbot/designs/analytics-broker-shovel.md)
- **rmqbot** — [`designs/conf-template.md`](rmqbot/designs/conf-template.md)
- **rmqbot** — [`designs/identities-in-definitions.md`](rmqbot/designs/identities-in-definitions.md)
- **rmqbot** — [`designs/prod-4x-upgrade.md`](rmqbot/designs/prod-4x-upgrade.md)
- **rmqbot** — [`designs/prod-tls-fix.md`](rmqbot/designs/prod-tls-fix.md)
- **sema** — [`designs/practice-erb-pair-programming.md`](sema/designs/practice-erb-pair-programming.md)
- **sema** — [`designs/web-app-words-to-types.md`](sema/designs/web-app-words-to-types.md)

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
- **gridworks-marketmaker** — [`explorations/launch-intentions.md`](gridworks-marketmaker/explorations/launch-intentions.md)
- **gridworks-marketmaker** — [`explorations/market-product-and-uniform-bids.md`](gridworks-marketmaker/explorations/market-product-and-uniform-bids.md)
- **gridworks-provisioning** — [`explorations/principal-kinds-extension.md`](gridworks-provisioning/explorations/principal-kinds-extension.md)
- **gridworks-scada** — [`explorations/deeds-and-trading-rights.md`](gridworks-scada/explorations/deeds-and-trading-rights.md)
- **gridworks-scada** — [`explorations/layout-axiom-complexity.md`](gridworks-scada/explorations/layout-axiom-complexity.md)
- **gridworks-scada** — [`explorations/liveness-and-sla.md`](gridworks-scada/explorations/liveness-and-sla.md)
- **gridworks-scada** — [`explorations/non-gnode-interfaces.md`](gridworks-scada/explorations/non-gnode-interfaces.md)
- **gridworks-scada** — [`explorations/sema-style.md`](gridworks-scada/explorations/sema-style.md)
- **rmqbot** — [`explorations/granular-permissions-and-web-admin.md`](rmqbot/explorations/granular-permissions-and-web-admin.md)
- **rmqbot** — [`explorations/mtls-fis-auth.md`](rmqbot/explorations/mtls-fis-auth.md)
- **sema** — [`explorations/dashboard-vocabulary-modeling.md`](sema/explorations/dashboard-vocabulary-modeling.md)
- **sema** — [`explorations/rulebook-source-drift.md`](sema/explorations/rulebook-source-drift.md)
- **sema** — [`explorations/two-claudes.md`](sema/explorations/two-claudes.md)
