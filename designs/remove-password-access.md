# remove-password-access

Status: Draft · Pass 0 · Updated 2026-10-10 · Linear: OPS-578

**EDD: yes** each flip is witnessed on the prod broker (the client's connection under its cert-derived name and its `auth_events` allow) and the final notches by a refused plaintext connect.

> What this is: the design that turns off password access to the prod
> broker. The platform services already authorize through FIS on cert
> plus claims; this moves the house scadas and LTNs the same way, then
> requires a client cert and closes the plaintext listeners.

## Why

On MQTT an explicit username and password outranks the cert-derived
name, so every live password user is a bypass of the certificate as the
identity (FIS executor "Rabbit config (the broker side; conf owned by
rmqbot)"). A leaked login with publish
rights can also drive the broker into its memory alarm, which blocks
every publisher. The gate cannot be called the single security mechanism
while a password still opens a connection.

## Starting point

- Gate on `hw1-1`; weather, gnr, gjk, ear, gnr-ear, the alerter and its
  prober on cert plus claims (gridworks-infra `rmqbot/rmq-docker/README.md`
  "Prod gate cutover, 2026-10 (record)").
- Houses and LTNs present certs already (CN = GNodeId) but still send
  the broker's default user's name and password, so the broker
  authorizes them on `internal`. There are no per-house users: the
  broker holds exactly two password users, the default login
  (management UI and break-glass) and `analytics.ear.reader`
  (`rabbitmqctl list_users` on `hw1-1`, 2026-10-09), and every house and
  LTN carries the default login's password in its config today.
- The proactor fork `v4.1.13+jm3` sets the upstream MQTT `client_id` to
  the per-process instance id FIS requires, witnessed on a dev scada
  against the gated dev broker. The houses' first gated connect is OPS-392's
  deployment spoke; this design starts after it.
- The scada pins `+jm3` on `main` and `actual-spruce` (merged
  2026-10-08), so a house picks the new `client_id` up at its next pull.

## Plan

One client at a time, each a bounded cutover the human runs; a straggler
delays the last two steps and breaks nothing.

1. **house flips** six house scadas on `main` (spruce on
   `actual-spruce`): pull the `+jm3` pin, drop the username and password
   from the scada's broker config so the cert name is the login,
   restart, witness the allow in `auth_events`. elm after **elm-row**:
   its scada cert recorded in the cert inventory and its FIS principal
   row when its pi is reachable. Once the tool has issued a house cert,
   `getkeys.py` comes out of the scada repo with a README pointer at the
   tool: a cert cut outside the tool is one the ledger cannot revoke.
2. **ltn flips** six LTNs on the two LTN boxes, same shape (restart
   snippet in gridworks-infra `ltn/README.md`); the LTN's cert CN is its
   own GNodeId.
3. **require-certs** `fail_if_no_peer_cert = true` in the box's
   `advanced.config`, a recreate per the rmqbot instance-README, once the
   broker log shows every client presenting a cert.
4. **remove-password-access** 5672 and 1883 close when no client sends a
   password; then the default user's password is rotated, since every
   house and LTN held the old one (the password-access close that stays
   in the Linear project). The last password client is the web realtime
   gateway on plaintext 5672; it leaves prod for the analytics tap broker
   (fed by a one-way shovel, since FIS cannot mint a read-only identity)
   under OPS-542, not by a cert of its own. This step waits on that move.

Flipped and witnessed (step 1):

- **oak** 2026-10-10 06:59 ET. Pull to `a70c10ea` and `mkenv-pi.sh`
  (proactor `+jm3`), the two `SCADA_GRIDWORKS_MQTT__USERNAME` /
  `__PASSWORD` lines commented out, restart. Broker lists the MQTT
  connection with user = cert CN `fbbea6a1-…` on 8883; FIS log on the
  broker box: `auth/user allow (superseded)`, `auth/vhost allow`, topic
  allows on the oak scada's write aliases; the scada's `gridworks_mqtt`
  link active one second later. oak2 pulled and rebuilt the same morning
  (it never reaches the broker; it feeds oak over local MQTT).
- **beech** 2026-10-10 07:02 ET, same recipe. Broker lists user = cert
  CN `19ee09df-…` on 8883; FIS `auth/user allow (superseded)` and
  `auth/vhost allow`; link active within a second.
- **fir** 2026-10-10 07:03 ET, same recipe; user = cert CN `53de05b6-…`,
  FIS allow (superseded) and vhost allow, link active within a second.
- **maple** 2026-10-10 07:11 ET, same recipe; user = cert CN
  `6267013a-…`, FIS allow (superseded) and vhost allow, link active.
- **spruce** 2026-10-10 07:12 ET, `actual-spruce` at `50e59e5e`, same
  recipe; user = cert CN `9024e45e-…`, FIS allow (superseded) and vhost
  allow, link active.
- **maple LTN** 2026-10-10 17:37 ET (step 2): `~/ltn-maple/gridworks-scada`
  at `a70c10ea`, proactor `+jm3`, the two `LTN_SCADA_MQTT__USERNAME` /
  `__PASSWORD` lines commented out, REPL restarted in its tmux session;
  broker lists user = cert CN `793ca985-…` on 8883, FIS allow (superseded)
  and vhost allow.
- **oak LTN** 2026-10-10 17:38 ET, same recipe on `ltn`; user = cert CN
  `b759f5bb-…`, FIS allow (superseded) and vhost allow.
- **beech LTN** 2026-10-10 17:38 ET, same recipe on `ltn2`; user = cert
  CN `4da8659f-…`, FIS allow.
- **elm LTN** 2026-10-10 17:44 ET and **fir LTN** 17:45 ET, same recipe on
  `ltn2`; users = cert CNs `d78d1f39-…` and `db350a9b-…`, FIS allow
  (superseded) each.
- **spruce LTN** 2026-10-10 18:15 ET on `ltn2`: checkout fast-forwarded
  from `jm/spruce` to `actual-spruce` `50e59e5e`, venv rebuilt (proactor
  `+jm3`), the two login lines commented out, REPL restarted; user = cert
  CN `fde9fa11-…` on 8883, FIS allow (superseded), vhost allow, topic
  allows. Its layout is still January's; a later tidy.

A house pulls, rebuilds its venv with `tools/mkenv-pi.sh` and restarts
before the flip; a pull without the rebuild leaves the old proactor in
the venv (oak, before its flip). Comment the two lines out or delete
them; an empty value still sends a username.

One password login remains on the broker (2026-10-10 18:20 ET): the
web-api2 realtime gateway (`gridworks-web-backend`, aiormq, plaintext
5672 from 34.206.144.158). Every house and LTN is on its cert.

Do this next: elm's scada after **elm-row** (its pi was unreachable
2026-10-10). Step 3 (require certs) can go once elm is on its cert, since
the gateway's plaintext 5672 connection presents no cert either way and
`fail_if_no_peer_cert` is a TLS-listener setting. Step 4 waits on
OPS-542 moving the gateway off prod.

## Done-when

- Every house and LTN connection on the prod broker carries its
  cert-derived name and has an `auth_events` allow; nothing but the
  management UI authorizes on `internal`.
- A plaintext connect to 5672 and to 1883 is refused.
- A connection without a client cert is refused at the handshake.
