# Supervisor service

Status: Draft · Pass 0 · Updated 2026-11-18 · Linear: OPS-695

**EDD: yes** verified by an experiment on the dev broker: N stand-in LTNs
and one Supervisor; pausing one child (`SIGSTOP`) produces a glitch within
the miss threshold, resuming it clears the glitch, and the Supervisor
dropping its own broker link produces no verdict about any child.

> What this is: the first real Supervisor, the control-plane service every
> gwbase Orchestrator already names and answers but which nobody has built.
> Its first job is to watch the fleet of per-house LTN processes.

## Problem

Every GNode on the broker is one process with one GNodeAlias, one registry
row and one cert. The FIS gate leases that cert to one running instance; a
second process presenting it supersedes the first, and a superseded
instance is refused thereafter. Bids and, next, trading rights check the
sender against the GNodeAlias inside the message. So one process may not
speak for several houses, and the fleet of six (then twenty, then a hundred)
houses is N LTN processes.

N processes need one place that knows they are alive and says so when they
are not. The child side of that exists: every Orchestrator requires
`my_super_alias`, auto-pongs a `heartbeat.a` from that alias and fires
`on_supervisor_heartbeat`
([`orchestrator.py:53-72`](../../../gridworks-base/src/gwbase/orchestrator.py),
`207-223`). Nothing exists on the other end. The only Supervisor code is the
`TinySupervisor` demo in
[`hello_rabbit.py:96-140`](../../../gridworks-base/hello_rabbit.py) and test
stubs.

## Requirements

Two, and the design must meet both.

1. **Identity.** One LTN process per house, each with its own `.env`, alias
   and cert. The Supervisor never speaks for a house.
2. **Operations.** One thing to deploy, one command to roll, one log to
   watch, for six houses and for a hundred. Fewer moving parts, less
   processing, is a real requirement and the reason a single LTN for many
   houses was attractive.

## Decisions

- **The Supervisor is not a GNode.** It is an `Orchestrator` with
  `ServiceSettings` and `TransportClass.Supervisor`, identified by alias
  only, with its own FIS Service principal and cert
  (gwbase executor `primary.md` "Invariants" item 25; gwbase executor
  `actors.md` "Service kinds"). Alias under the universe root: `hw1.super1`
  in production, `d1.super1` on the dev broker (the value gridworks-ltn's
  `template.env` already names).
- **systemd owns the processes.** Each house is an instance of one template
  unit, `gwltn@<house>`, the shape the ltn box runs today. The Supervisor
  is one more unit. It starts nothing. This is the gwbase deployment
  convention (gwbase executor `service-deployment.md`: one unit per service
  process, template units for multi-instance services, our services run
  native).
- **Version one restarts nothing.** A missed heartbeat is ambiguous: the
  child, the broker, or the Supervisor's own link may be the one that is
  down. Under the FIS gate a restart while the old process lives is a lease
  takeover, and the old instance is then refused. A restart action, if one
  is ever wanted, is a later design with its own experiment.
- **Reporting is fire-and-forget glitches**, so the ear and the
  journalkeeper record them. Warning for one silent child; a higher
  severity when every child is silent. No problem events: nobody needs to
  ack a liveness verdict.
- **The heartbeat is the existing word.** `heartbeat.a/000` in both
  directions: the Supervisor sends a fresh `MyHex` and the child's last
  `MyHex` as `YourLastHex`; it accepts a pong only when the pong's
  `YourLastHex` equals the hex it just sent.

## Open

Settle these at the grill before any code.

1. **Roster source.** Where the Supervisor learns its children: an env list,
   a registry query (every LTN whose supervisor is me), or the infra roster.
2. **Period and threshold.** Heartbeat period `T`, missed beats `K` before a
   verdict, and the glitch severities.
3. **Supervisor silence on the child side.** Today a child cannot notice a
   quiet supervisor. Whether it should, and what it would do.
4. **Who supervises the Supervisor**, and which time coordinator alias it
   uses in real time (`hw1.time`).
5. **Repo home.** A new `gridworks-supervisor` repo, or a service inside
   `gridworks-base`. The executor home follows.
6. **Scale.** Confirm a hundred `gwltn@` instances on one box is fine for
   systemd and the broker before anything else is considered.

## Out of scope

- Process management of any kind (spawning, restarting, memory caps).
  systemd has it.
- A dev-laptop launcher for N LTNs (no systemd there). That is a dev-stack
  recipe item, kept apart from this service.
- The LTN port itself. The Supervisor's first live children are the
  gwbase LTNs, so the port ships first; the Supervisor is built and tested
  against stand-ins on the dev broker in the meantime.

## Plan

1. Grill this design to Accepted, Pass 1.
2. One pairing hour: `orchestrator.py`, `hello_rabbit.py`, and how
   `gridworks-ltn` reads `GWLTN_SUPER_ALIAS`.
3. Repo scaffold on the gwbase service pattern (uv, `ci.sh` with ruff and
   pyright, vendored sema snapshot, `ServiceSettings` subclass with its own
   prefix, `service/` unit, README).
4. The actor: roster, timer, ping, pong check, miss count, glitch.
5. The experiment above, as a re-runnable harness against the dev broker.
6. Unit on the ltn box, principal and cert (minted by the human), infra
   README, executor section, changelog.

Effort: 28 h point, 18 to 45 h at 90%, for an engineer experienced in actor
systems and new to gwbase. Design time is extra.

## Do this next

Grill the six Open items with the person building it. Items 1 and 5 decide
the scaffold.
