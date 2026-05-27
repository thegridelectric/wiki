# Support non-GNode actors in `ActorBase`

Status: Draft · Pass 1 · Updated 2026-05-27

> Today `ActorBase` requires every consumer of `gridworks-base` to
> present a `g.node.gt`-shaped JSON file at a system-level path, even
> when the service isn't a GNode. This design unwinds that coupling
> in three interlocking pieces: split the settings shape (ServiceSettings
> vs GNodeSettings), adopt the XDG path convention, and Sema-validate
> the init JSON at the boundary. **All three land together** — each
> piece alone is incomplete; together they make the journalkeeper-style
> non-GNode service path clean.

## Motivation

The 2026-05-23/24 `gridworks-journalkeeper → base 0.4.0` refactor
(session `bright-frost`) exposed the friction. Journalkeeper consumes
the broker and persists to Postgres but is **not a GNode** — no GNode
role on the grid, no heartbeat/time-coordinator participation. To get
`ActorBase.__init__` to run, journalkeeper had to synthesize a fake
`g_node.json`:

```json
{ "Alias": "d1.journal.dev.bright-frost",
  "GNodeId": "00000000-0000-0000-0000-000000000001",
  "GNodeClass": "journalkeeper" }
```

This is two problems wearing one hat: (a) the *concept* "every actor
is a GNode" is wrong (journalkeeper, ear, future analytics consumers
are not GNodes); (b) even if it were right, the file isn't serving
its stated purpose — `ActorBase` reads three opaque strings and never
validates the contents as a real `GNodeGt` (the full Sema type has
eight fields + five axioms, none of which the constructor touches).

## Invariants the design holds

1. **`ServiceSettings` is the minimum to be an actor on the broker.**
   `alias` + `rabbit` + `paths`. No GNode identity.
2. **`GNodeSettings` extends `ServiceSettings`** with the GNode-only
   durable identity: `g_node_path`, `transport_class`. Loads `Alias`
   / `GNodeId` / `GNodeClass` from the on-disk file at construction.
3. **`ActorBase` consumes `ServiceSettings`**; `GridworksActor`
   consumes `GNodeSettings`. Existing subclasses that passed
   `GNodeSettings` to `ActorBase` keep working (covariant).
4. **The XDG convention governs default file locations.** Config:
   `~/.config/gridworks/<service>/`. Data:
   `~/.local/share/gridworks/<service>/`. No more
   `/etc/gridworks/g_node.json` as a hard default.
5. **`g_node.json` is parsed AS a `GNodeGt`** via the Sema codec,
   with axiom enforcement, and only by `GridworksActor`. A non-GNode
   service never needs the file.

## Sub-specs

- [`service-settings.md`](service-settings.md) — the
  `ServiceSettings` / `GNodeSettings` split. The base-class refactor
  that lets non-GNode actors avoid GNode identity entirely.
- [`xdg-paths.md`](xdg-paths.md) — adopting the XDG convention in
  `gridworks-base` for default file locations (follow the convention,
  don't lift proactor's full `Paths` class).
- [`init-json-validation.md`](init-json-validation.md) — Sema-validate
  `g_node.json` at the boundary (and generalize the principle to other
  init-JSON files).

## What success looks like

- Journalkeeper (and ear, future consumers) inherit `ServiceSettings`
  cleanly with no fake GNode identity.
- New services land their config under
  `~/.config/gridworks/<service>/` without root.
- A typo or drifted `g_node.json` fails at boot with a clear Sema
  error, not silently mid-run.

## Open

- **FIS handshake behavior for non-GNode services.** The handshake
  sends `client_properties` derived from `g_node_id` / `g_node_class`.
  Does FIS care if those are absent for a non-GNode service, or do
  we need a separate non-GNode handshake variant? Decide as part of
  the service-settings work.
- **Migration story for existing `/etc/gridworks/g_node.json`
  deployments.** Read-XDG-first-then-/etc fallback, or one-time `mv`
  + operator note? Decide at land time.
- **Other init-JSON candidates** (`hardware-layout.json` notably).
  See [`init-json-validation.md`](init-json-validation.md)
  "Generalizing".
