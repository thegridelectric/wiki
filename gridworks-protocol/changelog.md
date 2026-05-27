# Changelog: gridworks-protocol

<!-- pending commit -->
## 2026-05-26 · Open gridworks-protocol wiki domain + first design-spec

Created `wiki/gridworks-protocol/` with `executor/primary.md`
(acceptable-minimum spec) and `designs/gwproto-shrink.md` (the full
keep/migrate/delete plan based on import audit of proactor + scada on
`dev`, 2026-05-26). The design originated as a research finding
(`research/removing-unused-sema-from-gwproto.md`) and was migrated to
the `designs/` location when the wiki-wide design-spec lifecycle
convention was established same day (see `wiki/designs/changelog.md`).

Status: `designs/gwproto-shrink.md` is at `Draft · Pass 0` — content
is detailed but not yet ratified or formally iterated.

Why: gwproto had no wiki entry despite being a long-standing PyPI
package; the README still uses pre-Sema "Application Shared Language"
framing. The audit found that ~90% of gwproto's type surface is
duplicated in gwsproto, with scada as the only blocker — surfaces a
concrete cleanup path to shrink gwproto to just what proactor needs.
