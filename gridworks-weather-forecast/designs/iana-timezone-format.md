Status: Draft · Pass 0 · Updated 2026-09-17 · Linear: OPS-548

**EDD: no** a schema-only bump verified by `sema validate` against the
existing fixture, not an experiment.

# Bump `gw.weather.location.gt`'s `Timezone` to `iana.timezone.str`

## What this is

`gw.weather.location.gt/000` (published, immutable) validates its
`Timezone` field against the generic `non.empty.string` format, with a note
in the schema saying it is hand-validated "until an IANA-timezone format
word exists to retire this note." That word now exists: `iana.timezone.str`
(added alongside `gw.tou.tariff`, OPS-539), a shape-only regex format
(`^[A-Za-z_]+(/[A-Za-z0-9_+-]+){0,2}$`) with no tzdata dependency, so it's
trivial to implement in any language.

Because `gw.weather.location.gt/000` is `published`, swapping the `$ref` is
a validation-behavior change and requires a new version (`001`), not an
in-place edit.

## Do this next

- New version `gw.weather.location.gt/001`: `Timezone` references
  `iana.timezone.str` instead of `non.empty.string`; retire the
  hand-validated note from its description.
- Upgrade path `000 → 001`: structural no-op (same field, stricter
  format) — every valid `000` `Timezone` value that is a real tz-database
  name already matches the new pattern, so upgrade is a straight
  `model_dump()` / `model_validate()` with no field rewrite. No
  `UpgradeRequiresContext` case here.
- Registry: new `versions."001"` entry, `latest_version` bumped, dependency
  on `iana.timezone.str` added.
- Sweep consumers of `gw.weather.location.gt` (gridworks-weather-forecast
  producer/consumer code) for the version bump.

## Open

- Confirm no in-flight `000` `Timezone` values would fail the new pattern
  (spot-check emitted weather-location instances before publishing `001`).
