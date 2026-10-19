# detector-port — every house alert on the broker alerter

Status: Draft · Pass 0 · Updated 2026-10-17 · Linear: OPS-602

**EDD: yes** each kind reaches Verified by a witness on the dev broker
(a mocked scada driving the condition, the alerter restarted while the
alert is open) and then a shadow week beside gwalert on the alerts box
against hw1, the two outputs compared, and the kind's recorded trace
replayed green; the port is done when gwalert raises nothing the alerter
does not.

> What this is: the plan to move each house alert kind from the legacy
> journal-polling gwalert to the broker alerter, one spoke per kind,
> each one sema-typed and written for every layout the fall brings,
> then retire gwalert. The spec of what is already live is
> `executor/primary.md`.

**▶ Active spoke: [`no-data.md`](no-data.md)**

## Spokes, in order

1. **[`no-data.md`](no-data.md)** — live on the alerter; switch off gwalert's
   `no_data` once the overlap shows nothing missed.
2. [`zone-freeze-risk.md`](zone-freeze-risk.md) — a zone below 40 F.
3. [`zone-below-setpoint.md`](zone-below-setpoint.md) — a critical zone
   below its setpoint, gated on the setpoint phase.
4. [`hp-not-responding.md`](hp-not-responding.md) — heat pump commanded
   on, no power.
5. [`scada-reboot-loop.md`](scada-reboot-loop.md) — layouts arriving in a
   loop.
6. [`critical-glitch.md`](critical-glitch.md) — the scada's own Critical
   glitch relayed.
7. [`no-dist-flow.md`](no-dist-flow.md) — a heat call ended with no
   distribution flow.
8. [`no-store-flow.md`](no-store-flow.md) — store pump on, no store flow;
   only where a store pump exists.
9. [`hp-running-onpeak.md`](hp-running-onpeak.md) — heat pump power in a
   weekday on-peak hour.
10. [`local-control-active.md`](local-control-active.md) — the house on
    local control; needs a definition first.
11. [`retire-gwalert.md`](retire-gwalert.md) — the `gw_alerts` role, the
    unit, the façade, the repo.

## Invariants of the port

Every spoke follows these; a spoke states only what is particular to
its kind.

- **The rule reads the store, never a house.** A kind is a function of
  the store's tables (`readings`, `layouts`, `arrivals`, `g_nodes`,
  `alerts`) evaluated on the detector tick, the raise and the resolve
  both. Nothing polls and nothing runs in dispatch.
- **Meaning comes from sema, never from a name.** A reading's unit and
  exponent come from its channel in the stored `layout.lite`; a
  relay's role from the layout's relay config; a zone's criticality
  from the layout's critical zone list; a state from the state word.
  A rule that matches on a channel-name substring is the defect
  gwalert had (OPS-544) and is not ported.
- **Equipment is a layout fact.** A kind that needs a store pump, a
  distribution flow meter, a heat pump indoor unit or a thermostat
  fires only for a house whose layout has that thing; where it does
  not, the kind is simply absent for that house, not a missing-data
  log line. `houses_with_monobloc`, `ignored_house_aliases`, the
  spruce setpoint special case and `'maple' in house_alias` do not
  come over; what they encode becomes a layout fact or a silence.
  Two of the fall's installs have no iso valve and no buffer tank and
  one has no water tanks at all.
- **Thresholds are settings, named in the kind's description.** Never
  in the record, never inline. gwalert's are all hard-coded in
  `AlertGenerator.__init__`; each spoke names its own and its unit.
- **Each kind is a transition pair.** One `Firing` when the condition
  starts to hold, one `Resolved` under the same `AlertId` when it
  stops, so Opsgenie opens and closes with the condition and a second
  outage the same day pages again. Kinds that gwalert raised as a
  moment (a glitch, an on-peak hour) need a resolve rule, stated in
  the spoke.
- **Test first, then witness, then shadow.** Each spoke has its unit
  tests written before the rule (the condition, the clear, a restart
  with the alert open, the layout without the equipment), the
  dev-broker witness as `experiments/<date>-alerter-<kind>/`, and a
  shadow week against gwalert's output before gwalert's check is
  switched off. No house is paged twice for one condition.
- **Scada glitches that judge the same condition.** The scada raises
  its own critical-zone-cold and zone-freezing glitches on the box.
  A spoke whose condition the scada already judges says which side is
  the page and which is the evidence, and does not duplicate the page.

## Notes

- gwalert's checks and what each reads: `../../legacy/gwalert.md` and
  `alert_generator.py` (the per-check inventory is in each spoke).
- `no_more_oil` is dead in gwalert (returns on its first line) and is
  not ported until someone defines it.
