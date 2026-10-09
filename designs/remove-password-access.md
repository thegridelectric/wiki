# remove-password-access

Status: Draft · Pass 0 · Updated 2026-10-09 · Linear: OPS-578

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
4. **remove-password-access** 5672 and 1883 close when no fleet client sends a
   password; then the default user's password is rotated, since every
   house and LTN held the old one (the password-access close that stays
   in the Linear project).

Do this next: after OPS-392's deployment spoke witnesses one house
through the gate, pick the second house and run step 1 for it.

## Done-when

- Every house and LTN connection on the prod broker carries its
  cert-derived name and has an `auth_events` allow; nothing but the
  management UI authorizes on `internal`.
- A plaintext connect to 5672 and to 1883 is refused.
- A connection without a client cert is refused at the handshake.
