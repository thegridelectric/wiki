# Pico firmware rollout (spoke)

Status: Draft · Pass 0 · Updated 2026-10-14 · Linear: OPS-532

> What this is: the scada side of the pico firmware round
> [OPS-595](https://linear.app/gridworks/issue/OPS-595) and the order
> in which the fleet's btu and tank picos get the new build. The
> firmware is done and bench-verified on all three boards; its eight
> words are published. Nothing here starts until scada `main` is on
> the boxes, because its pico handlers differ from `legacy`'s by about
> 400 lines each and the work is written once.

## Why the order is fixed

The new firmware posts a `pico-heartbeat` every 10 s and counts every
non-200 as a failure: two failures rebuild the link, two more and the
pico resets itself. Today's scada answers the heartbeat 404 and refuses
`async.btu.params` 110 and `tank.module.params` 210 with an empty 200
(`actors/api_btu_meter.py`, `actors/api_tank_module.py`). A field pico
on the new build against today's scada would reset about every 40 s and
run on default params. So the scada work is the gate, every scada a
pico talks to must have it before that pico is reflashed, and the
firmware goes out house by house behind it.

## Steps, in sequence

1. **Heartbeat route.** `POST /<actor>/pico-heartbeat` on `ApiBtuMeter`
   and `ApiTankModule`: decode `pico.heartbeat` 000 through the codec,
   check `HwUid`, feed `PicoLiveness.heard`; a `ResetCause` of
   `SelfReset` is a Warning glitch. Twins for `pico.heartbeat` and
   `pico.reset.cause`; the scada's `sema_seed_request.yaml` gains the
   heartbeat, and `microvolts` and `multichannel.snapshot` leave the
   conformance test's no-word allowlist now that they have words.
2. **Params at both versions.** `async.btu.params` 100 and 110,
   `tank.module.params` 200 and 210 accepted side by side, the answer
   at the version received; 110 and 210 add `MacAddress` and (btu)
   `ReadTemps`. The scada keeps answering `ReadTemps` true: the BTU
   layout word requires the hot and cold channels, so a flow-only
   GW101 waits on a new version of that word (OPS-595 section 3). Both
   pins stay until the fleet is on the new firmware; dropping 100 and
   200 is the last step here.
3. **Liveness bound.** `PicoLiveness` gains `recovery_budget_s`
   (`PICO_RECOVERY_BUDGET_S = 50`) beside its multiple, the Warning
   glitch at 21 s of silence, `PicoMissing` and the rail cycle at 71 s.
   Tests in the style of `tests/actors/test_pico_identity.py`.
4. **Bench against a dev scada.** A Pico W from gridworks-pico's bench
   posting to a dev scada on the laptop: heartbeats 200, a 110 params
   post answered at 110, the liveness clock running on the heartbeat.
   This is the step that lets 1–3 be called built.
5. **Scada to the boxes.** Pull and restart per the instance READMEs,
   `main` everywhere and `actual-spruce` at spruce.
6. **Firmware to the boxes.** Copy `async_btu_main_no_net.py` and
   `tank_module_3_main_no_net.py` from the gridworks-pico commit into
   `starter-scripts/firmware/` with the commit in `firmware/SOURCE`,
   through git, never scp. `pico_reflash.sh <wait> <hwuid>=<btu|tank>`
   on the box stages the files, stops the scada, serves them from the
   API, cycles the 5 V bus, and reports which picos updated. Flow-meter
   picos (hall, reed) are not reflashed this way and are not in this
   round.
7. **One pico first.** Beech's primary-btu, the motivating case, in a
   week when someone will be in Millinocket; let it run a few days with
   the box log and the journal as the record. Then the rest of beech,
   then house by house, spruce last because its two scada lines must
   both be at step 5.
8. **Field windows.** OPS-595's windows 1–3 (posts dropped 45 s, posts
   dropped 150 s, scada down ten minutes) on the first reflashed pico;
   they take OPS-595's sections to Verified and this spoke with them.
9. **Drop the old pins** once every btu and tank pico posts 110/210.

Estimate for steps 1–4: about 9 h, 90% range 6–15; the width is the
dual-version params twins, which may need a discriminated-union pattern
gwsproto does not have yet.

## Do this next

Step 1, the heartbeat route, once scada `main` is on the boxes.
