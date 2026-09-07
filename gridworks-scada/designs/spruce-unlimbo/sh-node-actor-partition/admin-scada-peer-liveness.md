# admin-scada-peer-liveness (rope chunk)

Status: Draft · Pass 0 · Updated 2026-09-07 · Linear: OPS-392

> What this is: a chunk of the `sh_node_actor` partition rope, unestimated.
> Hub: [`primary.md`](primary.md).

 Neither side notices a dead link:
the scada holds Admin (auto Dormant) until a fixed 120 s timer, the
client shows "sent" as if in control. Fix shape (below):
`heartbeat.a` in both directions, a missed beat on the scada side
releases Admin within seconds, the client shows live only while its
echo returns; `heartbeat.a` has no gwsproto mirror yet. Matters before
any spruce window where a human is holding the pump; candidate for
the queue ahead of that, graduating with the on-box sender or into
`admin-for-nolan.md`.

## Field evidence and fix shape

**No heartbeat between admin and scada (found 2026-09-05, bench run
4).** The admin link is one-way in practice: the admin client publishes
a dispatch and watches for a few seconds; the scada holds Admin until
its own timeout and never learns whether the operator is still there,
and the operator never learns whether the scada is still listening. On
run 4 the laptop's tunnel had died silently and the first dispatch went
nowhere; nothing on either side said so. An operator can believe they
are controlling a scada they are absolutely not controlling, and the
scada can sit in Admin, its auto machine Dormant, for the whole timeout
with no operator attached. Matters before any spruce window where a
human is holding the pump; it graduates into `admin-for-nolan.md` or its own chunk
(this chunk).

What the scada experienced (`experiments/2026-09-05-dac-output-bench/
boot-2026-09-05-run4.log`, pi time; the client disconnected eight
seconds after its send, and between 23:01:37 and 23:03:32 the scada
logged nothing at all):

```
22:59:42.197 admin:  awaiting_setup_and_peer -- mqtt_suback --> awaiting_peer
23:01:29.244 admin:  awaiting_peer -- message_from_peer --> active
23:01:37.182 [scada] Message from Admin! top_state Admin
23:01:37.183 [scada] AutoGoesDormant: LocalControl -> Dormant
23:01:37.199 [lc] TopGoDormant: Normal -> Dormant
23:01:37.201 [scada] Admin Wakes Up
23:01:37.205 [secondary-010v] Dispatch from admin: volts x10 55 -> code 2200
23:03:32.021 [scada] Trouble with SendLayout: 'NoneType' object has no attribute 'component'
23:03:37.205 Shutting down due to ShutdownMessage, [Signal received: SIGTERM (15)]
23:03:37.287 [scada] Admin timed out! Auto
23:03:37.287 [scada] AutoWakesUp: Dormant -> LocalControl
23:03:37.310 [lc] Set auto.lc.n command tree
```

The admin link never left `active`. The only thing that ends Admin is
a fixed 120 s timer from the last admin message, and here it fired
after SIGTERM had cancelled the tasks, so the auto machine woke and
rewrote the command tree during teardown. The link has a
`send_ping<admin>` task but no peer-liveness rule behind it.

**Preferred shape: `heartbeat.a`** (verified in sema 2026-09-06,
`sema/definitions/types/heartbeat.a/000.yaml`): `MyHex` required,
`YourLastHex` optional, both `hex.char`, names sender-relative so one
type serves both directions. Its extended description scopes it to
"supervisor-tier liveness, not a contract instrument … within a
single trust domain … peers identified by alias and no signing or
non-repudiation is implied", which is exactly what admin↔scada is: an
operator tool and the scada it drives, no money, no umpire. So unlike
the scada↔LTN case (below) the canon needs no amendment. Sketch: the
client beats every N s with a fresh `MyHex` echoing the scada's last;
the scada answers in kind; a missed beat on the scada side releases
Admin (Dormant -> LocalControl the same way the timer does today, but
in seconds, not two minutes); the client shows the link as live only
while its own echo comes back, never "sent". `heartbeat.a` has no
gwsproto mirror yet (`slow_contract_heartbeat.py` is the only
heartbeat there).

**What the wiki already says about scada↔LTN heartbeats** (the
improvements in mind; this admin item is the small sibling):
- `executor/scada-ltn-link-state.md` "The contract-tier heartbeat is a
  separate, unfinished story": `SlowContractHeartbeat` (60 s while a
  contract is live) "is a first rough attempt at what is really
  wanted: a contract-tier heartbeat in the `heartbeat.a` shape"; it
  "has no silence deadline of its own"; the sema wrinkle is that
  `heartbeat.a`'s canon names scada↔LTN contract liveness as "a
  distinct, heavier mechanism … not modeled by this type", so amend
  the canon or mint a sibling (pending, sema-side).
- `research/principles.md`: "A heartbeat that demonstrates liveness
  must be between the SCADA and the LTN", because a cloud operator can
  fake liveness and "an offline SCADA means the contract is broken".
- `explorations/liveness-and-sla.md` "Two heartbeat layers — keep them
  separate" (transport ping vs contract-tier) and "Is application-level
  SCADA↔LTN heartbeating sound? — Yes, conditionally".
- `research/findings.md` F-008 (Joe's unpublished `heartbeat.a/001`
  that deleted the hex pair; decision "Do NOT rename MyHex→SuHex", the
  names are sender-relative) and F-009 (`MyDigit` "is too weak to be
  umpire-grade", a single decimal digit; the hex echo plus signing is
  the umpire-grade path).
- `wiki/designs/proactor-makeover.md` (OPS-428): echoing the peer's hex
  "is a strong proof that, at the application level, the message was
  fully received"; the makeover "may extend `heartbeat.a` or coin a new
  versioned word"; `harden-mqtt-half-open.md` defers "the scada↔LTN
  heartbeat" to it.
- `gridworks-ltn/designs/stand-up-ltn-on-gwbase.md`: the contract-tier
  heartbeat rides the gwbase LTN's `gw` envelope.
- **The issue that finishes the arc:** OPS-317, scada-health-diagnostics
  (folds OPS-410). Today neither side declares the scada↔LTN link down;
  the executor's "Improvement seed" is exactly that: a fire-and-forget
  `ally.inactive` / `ally.active` published on the links that still
  work the moment a peer goes away, plus the persisted liveness signal
  set for a JournalKeeper referee. The admin link needs the same two
  things one tier down, so this item is best folded into OPS-317's
  scope or named there in prose rather than opened on its own.
- Vision (`transactive-grid.md`): "price and weather move through the
  system as a shared heartbeat", a different sense of the word.
