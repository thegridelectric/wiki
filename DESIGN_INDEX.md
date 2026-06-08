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

- (cross-cutting) [`designs/linear-integration.md`](designs/linear-integration.md)
- **gridworks-base** — [`designs/decouple-amq-topic.md`](gridworks-base/designs/decouple-amq-topic.md)
- **gridworks-base** — [`designs/mock-transport-for-tests.md`](gridworks-base/designs/mock-transport-for-tests.md)
- **gridworks-base** — [`designs/neutral-message-metadata.md`](gridworks-base/designs/neutral-message-metadata.md)
- **gridworks-base** — [`designs/pika-thread-safe-publish.md`](gridworks-base/designs/pika-thread-safe-publish.md) (ActorBase publish thread-safety; decided: always-marshal via add_callback_threadsafe)
- **gridworks-base** — [`designs/routingclass-wire-aliases.md`](gridworks-base/designs/routingclass-wire-aliases.md)
- **gridworks-data** — [`designs/gw-data-analytics-deployment.md`](gridworks-data/designs/gw-data-analytics-deployment.md)
- **gridworks-journalkeeper** — [`designs/layered-test-harness.md`](gridworks-journalkeeper/designs/layered-test-harness.md)
- **gridworks-journalkeeper** — [`designs/s3-importer-improvements.md`](gridworks-journalkeeper/designs/s3-importer-improvements.md)
- **gridworks-protocol** — [`designs/gwproto-shrink.md`](gridworks-protocol/designs/gwproto-shrink.md)
- **sema** — [`designs/practice-erb-pair-programming.md`](sema/designs/practice-erb-pair-programming.md)
- **sema** — [`designs/snapshot-improvement.md`](sema/designs/snapshot-improvement.md)
- **sema** — [`designs/untangle-market-type-name.md`](sema/designs/untangle-market-type-name.md)
- **sema** — [`designs/web-app-words-to-types.md`](sema/designs/web-app-words-to-types.md)

## Concerns

_(every file under a `concerns/` folder, anywhere in the wiki)_

- **gridworks-journalkeeper** — [`concerns/scale-strategy-starter.md`](gridworks-journalkeeper/concerns/scale-strategy-starter.md)
- **gridworks-scada** — [`research/concerns/deeds-and-trading-rights.md`](gridworks-scada/research/concerns/deeds-and-trading-rights.md)
- **gridworks-scada** — [`research/concerns/layout-axiom-complexity.md`](gridworks-scada/research/concerns/layout-axiom-complexity.md)
- **gridworks-scada** — [`research/concerns/liveness-and-sla.md`](gridworks-scada/research/concerns/liveness-and-sla.md)
- **gridworks-scada** — [`research/concerns/non-gnode-interfaces.md`](gridworks-scada/research/concerns/non-gnode-interfaces.md)
- **gridworks-scada** — [`research/concerns/sema-style.md`](gridworks-scada/research/concerns/sema-style.md)
- **gridworks-scada** — [`research/concerns/transport-and-links.md`](gridworks-scada/research/concerns/transport-and-links.md)
- **sema** — [`research/concerns/dashboard-vocabulary-modeling.md`](sema/research/concerns/dashboard-vocabulary-modeling.md)
- **sema** — [`research/concerns/rulebook-source-drift.md`](sema/research/concerns/rulebook-source-drift.md)
- **sema** — [`research/concerns/two-claudes.md`](sema/research/concerns/two-claudes.md)
