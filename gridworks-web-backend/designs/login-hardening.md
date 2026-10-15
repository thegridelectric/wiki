# login-hardening — the dashboard earns its PII reads

Status: Draft · Pass 0 · Updated 2026-10-15 · Linear: OPS-600

**EDD: no** build-out on the login path; verified by the suite plus the
four checks under Verification against the deployed web-api box.

> What this is: the web-backend login reaches the bar for showing a
> customer's name and address, auth leaves journaldb, and only then does
> web-backend get a read-only role on the private `gridworks-pii` store
> so the dashboard's Address and Contact sections return. Depends on
> OPS-473: the store exists and roles already key on the TerminalAsset
> GNodeId; that design's Address and Contact sections stay dark until
> this ships.

## Do this next

Nothing until OPS-473's cedar onboarding has run. Then start with the
identity database and the sessions table, which every other step depends
on.

## Why the dashboard waits

The login today (read 2026-10-15): bcrypt hashes, a signed JSON Web
Token over one server secret, TLS at the edge, per-house role checks on
the summaries endpoint. And: tokens live seven days with no revocation,
token checks never consult the database, no rate limit or lockout on
either login endpoint, shared accounts named by role, two login paths
(v1 against a back-office database, v2 against journaldb), hashes in
the analytics database whose read credentials are the thing handed out.
A week-long bearer token reading every customer an admin role covers is
the credential strength FIS invariant 5 rejects for commands, and a
name plus address is at least as sensitive as a relay command. So the
new store is never read over the old login.

## The steps

1. **Identity database.** `users`, `sessions`, `user_installation_roles`
   in web-backend's own small Postgres on the pii box (loopback, LUKS,
   the same backup). The analytics read credentials never see a hash or
   a session again.
2. **Revocable sessions.** An opaque random session token in a sessions
   table, looked up on every request, so logout, deactivation and an
   operator's "kill this session" take effect at once. Expiry on the
   order of hours with an idle timeout.
3. **Login throttle.** Failed attempts counted per username and per
   source address, backoff after a handful, the lockout logged.
4. **One account per person**, named for the person, with the per-house
   roles as today. The shared `admin` and `beech-user` logins go away,
   so the PII change record can say who looked.
5. **One login path.** v1 and v2 collapse to one verify function and one
   store.
6. **Operator-set passwords** of reasonable length, set and reset through
   the gridworks-pii CLI (`set-password`). No self-service reset.
7. **The read-only role.** Web-backend holds a read-only role on the
   `pii` schema, reached over a tunnel it keeps up itself (a systemd
   managed `ssh -L` from the web-api box); the store still has no public
   listener. The summaries endpoint returns contact and address for the
   houses the caller's role covers, and the Address and Contact sections
   come back.

Not in these steps: passkeys and per-act step-up. They arrive with a
web-based PII write path, if one is ever wanted, and FIS invariant 5
describes the bar.

## Verification

The suite plus: a revoked session is refused on the next request; six
failed logins lock the account and the lockout is logged; the journaldb
`gw_visualizer` role can no longer select from `users`; the Information
page shows a contact only to a user with a role on that house.
