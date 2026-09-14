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
- **Mitsubishi**: `MitsubishiWUZSA48NMZ` (odu) + `MitsubishiERSFNM6E` —
  enum members exist, **no record**; wire to whichever fleet house runs
  it.

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

- The "assembly" question: whether the odu+idu pair earns a single
  name/record on top of the per-part records (Jonathan Woolley to name
  the assembly). Per-part records stand regardless.
- Serials arrive per install (beech's LG serial expected the week of
  2026-09-21); the record is authorable without the field serial (that
  rides the component `HwUid`, not the device-type record).
