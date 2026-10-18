# no-data — wean gwalert's check

Status: Draft · Pass 0 · Updated 2026-10-17

> What this is: the one step left on `NoData`: switch off gwalert's
> `no_data` check so no house is paged twice. The kind itself is live
> and specified in `executor/no-data.md`.

## Where it stands

`NoData` has paged through the alerter's tap since 2026-10-15 (oak's
LTN stopped by hand: raised, paged, resolved and closed within the
thresholds, where gwalert's five-minute loop missed the outage). gwalert's
`check_no_data` (`alert_generator.py:682`) still runs beside it, so a
silent house pages twice, once under the alerter's `AlertId` and once
under gwalert's per-day alias.

That oak window is the executor's first trace: the spec and the expected
two `gw.alert` records are `executor/traces/2026-10-15-oak-ltn-stop/`,
the input is materialised by `experiments/traces/pull_trace.py` from the
journal (13 reports and 2 layouts from oak's scada, every body decoded
through a snapshot built from the executor's seed copy). The journal has
the LTN's hourly glitch and none of its pings or acks, so the cause
clause's "ltn speaking" is not exercised yet. Decoding the wider window
also showed every `report.event/003` from spruce refused by that
snapshot. Chased 2026-10-17: the deployed alerter decodes as sent
(`auto_upgrade=False`, `alerter_actor.py:252`) and stores spruce every
report, so no NoData fires for spruce because none is due. The trace
snapshot auto-upgraded 003 to 004, and the 003 → 004 upgrade in sema was
a bare version bump, so a field 003 whose MessageId differs from
Report.Id failed the reinstated ReportIdentityPropagation axiom. Fixed in
sema on `jm/report-event-003-upgrade` (the upgrade takes the report's id
and created time; a live spruce 003 is a fixture); `pull_trace.py`
decodes green once the executor's seed snapshot is rebuilt from that.

## Do this next

1. Compare a week of both: the alerter's `gw.alert` rows in the journal
   (`NoData`, Firing and Resolved) against gwalert's `[ALERT] <house>: No
   data` lines in `journalctl -u gridworks-alerts` on the box. Every
   gwalert page should have an alerter Firing earlier or within one
   tick; list any that do not and say why (a house outside the fleet
   roots, a house silenced, a scada with no registry row).
2. With nothing missed, comment the `check_no_data` call out of
   `AlertGenerator.main` in gwalert (the way `check_in_atn` already is),
   commit on a `jm/` branch, deploy by pull and restart of
   `gridworks-alerts`, and note it in the changelog.
3. Settle spruce before trusting the comparison: find which of the three
   explanations holds for the refused 003 reports, and if the axiom is
   the fault, raise it with sema (a version published before June 2026
   may be corrected in place when shipped wire data proves it wrong).
4. Complete the trace: pull oak's LTN pings and acks for the window from
   the S3 eventstore by hand and merge them into the materialised input,
   so the clause table's "scada speaking; ltn silent" row is exercised.
5. Watch one more week. The alerter's `NoData` is then the only no-data
   page, and the kind is Verified when the shadow week is clean and the
   trace replays green against the alerter (the bar in
   `wiki/executor-CLAUDE.md`; the replay harness under
   `experiments/traces/` is still to be written).

## What stays a page at scale

A homeowner's internet outage (the scada-silent cause) becomes a
displayed fact, routine at a hundred homes, the readings held on the
scada and uploaded on return, nothing to act on from the cloud. An LTN
not up (the ltn-silent cause, and a fleet of them when an LTN box goes
down) is always a page: the LTN is the house's controller and the
platform's responsibility. A scada speaking but not sending its
reports (both speaking) is always a page: a fault in our code or
broker path on a house that looks healthy from outside, which nothing
but an alert finds. This routing belongs to the tap's paging rules, not
to the kind.
