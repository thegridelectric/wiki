# report.event v004

Status: Draft · Pass 0 · Updated 2026-06-23 · Linear: OPS-329

**EDD: no** build-out/fix — verified by the suite plus re-parsing real Spruce
`report.event` messages emitted after the fix against `report.event/004` with no
axiom failures.

> What this is: re-enforce the `report.event` identity/time axioms (re-added in
> sema `report.event/004`) by fixing the **scada emitter** so its messages
> actually satisfy them. Bite-sized; the architectural choice is call-site fix vs
> a type-level validator.

## Why v002 axioms 1 & 2 failed (not a regression)

`report.event` is an Event that wraps a `Report`. The axioms require the wrapper
to carry the wrapped report's identity:

- **Axiom 1:** `MessageId == Report.Id`
- **Axiom 2:** `TimeCreatedMs == Report.MessageCreatedMs`
- **Axiom 3:** `Src == Report.FromGNodeAlias` (this one passed — so v003 kept it)

The emitter never propagated them. `scada.py` `send_report()` builds:

```python
self.services.generate_event(ReportEvent(Report=report))
```

passing only the `Report`. `ReportEvent` inherits `MessageId` / `TimeCreatedMs`
from `EventBase`, where `MessageId = Field(default_factory=lambda: str(uuid4()))`
and `TimeCreatedMs` defaults to a fresh clock read. So the wrapper **mints its
own** id and timestamp, which by construction differ from the report's — a
different uuid (axiom 1) and a ~1 ms-off timestamp from two separate `time()`
reads (axiom 2, e.g. `…055` vs `…054`). v003 dropped axioms 1 & 2 to let Spruce
be the source of truth; we want them back.

## The fix

1. **Bump the version.** In `gwsproto/named_types/events.py`, `ReportEvent.Version`
   `Literal["003"]` → `Literal["004"]`. (Old stored v003 messages stay v003 —
   versioning handles them; no migration.)
2. **Propagate identity at the construction site** (`scada.py` `send_report`):

   ```python
   self.services.generate_event(ReportEvent(
       Report=report,
       MessageId=report.Id,
       TimeCreatedMs=report.MessageCreatedMs,
   ))
   ```

3. **(Recommended) Enforce at the type**, so no future call site can get it
   wrong: a `model_validator` on `ReportEvent` that defaults `MessageId` /
   `TimeCreatedMs` from `Report` when not explicitly set. Prefer this over the
   bare call-site fix — it makes the axioms structurally impossible to violate.

**Verify first:** confirm `services.generate_event(...)` does not re-stamp
`MessageId` / `TimeCreatedMs` downstream (a quick read of the proactor path);
if it does, the fix moves there.

## Done-when

- A freshly-emitted `report.event` from a running scada decodes strict against
  `report.event/004` with no axiom-1/2 errors.
- One of the previously-failing captured Spruce eventstore messages, re-emitted
  through the fixed path, passes.
- The scada suite is green.
