# The drumbeat to satellite CT nodes

Status: Draft · Pass 0 · Updated 2026-11-23

> What this is: the voltage-beacon spoke on how a satellite CT node (an
> ESP32-class MCU by a far load, with no wire back to the panel) gets on
> the drumbeat (`../../lexicon.md`) over Wi-Fi or Ethernet. Docked nodes
> in the panel use the wired pulse and are not covered here. Satellites
> use Wi-Fi or Ethernet only: a dedicated radio adds cost, build effort
> and field configuration to every satellite.

## Do this next

Bench two ESP32-P4 Ethernet boards running the ESP-IDF PTP example
(`examples/ethernet/ptp`) through a cheap unmanaged switch, first on a
quiet network and then with a saturating flow on another port. Toggle a
GPIO on each board at a computed common time and measure the edge
offset on a scope over an hour. No measured ESP32-P4 PTP accuracy is
published, so this number has high value of information: if the P4
holds about 1 µs through a home switch, a cabled satellite can claim
settlement grade; if it does not, settlement grade stays with nodes
docked in the panel.

## Kit to buy

Prices from search results of 2026-11-23; check stock and price on the
page before ordering.

| item | qty | about | where | why this one |
|---|---|---|---|---|
| ESP32-P4X-Function-EV-Board | 2 | £45 ex VAT (UK listing; US price not seen) | [DigiKey](https://www.digikey.com/en/products/detail/espressif-systems/ESP32-P4X-FUNCTION-EV-BOARD/29196984) | the board the ESP-IDF PTP example names: "It's recommended that you have two official ESP32P4 boards with Ethernet capabilities - ESP32-P4-Function-EV-Board". The original board is obsolete at DigiKey; the P4X is its successor. It also has an ESP32-C6 for Wi-Fi |
| ESP32-S3-DevKitC-1 (N8R8 or N16R8) | 2 | $12 to $15 | [DigiKey](https://www.digikey.ca/en/products/detail/espressif-systems/ESP32-S3-DEVKITC-1-N8R8/15295894) | the chip of the published beacon-frame result; for the Wi-Fi bench and Fine Timing Measurement |
| 5-port unmanaged switch | 1 | $20 | any | the PTP bench runs through one |
| Ethernet cables, USB-C cables | 4 each | | any | |

Set aside: the Waveshare ESP32-P4-ETH ($12.99) is far cheaper, but its
Ethernet chip is unconfirmed. Reader comments on the CNX Software
review name both the W5500 and the LAN8720, and a W5500 would bypass
the P4's timestamping MAC. Revisit once the PTP example is proven on
the Espressif board.

The bench also needs a two-channel oscilloscope: the PTP example's
README lists "Oscilloscope to measure the GPIO pulse alignment between
the master and slave devices."

## The methods

The timing budgets are in `primary.md`, the timing budget note: about
1 µs for a node claiming settlement grade, about 10 µs for sub-metering.
Errors at a given offset are from the table in
`../../research/split-voltage-current-accuracy.md`.

| | Wi-Fi, AP beacon frames | Ethernet, software timestamps | Ethernet, PTP hardware |
|---|---|---|---|
| How it works | the access point broadcasts a beacon frame every 102.4 ms; every device stamps the same frame on arrival in hardware, and a fit over a minute lines the clocks up | node and beacon trade packets and time the round trip | the same exchange, stamped in the Ethernet MAC |
| Measured or expected | ±25 µs raw, 5.35 µs standard deviation on ESP32-S3 with no rate correction; a one-minute fit expected well under 10 µs | about 5 µs constant error (chrony on Linux), 1.2 µs (STM32F107); not measured on an ESP32 | sub-µs expected; no ESP32-P4 measurement published |
| Reaches 1 µs | only with per-board-model calibration of the receive delay; unproven | marginal | likely |
| Hardware | any ESP32 with Wi-Fi; no added parts | any ESP32 Ethernet board | ESP32-P4 (or S31) on both the beacon and the node |
| Install | no cable; every device on the same access point | a cable to each satellite | a cable to each satellite |

Broadcast works well on Wi-Fi because one frame reaches every receiver
at the same instant. The delays before transmission (waiting for a quiet
channel, retries, queueing in the access point) are common to all
receivers and cancel; only receiver-side differences remain, and they
are small and mostly constant. A two-way exchange has no shared frame,
and on Wi-Fi the two directions differ unpredictably, which is why
software round-trip sync over Wi-Fi is milliseconds.

- **Wi-Fi beacon frames.** The risk is the network: a mesh system or a
  second access point splits devices onto different beacon sources, and
  the method only aligns devices hearing the same one. The voltage
  beacon could act as the access point for the metering devices to
  remove that risk.
- **Ethernet.** The risk is the cable run to each satellite. It beats
  Wi-Fi clearly only with PTP hardware, which means the ESP32-P4 at both
  ends.
- **802.11mc Fine Timing Measurement** is a fourth option: hardware
  timestamps at both ends of a two-way Wi-Fi exchange, sub-100 ns jitter
  in one open ESP32 library, with a fixed bias of a few µs between the
  two ends to calibrate out. S2, S3, C2, C3, C5, C6 and C61; not the
  original ESP32.
- A PTP-capable PHY (TI DP83640, about $13) adds hardware timestamps to
  any ESP32 with an RMII port, at the cost of significant firmware
  work. Kept in reserve.

## Then

1. Wi-Fi beacon frames on two ESP32-S3 boards against an ordinary home
   access point, scored three ways: raw per-beacon offset, a one-minute
   fit, and the residual after one calibration; repeated across reboots
   and two board models. Starting code: the DFKI ESP32-S3 port
   (github.com/dfki-in/OpenWiFiSync, branch esp32-rbis; not yet read).
2. Fine Timing Measurement on the same boards, across 20 reboots, to
   size the per-boot bias.

## Sources

Read on 2026-11-22. Quotes marked near-verbatim came through a
summarizing fetch and must be re-read before they are cited.

- Gundall et al., arXiv 2511.14457 (Nov 2025), ESP32-S3 beacon-frame
  sync with a stock router, checked over a GPIO wire:
  "the maximum observed values remain within ±25 microseconds. The
  standard deviation of the offset is approximately 5.35 microseconds"
- ESP-IDF `components/soc/esp32p4/include/soc/soc_caps.h`: only esp32p4
  and esp32s31 define `SOC_EMAC_IEEE1588V2_SUPPORTED`, "EMAC Supports
  IEEE1588v2 time stamping".
- ESP-IDF `examples/ethernet/ptp` README (near-verbatim): supported
  targets "ESP32-P4 | ESP32-S31"; no accuracy figure.
- IMEKO TC4 2010, paper 070 (STM32F107): "the offset of software
  timestamping is about 1,2 μs"
- chrony examples page (near-verbatim): wired LAN with software
  timestamps stable "to about 2 microseconds" with "a constant error of
  about 5 microseconds".
- github.com/abbbe/fts, `docs/fts-presa-20251203.pdf`, the ESP32 Fine
  Timing Measurement library: slide 10, "The disciplined timer becomes
  local MAC clock with 25ns resolution!"
- TI DP83640 datasheet: "Allows Sub 10-ns Synchronization to Master",
  "12 IEEE 1588 GPIOs for Trigger or Capture"

## Open

- Whether the ESP32-P4 EMAC has a hardware event-capture pin for
  stamping an ADC conversion edge, or only the target-time interrupt
  ESP-IDF exposes.
- Whether the Function-EV-Board's ESP32-C6 exposes the hardware receive
  timestamps the beacon-frame method needs, so one satellite board
  could try both links.
- Whether a station on the house access point can run Fine Timing
  Measurement against the beacon's own access point without dropping
  its association.
