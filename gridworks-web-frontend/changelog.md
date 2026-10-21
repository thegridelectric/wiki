# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-web-frontend` code repo**. The matching git commit (in
`gridworks-web-frontend`) holds the WHAT (the diff). Each entry's date
and one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

## 2026-10-21 — retire installations: the summary as the API returns it; Address and Contact not shown; Hardware and the sieg default from the layout (OPS-473, `jm/retire-installations` off `jds/v2_apis`) <!-- pending commit -->

The dashboard follows the web-backend summaries once the `installations`,
`customers` and `installers` tables leave journaldb. The summary type is
retyped to the fields the API returns: `TaGNodeId` joins, `DisplayName`,
`SystemMode`, `MainAutoState`, the snapshot facts and `LayoutLite` are
nullable, and the `HardwareLayout`, `InstallationContact` and
`SpaceheatParameters` types go, since no endpoint returns them. The
Installations table drops its Location column, filter and sort. The
Information page keeps its four sections: Address and Contact read "Not
shown here" until the customer store has a read path (OPS-600), Status
comes from the snapshot facts, Hardware from `LayoutLite`. The real-time
page's default sieg loop is on when the layout has a `sieg-flow` data
channel, and its gateway key is the last segment of `GNodeAlias`, so the
registry's display names can read however gnr likes. The Parameters page
starts from its defaults, since operational params are not on the bus.
`LayoutLite` and the sieg check are typed in `src/sema/` by hand, to the
fields read; a generated snapshot is the open gap at this boundary.
