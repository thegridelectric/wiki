# pico-bench-harness (design)

Status: Draft · Pass 0 · Updated 2026-09-21

**EDD: yes** the harness is itself the experiment: it is trusted once its
late-link scenario goes red on firmware known to skip the params post
(`0ca8a2f`) and green on the patched firmware, on both bench boards
(`experiments/future/pico-bench-harness/`).

> What this is: a bench harness for pico firmware (two real picos on a
> switched rail, a scripted listener in the scada's place), so a firmware
> bug found in the field gets a test that fails before its fix goes out.

## The problem

`gridworks-pico` has no tests. Pico code cannot be tested off the board in
a way that means anything: the behaviour that matters is the WiFi chip's
join timing and the WIZNET5K driver, which a stand-in does not have. The
params-retry patch (OPS-553) was tested in the field for that reason. The
harness lets the next firmware change pass on one PicoW and one Wiznet
pico before it goes to a house.

## The harness

In `experiments/future/pico-bench-harness/`, growing under OPS-402:

- the two bench picos on a rail the bench pi cuts with a relay;
- a listener in the scada's place that follows a script per scenario:
  answer at once, stay silent for t seconds and then answer, answer params
  with changed settings;
- a run is rail off, rail on, watch for a bounded time, then one line per
  scenario and board: PASS or FAIL, with the request log as evidence.

## First scenarios: the params retry

Each on both boards. They are the local test for the OPS-553 field bug,
written after the fact.

1. **Late link.** The listener refuses connections for 15 s after rail on
   (longer than the connect timeout), then answers. PASS: the params post
   arrives. Red on `0ca8a2f`.
2. **Late answer with changes.** As 1, and the params answer changes
   `CapturePeriodS`. PASS: the pico resets once, posts params again, and
   reports on the new period; no second reset.
3. **Prompt link.** The listener answers from the start. PASS: one params
   post, no retry, no reset. Guards the normal boot.
4. **Never answered.** The listener answers readings and never answers
   params. PASS: readings keep their cadence for 10 minutes and a params
   attempt arrives about every 30 s.

## Do this next

1. Build the harness start on the bench: one PicoW, one Wiznet pico, a
   relay on their rail, the scripted listener.
2. Show scenario 1 red on `0ca8a2f`, then the four scenarios green on the
   patched firmware.
3. Take the params-retry plan and these scenarios through the adversarial
   cycle at the Design scale (`adversarial-cycle.md`; pin in
   `~/.codex/config.toml`, `gpt-5.6-sol`, high). Round 1 ran on 2026-09-20
   against a wider plan and returned NOT APPROVED; the plan was then cut to
   the params retry and the harness start. The record is
   `scratch/firmware-patch/`: `plan-r1.md`, `sol-r1.md` (12 blocking
   findings), `fable-r1-response.md` (each finding checked, and the
   direction of the fold), `start-commit.txt`. Round 2 is a fresh thread,
   since the plan was rewritten and not just folded. Its focus text names
   the code as the contract (`gridworks-pico` on `td/pico-easy-fixes`:
   `tank_module/tank_module_3_main_no_net.py`,
   `btu_meter/async_btu_main_no_net.py`, `net.py`; and
   `starter-scripts/api/common.py` `update_pico_code`), states the
   Design-scale materiality bar, asks for every finding above it, carries
   the secrets clause, and says what round 1 found and what was cut, so
   Sol attacks the current plan: the reset on a late changed answer (reset
   loops, a reset landing in a flash write, the BTU flow count across a
   reset), the retry's place in each loop, `link_is_up()` on ethernet, and
   whether the four scenarios can fail for the right reason. Check each
   finding against the code, fold what holds, record `sol-r2.md` and
   `fable-r2-response.md`; at most four rounds. The human holds the Pass
   increment.

## Open

- The Linear issue for this design, and whether it is its own issue or
  part of OPS-402.
