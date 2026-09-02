# gridworks-pico — spec (primary)

Status: Draft · Pass 0 · Updated 2026-09-02

> What this is: the MicroPython firmware on the Raspberry Pi Pico W boards
> that read tank thermistors, flow meters and BTU meters in each house and
> post readings to the house scada over the LAN. Acceptable-minimum hub:
> overview, the field facts experiments have verified, glossary; the rest
> is Open and the firmware repo (`gridworks-pico`) is the authority.

## Overview

A pico boots from on-flash config (`comms_config.json` names the link,
wifi or WIZnet ethernet, and the scada it posts to), joins the LAN, and
posts readings and a params record to the scada's HTTP endpoint. The
scada's pico-cycler actor owns recovery: a pico that stops posting is a
"zombie", and the cycler power-cycles the shared VDC bus that feeds
every pico in the house. Scada-side policy for that bus lives in the
scada spec; this hub holds what is true of the picos themselves.

## Verified field facts

Status: Verified · Pass 0 · Updated 2026-09-02 · Reviewed 2026-08-05@5e77cee (`experiments/2026-08-03-pico-gap-analysis/`, `experiments/2026-08-05-pico-link-census/`, `experiments/2026-08-10-hp-snafu-and-pico-blackout-postmortem/`)

- **A permanently dead pico in the layout reboots every sibling.** The
  cycler shakes the shared VDC bus every 30 minutes while any zombie
  exists, so a house carrying one dead pico power-cycles all its picos
  about 48 times a day. Siblings that rejoin inside the 10-minute
  dropout floor make the shakes invisible; one that takes 13–14 minutes
  logs a "dropout" per shake. Spruce's dropout rate collapsed when the
  dead floor2 pico was removed from the layout, and fell again when
  three more wifi picos were removed, so the residual was wifi
  congestion on the herd. A dead pico is de-layouted, not left for the
  cycler to chase.
- **Link type is unobservable on the LAN.** The ethernet path brings up
  `network.WIZNET5K()` with no explicit MAC, and the driver's default
  carries no WIZnet OUI, so wired and wifi picos are indistinguishable by
  MAC prefix. Ground truth is each pico's on-flash `comms_config.json`
  (`WifiOrEthernet`); the picos do not report it and the layouts do not
  carry it. The fix is firmware self-report of link type and MAC in the
  params post, carried into the layout.
- **A VDC power-cycle cannot rescue a pico from an access point that is
  not broadcasting.** When the house router's 2.4 GHz SSID went down
  (2026-08-10) every wifi pico zombied at once and the cycler's shakes
  changed nothing; the wired side stayed up. All-wifi tank picos can
  run gapless for weeks (elm, 56 days), so wifi is not the fault, the
  AP is.

## Open

- The posting protocol and the params record, as sema words.
- Flash-write discipline and the filesystem-corruption model.
- Board variants and MicroPython version as layout-carried identity.
- Provisioning: one clear path from a blank board to a posting pico.

## Glossary

- **zombie** — a pico the scada has not heard from within its dropout
  floor.
- **shake** — the pico-cycler's power-cycle of the house's shared VDC
  bus.
- **dropout** — a gap in a pico's readings longer than the 10-minute
  floor.
