# Changelog: gridworks-protocol

<!-- pending commit -->
## 2026-05-26 · Open gridworks-protocol wiki domain

Created `wiki/gridworks-protocol/` with executor/primary.md (acceptable-
minimum spec) and research/removing-unused-sema-from-gwproto.md (full
keep/migrate/delete plan based on import audit of proactor + scada on
`dev`, 2026-05-26).

Why: gwproto had no wiki entry despite being a long-standing PyPI
package; the README still uses pre-Sema "Application Shared Language"
framing. The audit found that ~90% of gwproto's type surface is
duplicated in gwsproto, with scada as the only blocker — surfaces a
concrete cleanup path to shrink gwproto to just what proactor needs.
