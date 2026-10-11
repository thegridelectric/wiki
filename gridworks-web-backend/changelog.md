# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-backend` code repo**. The matching git commit (in
`gridworks-web-backend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

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
