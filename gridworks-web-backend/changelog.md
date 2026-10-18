# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-backend` code repo**. The matching git commit (in
`gridworks-web-backend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-16 — sema snapshots: published-only regen for both packages, the API seed beside its snapshot, and a test that main ships no staging word (OPS-473) <!-- pending commit -->

The regen script builds both vendored snapshots, `api/sema` and
`gateway/sema`, from their own seeds (`<package>/sema_seed_request.yaml`,
per sema's template; the API seed moves from the repo root, where
nothing regenerated it) and no longer passes `--allow-staged`: the sema
spec says a staging snapshot runs only against dev brokers, and web-api2
is production. A new test reads each snapshot's own
`definitions/registry.yaml`, where every word and version it ships has a
status, and fails on `main` when one is not published; off `main` it
reports them and skips. Nothing outside the repo is read, so it runs the
same on GitHub, where a pull request is judged by its target branch. Both snapshots are
regenerated from sema `1c52df0`: `layout.lite` 013 and its staging
closure leave (the gateway seed pins 011 and 012; the API seed's
`include_all_versions` skips staging on its own), and the API seed
drops `gw1.local.control.standby.top.state`, an enum sema withdrew on
2026-10-06 that nothing here reads. With 012 the latest published
version, the versionless `LayoutLite` class is 012 in both packages, so
the summaries' and the gateway's layout unions are `LayoutLite |
LayoutLite011`, and the gateway's system-mode read has no 013 case.

## 2026-10-15 — retire installations: the house list is the TerminalAsset rows of g_nodes; no contact, address or params in any response (OPS-473, `ddeee35` on `jm/retire-installations`)

The `installations`, `customers` and `installers` tables leave journaldb
(gridworks-data migration `e5a1c2d3f4b6`, `gw_data` 0.5.0) and roles
re-key to the TerminalAsset GNodeId. Every query that joined
`installations` for the house list now joins the `g_nodes` projection:
the data-access check and the hourly-electricity query resolve the URL's
house alias to the TA row (`<alias>.ta`) and match it against the role's
`ta_g_node_id` (null still means every house); the session's sys-admin
test reads the same column. The v2 summaries endpoint keys each house by
its TA GNodeId beside the alias, takes `display_name` from the TA row
(gnr owns it), and stops returning `address`, `primary_contact`,
`secondary_contact`, `hardware_layout` and `spaceheat_parameters`; the
layout is the latest `layout.lite` from the journal, decoded through the
codec. Operational params are not on the bus (`scada.params` last seen
2026-03), so the Status section loses that field. The household is in the
private customer store; this database hands out read credentials and
must hold nothing about a person. `gw-data` 0.5.0.

## 2026-10-11 — Realtame gateway goes to tap broker (not prod); decoding through its sema snapshot (OPS-586, `817933c`)

The gateway was the last password client on the prod broker, and it
spoke plaintext: AMQP to `hw1-1:5672` as the default login, so the
password and the whole fleet stream crossed the internet unencrypted. It
now connects to the analytics tap over TLS (`amqps://`, port 5671), a
scheme fixed in code so no `.env` can turn it back to plaintext, and the
tap has no plaintext listener anyway. The tap's Let's Encrypt
certificate verifies against the system CA bundle, so the gateway knows
the encrypted session is with the real tap, with no GridWorks CA file or
client certificate to install. It logs in as `web.gateway`, binds `gw.#`
on `ear_tx` with an exclusive `web.gateway.<uuid>` queue, and decodes
every message it keeps through a
vendored sema snapshot (`gw`, `report.event` 002–004, `layout.lite`
011–013, `snapshot.spaceheat` 003) instead of reading dicts. Every payload
decodes at the version it was sent in, so houses on `layout.lite` 011 and
012 keep their `SystemMode`; a box sending 013 shows none until OPS-542
picks up `gw.house.operating.status`. The password has no default any more, and
the user, host, port and vhost come from `.env`. With the gateway off
prod, OPS-578 can close 5672.
