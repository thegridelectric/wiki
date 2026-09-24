# Add service records

Status: Draft · Pass 0 · Updated 2026-09-23 · Linear: OPS-558

**EDD: no** build-out of one word and its journal path, verified by the suite
and a startup report on one house that carries a disabled name.

> What this is: a service-record word carrying the why and the plan behind
> each name in a layout's `DisabledNodeNames` and `DisabledChannelNames`.

## The note

The layout carries the fact: a name in `DisabledNodeNames` or
`DisabledChannelNames` is required by the word, declared in the layout,
currently not available, and pending a field visit. It does not carry the
story. Why a thing is unavailable, who found it, and what the plan is has
a person, a date and a resolution, and changes with tickets, not with the
design. Putting it in the layout would make every regeneration a place
where service history drifts or gets lost.

Spruce today: one thermistor is missing outright; another channel is a
defect on a gw101 BTU board that was not tested at provisioning, and the
board stays in because it still reports store flow, with a swap planned.
Beech: the dist BTU meter is a whole actor down, a gw101 rev B board where
the voltage never reaches the pico.

The word, one record per disabled name: the house, the node or channel
name, a kind (missing, defective, not yet installed, deferred), a
plain-text note, the plan, opened and closed stamps. Not part of the
layout closure. Rides the journal and shows in the startup report, so the
box says at boot which names are down and why.

Open: the exact fields; whether opening a record is a human tool or
something the scada does when a channel flatlines; where the records live
between boots.
