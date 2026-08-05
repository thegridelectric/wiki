# poison-messages (design)

Status: Draft · Pass 0 · Updated 2026-06-11

> What this is: make the event reupload loop poison-tolerant — one
> undecodable persisted event must not flap a link forever — and fix
> the reporting so that telling someone about the problem doesn't feed
> the problem. Change-now item from
> `executor/scada-ltn-link-state.md`; deliberately independent of the
> proactor overhaul.

## The gap

Verified 2026-06-10 on the dev rabbit: five events persisted before a
type-version bump could not be decoded by the LTN. The LTN's decode
failure produced silence (no nack, no ack), so the scada re-uploaded
the same five events every cycle (39 reuploads started, zero
completed) and the link flapped at the 5 s ack-timeout period
indefinitely.

**The reporting compounds the problem.** The ProblemEvents and comm
events generated *about* the flap are themselves AckRequired — they
join the same reupload queue on the same flapping link. The failure
reporter feeds the failure. Maxim (now in GridWorks_CLAUDE.md):
**if it flaps, skip the acks.**

## What gets built

0. **NOW — validate-at-boot cull (clears the known flap class).** The
   reupload today sends persisted bytes verbatim — the scada never
   tries to read its own stored events, which is why it can't notice
   they're poison. Add: at boot, decode each persisted event with the
   current types; **delete what fails** (scada and LTN run the same
   gwsproto, so what the scada can't read the LTN can't either).
   Scada-code-only, deployable by ordinary hand-pull, no update
   machinery needed. Items 1–3 below remain for the residual class
   (receiver-side failures the sender's own types can't predict).

1. **Skip-after-N / dead-letter in the reupload loop.** An event that
   has been sent N times without ack is quarantined: moved from the
   live store to a dead-letter directory (kept, not deleted — it is
   evidence), and the reupload proceeds without it. The loop always
   converges.
2. **Report the quarantine via `glitch`, not ack-required.** The
   flapping scenario is definitely a case for the glitch type: one
   glitch naming the quarantined events and the suspected cause,
   emitted on the fire-and-forget delivery class (shared with the
   ally-inactive design — same seam, two consumers). No ack demanded.
3. **An ack-policy axis per message kind — inverted default (decided
   2026-06-11).** Today everything event-like is AckRequired. The
   ruling: **nothing requires acks unless it backs a contract.** The
   startup/comm-state events (mqtt.connect, fully.subscribed,
   peer.active, response.timeout, startup, shutdown) stop demanding
   acks entirely — once the link works, the state-machine story has no
   audience, and a durable archive of transport self-narration is not
   accounting. Ack-required survives only for contract-backing data
   (report.event and kin) and the rare must-arrive alert; pings keep
   their ack (that ack IS the keepalive). Each ack-required type
   justifies itself in a small table in the code, not folklore. Field
   evidence for the ruling: in years of operation the persisted
   transition archive has never been consulted — and when the comm
   layer finally did misbehave (the 2026-06-10 flap), diagnosis came
   from local process logs and a live broker tap. The acked archive
   did contribute — a large net negative: it was the poison. Troubleshooting needs
   logs on the box and eyes on the broker, not acked persistence. Side
   effect: the poison surface shrinks to the few types that still
   persist-and-reupload.
4. **Ack-timeout loosening, riding along:** the 5 s
   `ack_timeout_seconds` shipped an order of magnitude tighter than the
   design intent (~1 min, "gross"). Loosen toward intent — it shrinks
   flap frequency in any residual pathology and costs nothing. (Can
   split out as a nit if the rest of the design waits.)

## Explicitly out of scope

- Receiver-side tolerant decode — **coming anyway**: the LTN is going
  gwbase, which is naturally tolerant (the tolerant parser + JK
  `legacy_hack` precedent). This design makes the *sender* converge
  even against a silent receiver, which stays necessary regardless.
- The store epoch gate that prevents this poison class from being
  created at update time (decided elsewhere).
- The proactor overhaul.

## Acceptance

Replay the 2026-06-10 scenario (stale-version events seeded in the
store, both processes on the dev rabbit):

- The link comes up and stays up — no 5 s flap.
- After N attempts the poison events sit in the dead-letter dir; the
  reupload completes; `Reuploads started` stops climbing.
- Exactly one glitch about the quarantine is visible to a catch-all
  broker observer, and it demanded no ack.
- A healthy event stream (fresh events) flows normally throughout.

## Relationships

- Gap and evidence: `executor/scada-ltn-link-state.md` (root-cause
  section); when this ships, that doc's poison bullet gets rewritten
  to describe the new behavior and this file is deleted.
- Shares the fire-and-forget delivery seam with the ally-inactive
  design — whichever builds first creates it.
- Code lands in gwproactor (reupload loop, ack policy) + a glitch
  emission; sema involvement only if glitch needs a variant
  (sema word-authoring if so).
