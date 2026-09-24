# Fleet hp.device.type.gt records (spoke)

Status: Draft · Pass 0 · Updated 2026-09-14 · Linear: OPS-532

> What this is: author and vendor a `hp.device.type.gt` record for every
> heat pump the fleet runs, so a house gen's `HpPartSpec` binds its
> `hp-odu`/`hp-idu` to real nameplate facts, not a bare `DeviceType`
> string. The `gw1.device.type` enum already names the units; this fleshes
> out the records behind those names.

**EDD: no** build-out (record authoring); verified by `sema validate` on
each record and the house gen loading it (`HpPartSpec.record_file`).

## Where it stands

`gw1.device.type` names three families of split/monobloc heat pump, but
only Samsung has vendored records:

- **Samsung AE055** (spruce): `SamsungAE055FCYDCG` (odu) +
  `SamsungAE055FEYMCG` (control box) — records EXIST in
  `tlayouts/src/tlayouts/device_types/` (`samsung.ae055.odu-…json`,
  `samsung.ae055.ctrl.box-…json`).
- **LG** (beech): `LGARUM048GSS5` (Multi V outdoor) + `LGARNH423K3A4`
  (Hydro Kit indoor) — enum members exist, **no record**. beech's gen
  references the `DeviceType` strings with no `record_file`; this spoke
  fills them.
- **Mitsubishi Ecodan** (maple): `MitsubishiWUZSA48NMZ` (odu) +
  `MitsubishiERSFNM6E` (hydrobox, no compressor) — enum members exist,
  **no record**. Only the odu gets an `hp.device.type.gt`; the hydrobox
  holds the primary pump, so the odu record says the package's pump is
  factory-installed.

## What a record carries

`hp.device.type.gt` fields (see `samsung.ae055.odu` for the worked
example): `MaxKwEl`, `HeatingCapacityBtuHr`, `CoolingCapacityBtuHr`,
`PrimaryPumpFactoryInstalled` / `PrimaryPumpOverridable` /
`PrimaryPumpAlwaysOn`, `Refrigerant`, `CompressorRatedAmps`, `Mca`,
`Mop`, `ProductInfoUrl`. A split system's indoor/control side is an
`hp.control.box.device.type.gt` record (as Samsung's control box is).

## The work, per HP

1. Gather the nameplate + product facts (the HP product-info Drive
   folders; the field nameplate photo for serials).
2. Author the `hp.device.type.gt` (+ `hp.control.box.device.type.gt`
   where the unit is split) — serialize through the snapshot runtime,
   `sema validate` green.
3. Vendor the record JSON into `tlayouts/src/tlayouts/device_types/`
   (dash-separated filename per the sema-typed-JSON convention).
4. Wire it into the house gen: `HpPartSpec(..., record_file=…)` so the
   gen loads it and the layout carries the `DeviceTypes` entry.

## Done when

Every heat pump a fleet layout references has a vendored
`hp.device.type.gt` record loaded by its gen; `sema validate` green on
each; no `HpPartSpec` left with a bare `device_type` string and no
record.

## Open

- **Defrost power signature.** The record carries no way to tell the
  compressor is defrosting. The scada judges it from power (LG Multi V:
  idu+odu under 8.4 kW; the retired Samsung hydro-kit rule was idu under
  4 kW), hand-kept in `house0.py` by the hp-odu `DeviceType` until the
  record carries the signature: which draw to watch (idu, or idu+odu) and
  the watt line. Add it here, then the table in `house0.py` retires.
- **Fir runs the Samsung AE055 as a split** (Hydro Unit + backup heater;
  the Drive folder "Samsung EHS Split A2W" names ODU AE055FCYDCG and IDU
  AE055FEYMCG), the same two device-type values spruce uses for its
  monobloc + control box. The enum descriptions call them "mono"; one
  pair of values serves both pairings, or the split earns its own. The
  defrost table keys the Samsung idu rule on the odu value either way.
- **Elm's Arctic high-temp monobloc is the MAHRW030ZA (BEH2)-R32**
  (installing 2026-09; the Drive folder "Arctic High Temp"). An R32 +
  R515b cascade, two compressors, leaving water to 95 C; the folder's
  060ZA(BE)-R32 sheet is the single-compressor EVI sibling, not elm's.
  It has no `gw1.device.type` value, no record, and no defrost signature.
  Proposed value `ArcticHighTempMAHRW030ZA` (maker + "HighTemp" + the
  designation, the enum's maker-plus-nameplate shape), with the gwsproto
  twin. A monobloc has one power draw, so its signature is `total`
  against a line learned from its first defrost season; a cascade's dip
  may be shallow if the high stage keeps drawing while the low stage
  reverses. Until then it is never judged in defrost.
- **Mitsubishi defrost signature, from maple's April 2026 data.** No rule
  exists for the Ecodan. The journal DB holds maple's `hp-idu-pwr`,
  `hp-odu-pwr`, `hp-lwt`, `hp-ewt` and `primary-flow` for all of April
  2026 (8k / 16k / 55k / 55k / 151k rows): pull them (`experiments/
  pull_readings.py`), find the defrost episodes (a leaving-water dip with
  the compressor still drawing, or the reversed-cycle draw pattern), and
  read the draw and line off them. Then the row goes into the control
  loop's table and, once the record carries the field, into the record.
- The "assembly" question: whether the odu+idu pair earns a single
  name/record on top of the per-part records (Jonathan Woolley to name
  the assembly). Per-part records stand regardless.
- Serials arrive per install (beech's LG serial expected the week of
  2026-09-21); the record is authorable without the field serial (that
  rides the component `HwUid`, not the device-type record).
