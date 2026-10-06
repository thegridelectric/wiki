# Magic thresholds

Status: Draft · Pass 0 · Updated 2026-10-01

> What this is: the inventory of numbers the scada and LTN decide with that
> live in code rather than in an ops word, a `names` constant, or a device
> record. Each row says what the number decides and where it sits, so the
> team can look down the list and choose, per row, whether it becomes a
> declared parameter, stays in code with a sentence saying why, or goes.
> The Disposition column is the decision; `open` means not yet taken.

## How to read it

A threshold is "magic" when a reader has to open the code to learn that
it exists. The candidate homes:

- **ops word** (`gw.house0.operational.params`, `gw.nolan.operational.params`)
  when a house or a season may want a different value.
- **`names` constant** when the value is fleet-wide and vocabulary-shaped
  (a channel, a node, a tariff clock).
- **device record** (`hp.device.type.gt` and kin) when the number is a
  property of a part.
- **stays in code, with a sentence** when it is an engineering margin no
  one will tune; the sentence is the obligation.

## Plant judgment (`actors/hydronic/house0.py`)

| Threshold | Where | What it decides | Candidate home | Disposition |
|---|---|---|---|---|
| 3-hour forecast window (`RswtF[:3]`, `RswtDeltaTF[:3]`) | `house0.py:608`, `:609`, `:673` | How far ahead `is_buffer_empty` / `is_buffer_full` look when setting the buffer's required temperature | ops word or a constant with a sentence | open |
| `MaxEwtF - 10` | `house0.py:615` | Caps the buffer-empty threshold 10 F under the heat pump's max entering-water temperature | ops word (a margin on a param already there) | open |
| `min_delta_f = 5.4` | `house0.py:710` | How much colder the store top must be than the buffer top before storage counts as colder (5.4 F = 3 C) | ops word | open |
| `usable_kwh < 0.2` | `house0.py:756` | Below this the store is "empty" | ops word | open |
| Defrost lines: LG Multi V total under 8.4 kW, Samsung AE055 idu under 4 kW | `hp_boss/sensing.py` (`DEFROST_SIGNATURES`), read at `house0.py` `hp_in_defrost` | Whether the heat pump is judged in defrost from its power draw | device record (`hp.device.type.gt`, noted in the records spoke) | decided 2026-09-15: hand-kept table until the record carries it |
| `PUMP_FLOW_GPM_THRESHOLD = 0.1` | `sh_node_actor.py:47` | Flow above which a pump counts as flowing (`store_pump_is_on`, `primary_pump_is_on`) | stays in code with a sentence, or ops word if a meter's noise floor differs by house | open |

## Heat-pump surface (`actors/hp_boss/sensing.py`, `actors/sieg_loop/strat_protect.py`)

| Threshold | Where | What it decides | Candidate home | Disposition |
|---|---|---|---|---|
| Compressor running above 500 W, stopped below 80 W (Samsung AE055, `SimHpOdu`) | `hp_boss/sensing.py` (`HP_TRAITS`) | The secondary pump and iso valve posture in the Nolan heating machine; does not handle defrost | device record (`hp.device.type.gt`), read once by the unit's sensed state machine on hp-boss (`control-hierarchy.md` "The heat-pump surface") | hand-kept table until the record carries it |
| Call-open lead 120 s | `hp_boss/sensing.py` (`HP_TRAITS`) | How long before an on-peak window opens the call opens, so the compressor has stopped drawing by the boundary | device record (the unit's stop lag) | provisional until the spruce call-cycling experiment measures it |
| `OFF_POWER_W = 500`, `OFF_SETTLE_S = 120` | `strat_protect.py` | Draw above which, this long after hp-boss reports off, the sieg loop is blind to the heat pump; not keyed by device type | the same device record values as the rows above, read from one place | open |

## Store temperature pass (`actors/hydronic/store_temps.py`)

| Threshold | Where | What it decides | Candidate home | Disposition |
|---|---|---|---|---|
| Valid tank range 35–200 F | `store_temps.py` (`MIN_VALID_TANK_TEMP_F`, `MAX_VALID_TANK_TEMP_F`) | A reading outside it is a sensor fault, not water | stays in code; the sentence is there | decided 2026-09-15 |

## Tariff clock (`actors/hydronic/shared.py`)

| Threshold | Where | What it decides | Candidate home | Disposition |
|---|---|---|---|---|
| On-peak windows | `sh_node_actor.py` `in_onpeak_window` | `is_onpeak`; the whole TOU strategy keys on it | read from the ops word: `Tariff.OnPeakWindows` (`gw.tou.window`: Start inclusive, End exclusive, over the listed days) | settled |
| "Just before on-peak" = the 2 minutes before a window opens, on a day that has one | `shared.py` `just_before_onpeak` | the pre-peak charge cue and the last setpoint-memory refresh | stays in code with a sentence | open |
| 2-minute look-ahead into peak | `shared.py` `is_onpeak` | `is_onpeak` turns true two minutes early | stays in code with a sentence | open |
| Whitewire heat-call threshold, 10 W | tlayouts House0 gen, each zone's `heat-call` DerivedChannel parameter | whether a zone is calling; the only whitewire threshold (the scada carries none) | per zone in the layout, or one fleet value, once measured against real readings | open (an assumption until measured) |

## Strategy timers (leaf ally and local control)

| Threshold | Where | What it decides | Candidate home | Disposition |
|---|---|---|---|---|
| `MAIN_LOOP_SLEEP_SECONDS = 60` | `all_tanks.py:37`, `buffer_only.py:36`, `tou_base.py:42` | The strategies' judgment cadence | stays in code with a sentence | open |
| `NO_TEMPS_BAIL_MINUTES = 5` | `all_tanks.py:38`, `buffer_only.py:37` | How long the ally tolerates no tank temperatures before giving up | ops word | open |
| `DEFROST_TIMEOUT_MINUTES = 20` | `all_tanks.py:39`, `all_tanks_tou.py:20` | How long a detected defrost is honored | device record or ops word | open |
| `STORE_DEFROST_DETECTION_MINUTES = 10` | `all_tanks.py:40`, `all_tanks_tou.py:21` | No defrost detection in the first minutes of charging the store | ops word | open |
| `BLIND_MINUTES = 5` | `tou_base.py:43` | How long without readings before local control goes scada-blind | ops word | open |
| `SYSTEM_COLD_MINUTES = 5` | `tou_base.py:44` | How long house and tanks stay cold before switching to non-electric backup | ops word | open |
| `COLD_DELTA_F = 2.0` | `hydronic/cold.py` | How far under its setpoint a critical zone is before it is cold | ops word | open |
| `COLD_LATCH_S = 300` | `hydronic/cold.py` | How long a critical zone is cold before the glitch and the dispatch refusal | ops word | open |
| `STILL_COLD_IN_BACKUP_S = 3600` | `hydronic/cold.py` | How long cold in backup before the still-cold glitch | ops word | open |
| `FREEZE_F = 40.0` | `hydronic/cold.py` | The zone temperature under which a zone is freezing | ops word | open |

## Procedural doctors and monitors (`actors/procedural/`)

A doctor restoring a pump's 0-10V defaults names the command node
(`set_010_defaults(command_node=...)`). With no argument the call is a silent
no-op under local control, where the host node is `lc` and the boss is `n`.

| Threshold | Where | What it decides | Candidate home | Disposition |
|---|---|---|---|---|
| `MAX_PUMP_DOCTOR_ATTEMPTS = 3` | `dist_pump_doctor.py:19`, `store_pump_doctor.py:18` | Attempts before the doctor declares the pump failed (critical glitch) | stays in code with a sentence | open |
| `MAX_WAIT_SECONDS` 50 (dist) / 15 (store) | `dist_pump_doctor.py:20`, `store_pump_doctor.py:19` | How long the doctor waits for flow after restarting the pump | stays in code with a sentence | open |
| `THRESHOLD_FLOW_GPM_X100 = 50` | `dist_pump_doctor.py:21` | Dist flow that counts as recovered (0.5 gpm; note `PUMP_FLOW_GPM_THRESHOLD` is 0.1) | one flow floor, shared with the pump-on predicates | open |
| `ZONE_CONTROL_DELAY_SECONDS = 50`, `PUMP_DELAY_SECONDS = 10` | `dist_pump_monitor.py:23`, `store_pump_monitor.py:23` | Grace after a zone or pump command before the monitor judges | stays in code with a sentence | open |
| 15 s and 5 s watchdog waits inside the doctor runs | `dist_pump_doctor.py:98`, `:139` | Settling time between the doctor's steps | stays in code with a sentence | open |

## LTN (`actors/ltn/ltn.py`)

| Threshold | Where | What it decides | Candidate home | Disposition |
|---|---|---|---|---|
| Contract energy under 1000 Wh rounds to 0 | `ltn.py:1218` | A next-hour contract too small to bid becomes no contract | ops word or a constant with a sentence | open |
| Forecast price used until minute 55 | `ltn.py:1608` | When the hour's price read switches source | goes with the price-source rework (the docstring says the real-time price is not used yet) | open |
| 48-hour price horizon padded from the last value | `ltn.py:1709` | FLO horizon and how a short forecast is extended | FLO parameter | open |

## Open

- The two flow floors (0.1 gpm for "pump on", 0.5 gpm for "doctor sees
  flow") should be one declared number or two with a reason.
- Rows are pinned by `file:line` on `jm/spruce-unlimbo` at 2026-09-15;
  re-pin when the files move.
