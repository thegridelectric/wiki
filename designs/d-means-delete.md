# A d universe means delete

Status: Accepted · Pass 1 · Updated 2026-11-25 · Linear: OPS-717

**EDD: no** a spec and guardrail change, verified by each repo's suite
and one boot of the simulated stack with its broker on a non-localhost
name: a `d1` service joins, an `hw1` alias is refused.

> What this is: the plan for changing what the `d` universe kind means,
> from "runs on one computer, all comms through localhost" to "all
> simulated, nothing kept, nothing trusted", and for replacing the
> localhost check that was its isolation guarantee. It lists where the
> old meaning is stated, what was decided, the legs and what is open.

## Why

The universe kind is the first letter of a GNodeAlias's first segment.
The authoritative text, the registry executor "Universes", defines `d`
by where it runs: "all comms go through localhost brokers", and makes
that the isolation guarantee. Two boot checks enforce it, and five more
docs restate it.

| Where | What it states |
|---|---|
| `wiki/grid-node-registry/executor/primary.md` "Universes" | `d` = dev, runs on a single computer, all comms through localhost brokers; the isolation guarantee |
| `grid-node-registry/README.md` "Universes" | the same ladder, summarized |
| `wiki/gridworks-base/executor/primary.md` invariant 12, `actors.md` "Every broker URL is checked" | the host is localhost iff the universe is d-kind; a remote dev universe refuses to boot |
| `gridworks-base/src/gwbase/transport_format.py` `is_universe` | the kind constraint (`d`, `h`, exactly `w`), with a note naming the missing sema `universe` format |
| `gridworks-scada/gw_spaceheat/universe.py` | `localhost ⇒ d1`; the alias universe must equal the broker host's |
| `wiki/gridworks-scada/executor/testing.md` "The universe guardrail" | the same, summarized |
| `wiki/gridworks-base/executor/provisioning.md` | "dev = all-localhost" in the ladder line |
| `wiki/world/primary.md` "DNS names" | a `d` universe's broker is inside its own pod or namespace and has no public DNS name |

The simulated stack is moving to a shared box under systemd and podman
(hosting path, milestone 1), and a laptop k3s follows. A `d1` broker
there is reached by a pod or service name, so localhost no longer
describes a `d` universe and the boot checks would refuse the stack.

## Decided (2026-11-25)

- **`d` means delete.** A `d` universe is all simulated. Its data is
  kept by no one and trusted by no one: a reader of a `d` universe's
  data cannot know where it came from. It runs on a laptop offline, on a
  laptop online or on a shared box, and the place makes no difference.
- **No fourth kind.** A fully simulated universe on a shared box is a
  `d` universe. `h` stays the mixed, re-runnable, data-keeping kind with
  no real money; `w` stays the one production universe.
- **`d1` stays** as the name of the usual dev tree, so the simulations
  keep their `d1.*` aliases and the dev seed is unchanged.
- **The kind rule gets its sema word.** A `universe` format: the token
  grammar with the kind constraint, and the three kinds' meaning in its
  description. It retires the kind constraint in gwbase
  `transport_format.is_universe` and is the one place the ladder's
  letters are spelled. `universe.run` is unchanged.

## The isolation guarantee

What `d` promised was that nothing in it can reach a real system or
real money. Localhost gave that for free. The replacement has two parts.

- **What joins.** A `d` universe holds no real asset and no real money.
  The place to say so is the `ta.deed`, whose ValidationState every
  reader consults. Today its one axiom runs the other way
  (SimulatedAssetNeverWorld: a ValidatedSimulatedAsset deed is never on
  a `w` alias), and nothing forbids a real-asset deed on a `d` alias. No
  TaValidator runs yet; every deed in use is written by hand. The
  enforcement is a second axiom on a new `ta.deed` version: if the
  first segment of TaAlias is `d`-kind, ValidationState SHALL be
  UnValidated or ValidatedSimulatedAsset. The generated runtime checks
  axioms at decode, so a `d` scada refuses a real-asset deed at boot
  and the registrar's script cannot write one.
- **Where its broker is.** A `d` universe's broker has no public DNS
  name (`world/primary.md` "DNS names"). At boot a service checks the
  broker URL's host against the alias kind:
  - `d`-kind alias: the host SHALL be a non-public name, which is
    localhost, a single-label name (a pod, compose or namespace service
    such as `rabbit`), or a private address. A public DNS name is
    refused.
  - `h`- or `w`-kind alias: the host SHALL be a public DNS name whose
    first label names the universe and run (`hw1-1`), as today.

  The check keeps what it had: a `d1` service cannot be pointed at
  `hw1-1.electricity.works`, and an `hw1` service cannot be pointed at
  a localhost or pod broker. What it gives up is naming the universe
  from a non-public host: the scada's `localhost ⇒ d1` becomes
  "non-public host ⇒ the alias is d-kind", since a pod broker called
  `rabbit` names no universe. Two `d` universes on one box are told
  apart by their vhost, which the AMQP side already checks and the MQTT
  side cannot see.

## The legs

In order. Each is its own branch and PR in its repo.

1. **sema.** The `universe` format, staged then published under the
   registry rules; the kind meanings in its description. `ta.deed` 001
   with the NoRealAssetInDUniverse axiom above; `ta.deed` 000 is
   published and stays as it is.
2. **Registry text.** The executor "Universes" section states the new
   `d` and the guarantee above; the README summary follows.
3. **gwbase.** Invariant 12 and `actors.md` restate the host rule; the
   boot check implements it; `is_universe` takes the vendored format.
4. **scada.** `universe.py` implements the non-public-host rule and
   drops `DEV_LOCALHOST_UNIVERSE`; `testing.md` follows.
5. **Summaries.** `provisioning.md` and `world/primary.md` agree with
   the registry text.

## Verification

1. sema: the format's examples and counterexamples in its yaml; the
   deed axiom's counterexample (a ValidatedRealAssetAndGps deed on
   `d1.…`); the snapshot regen in gwbase, scada and ltn.
2. gwbase and scada suites, with the boot-check tests rewritten to the
   host rule: localhost `d1` boots, `rabbit` `d1` boots, public-name
   `d1` refuses, localhost `hw1` refuses.
3. The simulated stack boots on the sim box with its broker reached by
   its service name.

## Open

- **Private addresses.** Whether a `d` broker may be reached by a
  private IP at all, or only by localhost and a single-label name. A
  smaller rule is easier to check and to explain.
- **The scada's vhost.** The MQTT side sees no vhost, so a scada cannot
  tell two `d` universes apart. Whether that matters before a second `d`
  universe shares a box.
- **Whether the h/w host rule tightens.** Today the first DNS label is
  parsed for the universe. Whether to require the full
  `<universe>-<run>.<zone>` shape.

## On completion

- The registry executor "Universes" is the one definition; every
  summary points at it and adds nothing.
- The hosting-path project's milestone 1 no longer waits on this.
- This file is deleted and OPS-717 finalized.

## Do this next

Leg 1: read the sema spec and the formats registry and authoring spokes,
post the read-receipt, then draft the `universe` format on a `jm/`
branch of sema.
