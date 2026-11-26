# critical-glitch — the scada's own Critical glitch relayed

Status: Accepted · Pass 1 · Updated 2026-11-25

> What this is: the port of gwalert's `check_for_glitches` as the
> alerter's `CriticalGlitch` kind, and the cut-over that removes the
> legacy check.

## The kind

- **Reads:** the `glitch` word (000, published), vendored in the alerter
  snapshot. The glitch arrives on the ear exchange from the scada under
  its own alias (`<house>.scada`), and the house is the tracked
  TerminalAsset behind that alias; an untracked scada's glitch is
  dropped. The actor hands each glitch to the rule as it arrives, so no
  table holds glitches: the alert record is the storage.
- **Fires** on a Critical glitch with the glitch's summary and node as
  the alert summary: `<Summary> [<Node>] (<house>.ta)`. A Warning does
  not page.
- **Hold:** a repeat of the same summary inside `critical_glitch_hold_s`
  (7200 s, matching gwalert's de-duplication) extends the alert; the hold
  passing with no repeat resolves it, since a glitch is a moment and the
  alert is the hold. An alert open across a restart counts its hold from
  `RaisedMs`.
- **One open per house.** A Critical with a different summary while one
  is open supersedes it: the open alert resolves ("superseded by …") and
  the new one raises, so each distinct summary pages once. `Subject`
  stays empty: the word reserves it for alerts about a service or host.
- **Layout:** none.
- **Tests** (`tests/test_critical_glitch.py`): a Critical fires with its
  summary; a Warning does not; an untracked scada is ignored; a repeat
  inside the hold extends without re-raising; the hold passing resolves
  and the same summary afterwards is a new alert; a different summary
  supersedes; a restart counts the hold from the raise; the actor relays
  a wrapped glitch from the broker.

## Cut-over

No shadow period: the relay is stateless, so the dev-broker witness and
the next real Critical are the verification. gwalert's
`check_for_glitches` goes in the same change, with its pump checks
(`check_dist_pump`, `check_store_pump`), which the scada's own pump
doctors now cover: a pump drawing running power under a flow meter that
reads zero is a Warning glitch on the meter's node, and a pump that will
not run is a Critical glitch that pages through this kind. The
`no-dist-flow` and `no-store-flow` spokes are deleted for the same
reason.

## Build status

- 2026-11-25: `CriticalGlitchRule` written with its tests, `glitch` in
  the alerter seed, gwbase at 0.7.3 with `GWALERTER_LOG_TZ` in the
  template; gwalert's glitch and pump checks removed. Awaiting the
  dev-broker witness and the alerts-box deploy.

## Do this next

Witness on the dev broker: a mocked scada under the fleet roots sends one
Critical and one Warning glitch; the alerter raises one `CriticalGlitch`,
the tap pages it once, and the hold resolves it. Then deploy both repos
to the alerts box per its instance-README and add the kind's concern to
the executor (Axioms, Clauses, Bindings, Settings).
