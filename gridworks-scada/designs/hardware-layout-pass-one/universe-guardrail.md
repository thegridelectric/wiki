# Universe guardrail — alias ↔ broker coherence (spoke)

Status: Draft · Pass 0 · Updated 2026-07-04

**EDD: no** a boot-time validation guardrail; verified by the scada refusing to boot on a
universe mismatch (a unit test + the `sim_boot` harness), not a standalone experiment.

> What this is: the rule that a GNode may only talk on a broker in its own *universe*, and the
> cheap scada-side check that enforces it. Born from the sim work — a simulated layout must never
> reach a real-money broker — and from the concern that dev (`d1.*`) aliases could publish on the
> hybrid/production broker.

## What a universe is

A **universe** is the first dotted segment of a GNodeAlias:

- `d1.isone.ct.newhaven.orange1.scada` → universe **`d1`**
- `hw1.isone.me.versant.keene.maple` → universe **`hw1`**

The **kind** is the first letter of that segment: **`d`** = dev, **`h`** = hybrid, **`w`** =
production. Dev and hybrid universes may be **many** (`d1`, `d2`, `h1`, `hw1`, …); there is exactly
**one production universe** (`w…`) — the only place GridWorks MarketMakers manage real money. So
"is this real money?" ⇔ "is the universe the single production one?"

## The broker carries the same universe

A rabbit broker names its universe in two coherent places:

- **DNS host:** `hw1-1.electricity.works` — first label is `<universe>-<instance>`.
- **AMQP vhost:** `hw1__1` — `<universe>__<instance>`.

The `-<n>` / `__<n>` is a **broker/world-instance index** (lets a universe run several broker hosts,
or be torn down and recreated, without changing identity) — it is **not** part of the universe.
The dev rabbit (`gw-dev-rabbit`) runs on `localhost` serving vhost `d1__1`.

```
universe_of(alias) = alias.split(".")[0]              # hw1.isone...        -> hw1
universe_of(host)  = host.split(".")[0].split("-")[0] # hw1-1.electricity.. -> hw1
                     # localhost is the dev rabbit -> d1
```

## The guardrail — alias ↔ broker host (cooperative — SHIPPED `822b150c`)

At boot the scada asserts, for its GNodeAliases, `universe_of(alias) == universe_of(broker_host)`
(`localhost ⇒ d1`). If they disagree it refuses to boot. This is the check that stops a `d1.*`
scada landing on the `hw1` broker.

**Shipped 2026-06-29 (`822b150c`):** `gw_spaceheat/universe.py` (`universe_of_alias` /
`universe_of_host` / `assert_universe_coherence`), wired into `ScadaApp.make_app_for_cli` — the real
`cli.py run` boot path, deliberately **not** generic construction, so unit tests loading `hw1`
fixtures on localhost are unaffected. `sim_layout.py` dev-ifies aliases to match. Unit tests cover
the helpers + the mismatch refusal.

**Why the host is enough.** The broker guarantees its host and vhost encode the same universe
(infra invariant: `hw1-1.electricity.works` only ever serves `hw1__1`), so the scada — which talks
**MQTT** and sees the host but not the vhost — can use the **host as a sound proxy for the vhost**.
It never needs to know the vhost independently.

**What "enough" covers.** This is a **cooperative** check: it protects against any client that runs
it. That fully covers **honest misconfiguration** (a fat-fingered `.env`), which is the day-to-day
worry, because every publisher today is a GridWorks scada running this code. It does **not** stop a
client that skips the check (an old build, a throwaway script using the public `smqPublic` creds
against the wide-open rabbit `write: ".*"`).

**The real boundary is server-side, in gridworks-base.** To make a wrong-universe alias *physically*
unable to publish, scope each vhost's rabbit permission regex to the universe prefix + issue
per-universe credentials. That is `gridworks-base` infra and its own issue — captured in
[`../../designs/simulated-test-environment/gleanings.md`](../simulated-test-environment/gleanings.md)
"Opportunities for improvement". The scada check is the cheap first line; the rabbit perms are the
hard boundary (defense-in-depth, needed once untrusted publishers exist).

## Ties to the sim work

- A simulated layout (any `sim.*` component / `SimSensorActor`) must run in a **dev or hybrid**
  universe — never production. The scada-side universe check + dev/hybrid broker is what enforces
  "no simulation against real money."
- `sim_layout.py` (the simulated-house0 transform) must therefore **rewrite GNodeAliases into the
  dev universe** (`d1…`) so the sim layout is coherent with the dev broker it boots on — otherwise
  this guardrail (rightly) rejects a `hw1.*` sim layout on `localhost`/`d1`.

## Deferred — the sema axiom

The layout-internal half — *if any component is `sim.*` then the universe kind ≠ production* — is a
self-contained **sema layout axiom** (`check_axiom_n`, the layout has both the components and the
aliases). Add it once the production universe token is fixed; it only fully bites when a `w`
universe exists. The alias↔host boot check above is the part that shipped this pass.

## What makes a universe REAL — TaDeed / TaValidator (future)

"No simulated components" is only the *first* gate on being REAL. The deeper requirement is
**provenance**: a TerminalAsset is legitimate in a non-dev universe only if it holds a **TaDeed**
signed by a **TaValidator** of the matching universe class:

- **dev (`d`)** — the only class **exempt** from a TaDeed (you can stand up dev TerminalAssets freely).
- **hybrid (`h`)** — requires a TaDeed signed by a **hybrid** TaValidator.
- **production (`w`)** — requires a TaDeed signed by a **real (production)** TaValidator.

So the future, full definition of "this is REAL" is roughly: **no simulated components AND a valid
TaDeed from the appropriate-class TaValidator.** That makes the `is_simulated`→derived refactor a
*subset* of a larger `universe`/provenance check — worth keeping in view so the boolean isn't
re-entrenched as the authority. (Provenance/TaDeed verification is well beyond this pass — captured
here so the universe model carries the whole picture.)

## `is_simulated` is related — and due for refactor

The free-floating `ScadaSettings.is_simulated` boolean overlaps this: "am I simulated?" should be
derivable from the layout (sim components present) + universe, not a hand-set switch. Refactor note
in [`../../designs/simulated-test-environment/gleanings.md`](../simulated-test-environment/gleanings.md).
