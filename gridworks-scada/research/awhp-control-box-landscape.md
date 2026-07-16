# AWHP control-box landscape — can GridWorks build its own?

Status: Draft · Pass 0 · Updated 2026-07-15

> What this is: research (pre-spec, not normative) on how AWHP indoor control boxes get
> made, the per-vendor ODU↔controller protocol picture, what a GridWorks-built box would
> require (UL/warranty), and the negotiation angle with smaller manufacturers (Ecoforest
> intro via John Siegenthaler). Single-pass web-research agent, 2026-07-15 — claims are
> labeled [documented] (vendor doc/press/manual verified), [community] (open-source/forum
> reverse-engineering), [inference], or [rumor]; spot-check a citation before building on
> it. Requested from the spruce-relay-control thread (OPS-392); the control-box motivation
> is recorded there (vendor boxes ~$1.5–2k installed, opaque pump logic, gated features).

## Executive summary

Fully replacing a major vendor's indoor control kit and speaking its proprietary ODU bus is
technically possible only for Samsung (the NASA bus is well decoded), is done today only by
uncertified hobbyist projects, and carries the whole warranty/causation fight. The cheaper
fact the research surfaced: **for nearly every relevant vendor, a sanctioned writable
digital command surface already exists** — built in (Chiltrix, SpacePak SIM, Nordic, LG,
Ecoforest) or a ~$200 vendor accessory (Samsung MIM-B19N, Mitsubishi MelcoBEMS A1M on the
FTC). No commercial company was found that replaces a major-brand hydro module outright;
every commercial precedent (Homely, Intesis, Harvest Thermal) keeps the vendor's brain in
the loop and commands it.

**Easiest path:** a GridWorks box that is a *supervisory* controller — the scada node plus
RS-485 — commanding each vendor's sanctioned interface, owning the circulator and hydronic
relays itself, and eliminating the vendor hydro module only where the vendor permits it.
Built low-voltage from UL-recognized components, that box has a realistic ETL listing path
(~$15–50k, 2–4 months), with field-labeling bridging the first tens of homes.

## Q1 — how control boxes get made; third-party precedent

- Big Asian brands build hydro modules in-house (Mitsubishi FTC at Livingston, Scotland;
  Samsung MIM kits are Samsung parts) [documented].
- European/smaller OEMs buy programmable controller platforms: **Carel** sells a ready-made
  residential-heat-pump application on c.pCO explicitly so "any manufacturer" can ship a
  heat pump; Siemens (Climatix S400) and Danfoss (MCX) run OEM heat-pump lines. Ecoforest
  is a Carel c.pCO shop [documented]. If GridWorks ever becomes the system OEM, Carel is
  the industry-standard way to build the box — but these drive generic compressor/EEV
  hardware, not another vendor's proprietary bus.
- **Sanctioned third-party control hardware exists** — Intesis (HMS) gateways "developed in
  collaboration with" Mitsubishi/Samsung/Daikin/LG/MHI; a July-2025 Intesis cascade
  controller manages up to 8 Samsung EHS A2W units over Modbus TCP; Mitsubishi's MelcoBEMS
  MINI (A1M) is built by UK partner Planet Devices under Mitsubishi's brand [documented].
- **Unsanctioned true controller replacements are hobby-grade only**: HeishaMon (Panasonic
  CN-CNT), P1P2MQTT (Daikin P1/P2), Samsung NASA bridges [documented as projects; none
  certified].

## Q2 — per-vendor ODU↔controller picture

- **Samsung EHS:** the MIM control kit is the mandatory brain (F1/F2 NASA RS-485 to ODU;
  F3/F4 to the wired remote). Two community sources report the ODU ignores injected F1/F2
  commands without the MIM — control authority lives at the MIM layer. NASA is well decoded
  with write support (esphome_samsung_hvac_bus, EHS-Sentinel) [community]. **Sanctioned
  path: MIM-B19N Modbus RTU module (~£150)** — read/write on/off, water-law target, zone
  setpoints, DHW; its config registers accept arbitrary NASA MessageSet IDs (effectively an
  official NASA gateway; Samsung register manual DB68-07538A) [documented]. SG-Ready
  contacts on the control kit [documented]. US EHS lineup announced CES 2025; **US-channel
  availability of MIM-B19N unconfirmed** — distributor question.
- **Mitsubishi Ecodan:** the ODU↔FTC link has no public decode — bypassing the FTC is off
  the table. Everything attaches at the FTC's CN105 service port: community bridges
  (gekkekoe/esphome-ecodan-hp is most mature) and the **sanctioned Procon MelcoBEMS A1M**,
  whose published Modbus table is full command (on/off, mode, flow/tank setpoints,
  force-DHW, prohibits, BMS-supplied outdoor temp) [documented]. Mitsubishi sells the FTC
  standalone (PAC-IF07xB-E "free planning") for third-party hydraulics; FTC6 has SG-Ready
  inputs; the PAC-IF011B/013B air-side interfaces take 0-10V/4-20mA capacity demand (EU
  parts — the only real analog-demand path found among majors) [documented]. **METUS
  launched US single-phase ecodan ATW 2026-03-19** (WUZ 2/3/4-ton H2i, −22°F, 158°F max
  flow) [documented]; US availability of A1M/PAC-IF parts unconfirmed.
- **LG Therma V:** native Modbus RTU built in (DIP-switch enable; memory map printed in the
  installer manual) — on/off, mode, heating/DHW setpoints writable; the R290 monobloc has an
  explicit third-party-control installer setting [documented]. Register/firmware quirks
  [community]. Not sold in the US at research time.
- **Smaller makers:** **Ecoforest** — documented "MODBUS SLAVE EXTENDED" BMS mode (public
  Control Applications Manual; writes bypass safety features per the manual's own warning);
  official register map circulates to integrators ("Modbus 2021 EN v02"); Carel platform;
  US entity exists, ecoAIR UL/ETL status unconfirmed [documented + community]. **Chiltrix
  CX34/CX50** — Modbus RTU marketed, register doc on request, community-proven full control.
  **Nordic/Maritime Geothermal ATW** — best documentation posture found: full BACnet MS/TP
  R/W object tables printed in the free public manual; caveat: two-stage, not inverter.
  **SpacePak Solstice SIM** — full writable Modbus table in the public install manual (reg
  1011 on/off, 1012 mode, 1192 heating target); split (SIS) has none. **Arctic** — weakest:
  Chinese-OEM monobloc, IOM shows no BMS port (dry contacts only); one dealer page claims
  Carel-with-BMS-card "on request", conflicting with the IOM [documented but conflicting].

## Q3 — what a GridWorks box requires

- **Listing:** UL 873 is withdrawn; live standards are UL 916 (energy management) and
  UL 60730-1 (+Part 2s). 60730 Annex H software-class evaluation applies only if the box
  performs *protective* functions — keep high-limit/freeze protection in listed components.
  Any NRTL mark works; ETL commonly cheaper/faster. Ballpark $15k–50k and 8–16 weeks for a
  controller built from recognized components, + FCC Part 15, + ~$10k–30k/yr follow-up
  [expert commentary]. **Bridges:** NEC 2023 (adopted statewide in Maine, eff. July 2024)
  formalizes field labeling via Field Evaluation Bodies; UL 508A panel-shop certification
  (~$3–8k + audits) allows self-labeled panels from listed components (AHJ acceptance for
  residential HVAC varies) [documented/expert commentary]. Harvest Thermal's pattern: keep
  the box 24V low-voltage so the line-voltage burden stays on off-the-shelf listed parts.
- **Warranty:** Magnuson-Moss bars conditioning warranty on vendor parts (FTC guidance +
  2018/2021 actions), but vendors may deny where the third-party part *caused* the failure
  — a reverse-engineered bus gives a colorable causation story on every compressor failure;
  commanding via the vendor's own sold Modbus interface largely defuses it [documented +
  inference; no HVAC-bus case law found].
- **Protocol licensing:** exists only as bilateral collaborations with established gateway
  vendors; no open developer program at any major. The practical license is productized:
  buy the gateway accessory.

## Q4 — negotiation plausibility

- **Homely** (UK) commercially controls Samsung/Mitsubishi/Daikin/LG/Midea fleets with no
  bespoke protocol deals — it buys each OEM's Modbus accessory. **Harvest Thermal** built a
  commercial product around the closed SANCO2 with no protocol at all (owns the hydronics,
  manipulates the native sensor/dry-contact interface, CTA-2045) [documented].
- Smaller makers demonstrably share: **Lambda** publishes full Modbus with writes; **NIBE**
  publishes S-series Modbus including a direct power-limit-in-watts register — the
  strongest external-control semantics found — and owns **Enertech** (US), a real
  negotiation door. Chinese ODMs email register maps on request [documented + community].
- **Ecoforest already behaves like a partner** (public BMS-mode doc, register map in
  integrator circulation). A 100-home fleet with Siegenthaler advocacy is a credible
  integrator account, not a stretch [inference].

## Q5 — skip-the-protocol alternative (native external control, buyable in NA)

| Unit | Interface | Control scope | Caveat |
|---|---|---|---|
| Chiltrix CX34/CX50 | Modbus RTU built in | mode, setpoints, on/off; 200+ params | register doc on request |
| SpacePak Solstice SIM | Modbus RTU, public table | on/off, mode, heating target | split (SIS) excluded |
| Nordic ATW | BACnet MS/TP, public R/W tables | demand, mode, setpoints | two-stage, not inverter |
| Ecoforest ecoAIR/ecoGEO | Modbus slave mode | full BMS demand authority | map via company; US cert TBD |
| Samsung EHS (US arriving) | MIM-B19N accessory | setpoints, water law, DHW, on/off + arbitrary NASA points | US accessory availability TBD |
| Mitsubishi ecodan US (3/2026) | A1M Modbus on FTC | full command incl. force-DHW | US A1M availability TBD |

No US residential AWHP takes raw 0-10V compressor demand; the only analog-capacity path is
Mitsubishi's EU PAC-IF family. CTA-2045 ships US-side only on tank water heaters.

## Recommended next actions

1. **Ask Jeff Lawrence / Ecoforest:** current official Modbus register doc (the circulating
   one predates the R290 ecoAIR+ line); warranty posture when a third-party BMS is demand
   authority in MODBUS SLAVE EXTENDED mode + the supported write set; ecoAIR US
   certification status/timeline (the "non-UL" note is the blocker); US integrator/pilot
   partnership; the Carel c.pCO application notes.
2. **Bench one Samsung MIM-B19N and one Chiltrix (or SpacePak SIM)** driven from the scada
   over RS-485 in an EDD harness — a few hundred dollars converts this report to Verified.
3. **Ask METUS/distribution** whether A1M and PAC-IF07x parts are supported with the new US
   ecodan line.
4. **Scope the GridWorks box as supervisory, low-voltage** (scada node + RS-485 masters +
   circulator/relay outputs from UL-recognized components; protective functions stay in
   listed devices; ETL to UL 916/60730; FEB field-labeling for the first cohort).
5. **Keep NASA/CN105 reverse engineering off the critical path** — the open-source stacks
   stay as monitoring/diagnostics and vendor-conversation leverage.
6. **Longer shots:** NIBE via Enertech (power-limit register in a US product); Nordic
   directly (integrator-neutral docs already public).

## Key uncertainties

US-channel availability of MIM-B19N and A1M/PAC-IF (unconfirmed either way); ecoAIR UL
status; Harvest Pod's own listing status; whether any vendor's warranty desk honors
third-party Modbus command in practice (no precedent found either direction);
Intesis/CoolAutomation licensing terms (undisclosed).

## Source index (primary citations)

Carel c.pCO HP application: carel.com/high-efficiency-management-for-residential-heat-pumps ·
Intesis Samsung EHS cascade: hms-networks.com/news (2025-07-14) · MelcoBEMS A1M ATW register
tables: s3.amazonaws.com/enter.mehvac.com (MelcoBEMS_MINI_A1M-ATW_Modbus V1.0.4) · MIM-B19N
registers: github.com/ZimKev/MIM-B19n_Modbus (mirrors Samsung DB68-07538A) · NASA decode:
github.com/omerfaruk-aran/esphome_samsung_hvac_bus, github.com/echoDaveD/EHS-Sentinel ·
Ecodan CN105: github.com/gekkekoe/esphome-ecodan-hp · LG Therma V Modbus: manualslib
manual/2050610 p.257 · Ecoforest BMS: ecoforest.com/academy Control-PSM-Gen1-V07E manual +
github.com/bp-ouhaha/EcoForest-modbus-registers · Nordic ATW manual: nordicghp.com (001970MAN) ·
SpacePak SIM manual: literature.mestek.com/dms/SpacePak/SIM_Installation_Manual.pdf · Arctic
IOM: hvacquick.com Arctic_HP_IOM.pdf · METUS US ecodan launch: businesswire 2026-03-19 ·
UL 916 / 60730: intertek.com standards updates · Magnuson-Moss: ftc.gov business-guidance
warranty law · Homely compatibility: homelyenergy.com/compatibility · Harvest Thermal:
neea.org product-council deck, docs.harvest-thermal.com · NIBE Modbus: assetstore.nibe.se
(878103) · NIBE–Enertech: nibe.com investors 2014-11-07 · Lambda protocol: lambda-wp.com
Modbusprotokoll.pdf · Maine NEC 2023: up.codes/viewer/maine/nfpa-70-2023.
