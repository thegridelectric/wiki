# api-pattern — the house HTTP pattern

Status: Draft · Pass 0 · Updated 2026-08-11

> What this is: how GridWorks services expose HTTP surfaces — the
> route grammar, the sema-word contract, and the read-façade posture.
> Canonical home for the pattern; per-service docs (gnr's executor,
> service changelogs) state their own adoption and converge here.

## The split — by traffic shape, not by consumer

Writes ride rabbit; reads ride an HTTP/FastAPI façade. A change event
is genuinely pub/sub and belongs on the bus; a query is
request-shaped and belongs on HTTP. **Nothing binding crosses REST**
— acks and authoritative state live on the bus and in the owning
service; REST serves derived, read-only projections. gwbase is
deliberately HTTP-silent: serving HTTP is service-level composition,
never a base-class capability.

The façade is thin: it translates HTTP onto the same
transport-agnostic reads the service's other adapters use (gnr's
`AuthoritySource`, gwwf's `WeatherReads`) and holds no service logic
of its own.

## Posture

Public, read-only, CORS-open (read verbs only). TLS terminates at the
fronting proxy (Caddy + Let's Encrypt); the service binds loopback.
Privacy rides the data shape, not a network perimeter: opaque
identity in the open system; sensitive data held separately by the
party that owns it, encrypted, deletable.

## Route grammar

`/<party>/<sema-type-with-hyphens>`.

- **The party segment is the service's identity.** A GNode service
  uses its **hyphenated GNodeAlias** (the LRH transform routing keys
  use: `d1.weather` → `/d1-weather/…`), derived from settings at app
  build — never a hardcoded nickname. A non-GNode service uses its
  service name (`/gnr/…`). On inbound device surfaces the party is
  the sending node (`POST /{from_node}/flow-reed-params`).
- **The second segment is the sema TypeName with dots → hyphens** —
  the same rendering the routing-key grammar uses, because dots are
  separators in both worlds. The transform is wire-form only; the
  word keeps its dotted name everywhere else.
- **Bodies are full sema words, never ad-hoc scalars.** A
  request-shaped read takes a request word and returns a word
  (`POST /gnr/g-node-forest-request` → `g.node.forest`).
- **The sanctioned exception: point lookups.** A read keyed by a
  single scalar is a GET with a format-typed path param
  (`GET /gnr/g-node-by-alias/{alias}` with `alias: LeftRightDot`),
  named descriptively. The sema-word rule stays binding on the
  RESPONSE side always; parameterized reads do not mint request
  words just for uniformity.

## Docs are part of the contract

Routes return **the sema types themselves** as response models with
`response_model_exclude_none=True` — with the sema base's PascalCase
alias generator this is byte-identical to the runtime's `to_dict()`
wire form, and `/docs` then documents the real sema schemas. Pin the
wire form with a **DB-free test** over an injected read source. An
OpenAPI post-pass links every sema-word schema to its canonical
definition, derived from the schema's TypeName/Version defaults —
never hand-maintained. A `/ping` health route rounds out the surface.

## Consumption idiom

A consumer bootstraps and queries over the façade and rides bus
broadcasts for invalidation — never rabbit request/reply, and never
another service's database (each service is its own DB's sole
accessor). One read API per service serves all of its pull consumers.

## Deployment shape

Two systemd units per service: `<svc>-rabbit.service` (the bus actor)
and `<svc>-api.service` (uvicorn, stdout to journald), per the gwbase
service-deployment spec.

## Foreign-contract exceptions

Where an external protocol dictates the shape, the deviation is taken
and documented as such — e.g. FIS's `/auth/*` routes speak the
rabbitmq-auth-backend-http contract (`{"result": "allow"|"deny"}`),
not the house grammar. The exception is the external contract, never
convenience.

## Examples

- `grid-node-registry/src/gnr/api.py` — the reference read façade
  (non-GNode party, word-bodied forest read, GET point lookups,
  OpenAPI sema links).
- `gridworks-weather-forecast/src/gwwf/api.py` — a GNode service's
  façade (alias party segment, record listings + latest-message
  pulls).
- `starter-scripts/api/` — the inbound device surface (picos POST
  full words to the pi).
