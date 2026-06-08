# GridWorks designs + concerns index


> Flat directory of every file under any `designs/` or `concerns/`
> folder across the wiki. Maturity / workflow state are NOT encoded
> here — each file's own `Status:` line carries maturity; Linear
> carries workflow (status / owner / priority). For the lifecycle
> convention, see [`designs-process.md`](designs-process.md). For
> "what lives where" across designs / concerns / executor / Linear,
> see [`glossary.md`](glossary.md) "Where content lives".

## Designs

_(every file under a `designs/` folder, anywhere in the wiki)_

- (cross-cutting) [`designs/concerns-to-explorations-migration.md`](designs/concerns-to-explorations-migration.md) (rename concerns/ → domain-root explorations/; deferred to a fresh session)
- (cross-cutting) [`designs/linear-integration.md`](designs/linear-integration.md)
- **gridworks-base** — [`designs/decouple-amq-topic.md`](gridworks-base/designs/decouple-amq-topic.md)
- **gridworks-base** — [`designs/log-sema-round-trip.md`](gridworks-base/designs/log-sema-round-trip.md)
- **gridworks-base** — [`designs/mock-transport-for-tests.md`](gridworks-base/designs/mock-transport-for-tests.md)
- **gridworks-base** — [`designs/neutral-message-metadata.md`](gridworks-base/designs/neutral-message-metadata.md)
- **gridworks-base** — [`designs/pika-thread-safe-publish.md`](gridworks-base/designs/pika-thread-safe-publish.md) (ActorBase publish thread-safety; decided: always-marshal via add_callback_threadsafe)
- **gridworks-base** — [`designs/routingclass-wire-aliases.md`](gridworks-base/designs/routingclass-wire-aliases.md)
- **gridworks-data** — [`designs/dev-branch-and-pr-gate.md`](gridworks-data/designs/dev-branch-and-pr-gate.md)
- **gridworks-data** — [`designs/gw-data-analytics-deployment.md`](gridworks-data/designs/gw-data-analytics-deployment.md)
- **gridworks-homeassistant** — [`designs/btu-meter-integration.md`](gridworks-homeassistant/designs/btu-meter-integration.md) (BTU meter → HA via HACS integration; Linear OPS-47)
- **gridworks-journalkeeper** — [`designs/layered-test-harness.md`](gridworks-journalkeeper/designs/layered-test-harness.md)
- **gridworks-journalkeeper** — [`designs/s3-importer-improvements.md`](gridworks-journalkeeper/designs/s3-importer-improvements.md)
- **gridworks-journalkeeper** — [`designs/upgrade-gjk-sema-snapshot.md`](gridworks-journalkeeper/designs/upgrade-gjk-sema-snapshot.md) (regen vendored sema snapshot post-untangle; nit; Linear OPS-379; blocked by OPS-378)
- **gridworks-protocol** — [`designs/gwproto-shrink.md`](gridworks-protocol/designs/gwproto-shrink.md)
- **gridworks-scada** — [`designs/circulator-pump-0-10v-models.md`](gridworks-scada/designs/circulator-pump-0-10v-models.md) (pump make/model + 0–10 V response representation; Linear OPS-27)
- **gridworks-scada** — [`designs/simulated-test-environment.md`](gridworks-scada/designs/simulated-test-environment.md) (simulated terminal assets + drivers over dev Rabbit; Linear OPS-40)
- **observability** — [`designs/consolidate-from-infra-scada-jk.md`](observability/designs/consolidate-from-infra-scada-jk.md)
- **rmqbot** — [`designs/analytics-broker-shovel.md`](rmqbot/designs/analytics-broker-shovel.md)
- **rmqbot** — [`designs/conf-template.md`](rmqbot/designs/conf-template.md)
- **rmqbot** — [`designs/identities-in-definitions.md`](rmqbot/designs/identities-in-definitions.md)
- **rmqbot** — [`designs/prod-4x-upgrade.md`](rmqbot/designs/prod-4x-upgrade.md)
- **rmqbot** — [`designs/prod-tls-fix.md`](rmqbot/designs/prod-tls-fix.md)
- **sema** — [`designs/practice-erb-pair-programming.md`](sema/designs/practice-erb-pair-programming.md)
- **sema** — [`designs/snapshot-improvement.md`](sema/designs/snapshot-improvement.md)
- **sema** — [`designs/untangle-market-type-name/primary.md`](sema/designs/untangle-market-type-name/primary.md) (hub-and-spoke; spoke: structured-enums)
- **sema** — [`designs/web-app-words-to-types.md`](sema/designs/web-app-words-to-types.md)

## Concerns

_(every file under a `concerns/` folder, anywhere in the wiki)_

- **gridworks-admin** — [`research/concerns/admin-gateway-service.md`](gridworks-admin/research/concerns/admin-gateway-service.md)
- **gridworks-admin** — [`research/concerns/when-to-add-grpc.md`](gridworks-admin/research/concerns/when-to-add-grpc.md)
- **gridworks-base** — [`research/concerns/logging-for-observability.md`](gridworks-base/research/concerns/logging-for-observability.md)
- **gridworks-fleet-index-service** — [`research/concerns/principal-model.md`](gridworks-fleet-index-service/research/concerns/principal-model.md)
- **gridworks-journalkeeper** — [`concerns/scale-strategy-starter.md`](gridworks-journalkeeper/concerns/scale-strategy-starter.md)
- **gridworks-provisioning** — [`research/concerns/principal-kinds-extension.md`](gridworks-provisioning/research/concerns/principal-kinds-extension.md)
- **gridworks-scada** — [`research/concerns/deeds-and-trading-rights.md`](gridworks-scada/research/concerns/deeds-and-trading-rights.md)
- **gridworks-scada** — [`research/concerns/layout-axiom-complexity.md`](gridworks-scada/research/concerns/layout-axiom-complexity.md)
- **gridworks-scada** — [`research/concerns/liveness-and-sla.md`](gridworks-scada/research/concerns/liveness-and-sla.md)
- **gridworks-scada** — [`research/concerns/non-gnode-interfaces.md`](gridworks-scada/research/concerns/non-gnode-interfaces.md)
- **gridworks-scada** — [`research/concerns/sema-style.md`](gridworks-scada/research/concerns/sema-style.md)
- **gridworks-scada** — [`research/concerns/transport-and-links.md`](gridworks-scada/research/concerns/transport-and-links.md)
- **rmqbot** — [`research/concerns/granular-permissions-and-web-admin.md`](rmqbot/research/concerns/granular-permissions-and-web-admin.md)
- **rmqbot** — [`research/concerns/mtls-fis-auth.md`](rmqbot/research/concerns/mtls-fis-auth.md)
- **sema** — [`research/concerns/dashboard-vocabulary-modeling.md`](sema/research/concerns/dashboard-vocabulary-modeling.md)
- **sema** — [`research/concerns/rulebook-source-drift.md`](sema/research/concerns/rulebook-source-drift.md)
- **sema** — [`research/concerns/two-claudes.md`](sema/research/concerns/two-claudes.md)
