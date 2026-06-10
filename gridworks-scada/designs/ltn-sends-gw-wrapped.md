Status: Accepted · Pass 1 · Updated 2026-06-09 · Linear: OPS-387

# LTN sends a real `gw`-wrapped message, not the `Dst="broadcast"` hack

What this is: a fix-direction design for the SCADA-side half of "current LTN
messages must survive a gwbase consumer." The LTN today publishes several
message types with the **magic string `Dst="broadcast"`**, which the proactor
encodes into a wire routing key that has no valid GridWorks envelope — so a
gwbase consumer drops it (acks-then-returns → silent loss). The interim fix is
to emit a proper `gw`-wrapped message addressed to a real proactor peer
(`Bid` → the MarketMaker; the rest → the scada); the durable fix is a true
broadcast once the LTN is itself a gwbase actor.

## The hack

`gw_spaceheat/actors/ltn/ltn.py` publishes to the `SCADA_MQTT` link with
`Dst="broadcast"` at **five sites**:

| Line | Payload type | New `to` peer |
| --- | --- | --- |
| 599 | `Bid` | **MarketMaker** (its real consumer) |
| 610 | `FloNextHourPlans` | scada (`s`) |
| 620 | `Glitch` | scada (`s`) |
| 892 | `FloParamsHouse0` | scada (`s`) |
| 1051 | `FloParamsHouse0` | scada (`s`) |

The proactor builds the MQTT topic as
`{envelope_type}/{src}/to/{dst}/{message_type}`
(`gridworks-protocol` `gwproto/topic.py:75`,
`gridworks-proactor` `proactor_implementation.py:161`). `"broadcast"` is **not
a real proactor peer** (peers are short_names like `s`, `a`) and the resulting
wire routing key's leading token is neither a gwbase `MessageCategory`
(`rj`/`rjb`/`gw`) nor anything `parse_routing_key` can interpret. So the key
fails parse on its very first token and `ActorBase.on_message` acks-then-returns
— the same silent-loss mechanism as the short-form `to.s` / `ws` drops, but it
trips one step earlier.

**Prod evidence** (2026-05-27 survey, catch-all `#` on `ear_tx`, per 10 min):
`broadcast.glitch` ×3, `broadcast.flo-next-hour-plans` ×2 — dropped before
`dispatch_message`.

## Why it's a hack (and why a true broadcast is wrong *today*)

The LTN is currently a **proactor/scada actor**, not a gwbase AMQP actor. It
only has the proactor `Message(Src, Dst, Payload)` grammar and a single MQTT
link to its scada. It has no way to emit a real gwbase `rjb` (JsonBroadcast)
envelope — that capability belongs to a gwbase actor. `Dst="broadcast"` was a
stand-in for "fan this out," but on the wire it degrades to an unroutable,
unparseable key.

## Fix direction (decided): address a real peer, `gw`-wrapped

Change the five sites to send a normal `gw`-wrapped message **to a real proactor
peer** instead of the magic `Dst="broadcast"`:

- **`Bid` → the MarketMaker.** The bid's real consumer is the MarketMaker, so it
  addresses the MarketMaker peer. The `to`-class is just a semantic indicator
  (it does not drive delivery — see `MessageCategory` in gwbase), but it carries
  weight, so we make it the *correct* indicator.
- **The other four → the scada,** keeping the proactor short_name **`s`**. An
  `s → scada` rename through the scada/layout code isn't worth the churn for a
  pure semantic indicator (unlike `atn → ltn`, which changed real identity). The
  short_name `s` lives in the scada's hardware layout (today JSON; becoming a
  Sema type, e.g. `gw1.nolan.layout`, on OPS-334).

The proactor encodes `gw/<src>/to/<dst>/<type>`, which the MQTT plugin bridges to
AMQP routing key `gw.<src>.to.<dst>.<type>` — a valid 5-token `GridworksWrapped`
key that gwbase's `WrappedRoutingEnvelope` grammar parses (with the gwbase
tolerance change, since `s` is a short_name; below).

At each site, leave a comment:

```python
# HACK: emitted as a gw-wrapped message to <peer> because the LTN is not yet a
# gwbase actor and cannot publish a real rjb broadcast. Revert to a true
# JsonBroadcast (rjb) once the LTN is ported to a gwbase actor.
```

## Consistency with the gwbase change (REQUIRED — read together)

This fix is **coupled to** the gridworks-base design "gwbase MUST accept current
LTN/SCADA routing keys" (the parser-tolerance change). The scada peer's `Dst` is
a proactor **short_name** (e.g. `s`), so the resulting `to`-class token is `s`,
which the **current** gwbase parser rejects (`s` is not a `RoutingClass`). So:

- The wire key this design produces (`gw.<src>.to.s.<type>`) is parseable **only
  after** the gwbase parser change lands (treat the wrapped `to`-class as an
  opaque short_name, never raise/drop on an unknown one). **Sequencing: gwbase
  tolerance first, then this scada change** — otherwise the messages are still
  dropped, just with a different (parseable-looking) key.
- This design deliberately does **not** ask gwbase's main parser to learn
  `broadcast` as a `MessageCategory`. Removing `Dst="broadcast"` at the source
  stops *new* `broadcast.*` traffic, so the gwbase fast-path parser never has to
  swallow it.
- **The `broadcast.*` tolerance is kept, not retired — a durable `legacy_hack`.**
  Historical `broadcast.*` messages already exist (and more will accumulate until
  this change ships everywhere), and we must be able to **re-apply / load that
  legacy data** later. So the JournalKeeper-side tolerance is a clearly-named,
  *permanent* `legacy_hack` (NOT an interim bridge): an explicitly-labelled
  branch that recognizes the legacy `broadcast.*` shape and routes it to the
  right type, retained so legacy replay/backfill keeps working. It lives in the
  gridworks-journalkeeper domain, kept separate from the main parser so the
  fast path stays clean.

Net: gwbase tolerates legit short-form `to`/`from` class tokens; the LTN stops
emitting *new* no-envelope `broadcast.*` keys; a named `legacy_hack` permanently
recognizes the historical `broadcast.*` shape for replay/backfill. The three
pieces are complementary, not overlapping.

## Resolved decisions

- **Consumers / `to`-peer** — `Bid` → MarketMaker; the other four → scada. (was
  open: "intended consumers".)
- **scada short_name** — keep `s`; no `s → scada` rename (it's only a semantic
  indicator). (was open: "which short_name".)
- **All five sites** are changed (not a subset). (was open.)

## Open questions

- **Exact current wire key** for each site — confirm via the broker mgmt API
  (the survey saw a leading `broadcast` token; reconcile against the
  `{envelope_type}/{src}/to/{dst}/{type}` grammar). The JK `legacy_hack` matches
  a `broadcast` token *anywhere* in the key to stay robust to this until
  confirmed.
- **Port-to-gwbase milestone.** When the LTN becomes a gwbase actor, replace
  these with real `rjb` broadcasts and delete the HACK comments.

## Status / tracking

Accepted · Pass 1 · **Linear OPS-387** (In Progress). On completion, the durable
distillate folds into the relevant `executor/` spec and this design file is
deleted (designs are ephemeral). Sequenced after the gridworks-base
tolerant-parse change publishes.
