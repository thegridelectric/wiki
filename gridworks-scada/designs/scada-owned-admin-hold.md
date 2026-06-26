# Scada-owned admin hold

Status: Draft · Pass 0 · Updated 2026-06-22 · Linear: OPS-194

**EDD: yes** verified by a real-broker experiment: set a long hold, kill the
admin panel, confirm the relays stay held and the scada reverts exactly at the
deadline — not by code reading.

> What this is: make the admin top-state hold a **scada-owned, scada-reported**
> timeout that survives the panel dropping, with an explicit long / "until
> released" hold, and panels that display the scada's real remaining time
> rather than a local cosmetic countdown.

## Current behavior (verified 2026-06-22)

The scada **already holds admin top-state autonomously** — it does not depend on
the panel staying connected:

- `process_admin_keep_alive` / `process_admin_dispatch` (`scada.py` L450/498/530)
  call `_renew_admin_timeout(TimeoutSeconds)`; `_timeout_admin` (L1562) sleeps
  `timeout_seconds` (capped at `settings.admin.max_timeout_seconds`) then
  `admin_times_out()` → Auto/LocalControl.
- The admin client sets **no MQTT last-will** and the scada has **no
  on-disconnect revert** — admin drops only on timeout or explicit
  `AdminReleaseControl`. So laptop sleep / MQTT drop alone does **not** end the
  hold.

So "admin dies after I walk away" is not a crash — the hold simply lasts the
**last command's `TimeoutSeconds`**, and:

- `DEFAULT_ADMIN_TIMEOUT = 5 min` (`gridworks-admin/.../config.py` L14). A bare
  relay toggle (`set_relay` → `AdminDispatch.TimeoutSeconds`) without setting the
  TimeInput minutes holds only 5 min, then reverts.
- The on-screen `TimerDigits` is purely cosmetic (local `monotonic` countdown);
  it neither drives the scada nor auto-renews. The panel's timer can disagree
  with the scada's real deadline.
- `>24h` → `None` → the scada's `max_timeout_seconds` cap. No clean "hold until
  I release."

## Scope (the rewritten [OPS-194](https://linear.app/gridworks/issue/OPS-194) bullets)

1. **Survive the panel drop — intentionally and tested.** Already true; raise /
   clarify the default and add an explicit **long hold** and a **hold-until-
   released** option (bounded by a safety max).
2. **Scada owns + reports the authority and the remaining time.** The scada
   publishes its admin top-state + remaining hold seconds; the panel displays
   that (replacing the cosmetic timer), so multiple panels stay consistent and
   a reopened panel shows the true remaining time.
3. **Unify per-command timeout vs the session hold** — a quick relay toggle
   should not silently reset the hold to 5 min; decide the semantics (inherit
   the current hold? a minimum floor?).
4. *(consider)* pump doctor running under admin.

## Open

- Reporting channel: extend the snapshot, or a new `admin.status` named type
  carrying top-state + remaining seconds?
- Align the admin `MAX_ADMIN_TIMEOUT` (24h) with the scada
  `max_timeout_seconds`; pick the indefinite-hold safety cap.
- Does "until released" need a periodic re-assert for safety, or is a long
  scada-side timeout enough?

## EDD experiment

Real broker: set a long hold, kill the panel (and separately, sleep/disconnect
MQTT); assert the relays stay held and the scada reverts exactly at the
deadline. Reopen a panel mid-hold; assert it shows the scada's true remaining
time. The re-runnable reproducer behind the eventual `Verified` stamp.
