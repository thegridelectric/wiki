# Production security: a weekly supervised patch run

Status: Draft · Pass 0 · Updated 2026-11-11 · Linear: OPS-662

**EDD: no** infra remediation; verified by re-surveying the live boxes
after each weekly run (kernel running = kernel installed, no
reboot-required, sshd at the distribution's current security build).

> What this is: how the production boxes (the platform VMs in
> `gridworks-infra/platform-inventory.md` and the scada Pis in
> `gridworks-infra/fleet-inventory.md`) get security patches and the
> reboots those patches need, on a weekly cadence, launched by a human who
> stays around while it runs.

## Findings (2026-11-08 whole-fleet survey)

Read-only pass over 26 of 28 boxes in `~/.ssh/config`: 13 platform VMs
and 13 house or bench Pis. Two did not answer: honeysuckle (bench Pi, off) and hw1-2 (refuses the
key the config names; what it is appears in no infra doc). ltn2 in the
ssh config is a box that no longer exists; every LTN runs on ltn. Raw output per box is in
`scratch/security-survey/`.

- **Every Ubuntu VM but pii has a pending kernel reboot.** Hetzner boxes
  (alerts, ear, flo, forecast, gjk, gnr, mm, tap) run 6.8.0-137 or -138
  with -147 installed; web runs 6.17 with 7.0 installed; rmqbot runs
  7.0.0-1008 with -1016 installed; certbot and ltn (Ubuntu 22.04) have
  newer aws kernels installed too. Uptimes: certbot 1 year 28 weeks, ltn
  35 weeks, rmqbot 16 weeks, web 16 weeks, gjk 12 weeks, ear, forecast
  and gnr 10 weeks. `unattended-upgrades` is installed and enabled on
  all 13, `Automatic-Reboot` is unset everywhere, so userspace is
  patched and kernels are not. rmqbot reports itself as Ubuntu 26.04.
- **The Pis have never been patched.** No `unattended-upgrades` on any
  of the 13. Around 150 packages with a security update pending on each
  (openssh-server deb12u3 or deb12u2, candidate deb12u10; the rest is
  mostly the desktop image: cups, ghostscript, imagemagick, evince,
  dnsmasq). Kernel 6.6.31 or 6.6.47 running, 6.12.115 the candidate.
  Pi uptimes 11 days to 7 weeks. Tailscale versions range 1.70 to 1.92.
  Every Pi listens on 0.0.0.0 for sshd and mosquitto (1883); the
  House0 scadas also on 8000. All behind the house NAT.
- **sshd:** key-only everywhere (`PasswordAuthentication no`,
  `KbdInteractiveAuthentication no`). Root login is `prohibit-password`
  (shown as `without-password`) on the Hetzner VMs, certbot, ltn, web
  and some Pis, `no` on pii and the other Pis. Ubuntu sshd is at the
  current security build on every VM.
- **Host firewalls:** ufw inactive and no fail2ban on every box.
  Exposure is decided by the cloud firewall alone (Hetzner firewall,
  AWS security groups, home NAT); the AWS groups were not read.
  Services bound to all interfaces: sshd on every VM; caddy 80/443 on
  alerts, forecast, gnr; docker-proxy 5436 on forecast and 5671/15671
  on tap; rabbit 5671/8883/15671 plus epmd 4369 and 25672 on rmqbot.
- **Keys:** the per-box pattern is real on every box: `<box>-<person>`
  on the service login, `<box>-jessica` alone on root (Hetzner VMs and
  tap), `fleet-<person>` on the Pis and ltn. Five fleet keys on most
  Pis; elm and elm2 lack fleet-olly; flo lacks joe; mm and pii are
  jessica-only; certbot's key is `jessica-certbot-2026`; tap's are
  `shovel-jessica` plus `rmqtap-<person>`; gnr's root key is the
  gnr-jessica key under the comment `gnr`. rmqbot root has the AWS
  forced-command stub that redirects to `ubuntu`. 43 distinct key
  names across the fleet for five people.
- **Reporting:** the session drift hooks report git drift weekly and say
  nothing about reboot-required or pending security updates.

## Shape

A weekly run, one box at a time, from the laptop, with the human present.
Each box: apply the distribution's security updates, reboot when the box
asks for it, wait for the units to come back, print HEAD, unit states
and the running kernel. A recurring Linear issue is the weekly prompt;
the drift hook reports patch state between runs.

The run is supervised because every box is a single service with no
standby, and a reboot that does not come back is an outage until a human
notices. The scale this is designed for is the fleet of this year
(about ten VMs and a dozen Pis). The review below says where it stops
fitting as the fleet grows.

## Review of current practice (2026-11-06)

Web research by a subagent, sources in the OPS-662 comment thread;
provenance ad hoc (precedence 4), verify before canonizing.

- **Ubuntu unattended-upgrades** installs the `-security` pocket (and
  ESM) only; kernels are in it, so the new kernel is installed and waits
  for a reboot. `Automatic-Reboot` defaults to false. Turning it on
  reboots unattended whenever `reboot-required` appears, with an optional
  time of day. A supervised weekly reboot is the alternative.
- **Livepatch** needs Ubuntu Pro (free tier five machines, personal and
  small-scale use), covers x86 `generic` kernels on 24.04 and no arm64
  before 26.04, and still wants a reboot onto a newer kernel every nine
  to thirteen months. It lowers the urgency of a reboot and does not
  remove it. Not worth it at this count.
- **Debian 12 on the Pis:** the stock unattended-upgrades origins are
  Debian and Debian-Security only; Raspberry Pi's own packages (kernel,
  firmware) come from the Raspberry Pi origin with no security channel,
  so they are all-or-nothing. Practice for field fleets: install
  Debian-Security unattended, hold kernel and firmware (`apt-mark hold`)
  and move them on a canary Pi first, reboot only in an attended window,
  `needrestart` for library updates between reboots.
- **oak's sshd** (`deb12u3`) has the regreSSHion fix (CVE-2024-6387) and
  is five to seven security revisions behind bookworm's current build
  (`deb12u10`, 2026-05). The later fixes are lower severity; the Pis
  have no public ssh. Still a fleet-wide check in the survey.
- **ssh exposure:** CISA's guidance is that management interfaces are
  off the internet or behind a separate enforcement point. Tailscale SSH
  authenticates by tailnet identity, so revoking a person ends their
  sessions and there are no keys to distribute; the Pis are on the
  tailnet already. The Hetzner firewall takes CIDR source allowlists
  (500 rules, label selectors). Fit for this team: put the VMs on the
  tailnet and close 22 to the world, allowlist as the fallback for a box
  that cannot run Tailscale.
- **Scale:** one box at a time with a human watching is workable at ten
  boxes. At fifty it is three to four attended hours a week. At two
  hundred the human approves a kernel rollout ring (canary, then a tenth,
  then the rest) and handles the failures a health check reports;
  security updates install unattended everywhere. Ansible `serial` with
  `max_fail_percentage: 0` and a health check between batches is the
  usual tool.
- **Tailscale plan** (read 2026-11-08 at tailscale.com/pricing): we
  stay inside the free Personal plan. It allows up to 6 users, unlimited
  user devices (laptops and phones logged in as a person) and 50 tagged
  resources (servers and Pis, which log in by tag), with a dollar a
  month for each tagged resource above 50; the page says overages are
  not yet enforced. The hundred-device figure is from an older version
  of the plan. Every VM and every house Pi is a tagged resource, so the
  fleet fits at 20 homes and does not at 100: by then the Pis are off
  the tailnet (OPS-663) or the plan is paid.
- **Reporting:** `/var/run/reboot-required` and `reboot-required.pkgs`;
  `apt-check` prints `total;security` counts on Ubuntu; `needrestart -b`
  gives machine-readable kernel and service state on both.
- **Software outside apt on the Pis:** uv (the standalone binary from
  the astral installer, in `~/.local/bin`) and the pyenv Python 3.12 the
  scada venv is built on. Neither `unattended-upgrades` nor the weekly
  run touches them. No Raspberry Pi OS packages uv: bookworm and trixie
  have none, and Debian's `uv` package reached testing only in June 2026
  (Debian 14, 2027, at an old version). Both are build-time tools: the
  services run `.venv/bin/python` directly, and uv runs only when a
  human rebuilds the venv after a roll stops on a `uv.lock` change. So
  they are updated at that moment: `uv self update` on the box and on
  the laptop before any rebuild (a laptop uv behind the box's rewrote
  the lock format on 2026-11-09), and the Python moved by the sd-card
  recipe at a re-image. The VMs have the same question for anything
  installed by pip or a curl installer; the survey did not list it.

**What this does to the plan.** The weekly supervised run stands for the
VMs this winter, with `Automatic-Reboot` left off so the reboot is the
run's. The Pis get Debian-Security unattended, kernel and firmware held,
and a canary house before the rest; their reboots are attended and
seasonal. The VMs join the tailnet and 22 closes. The design names the
twenty-home point as where the run becomes a canary plus batches with a
health check, so the script is written with that in mind (a per-box
table, a health check, no interactive steps).

## Plan

1. **Review current practice.** Done; the section above.
2. **Survey the whole fleet** with one read-only pass (every VM, every
   Pi): running versus installed kernel, reboot-required, sshd build,
   unattended-upgrades state, and every login's `authorized_keys`.
   Record it here.
3. **One key per person, in the first sweep.** Keys are named
   `<family>-<person>` today, so a person has one key per box family.
   This becomes one key per person: the `fleet-<person>` key, which all
   five people already have and which already opens the Pis and ltn,
   opens every login that person is entitled to. No new key is made.
   Every login on every box and Pi opens to the whole team, the same
   five fleet keys (jessica, joe, thomas, olly, george) everywhere; the per-box rosters that differ today
   (flo without joe, mm, pii and certbot jessica-only) go away. Per box,
   the sweep appends the five fleet keys to each login's
   `authorized_keys`, confirms a fresh login with a fleet key, then
   removes the per-box lines. Root on the Hetzner boxes and rmqtap, the
   only admin path there (the service login has sudo for its own unit
   only), opens with `fleet-jessica` alone: admin stays one person. This is the posture the tailnet end-state has
   anyway: once the VMs are on the tailnet with Tailscale SSH (step 8),
   who may log in is one ACL for the whole team, and the keys retire.
   The
   per-family split added friction and defended against little: the
   private halves of one person's keys already sit together in that
   person's `~/.ssh` and in 1Password, so a lost laptop exposes them all
   at once either way, and the controls that matter are per-person
   revocation, key-only auth and current sshd. Each key stays
   per-person, never shared, and gets a passphrase. The sweep that
   patches a box also replaces its `authorized_keys`; the roster in
   `gridworks-infra/authority/ssh-access.md` stays the authority, one
   column per person.
4. **The patch script** in `gridworks-infra/tools/`, in the style of
   `box-deploy.sh`: a per-box table, one box per invocation, refuses to
   run when the box's checkout is dirty, prints what is running at the
   end. Pis included, over the tailnet.
5. **Cold-boot check** per service before the first reboot of a box:
   each unit enabled, comes back on its own, and the FIS cert lease
   survives a reboot (a box whose service is refused after a reboot is
   the failure this step exists to find first).
6. **Pis:** `unattended-upgrades` on Debian-Security in the sd-card
   recipe, kernel and firmware held, one canary house ahead of the rest,
   plus a one-time fleet pass. The recipe also names the version of
   everything outside apt (uv, the Python the venv uses) and the roll
   runbook has `uv self update` as the first line of a venv rebuild.
   The survey gains a per-box list of software outside apt. The Pis leave the tailnet once the
   on-demand support tunnel (OPS-663) works on one house; that keeps the
   tailnet's tagged-resource count at the platform VMs however many
   homes there are.
7. **Weekly prompt and reporting:** a recurring Linear issue (`loop`
   label) and the drift hook extended to reboot-required plus pending
   security-update count per box.
8. **Inbound ssh:** the VMs join the tailnet, 22 closes on the Hetzner
   firewall, a source allowlist for any box that cannot run Tailscale;
   recorded in `gridworks-infra/authority/ssh-access.md`.
9. **Pis run only what the scada needs.** The house Pis are headless,
   yet they boot `graphical.target` from the Desktop image: lightdm, a
   compositor and wayvnc start on every boot, 104 desktop packages are
   installed (firefox, vlc, thonny, geany, cups, piwiz, the UI mods) and
   on 2026-11-09 they were 88 of beech2's 185 pending Raspberry Pi
   updates. Beyond ssh, mosquitto and tailscale the only listeners are
   cups on 631 (localhost) and avahi mDNS on 5353 (all interfaces);
   bluetooth, ModemManager, udisks2, triggerhappy and accounts-daemon run
   with no job. Three tiers, beech2 first as the canary, each tier a day
   before the next:
   - Services, no reboot: `systemctl set-default multi-user.target`;
     disable and stop lightdm, wayvnc-control, rpi-display-backlight,
     glamor-test, cups, cups-browsed, bluetooth, hciuart, ModemManager,
     triggerhappy, udisks2, accounts-daemon; mask the cups socket. Keep
     avahi-daemon: `<host>.local` is how a visitor on the house LAN finds
     a pi, the sd-card recipe installs it for that, and the older pico
     firmware (gridworks-pico `archive/`, and the `BackupUrl` in the
     tank, flow and BTU comms configs) posts to `http://beech.local:8000`.
     Keep NetworkManager and wpa_supplicant (wifi is the fallback when a
     house's ethernet dies), cron, apparmor, fake-hwclock, dphys-swapfile
     and rpi-eeprom-update (it flashes only a staged update; the EEPROM
     move is its own decision).
   - Packages, the exact list (apt treats a `*` in a name as a pattern
     matched anywhere, so `libfm*` also matched libfdt1 and would have
     taken raspi-config with it: every name is spelled out, and
     raspi-config, raspberrypi-sys-mods, device-tree-compiler and iw are
     marked manual first so autoremove keeps them):
     ```
     sudo apt-mark manual raspi-config raspberrypi-sys-mods device-tree-compiler iw
     sudo apt-get purge --autoremove -y raspberrypi-ui-mods lightdm lightdm-gtk-greeter wayfire labwc piwiz firefox vlc thonny geany cups cups-browsed cups-client cups-common cups-core-drivers cups-daemon cups-filters cups-filters-core-drivers cups-ipp-utils cups-pk-helper cups-ppdc cups-server-common lxde lxde-core lxpanel pcmanfm libfm4 libfm-gtk4 pulseaudio pulseaudio-utils pulseaudio-module-bluetooth xserver-xorg-core xserver-common rpi-firefox-mods
     sudo apt-get clean
     ```
     About 250 packages go, in under two minutes. The check afterwards:
     `gwspaceheat` (or `gwspaceheat2`), mosquitto, tailscaled, ssh,
     NetworkManager and avahi-daemon active, no failed units, raspi-config
     still installed, `import board, RPi.GPIO` from the scada's `.venv`.
     The whole stage is `scratch/security-survey/pi-trim.sh`, run as
     `ssh <pi> 'bash -s' < pi-trim.sh`.
   - New cards: Raspberry Pi OS Lite, so none of this exists on the
     next image; the sd-card recipe drops its "enable 1-wire" line at
     the same time (fir2 and elm2 have `dtoverlay=w1-gpio` with nothing
     on the pin, and log phantom family-0 devices hourly).
   Scheduled after the uv venv rebuilds across the fleet are done, so
   one change at a time is on each box.
## Pi catch-up runbook

The runbook is `gridworks-infra/scada/pi-security-runbook.md`, the stages
`trim`, `debian`, `kernel`, `reboot` and `check` of
`gridworks-infra/tools/pi-patch.sh`, one authority for the package lists
and the checks. The paste blocks and the scratch scripts that preceded it
are retired.

## Status

- 2026-11-08: step 2 survey done; step 3 keys done on every reachable
  box (service logins: five fleet keys; Hetzner and rmqtap root:
  `fleet-jessica` alone; AWS and Pi root: sudo only).
- 2026-11-09: first attended reboot sweep, security updates already on
  via unattended-upgrades, kernel reboot only, one box at a time with a
  pre-check and a post-check (kernel, every unit active and enabled,
  broker connections, failed units, error-level journal lines). Done:
  mm, gjk, alerts, ear, forecast, gnr, flo, rmqtap, web-api2, certbot
  and rmqbot, each back in about 30 seconds, all clean. The broker
  reboot (14:00:15Z, team told beforehand) gave a 28 s broker gap:
  listeners ready at 14:00:43.5; the nine gwbase AMQP clients all back
  between 3.8 and 4.6 s after that; the twelve MQTT clients between 2.4
  and 8.8 s, the six LTNs on the ltn box arriving within 20 ms of each
  other at 8.7 s. The 09:00 ET contracts formed at 09:00:59 instead of
  on the hour; the price publish had gone out before the shutdown. Lesson
  for the runbook: keep the broker reboot out of the :58 to :02 window.
  Pending: the Pis (step 6). pii needs no reboot.
- 2026-11-09, later: uv venv rebuilds done on all eleven pis and the six
  LTNs, old pip venvs removed, so step 9 began. beech2 tier 1 (services)
  done: default target multi-user, twelve services disabled and stopped,
  cups socket masked; listeners are ssh and mosquitto only; scada,
  mosquitto, tailscale, ssh, NetworkManager, wpa_supplicant and cron
  active, no failed units, no glitches. avahi was in the first list,
  stopped for about twenty minutes and re-enabled once the pico
  `.local` dependency was found; `beech2.local` resolves again from
  beech. Tier 2 dry run saved at
  `scratch/security-survey/beech2-purge-dryrun.txt`: 23 packages from
  the purge list, 184 with autoremove, no i2c, gpio, ssl or python3
  runtime library among them (the scada's interpreter is uv's own build
  and links only libc); the autoremove list is the desktop's own
  libraries plus the 6.6.31 kernel and headers. Tier 2 runs a day after
  tier 1. The trim goes before the patch sweep on each remaining pi: the
  desktop packages were 88 of beech2's 185 pending updates.
- 2026-11-09, beech2 (beech's second pi, `gwspaceheat2` only), the
  first Pi catch-up, run by hand from the box's shell with the commands
  given one stage at a time: the Debian-Security pocket (154 packages)
  while the scada ran; then the Debian point-release pocket (177
  packages: openssh-server deb12u3 to deb12u10, systemd, sudo,
  mosquitto, bash, util-linux) also while it ran, mosquitto restarting
  under the scada without incident; then kernel 6.6.47 to 6.12.115,
  raspi-firmware 2024-09 to 2026-09, rpi-eeprom package 24.0 to 28.33
  and tailscale 1.72.1 to 1.104.5; then one reboot. `gwspaceheat2` was
  back at 12:34:24 ET, about a minute after the reboot command, enabled,
  no failed units, zero error or warning lines in its journal, synced
  readings flowing to the broker. `import board, RPi.GPIO` passes on the
  6.12 kernel, so RPi.GPIO 0.7.1 is fine there (the pis need it and no
  requirements file named it; scada branch `jm/pi-rpi-gpio` adds it to
  the uv `drivers` group). Decisions taken on the way: the Debian
  point-release pocket IS applied (the 12.15 point release had absorbed
  the sshd fixes, so the security pocket alone left openssh-server at
  deb12u3); the ~185 Raspberry Pi origin desktop packages are not; the
  bootloader EEPROM update `rpi-eeprom-update` offers is left for a
  separate decision; the ssh package's own prompt about the modified
  `sshd_config` is answered "keep the local version" (dpkg's
  `--force-confold` does not reach it). The kept file differs from the
  offered one in two lines, `PermitRootLogin no` and
  `PubkeyAuthentication yes`, both commented defaults in the offered
  file; `PasswordAuthentication no` and `KbdInteractiveAuthentication
  no` are in both, so key-only login did not depend on the answer. The
  5 installed kernels each get an initramfs rebuilt, the slow part: the
  whole catch-up took about 45 minutes attended, of which perhaps 10
  were the box working.
- 2026-11-09, afternoon: stage A (trim) run by the script on elm2
  15:38, fir2 15:40 and maple2 15:42 ET, all clean. beech2's own trim
  had kept the X server and rpi-firefox-mods because the pasted purge
  line arrived cut short.
- 2026-11-11: stage A on oak2 from its shell. The first paste of the
  purge line was cut at 220 characters (cups-filters), a second at 204;
  the stage A block was rewritten as short lines with a word-count guard
  and a leftover check, and the re-run removed the remaining 17 X server
  packages. beech2's three leftovers purged the same morning. Both pass
  every stage A check; listeners are ssh and mosquitto only. All five
  secondaries are trimmed; beech2 alone has stages B to D.
- 2026-11-11, morning: stage A on the six primaries, beech by paste
  from its shell, oak, fir, maple, elm and spruce by the script from the
  laptop (about 250 packages each, under two minutes, the scada running
  throughout, zero warnings). The documented ssh line had `-n`, which
  feeds `bash -s` an empty stdin; the first attempt on oak did nothing.
  Stages B to D on elm2 and fir2 by paste, maple2 and oak2 by script:
  stage B 7 to 13 minutes, stage C about 4, reboot back in 32 seconds,
  every one on 6.12.115 with the scada active and enabled, its reupload
  complete within a second of the broker link, tailscale 1.104.6, import
  ok, avahi active, no failed units, no error lines. Stage B's one-liner
  was rewritten as short lines like stage A. The dpkg "unable to delete
  old directory /lib/firmware/raspberrypi/..." warnings in stage C are
  the merged-/usr quirk (the new rpi-eeprom lists the same files under
  /usr/lib) and are harmless. reboot-check.sh now takes an ssh-config
  alias and reboots through sudo, so it reaches a pi as well as a VM.
  All five secondaries are done through stage D; the six primaries
  through stage A.
- 2026-11-11, midday: beech through all stages. Stage B 15 minutes and
  stage C 5 by script with the scada running; reboot by the human from
  the laptop, back in 32 seconds on 6.12.115; both MQTT links active
  within a second of the scada start, relays initialised, all eight
  picos posting inside the first minute, zero warnings. Found before the
  reboot: beech's `gwspaceheat` unit and restart timer were disabled (the
  unit symlinks were placed 2025-08-28 and never enabled), which is why
  the 2025-10-25 boot left the house without its scada for two hours
  until a hand start; enabled, and the dangling `gwspaceheat2-restart.timer`
  link to the old repo removed. The reboot stage now refuses a disabled
  unit, and the post-reboot line reads the scada journal for links,
  relays and picos. Scripts and runbook moved to gridworks-infra.
- 2026-11-11, afternoon: oak and fir through every stage and rebooted
  (neither had beech's dangling timer link; their unit links point at the
  live repo). maple through `debian` and `kernel` by script, elm and
  spruce by `pi-patch.sh all`, then all three rebooted at 15:15 ET by the
  human. maple and elm reached multi-user 13 s after boot with the scada
  started and all three MQTT links connected, zero warnings, no failed
  units. spruce took 66 s to multi-user because
  `NetworkManager-wait-online` timed out (its one failed unit; the scada
  and its links were fine once started), so a spruce boot has a one-minute
  scada gap. Cause: a saved wifi profile `NOKIA-9EF1` (a phone hotspot)
  with autoconnect on and no device to come up on; wait-online waits for
  every autoconnect profile. Fix proposed: turn its autoconnect off. All eleven Pis are on 6.12.115 with zero pending security
  updates and tailscale 1.104.6: the Pi catch-up (step 6, one-time pass)
  is complete. The runbook, `pi-patch.sh` and the recipe note are
  committed in gridworks-infra (d07909b); gnr and gjk pulled to
  origin/main. Second hardware batch ordered: ten Pi 4 Model B 2 GB and
  ten SanDisk High Endurance 32 GB cards; the choice and its reasons are
  in `gridworks-infra/scada/sd-card-recipe.md` "Hardware to buy".
- 2026-11-12: hw2-1 (the `hw2` simulation host, Hetzner cx43, Ubuntu
  24.04, created 2026-11-11) brought into the fleet. Its first morning
  showed the shape every new Ubuntu image has: 138 updates pending,
  109 of them security, kernel 6.8.0-138 running with -147 installed
  and a reboot required. unattended-upgrades was already on (the image
  default) and had done the security pocket overnight; the rest of the
  security pocket was run by hand, then the reboot, with nothing
  running on the box to check beyond docker, ssh and the failed-unit
  list: kernel 6.8.0-149, zero failed units, zero pending security
  updates. The ordinary pocket (32 packages) is left, as on every other
  VM. sshd is key-only, root is `fleet-jessica` alone, `sim` has the
  five fleet keys, ufw inactive behind the Hetzner firewall (22 and
  icmp), no tailscale yet: it joins the tailnet with the rest in step 8.
  ESM Apps and the 26.04 release upgrade that the login banner offers
  are not taken on any VM.
  Housekeeping the same day: the stale SlowContractHeartbeat files
  (version 000 and 001, on beech, fir, elm, maple and in the five older
  `ltn-<house>` data dirs on the ltn box) deleted; oak's live 002 file
  kept. The `atn/` data dirs under each `ltn-<house>/.local/share/gridworks/`
  (price-forecast and curtailment CSVs, weather.json, copied from the
  old AWS box, now gone) and the four `flo_next_hour_plans.json` files
  are also legacy and still there.
- Next move: step 7, the weekly prompt (a recurring Linear issue with
  the `loop` label) and the drift hook extended to reboot-required plus
  pending security-update count per box, so the fleet cannot drift back
  while step 8 is designed. The box roster for both is the platform
  inventory plus the eleven Pis; hw2-1 is on it (root login, no service
  to pre-check).
- The ordinary updates pocket (35 to 67 packages per box) is left for a
  decision on whether the weekly run applies it.

## Open questions

- Reboot order and the blast radius of each box: the broker (rmqbot) and
  the registry (gnr) are depended on by everything else; their reboot is
  a fleet event.
- Does anything on a Pi depend on uptime (an in-memory state the scada
  rebuilds slowly)? If so the Pi reboot is scheduled, not weekly.
- Tailscale SSH versus plain sshd over the tailnet: identity-based login
  would also settle the key question (step 3) by removing keys. One
  decision, taken with Olly.
