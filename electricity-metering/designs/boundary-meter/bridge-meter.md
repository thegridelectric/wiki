# The bridge meter

Status: Draft · Pass 0 · Updated 2026-11-22

> What this is: the first step of boundary-meter. A bought class 0.2
> meter beside the voltage beacon settles with the ISO for the houses
> that come before our own meter is listed. This spoke picks it, verifies
> its class, and gets our box reading it.

## Do this next

Verify the Acuvim II's class: its datasheet says ANSI C12.20 class 0.1
and its product page says 0.2 in places, with no lab named. Ask
Accuenergy for the test report and the lab. At the same time price the
set: the meter, the AXM-WEB2 module (MQTT, HTTPS push, 1 s logging), and
two C57.13 class 0.3 solid-core CTs from a third party (Eaton S060-201
or EIG LV-CT-120), since Accuenergy's own solid-core CTs are rated to
IEC 61869-2 and not C57.13.

## Then

- Confirm the 2-element 3-wire single-phase wiring covers both 120 V
  legs and the 240 V heat pump feeder in one register set.
- Ask ISO New England participant support or the Assigned Meter Reader
  what evidence they want for a class 0.2 claim on a non-utility meter,
  before buying.
- A reader on our box: MQTT from the WEB2 into the scada's power meter
  actor pattern (`gridworks-scada/gw_spaceheat/actors/power_meter.py`),
  readings as sema `power.watts` and the cumulative registers for
  energy.
- Fallbacks if the Acuvim fails verification: the Elkor WattsOn-Mark II
  (class 0.2 certified, UL E250395, 100 ms HTTP POST), then the EIG
  Shark 250 (class 0.1, UL E250818, Modbus polled at 5 s)
  (`../../hardware/existing-meters.md` "When the utility lets us choose").

## Open

- Whether the bridge meter stays in the panel after ours is listed, as
  the audit reference, or is reused in the next house.
