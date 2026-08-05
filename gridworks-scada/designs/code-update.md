# Code update (design)

Status: Accepted · Pass 1 · Updated 2026-06-11 · Linear: OPS-401

> What this is: the build spec for fleet code update — how scada code
> gets onto houses and what happens to on-disk state when it does. All
> decisions ratified 2026-06-10/11; **not currently scheduled** (high
> priority, queued). A 100-homes gate: hand-imaged SD cards and by-hand
> pulls carried 6 houses; they do not carry 6 → 20 → 100.

## Settled decisions

| Decision | Ruling |
|---|---|
| Pattern | **Pull-based version handshake** over the existing broker; pointer not payload; separate supervisor applies. (Convergent industry pattern: AWS IoT Jobs / LwM2M / Omaha.) |
| Build vs platform | **Build thin in-house.** Per-device platform rent is structurally incompatible with fleet economics at 100+; balena also misfits (remote shell vs no-back-door, their OS, second control plane). RAUC-or-Mender noted as OS-layer escalation checkpoint at ~100 houses. |
| Persisted event store | **Epoch/fingerprint gate at boot**: on protocol-fingerprint mismatch, archive store aside, start clean. Lossy and fine ("this isn't accounting"). No upgrade-on-read. |
| Obligations | Device stores never constitute obligations — the MarketMaker's **stored timestamped ack IS the contract** (see the launch-new-simple-marketmaker design). Wipe is provably harmless. |
| Artifact | **Vendored wheelhouse in the release** (offline `uv sync --frozen`) + **supervisor wheel cache, hash-verified per reuse** (~100 MB release → ~1 MB typical download). |
| Restart safety | Non-issue: relay failsafes are field-proven; house stays warm as long as there is power. ~24 h deferral ceiling is an engineering default, not a safety bound. |
| Remote access | Tailscale on the first ~20 only. **Fleet end-state: NO BACK DOOR** — rollback machinery is the entire remote recovery story; beyond it, you drive out and knock on the front door. |
| Signing | **Deferred to the crypto-key work** (substrate-fit design) — part of the metering-trust fabric ([`metering.md`](../../economy-energy-markets/executor/metering.md)). Interim: sha256 pinning end-to-end, no false precision about signatures. |
| Picos | **Out of scope. No field firmware downloads to picos** (see Boundaries). |
| OS | **Out of scope by posture** (see Boundaries). |
| Wire vocabulary | Own small sema words at build time (sema word-authoring); **NOT layout.lite** (firmware isn't layout). Deliberately under-prescribed until the mechanism is built. |

## Architecture

Four components. Everything safety-critical delegates to proven
machinery: systemd, `rename(2)`, uv, sha256.

### 1 · Release artifact (built by CI)

- **`manifest.json`** — version, code-tarball hash, per-wheel name+hash
  list, the **protocol fingerprint** (hash of the gwsproto type-version
  set, for the store epoch gate), minimum supervisor version.
- **Code tarball** — the app at a tag, version baked in
  (`setuptools_scm`/`_version.py`; extends [OPS-7](https://linear.app/gridworks/issue/OPS-7)'s field-verified git
  detection).
- **Wheels** — fetched individually by name+hash, so the cache works.
- **CI builds on the fleet's OS template image** (same glibc/platform
  tag) — a release can never outrun the fleet OS because it is born on
  it; a toolchain that refuses the template fails in CI, not in a
  basement. Fleet Python is pinned per OS epoch.

### 2 · Supervisor (on the Pi, own systemd unit)

Owns apply; never shares a process with the app. Disk layout:

```
~/gridworks/releases/<version>/   # code + per-release venv
~/gridworks/releases/<version>/.committed   # stamp after health gate
~/gridworks/current  -> releases/<version>  # atomic symlink flip
~/gridworks/wheel-cache/                    # hash-verified reuse
```

Update sequence: `offered → fetch (manifest, tarball, missing wheels;
verify every hash; check SD free space) → install (per-release venv,
uv sync --frozen offline) → await quiescence → flip (rename(2)) →
restart app → commit gate → .committed + announce` — or `revert` at
any failure: flip back to previous committed release, report, never
retry that version.

- **Quiescence**: a defined predicate (state file or broker-visible
  state — pin at build); hard ceiling ~24 h, then proceed with a loud
  `deferred-past-ceiling` event; wedged-scada rule: no answer within
  timeout counts as quiescent after the ceiling.
- **Commit gate = LOCAL health only**: app service up, watchdog
  patting, no crash loop for N minutes. Never broker reachability.
  Boot-counting: M crash-loops in the window → revert.
- **Store epoch gate**: at app boot, store stamp vs running release's
  protocol fingerprint; mismatch → archive store dir aside
  (timestamped) + start clean + loud event.
- **Supervisor self-update**: the supervisor is itself an artifact
  updated by the same flip+gate pattern, plus a dead-simple fallback
  (systemd-path/cron reinstall from a pinned URL). **Freeze policy:**
  any supervisor change requires a design pass + the tested
  self-update path.

### 3 · Deploy service (cloud side; hosting open)

Answers the handshake: desired version + artifact pointer + manifest
hash, per house (per-house manifest = canary ordering). Records
per-device status. **Revert memory from day one**: a reverted
(device, version) pair is blacklisted and the rollout halts loudly.
Emits a fleet-staleness alarm if no announcements arrive for N hours
(the deploy service is itself watched).

### 4 · Wire handshake (sema words at build time)

Three meanings, words designed when built: **announce** (my version +
supervisor version, on every connect), **offer** (desired version +
pointer + manifest hash), **status** (applied / reverted / deferred /
failed, loud). Announce doubles as fleet inventory.

## Invariants (testable; the skeptic-proofed core)

1. Local health, never connectivity: an ISP outage CANNOT restart,
   revert, or kill the heating controller.
2. A reverted (device, version) is never offered to that device again,
   and halts the fleet rollout until a human looks.
3. Every byte that executes was hash-verified against the manifest —
   including cached wheels at reuse time.
4. The previous committed release is never pruned; a release is a valid
   revert target only after a committed run.
5. One poison artifact cannot wedge the supervisor: any failure path
   ends in `reverted` + report, not a loop.
6. The supervisor can update itself, and its fallback reinstall path
   works with the supervisor dead.
7. No component of this system provides shell-equivalent access
   (NO BACK DOOR) — it can fetch, verify, flip, restart, revert,
   report; nothing else.

## Boundaries (out of scope, by decision)

- **Picos: no field firmware downloads, ever.** OTA + routine 5 V bus
  cycling = bricked picos (couple lost per season; in-person
  micropython reflash to recover); the OTA crutch also hid
  gridworks-pico code-quality debt. Firmware changes at provisioning /
  bench only; the press-a-button OTA path is retired; pico code must be
  provisioning-grade. *Residual to scope separately:* audit every
  flash write in gridworks-pico (params persistence carries the same
  brick window).
- **OS upgrades: never in place, in the field.** Practice is
  fix-when-broken and it works. The **tsunami brick** rule: an apt+
  reboot wave across shell-less houses is a *correlated* fleet-wide
  failure — the thing we refuse to build a path toward (vs the
  uncorrelated single-house failures the A/B machinery handles). The
  OS ships at provisioning; the template advances at bench; any Pi
  that comes home gets reflashed. Optional: security-only
  `unattended-upgrades` with auto-reboot OFF (only kernel patches need
  reboots; reboot authority, if ever, is the supervisor's). Calendar,
  not machinery: CA root bundle expiry (broker TLS depends on it),
  tzdata, OS/Python EOL. The toolchain floor is held by CI-on-template
  (Architecture §1).

## Existing bricks

- **[OPS-7](https://linear.app/gridworks/issue/OPS-7) / #375 (field-verified, beech):** git-commit detection at
  startup, carried in layout-lite ShNode. The announce is an extension
  of this; the layout-lite carriage is interim (firmware isn't layout).
- gwbase precedent: LTN reads gridflo's commit into FloParamsHouse0.
- Today's deploy reality being replaced: SD-card recipe + by-hand
  pulls; no version-awareness; no store gate (March/April events were
  still in a June store — the 5 s link-flap incident).

## Build plan (each step has a done-check; ~2 days code, then field)

0. **uv on a real armv8 Pi** — the app builds/runs under uv on the
   template image. Everything depends on this.
1. **CI artifact** — tag → manifest + tarball + wheelhouse, built on
   the template image. Done: artifact installs offline on the bench Pi.
2. **Supervisor** — full sequence + revert + epoch gate + self-update
   + fallback. Done: bench drill passes — no-op bump, deliberately
   broken release (reverts + reports), kill -9 mid-fetch and mid-flip
   (recovers), supervisor self-update, store-epoch rotation event.
3. **Deploy service** — handshake + per-house manifest + revert
   blacklist + staleness alarm. Done: bench Pi driven end-to-end from
   it.
4. **Sema words** — announce/offer/status via sema word-authoring.
5. **Field: backup pi2, over the summer** — real hardware, real
   residential network, zero comfort stakes. Run no-op bump, broken
   release, normal cadence **until updates are boring**. Exercise the
   failure paths; no ceremonial soaks.
6. **Fleet rollout** — canary-ordered via per-house manifests, only
   after pi2 has made it boring.

## Open

- Deploy-service hosting (cloud-side; likely near FIS — the announce
  shares the FIS/Principal connection-authority trust moment).
- Quiescence predicate concrete form (pin in step 2).
- How supervisor status reaches the broker (own thin connection vs
  file handoff to the scada's event path) — pin in step 3.
- Signing arrives with the crypto-key design (substrate-fit); slot is
  the manifest signature, already shaped for it.
