# BTU meter integration (Home Assistant)

Status: Draft · Pass 0 · Updated 2026-06-08 · Linear: OPS-47

> What this is: the change plan for exposing the GridWorks BTU meter to Home
> Assistant via the `gridworks-homeassistant` HACS integration. Ported from
> Linear **OPS-47**. Sits under the broader, still-open
> [Home Assistant + LTN wrapper exploration](../../explorations/home-assistant-ltn.md);
> this design is the concrete, near-term slice.

## Problem

GridWorks pico-based devices (BTU meters, tank modules) should be readable from
Home Assistant so HA-based SCADA systems (e.g. Aris / Jonathon's) can consume
them. The vehicle is the existing **`gridworks-homeassistant` HACS integration**
— a simple HTTP API over the pico devices — which needs BTU-meter-specific
endpoints, calculations, and configuration. (It was also Jessica's chosen way to
learn the HA ecosystem.)

## Current state

- **`gridworks-homeassistant`** is a HACS integration with an HTTP API pattern
  **`/api/<actor_name>/<type_name>`** for GridWorks pico open-source devices
  (e.g. `Gw101 PicoBtu1`, `Gw100 TankModule3`). Endpoint pattern is decided;
  the BTU-meter specifics are not yet built.
- The BTU meter lives in **`gridworks-pico`**, which is itself due for an
  overhaul (tracked separately).

## Scope of work

Absorbed from OPS-47's checklist, grouped:

**API surface**
- Import the relevant pydantic named types into the integration.
- Decide **str vs enum** at the API boundary (esp. for units).
- Fix the existing endpoint patterns in the original code to match
  `/api/<actor_name>/<type_name>`.
- Create the **BtuMeter endpoints**.

**Vocabulary**
- Add **Sema** vocabulary for the relevant types (OPS-47 says "ASL" — legacy
  for Sema; see [`glossary.md`](../../glossary.md)).
- Decide whether **Units** are an enum or a string (the str-vs-enum question,
  resolved once for the boundary).

**Calculations**
- Add the simple BtuMeter calculations: **power output** and **energy
  accumulation**.

**Integration + config**
- Test **MQTT** integration.
- Test the **backup URL** path with Home Assistant.
- Configuration: (a) values passed on to the pico — names, update intervals,
  async triggers; (b) local display adjustments — Celsius vs F, MMBTU vs kWh.

**Hardening**
- More robust **error handling** for network failures.
- **Authentication** — currently HA's built-in auth; consider device-specific.
- Expand the README.

## Open questions

- **str vs enum at the HTTP boundary.** A single decision (likely enum in Sema,
  string on the wire where HA ergonomics demand) applied consistently to units
  and other categorical fields.
- **Auth model.** Is HA's built-in auth sufficient, or do pico devices need
  device-specific credentials?
- **Relationship to `gridworks-pico` overhaul.** How much of this waits on the
  BTU meter overhaul vs proceeds against the current firmware.

## Implementation notes

- **No code yet.** Per the implementation gate, reach `Accepted` (Pass ≥ 1)
  before `gridworks-homeassistant` edits matching this scope begin.
- **Any Sema change** goes through `/make-sema-word` (read `sema/CLAUDE.md`).
- Touch points: `gridworks-homeassistant` (HACS integration), `gridworks-pico`
  (device firmware), `sema` (boundary types/enums).
