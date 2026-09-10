# admin-on-the-fabric

Status: Draft · Pass 0 · Updated 2026-09-09 · Linear: OPS-429

**EDD: yes** verified by two operators, each with a personal cert, driving
a real scada through `hw1.admin` on the prod broker: the session opens,
beats, is taken over by the second, and dies within seconds when the
first operator's link is cut, every step on `ear`.

> What this is: the small design that moves the admin session
> ([OPS-529](https://linear.app/gridworks/issue/OPS-529)) from the Pi's
> local broker onto the prod broker as `hw1.admin`, over the addressed
> `gw` envelope. Stage 3 of the hub's Stages (`../executor/primary.md`).
> It changes the carrier and adds the cert roster; it does not change a
> word of the session.

## What this stands up

- **`hw1.admin` on the prod broker.** One service-kind Principal, one
  cert, FIS lease per run. Its publishes are pinned to its alias at
  segment 2 like every other principal's; no operator principal kind,
  no per-method permission map.
- **The admin process with a cert roster.** It holds the `hw1.admin`
  cert and the client certs of the humans allowed to drive admin in
  this universe. Humans connect to it over HTTPS with their own cert
  from a CLI or TUI, never a browser. It arbitrates which human is
  behind the identity, relays beats untouched, and drops a human's
  session the instant their socket dies, sending the scada a release.
  Where it runs is open; a first cut on an operator's laptop is
  acceptable so long as it is the same process.
- **Addressed messages.** Admin words ride
  `gw.hw1-admin.to.scada.<scada-alias-lrh>.<type-name>`; the scada
  answers `gw.<scada-alias-lrh>.to.admin.hw1-admin.<type-name>`. The
  header carries `MessageId` and `CreatedAtUnixMs`. `admin` joins
  TransportClass. The envelope, the header version and the scada
  joining the fabric are defined by the proactor makeover
  ([OPS-428](https://linear.app/gridworks/issue/OPS-428)) with the
  header id from message-identity
  ([OPS-502](https://linear.app/gridworks/issue/OPS-502)); this design
  consumes them.
- **The audit word.** Every open, takeover, release and expiry reaches
  `ear` naming the human, the scada, the session and the outcome.
  Whether holder-changed doubles as it or a session-event word is
  minted is decided here, under the sema gate.

## Build order

1. The scada consumes addressed messages and binds on its own alias
   ([OPS-428](https://linear.app/gridworks/issue/OPS-428) delivers
   this; admin is its first second-talker consumer).
2. The `hw1.admin` cert and Principal, minted with the certbot tool
   ([OPS-420](https://linear.app/gridworks/issue/OPS-420) "Minting a
   platform-service cert"); the FIS write rule pins its alias.
3. The admin process gains the `hw1.admin` connection, the cert roster,
   HTTPS with client certs, beat relay and socket-death release.
4. `gwa` becomes the human-side client of that process; the TUI lifts,
   the transport under it changes.
5. Run alongside tailscale on one house, then stop the tailscale path.

## Done-when

- Two operators with personal certs, one after the other, drive a real
  scada through `hw1.admin` on the prod broker; the second's
  take-control ends the first's session and the first's client says so.
- Cutting an operator's link ends the session at the scada within ten
  seconds, witnessed in the scada log and on `ear`.
- A client presenting no roster cert is refused by the admin process;
  a publish from any principal other than `hw1.admin` on an admin word
  is refused by FIS.
- Tailscale carries no admin traffic.

## Depends on

- The proactor makeover
  ([OPS-428](https://linear.app/gridworks/issue/OPS-428)): the
  addressed envelope and the scada in the fabric.
- mtls-fis-auth ([OPS-420](https://linear.app/gridworks/issue/OPS-420)):
  the cert plane and alias pinning, and the production-deploy gate:
  admin SHALL NOT drive a real house's relays over a weaker path.
- The admin session ([OPS-529](https://linear.app/gridworks/issue/OPS-529)):
  every word this carries.
- Message identity ([OPS-502](https://linear.app/gridworks/issue/OPS-502)):
  the header version `CreatedAtUnixMs` rides in.

## Out of scope

- A browser front. Not planned. If it ever comes it follows the hub's
  "A login is never authority" invariant and gets its own design.
