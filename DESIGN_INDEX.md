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
- **gridworks-base** — [`designs/decouple-amq-topic.md`](gridworks-base/designs/decouple-amq-topic.md)
- **gridworks-base** — [`designs/log-sema-round-trip.md`](gridworks-base/designs/log-sema-round-trip.md)
- **gridworks-base** — [`designs/mock-transport-for-tests.md`](gridworks-base/designs/mock-transport-for-tests.md)
- **gridworks-base** — [`designs/must-accept-current-ltn-messages.md`](gridworks-base/designs/must-accept-current-ltn-messages.md) (gwbase MUST NOT drop current LTN/SCADA/weather short-form-class messages; data-loss bug; consolidates ex-routingclass-wire-aliases)
- **gridworks-base** — [`designs/neutral-message-metadata.md`](gridworks-base/designs/neutral-message-metadata.md)
- **gridworks-base** — [`designs/publish-backpressure.md`](gridworks-base/designs/publish-backpressure.md) (bound the marshaled-send queue; backlog follow-up to OPS-383; Linear OPS-384)
- **gridworks-data** — [`designs/dev-branch-and-pr-gate.md`](gridworks-data/designs/dev-branch-and-pr-gate.md)
- **gridworks-data** — [`designs/gw-data-analytics-deployment.md`](gridworks-data/designs/gw-data-analytics-deployment.md)
- **gridworks-homeassistant** — [`designs/btu-meter-integration.md`](gridworks-homeassistant/designs/btu-meter-integration.md) (BTU meter → HA via HACS integration; Linear OPS-47)
- **gridworks-journalkeeper** — [`designs/integrate-gwbase-sema-updates/primary.md`](gridworks-journalkeeper/designs/integrate-gwbase-sema-updates/primary.md) (integrate gwbase 0.5.x + sema updates into JK; hub; folds ex-upgrade-gjk-sema-snapshot; Linear OPS-386)
- **gridworks-journalkeeper** — [`designs/layered-test-harness.md`](gridworks-journalkeeper/designs/layered-test-harness.md)
- **gridworks-journalkeeper** — [`designs/s3-importer-improvements.md`](gridworks-journalkeeper/designs/s3-importer-improvements.md)
- **gridworks-marketmaker** — [`designs/launch-new-simple-marketmaker/primary.md`](gridworks-marketmaker/designs/launch-new-simple-marketmaker/primary.md) (launch a new simple MarketMaker; hub + `evaluate-existing-repo` spoke)
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
- **sema** — [`designs/web-app-words-to-types.md`](sema/designs/web-app-words-to-types.md)

## Explorations

_(every file under an `explorations/` folder, anywhere in the wiki)_

- (cross-cutting) [`explorations/aris-collaboration.md`](explorations/aris-collaboration.md)
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
- **gridworks-scada** — [`explorations/transport-and-links.md`](gridworks-scada/explorations/transport-and-links.md)
- **rmqbot** — [`explorations/granular-permissions-and-web-admin.md`](rmqbot/explorations/granular-permissions-and-web-admin.md)
- **rmqbot** — [`explorations/mtls-fis-auth.md`](rmqbot/explorations/mtls-fis-auth.md)
- **sema** — [`explorations/dashboard-vocabulary-modeling.md`](sema/explorations/dashboard-vocabulary-modeling.md)
- **sema** — [`explorations/rulebook-source-drift.md`](sema/explorations/rulebook-source-drift.md)
- **sema** — [`explorations/two-claudes.md`](sema/explorations/two-claudes.md)
