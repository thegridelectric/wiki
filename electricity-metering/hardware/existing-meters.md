# Existing meters as the boundary meter

Status: Draft · Pass 0 · Updated 2026-11-22

> What this is: the commercially available meters surveyed as candidates
> for the boundary meter (`../README.md` "The chosen architecture"),
> sorted into those that might meet the ISO bar and those that cannot,
> with price and read-out facts. Also the short list to suggest when a
> municipal utility or CMP territory lets us choose a meter before our
> own exists. Web research of 2026-11-22 by a research agent from vendor
> sheets, UL files and distributor prices; rows marked (s) rest on a
> search summary that was not read in full, so read the source before
> citing them. Not normative.

## The bar

- **ISO settlement**: OP-18 Appendix C, Energy Billing column: a class
  0.2 watt-hour meter (ANSI C12.20, now folded into ANSI C12.1-2024;
  vendors still quote C12.20) with IEEE C57.13 class 0.3 current and
  voltage transformers, which means solid-core or CT-rated CTs. The DRR
  2.0 allowance does not apply to GridWorks (`../README.md`).
- **Local read**: every reading readable from the house, poll or push,
  at 5 to 10 s or better; once a second and MQTT is the gold standard.
- **Fit**: UL listed; both 120 V legs of a split-phase service; a form
  that fits a sub-panel enclosure.
- **Cost**: meter plus two class 0.3 solid-core CTs plus any comms
  module. A C57.13 class 0.3 200:5 CT is about $335 each (EIG LV-CT-120
  price; Eaton S060-201 is rated 0.3 with no public price).

No documented ISO New England settlement acceptance was found for any
meter below. Acceptance is a per-installation question for the Assigned
Meter Reader; the class is the necessary condition and the installation
review is the rest.

## Might meet the ISO bar

| Meter | Class, evidence | UL | CT inputs | Local read | Meter price | What it lacks |
|---|---|---|---|---|---|---|
| Accuenergy Acuvim II + AXM-WEB2 | 0.1 on the datasheet, 0.2 elsewhere on the product page; no lab named | UL 61010-1 | 5 A, 333 mV, Rogowski; 1LL 2CT wiring for split-phase | MQTT, HTTPS push, Modbus TCP; 1 s datalogging | about $660 to $930 plus $225 to $295 for the WEB2 | its own solid-core CTs are IEC 61869-2 class 0.2 with no C57.13 rating, so pair with a third-party 0.3 CT; the class inconsistency wants a test report |
| Elkor WattsOn-Mark II 5A-LD | 0.2, "Accuracy Certified", no lab named | E250395 | 5 A; split-phase supported | HTTP POST, Modbus TCP, web server; instantaneous W at 100 ms | quote | no MQTT; no time sync stated |
| EIG Shark 250 | 0.1 certified | E250818 | 5 A | Modbus RTU/TCP, DNP3, IEC 61850; poll | quote | no MQTT; no push |
| EIG Shark 200 (s) | 0.2 certified | yes | 5 A | Modbus; poll | quote | no MQTT |
| DENT PowerScout HD (s) | 0.2 | enclosure version Listed; plate version Recognized only | 5 A and mV | Modbus, BACnet; poll | $728 (PS3HD) | no MQTT |
| Satec EM235 | 0.2S IEC 62053-22 and 0.2 C12.20 | yes to 277/480 V | 1 A, 5 A, HACS | Modbus, DNP3, IEC 61850; poll | quote | no MQTT; IRIG-B input "future release" |
| Schneider PowerLogic PM5560 (s) | 0.2 per C12.20 | cULus | 5 A | Modbus, BACnet; poll | $3,574 list | price; no MQTT |
| SEL-735 | 0.1, SEL's own data on about 1,000 meters | not stated | 5 A, 0.001 to 22 A | Modbus, DNP3, IEC 61850, FTP; C37.118 synchrophasors at 60/s; 3 ksps waveform stream | $2,554 and up | price; UL unconfirmed; no MQTT |
| Veris E51C2 (s) | 0.2 | not confirmed | 333 mV documented only for the 0.5 variant | Modbus; poll | quote | CT input at class 0.2 unclear |

---

## Cannot meet the ISO bar

| Meter | Class, evidence | Local read | Meter price | Why not |
|---|---|---|---|---|
| eGauge Pro / Core (EG4xxx) | 0.5 with approved ECS or ACT CTs, Eurofins report TEL111846-ANSI (2021) | JSON push or poll; 1 s for the last hour; waveform capture on firmware 4.2+ | $1,365 (Pro) | class 0.5 |
| Continental Control Systems WattNode WND-WR-MB | 0.5 | Modbus RTU; poll | quote | class 0.5; 333 mV CTs |
| EKM Omnimeter Pulse UL v.4 | 0.5 by its sheet; California CTEP submeter approval; partial C12.20 test with solid-core CTs (`ekm-meter.md`) | RS-485, EKM protocol; poll | about $200 | class 0.5; its CTs have no C57.13 class |
| Itron Gen5 Riva read locally (the Xcel "Launchpad" pattern) | 0.5 residential | IEEE 2030.5 Wi-Fi endpoint; instantaneous demand, summations, power factor; polled at about 5 s; no voltage, no time | none; the utility owns it | class 0.5; the utility must enable the endpoint |

## When the utility lets us choose

In CMP territory and with municipal utilities we may have no say in the
meter, or we may be asked for one. Until our own meter exists the
suggestion is, in order:

1. **Acuvim II with AXM-WEB2 and third-party class 0.3 CTs**: the one
   candidate with push and MQTT at a sane price, about $1,500 to $1,900
   per house installed with CTs. Confirm the class with a test report
   first.
2. **Elkor WattsOn-Mark II**: class 0.2 certified and UL Listed, 100 ms
   HTTP POST; a plain HTTP push is a serviceable local read.
3. **Shark 250** where the utility already knows EIG; Modbus polling at
   5 s is enough for the read, short of the gold standard.

Any of the three needs a Modbus or HTTP reader on our box; the eGauge
power meter actor in the scada is the pattern.

## None of them is a voltage beacon

The second question the survey asked was whether a purchasable class 0.2
meter exposes a voltage phase and a timebase another device can share
(`../lexicon.md` "Voltage beacon"). Only the SEL-735 does part of it:
UTC-referenced synchrophasors and a waveform stream. It takes an IRIG-B
input and offers no PTP, PPS or IRIG output, so a GPS clock has to sit
beside it, and the pair costs three to four thousand per house. Every
other meter offers NTP with no stated accuracy and, at most, leg-to-leg
angles. None documents running user code, so the economy market maker's
host is our own Linux whichever meter is bought.

## What this says for us

As of 2026-11-22 the data leans toward our own meter. The purchasable
meters that meet the bar deliver a 5 A Modbus or HTTP surface and no
beacon; the gold standard (MQTT, once a second, a good API, a shared
timebase, the MarketMaker on board) exists only as the device we build,
at roughly a year and a certification budget (one published anecdote:
a new UL file at nine to eleven months and $40,000 plus; no NRTL price
for C12.20 testing was found). The README's "who the boundary meter is"
stays open until that is decided; the suggestions above are for the
houses that come first.
