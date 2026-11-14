# Pi support tunnel: an on-demand reverse tunnel from a house Pi

Status: Draft · Pass 0 · Updated 2026-11-08 · Linear: OPS-663

**EDD: yes** verified on one house: a tunnel opened by a word over the
live broker, used for a shell session, closed by its window, and nothing
listening on the Pi afterwards (checked from the bastion and from the
Pi's own socket table).

> What this is: how a person reaches a house Pi by hand once the Pi has
> no standing inbound path and is off the tailnet. A word over the broker
> asks the scada to dial out to a bastion on the tailnet; the tunnel
> closes itself after a fixed window; every open and close is a report in
> the journal.

## Relation to code-update

Decided 2026-11-08: the fleet keeps a by-hand access path at every
scale, not only for the first twenty homes. The code-update design
(OPS-401) is amended to match. Its update machinery still provides no
shell, and this tunnel is the one by-hand path onto a house once the
house is off the tailnet.

## Why

Today ssh over the tailnet is the support path and the by-hand update
path to every house Pi, so the tailnet's tagged-resource count is the
house count. The fleet is heading to a Pi that is outbound-only:
code-update delivers software over the broker and production-security
(OPS-662) takes the Pis off the tailnet. A hands-on path for the hard
cases is what this design adds, if the conflict above resolves in its
favour.

## Shape

1. **Trigger.** A sema word asks a named scada to open a tunnel. The
   scada verifies the sender; the broker's cert gate and the FIS
   principal are the first answer to who may send it. The word names the
   window length.
2. **Far end.** A bastion login on a tailnet VM. The Pi dials out with
   its own key and a remote port per house for the session's lifetime;
   the person connects to the bastion over the tailnet and through the
   port.
3. **Lifetime.** The tunnel closes at the window's end or on a close
   word. Nothing listens on the Pi between sessions; the Pi's `sshd` is
   reachable only through the tunnel.
4. **Audit.** Each open and close is a report into the journal naming the
   house, the requesting principal and the window, so the fleet record
   shows who was on which house when.
5. **Handoff.** Proven on one house; then the Pis leave the tailnet
   (OPS-662 step 6) and code-update names this as its support path.

## Open questions

- Which principal class may send the open word, and whether a second
  person's approval is needed at fleet scale.
- The bastion: a login on an existing VM or its own small box.
- Whether the tunnel is plain `ssh -R` from the Pi or Tailscale's own
  ephemeral node joined for the window and removed after it.
