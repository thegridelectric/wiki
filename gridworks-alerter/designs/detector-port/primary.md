# detector-port — every house alert on the broker alerter

Status: Draft · Pass 0 · Updated 2026-10-19 · Linear: OPS-602

**EDD: yes** each kind reaches Verified by a witness on the dev broker
(a mocked scada driving the condition, the alerter restarted while the
alert is open) and then a shadow week beside gwalert on the alerts box
against hw1, the two outputs compared, and the kind's recorded trace
replayed green; the port is done when gwalert raises nothing the alerter
does not.

> What this is: the plan to move each house alert kind from the legacy
> journal-polling gwalert to the broker alerter, one spoke per kind,
> each one sema-typed and written for every layout the fall brings,
> then retire gwalert.

## The pattern

Use the no-data port as the template for every kind. The recommended
pattern: make the alert on the alerter, let it run beside the legacy
gwalert alert for a while so the two can be compared, then retire the
legacy alert. (The `NoData` alert has been running beside gwalert's
since 2026-10-15 and the legacy `no_data` check can safely be retired
now.)

## Read first

- [alerter README](https://github.com/thegridelectric/gridworks-alerter/blob/main/README.md):
  what the alerter is, its three services, the kinds it raises, how it
  is put together.
- [the alerter on the broker](https://github.com/thegridelectric/gridworks-infra/blob/main/rmqbot/platform-service-example.md):
  what being on the production system means for a platform service and
  how the actor connects, which exchanges it uses and how it hears the
  whole fleet.
- [the alerts box](https://github.com/thegridelectric/gridworks-infra/blob/main/alerts/instance-README.md):
  where the alerter runs in production beside the legacy gwalert, and
  how to deploy and restart it.
  - It describes the mechanism for silencing certain houses: the
    silences file's path on the box, a sample, and how to edit it.
- [core alerter actor script](https://github.com/thegridelectric/gridworks-alerter/blob/main/src/gwalerter/alerter_actor.py):
  the actor that binds to the audit exchange, keeps the store and runs
  the rules on a tick.
- [NoData](https://github.com/thegridelectric/gridworks-alerter/blob/main/src/gwalerter/no_data.py):
  the one rule that is live. Note: replaced `NoData` with three kinds, `ScadaSilent`,
  `LtnSilent` and `NoData`. All three are one condition: no readings
  arriving from a tracked house's scada for longer than the silence
  threshold. Readings come in report events, and a scada stops sending
  report events, while still sending snapshots, when it is not talking
  to its LTN. So the kind says which party has gone quiet:
  - `ScadaSilent`: nothing has been heard from the scada at all. The
    house side is down, usually the homeowner's internet.
  - `LtnSilent`: the scada is speaking and its LTN is not. The reports
    are safe on the scada's disk and upload when the LTN returns, but
    the house is without its controller.
  - `NoData`: both are speaking and no reports arrive. A fault between
    two live parties, in our code or broker path, which nothing but an
    alert finds.

  An open alert whose cause moves keeps its id and changes kind.

## Spokes

### Now

- ✅ DONE no-data — the silence trio (`ScadaSilent`, `LtnSilent`,
  `NoData`), live on the alerter since 2026-10-15.
- [`critical-glitch.md`](critical-glitch.md) — the scada's own
  Critical glitch relayed. Next: the `glitch` word is published and
  unchanged by the merge below, and once this kind is live the zone
  conditions the scada judges page through it.
- [`scada-reboot-loop.md`](scada-reboot-loop.md) — layouts arriving in
  a loop. Counts arrivals of the layout word whatever its version, so
  it does not wait on the merge.

### On scada `main` since 2026-10-26

Scada `main` (`50da8d28`) ships `layout.lite` 013 and the new layout
words (the hydronic layout, the water store, the zone call circuits),
the heat pump's behaviour in sema, operational params with the tariff,
and the scada's own Critical glitches for a cold critical zone and a
freezing zone. Each of these reads something it changes.

- [`no-dist-flow.md`](no-dist-flow.md) — a heat call ended with no
  distribution flow. The heat-call channels and their meaning come
  from the new zone words.
- [`no-store-flow.md`](no-store-flow.md) — store pump on, no store flow;
  only where a store pump exists. The store pump's role comes from the
  new water-store word.
- [`hp-not-responding.md`](hp-not-responding.md) — heat pump commanded
  on, no power. Starts with a review of how the heat pump's behaviour
  is captured in sema.
- [`hp-running-onpeak.md`](hp-running-onpeak.md) — heat pump power in a
  weekday on-peak hour. The on-peak schedule is the tariff in the
  operational params.
- Likely to go rather than be ported:
  - [`zone-freeze-risk.md`](zone-freeze-risk.md) — a zone below 40 F.
    The merge has the scada raise it as a Critical glitch; then it is
    covered by `critical-glitch.md` and this spoke is deleted.
  - [`zone-below-setpoint.md`](zone-below-setpoint.md) — a critical
    zone below its setpoint. Same merge, same Critical glitch, same
    fate.
  - [`local-control-active.md`](local-control-active.md) — the house
    on local control. Almost certainly removed: gwalert's check is
    disabled, the fallback is by design, and the LTN-silent case is
    already a kind.

## Last

[`retire-gwalert.md`](retire-gwalert.md): the `gw_alerts` role, the
unit, the façade, the repo, once every kind gwalert still raises is on
the alerter.
