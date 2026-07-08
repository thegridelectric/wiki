# staging-word-status — a middle lifecycle tier for sema words

Status: Accepted · Pass 1 · Updated 2026-07-07 · Linear: OPS-445

**EDD: no** registry/tooling build-out; verified by the sema suite (status
validator, hash-pin test, snapshot-builder tests), not gated on a standalone
real-world experiment.

> What this is: the plan for adding a `staging` word status to sema — the
> lifecycle model, the initial published/staging partition of the registry,
> the enforcement mechanics, and the sanctioned spec edits. Resolved in the
> 2026-07-06 grill; this file exists so the plan is reviewable in one place
> before implementation.

## The model

- **`status` becomes required and explicit on EVERY registry entry** —
  formats, enums (versioned and literal), versionless types, and every type
  version. Absence is a validation error, not a default.
- **Types and versioned enums** carry status **per version**:
  `draft | staging | published`.
- **Formats** carry status at the **word level**: `draft | published` —
  formats never stage.
- **Versionless types and literal enums** carry status at the **word
  level**: `draft | staging | published`.
- **draft** — not ready to use at all. Excluded from `latest_version`, the
  public registry, runtime generation, and snapshots (as today).
- **staging** — in real use across repos, fully mutable in place,
  snapshot-consumable, **dev brokers only**. Never hybrid, never production.
- **published** — immutable: no functional change to fields, `$ref`/dependency
  versions, axioms, constraints, `required`, or enum values (a published
  versioned enum stays additive across *new* versions). Content-hash-pinned.
  Hybrid/production eligible.
- **URL go-live is a serving event, not a status change.** Nothing is served
  yet; staging `$id`s keep the canonical `schemas.electricity.works` URL.
- **Closure coherence:** a published version's full `$ref` closure
  (structural + axiom) must itself be published. A published word may not
  reference a staging or draft word.
- Promotion (staging → published) never touches `created`.

## Initial partition — the derivation principle

Published status is owed to the broker archive: a version must be published
exactly when payloads validated against it cross (or have crossed) non-dev
brokers — directly, or embedded in a word that does.

- **Seeds:** the wire-reached versions of broker-crossing words (from the
  dev + actual-spruce gwsproto pins), *minus* layout-file vocabulary.
  Components, device types, channel configs, and the authored layout words do
  not cross brokers as sema payloads — scada reads them from disk — so a
  gwsproto pin alone does not obligate publishing them. The runtime sema
  words are `layout.lite` and `scada.control.capabilities` only.
- **Published** = the seeds, plus their full `$ref` closure, plus every other
  non-draft entry that is not layout-work vocabulary. All formats, the
  versionless types (`gridworks.ack`, `gridworks.ping`, `gw`), and the
  literal enums are published at the word level.
- **Staging** = the layout-work cluster: the words being reshaped by
  hardware-layout pass one, and anything using them. A coherence fixpoint
  demotes referrers — `layout.lite/013–015` land staging because they embed
  staging component versions.

Derivation is scripted against `registry.yaml` + the gwsproto pins (session
scratch, re-runnable); the write-out is mechanical from its output. Result:
**110 published type versions / 62 staging** (plus enums below).

### Notable consequences (each checked against the registry indexes)

- Nine layout-cluster versions publish anyway because wire
  `layout.lite`/`scada.control.capabilities` versions embed them — the
  archive carries their payloads: `channel.config/000`,
  `gw1.tank.temp.calibration/000`, `gw1.tank.temp.calibration.map/000`,
  `i2c.multichannel.dt.relay.component.gt/002+003`,
  `pico.flow.module.component.gt/000`, `pico.tank.module.component.gt/011`,
  `relay.actor.config/002`, `sim.pico.tank.module.component.gt/000`.
- **`dfr.component.gt/000` and `ads111x.based.component.gt/000` stay staging
  and keep mutating in place at /000.** Their only referrer is
  `gw.house0.layout/000` (staging); no runtime sema word reaches them
  (confirmed via `indexes/reverse_dependencies.yaml`). The June in-place
  rebind to the stripped configs is therefore ordinary staging-era mutation,
  not an archive wound — no repair versions needed.
- `send.layout/000+001` publish: their deps are formats only
  (`left.right.dot`, `utc.milliseconds`/`spaceheat.name`); they embed no
  layout vocabulary.
- `relay.actor.config/003` stays staging: layout-file-only (gwsproto pins it,
  no wire closure reaches it). `/002` publishes via the i2c relay board;
  `/004` is the reshaped version, staging.
- `scada.control.capabilities/001+002` publish: catch-ups beyond the
  wire-pinned 000, but every dep of theirs publishes, so they cohere.

### Reviewed calls beyond the rule

- **`sim.ready/000` and `sim.timestep/000` publish; `sim.plant.flux/000` and
  `sim.plant.actuation/000` stay staging.** The harness handshake words are
  settled; the plant flux/actuation vocabulary is still evolving and crosses
  dev brokers only (the hybrid fleet will force publishing it later,
  deliberately).
- **`i2c.adc.channel`** (literal enum) is **staging** at the word level —
  layout-work vocabulary, referenced by no non-draft type yet.

### The staging set — types (60 versions)

`ads.channel.config/000+001` · `ads111x.based.component.gt/000` ·
`ads111x.based.device.type.gt/000` · `capture.tuning/000` ·
`channel.config/001` · `dfr.component.gt/000` · `dfr.config/000+001` ·
`egauge.register.config/000` · `electric.meter.channel.config/000+001` ·
`electric.meter.component.gt/001+002` · `electric.meter.device.type.gt/000` ·
`gpio.relay.component.gt/000` · `gw.house0.hydronic/000` ·
`gw.house0.layout/000` · `gw.house0.operational.params/000` ·
`gw.native.gpio.pin/000` · `gw.nolan.layout/000` · `gw1.hvac.zone/000` ·
`gw1.scada.device.type.gt/000` · `gw1.simple.sim.layout/000` ·
`gw1.tank.temp.calibration/001` · `gw1.tank.temp.calibration.map/001` ·
`gw108.gpio.sensor.component.gt/001+002` ·
`gw108.vdc.relay.component.gt/001+002` · `hubitat.component.gt/000` ·
`hubitat.poller.component.gt/000` · `i2c.adc.config/000` · `i2c.bus/000` ·
`i2c.dac.config/000` · `i2c.multichannel.dt.relay.component.gt/004+005` ·
`i2c.relay.component.gt/000` · `i2c.thermistor.channel.config/001+002` ·
`i2c.thermistor.interface.config/000` ·
`i2c.thermistor.reader.component.gt/001+002` · `layout.lite/013+014+015` ·
`linear.one.dimensional.calibration/000+001` ·
`pico.btu.meter.component.gt/000+001` · `pico.flow.module.component.gt/001` ·
`pico.tank.module.component.gt/012` · `relay.actor.config/003+004` ·
`relay.control.config/000` · `sim.pico.tank.module.component.gt/001` ·
`sim.plant.actuation/000` · `sim.plant.flux/000` ·
`sim.relay.component.gt/000` · `sim.sensor.component.gt/000` ·
`web.server.component.gt/001+002`

### The staging set — enums (7 versions + 1 literal word)

`gw1.device.type/000+001` (the device-type enum at the heart of the layout
work) · `gpio.sense.mode/000` · `gw.house0.primary.flow.source/000` ·
`i2c.adc.type/000` · `i2c.dac.type/000` · `thermistor.data.method/000` —
each referenced only by staging layout words — plus the literal enum
`i2c.adc.channel` (word-level). Every other non-draft enum version publishes
(26 have published referrers; unreferenced versions of published-family
enums publish with them).

## Enforcement (stays OUT of the sema spec)

Trust in published immutability does not ride on the honor system:

1. **Registry validator + suite test:** `status` required on every entry
   (error on absence or on an illegal value for the word class);
   published-closure coherence enforced. `latest_version` and runtime
   generation work from non-draft versions as today; the public-registry
   index carries status per version.
2. **Content-hash pinning:** every published schema file's content hash is
   recorded in the public-registry index; a suite test recomputes and
   compares, so any edit to a published file fails CI.
3. **Snapshot builder defaults to published-only:** if the requested
   `local_names` closure touches a staging or draft version, the build fails
   and lists the offenders. `--allow-staged` permits staging (never draft)
   and marks the output: a machine-readable `staging: true` in the snapshot
   indexes plus a "PLEASE ONLY USE IN DEV" banner at the top of the snapshot
   README. Consumer build scripts (`build_tlayouts_snapshot.sh`,
   `build_gwta_snapshot.sh`) gain `--allow-staged`.
4. **Conformance sweep `--release-gate`:** every gwsproto-pinned version must
   be published; run before any non-dev deploy.
5. **`sema promote <type> <version>`:** the human promotion act — verifies
   the closure is published, records the content hash, flips the status,
   never touches `created`.
6. **Ear tripwire (later, parked):** alarm on an unpublished
   TypeName/Version heard on a non-dev broker. Alarm only; promotion stays a
   human act.

## Spec edits (sanctioned in the grill; still one review with Jessica at the diff)

- `registry/structure.md` — the status section: required on all entries, the
  value sets per word class, no absent-default.
- The draft-promotion sentence — promotion no longer rewrites `created`.
- `snapshot.md` — published-only default, `--allow-staged`, the staging
  marker.
- `primary.md` — the publication paragraph (status vs the serving event).

## Build order

1. Registry write-out of every status per this partition (mechanical from the
   derivation script; `metadata.last_updated` bumped per the timestamp maxim).
2. Validator + suite test; index regeneration ripple.
3. Hash pinning + its test.
4. Snapshot builder default / `--allow-staged` / marker / README banner;
   consumer build scripts.
5. Spec edits (one diff, reviewed).
6. Conformance sweep `--release-gate`; `sema promote` helper.
7. Changelog entry + suggested commit (Jessica commits).

## Out of scope

The registration backlog (~40 gwsproto types without sema words, plus the
known version gaps) stays a named backlog, not a blocker. The gwsproto
catch-ups (`layout.lite` 013→015, `scada.control.capabilities` 000→002) are
separate work. The `GridWorks_CLAUDE.md` immutability maxim gets reworded to
the status model after this lands (file claim currently held by another
session).
