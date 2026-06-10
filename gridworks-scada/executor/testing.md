Status: Draft · Pass 0 · Updated 2026-06-09

# Testing LTN ↔ SCADA (in-process live-test harness)

What this is: how to exercise a real **LTN talking to a real SCADA** in a single
process, with no external broker — the `ScadaLiveTest` harness. Use it to verify
anything that crosses the LTN↔SCADA link (addressing, topics, contract/heartbeat
flow, event upload), including the routing-key shape an LTN actually puts on the
wire.

## The harness

`tests/utils/scada_live_test_helper.py::ScadaLiveTest` extends
`gwproactor_test`'s `TreeLiveTest`. It boots a **proactor tree** in-process and
links the nodes over the gwproactor test transport (an in-memory paho link — no
`gw-dev-rabbit`, no MQTT port, no AMQP):

| Role | App | Handle |
|---|---|---|
| **parent** | `LtnApp` (`gw_spaceheat/ltn_app.py`) | `h.parent` (proactor), `h.parent_app` |
| **child1** | `ScadaApp` (`gw_spaceheat/scada_app.py`) | `h.child` / `h.child1`, `h.child_app` |
| **child2** | `Scada2App` (`gw_spaceheat/scada2_app.py`) | `h.child2`, `h.child2_app` |

So in the proactor tree the **LTN is the parent and the SCADA is its child** —
the inverse of the financial/contract relationship, but it is how the proactor
link is wired (the SCADA is the party that goes offline, so it dials out).

**Fake hardware layout.** `tests/conftest.py` sets
`TEST_HARDWARE_LAYOUT_PATH = tests/config/<DEFAULT_LAYOUT_FILE>` and calls
`set_hardware_layout_test_path(...)`. `gwproactor_test`'s autouse fixture then
copies that layout into an **isolated XDG config dir per test** — so each test
gets a clean house-0 layout and never touches your real `~/.config`. The SCADA
short_name comes from this layout via `H0N.primary_scada = "s"`.

## Basic usage

```python
import pytest
from tests.utils.scada_live_test_helper import ScadaLiveTest

@pytest.mark.asyncio
async def test_tree_connect(request: pytest.FixtureRequest) -> None:
    async with ScadaLiveTest(start_all=True, request=request) as h:
        await h.await_for(
            lambda: h.child_to_parent_link.active()
            and h.child1_to_child2_link.active()
            and h.child2_to_child1_link.active(),
            "ERROR waiting for children to connect",
        )
```

- `start_all=True` boots parent + both children; `request` is the pytest fixture.
- `await h.await_quiescent_connections()` waits for the whole tree to connect
  **and** finish the default event upload — the usual "system at rest" gate.
- Children default to **simulated** drivers (`child1_simulated` / `child2_simulated`
  in `ScadaLiveTest.__init__`), so no real hardware is needed.

## Links and per-link stats (what to assert on)

`TreeLiveTest` exposes the link states and **`RecorderLinkStats`** for each edge:

| Edge | LinkState | Stats |
|---|---|---|
| LTN → SCADA | `h.parent_to_child1_link` | `h.parent_to_child1_stats` |
| SCADA → LTN | `h.child_to_parent_link` (= `h.child1_to_parent_link`) | `h.child1_to_parent_stats` |
| SCADA ↔ SCADA2 | `h.child1_to_child2_link` / `h.child2_to_child1_link` | `h.child1_to_child2_stats` / `h.child2_to_child1_stats` |

The recorder stats count messages **received by topic** (see
`gwproactor_test` `InstrumentedProactor` / `live_test_helper.py`
`num_received_by_topic`, and `MQTTTopic.encode(envelope_type, src, dst, type)`
to build the expected topic). This is the hook for asserting that a message the
LTN addressed to the SCADA actually arrives at the SCADA on the expected topic.

## Recipe: verify LTN → SCADA addressing (the gw-wrapped change)

The proactor encodes a published `Message` as MQTT topic
`gw/<src>/to/<Dst>/<MessageType>`. When the LTN sends with
`Dst=self.scada.name` (`= "s"`), the SCADA — subscribed to its own short_name —
receives it; when the LTN sent the old `Dst="broadcast"`, the SCADA was **not**
the addressee and never received it. So the behavioral check for the
`ltn-sends-gw-wrapped` change (design, OPS-387) is:

1. Boot the tree and reach quiescence.
2. Drive the LTN to emit one of the changed types (e.g. `FloNextHourPlans` /
   `Glitch` → scada; `Bid` → `Dst="mm"`). A sample `FloParamsHouse0` lives in
   `tests/actors/test_ltn.py::get_sample_house_0_flo_params`.
3. Assert the SCADA's received-by-topic count for `gw/<ltn>/to/s/<type>`
   increments (and, for `Bid`, that it goes to `to/mm`, not the scada).

`Bid → "mm"` is deliberately the gwbase `RoutingClass.MarketMaker` token, so the
wire key `gw.<src>.to.mm.<type>` already matches the new/future rabbit structure
(it resolves to `TransportClass.MarketMaker` on the consumer side). See the
gridworks-base design `must-accept-current-ltn-messages` for why the consumer
(gwbase) tolerates these tokens.

## Running

The scada tests are pytest + `pytest-asyncio` (`asyncio_mode`/markers per
`pyproject.toml`), run inside the scada's own venv (the repo is not a flat `uv`
project; see the repo `README`/`x86.sh`). `gwproactor_test` provides the autouse
config-isolation and certificate fixtures.

## Open

- Document the exact LTN entry point to *drive* a single publish of each changed
  type (so the recipe above is a one-liner, not a re-derivation).
- Confirm the precise `RecorderLinkStats` accessor for received-by-topic counts
  and pin it with a `file:line` once a test exercises it.
- This in-process harness does not model the broker `ear`/`#` tap or the AMQP
  side; for end-to-end *persistence* (LTN → broker → JournalKeeper) use a
  dev-broker run against `gw-dev-rabbit` instead.
