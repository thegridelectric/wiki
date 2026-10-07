# Scada provisioning (design)

Status: Draft · Pass 0 · Updated 2026-10-07

> What this is: when, in the life of a Pi scada, each thing it needs
> arrives on the box, and which route is the default. Opened to hold the
> weather records' answer; the rest of the provisioning sequence is
> gathered here as it is decided. No Linear issue yet.

## Weather records arrive at or after TaValidation

A scada fills a missing or stale forecast from its location's seasonal
template, and needs the bundle record (slice grid, units) to lay the
fill on. Neither may be absent at first boot. Decision: both records
are loaded **at or after TaValidation**, on the provisioning path, which
has internet; the default route is that the provisioning step asks the
weather service for the bundle record its ops word names and the
location's seasonal template and places them in the scada's config dir
beside the operational params. The pull path keeps both fresh
afterwards. A box that boots with neither has no forecast and says so
(WARNING); it is a provisioning gap, not a runtime fallback.

Depends on gwwf's seasonal-template word and rung (tracked in the
spruce-unlimbo work under OPS-392 until it has its own issue).

## Open

- The full provisioning sequence (deed, layout, ops params, weather
  records, broker credentials) in one ordered list.
- Who runs the step: `experiments/put_layout.sh` today; the provisioning
  tool it becomes.
