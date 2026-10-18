# retire-gwalert — the last step

Status: Draft · Pass 0 · Updated 2026-10-16

> What this is: what goes when every kind gwalert still raises is on
> the alerter.

## Do this, in order

1. Stop and disable `gridworks-alerts.service` on the alerts box under
   the `alerts` login; watch one week of the alerter alone.
2. Drop the `gw_alerts` role from the journal database (gridworks-data
   creates roles; the drop goes through its migration in dev and prod,
   `gridworks-infra/databases/journaldb.md` for which login does it).
   With it goes the alerter's last read of a database it does not own.
3. The alert-manager and its Caddy façade: already stopped; remove the
   units and the Caddy routes, and the web backend's read of
   `/alerts-history` goes to the journal's `gw.alert` rows (OPS-547
   names the alerts page move).
4. Archive `thegridelectric/gridworks-alerts` (read-only on GitHub),
   delete `legacy/gwalert.md` from the wiki, and move anything still
   true in it (the Opsgenie per-day alias as the reason the alerter
   owns closes) into `executor/`.
5. Update `gridworks-infra/alerts/instance-README.md`: one login, three
   units.
