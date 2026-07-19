# gjk persistors — what the custom persistors do

Status: Draft · Pass 0 · Updated 2026-06-09

> Sub-spec of [`primary.md`](primary.md): the persistor stack in depth, with
> emphasis on the **channel model** and the fact that the `readings` fan-out is
> a **lossy projection**. The specific shape here is implementation
> (ultimately Joe's call); the load-bearing point this doc insists on is the
> lossiness and where meaning does/doesn't stay rigorous.

## The two tables a persistor touches

- **`messages`** — the faithful record: the decoded message stored whole
  (payload jsonb). Nothing is lost here; it mirrors the immutable bus record
  (EAR/S3).
- **`readings`** / **`reading_channels`** — a **derived, flattened
  time-series projection**: rows of `(timestamp, channel_id, numeric value)`.
  This is where information is selected, scalarized, and lost.

## Default vs custom persistors

The default path stores the message in `messages` and stops. A **custom
persistor** additionally fans selected fields into `readings` (and, for
layouts, maintains `reading_channels`). Four custom persistors today:
`layout.lite`, `report.event`, `flo.params.house0`, `weather.forecast`.

## The channel model — two rigorous kinds, one not

`reading_channels` rows carry a `channel_type`, and there are **three** kinds —
and this is the crux:

| kind | `channel_type` | backed by a Sema type? | source |
|---|---|---|---|
| **DataChannel** | `data.channel.gt` | **yes — rigorous** | `layout.lite.data_channels` |
| **DerivedChannel** | `derived.channel.gt` | **yes — rigorous** | `layout.lite.derived_channels` |
| **PseudoChannel** | `gjk.pseudo` (a literal, not a Sema type) | **no** | hand-declared in persistor code |

So channel meaning lives in **two different places** depending on the channel:

- For **data / derived** channels, meaning is **explicit in Sema**
  (`data.channel.gt` / `derived.channel.gt`) and arrives in the `layout.lite`
  message. `LayoutLitePersistor` just mirrors those into `reading_channels`.
- For **pseudo** channels (price, weather, machine-states), there is **no
  rigorous Sema channel type**. The channel's name/unit/meaning is declared
  *in persistor code* (`PseudoChannel(...)` literals) and registered at import.
  This is a deliberate convenience, but it means **the meaning of a pseudo
  channel is encoded in gjk rather than in Sema** — the one place the
  ecosystem otherwise insists meaning must be explicit (see
  `wiki/vision/where-meaning-lives-in-gridworks.md`).

`LayoutLitePersistor` is the channel registry keeper: it syncs all three kinds
into `reading_channels`, deactivating (via `deactivated_date`) any whose
unit/type drifted or that vanished from the layout. It writes no readings
itself — it defines the channels the others write against.

## What each custom persistor projects (and drops)

- **`report.event`** → `readings`, three sub-paths:
  - **channel readings** — `report.channel_reading_list` → readings keyed to
    *existing* `reading_channels` by name; **channels not already present are
    silently skipped**. These reference the rigorous data/derived channels.
  - **zone heat-call synthesis** — for every `*-whitewire-pwr` channel whose
    layout declares no matching `*-heat-call` channel, a `heat-call` pseudo
    channel is invented and each whitewire-pwr reading derives a 0/1 heat-call
    reading (on-threshold per site: beech 100 W, elm 1 W, default 20 W). This
    exists because most of the deployed fleet does not report heat-call
    natively (spruce is the exception); the analytics crew reads these pseudo
    channels. Where a layout *does* declare heat-call channels, the synthesis
    steps aside — that interaction is what the per-site layout migration has
    to preserve.
  - **machine states (the smush)** — `report.state_list` is flattened onto
    `SemaEnumPseudoChannel`s via a hand-maintained `STATE_CHANNELS` map
    (`machine_handle` → pseudo enum channels, with `auto.h→auto.lc`,
    `a.aa→ltn.la` rewrites). Each state string is converted to an **integer**
    via `get_sema_enum_value`, which **hashes unrecognized values** as a
    fallback. So a richly-typed machine-state stream — which *also* has
    rigorous Sema types (`machine.states` / `single.machine.state`) — is
    re-expressed as integer readings on invented channels. Two
    non-aligned representations of the same fact; the readings one is lossy
    (enum→int, hash collisions possible, mapping maintained by hand).
- **`flo.params.house0`** → 3 pseudo channels (`buffer-available-kwh`,
  `lmp-usd-per-mwh`, `total-usd-per-mwh`), taking only the **first** element of
  the forecast arrays (`lmp_forecast[0]`, …). The flo params object is large;
  this projects a handful of first-step scalars.
- **`weather.forecast`** → 2 pseudo channels (`forecast-ws`, `forecast-oat`),
  again only the **first** array element; the rest of the forecast horizon is
  dropped from `readings`.

## The point: `readings` is a lossy projection

`readings` deliberately keeps a small, query-friendly numeric slice. It drops
structure, drops all but the first element of forecast arrays, scalarizes
enums, and encodes pseudo-channel meaning in code rather than Sema. **That is
acceptable only because the full record is preserved upstream** — the whole
message sits in `messages` (jsonb) and in the EAR/S3 history — so the
projection can always be re-derived or extended without data loss
(`wiki/vision/data-meaning-sovereignty.md`: complete record underneath,
opinionated projections on top).

Worth flagging for the owner (Joe's call):
- pseudo channels carry meaning that is **not rigorous in Sema** — a candidate
  for promotion to real channel types where it matters (esp. machine states,
  which already have Sema types);
- the `report.event` state handling **smushes** a typed stream into integer
  readings with a hand-maintained map + hash fallback;
- first-element-only projection of forecast arrays is a silent horizon loss.

None of these are bugs — they are projection choices. The job of this doc is to
make the lossiness explicit so it's a *decision*, not an accident.
