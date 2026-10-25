# gridworks-web-backend and gridworks-web-frontend — Claude protocol

Status: Draft · Pass 0 · Updated 2026-10-24

> What this is: the rules for any session that edits the web-backend, the
> web-frontend, or the seam between them (the words the backend serves and
> the browser reads). Appended by `wiki/tools/backend.sh`.

## The seam is sema

- Every structure that crosses from backend to browser is a sema word,
  constructed through the generated snapshot classes on the backend and
  typed by the vendored `.d.ts` in the frontend. A hand-built dict or an ad
  hoc JSON shape at the seam is a defect.
- When a change touches the seam, the seam is cleaned up in the same
  change: the word is made right, and any string convention the browser
  used in its place is replaced or annotated (see "Patterns").
- Nothing the scada reported cleanly is lost in translation. When a word
  the backend serves drops a fact the scada's word had (an enum version, a
  node name, a machine's identity), the fix is a word that keeps it, not a
  convention that lets the browser guess it back.

## Patterns

- The browser SHALL NOT decide meaning by matching channel names. A regex
  or substring match on a channel name in the frontend is a known gap, and
  so is one in the backend.
- Every such match that a change touches gets a note beside it: the fact
  it extracts (a zone ordinal, a depth ordinal, a machine) and the layout
  or sema fact that replaces it. The notes are the input to how the layout
  and the operational parameters finalize.
- A projection the browser needs that no word gives (a house's control
  mode across several machines) becomes a sema enum, derived in the
  backend, and is sent as data. The browser renders; it does not infer.

## Readers across layout eras

- A channel's `reading_channels` rows across layout changes are one
  lineage; every reader (csv, bundle, hourly) reads the lineage, in the
  newest row's unit, through `api/v2/readings_units.py`. A reader that
  groups by (name, unit, unit type) is the antipattern.
- A state row is identified by its enum and version (`unit_type`, `unit`);
  a position is resolved through that pair, and `Enum` resolves through
  the newest vendored version.

## Verification

- A reader change is verified against production-shaped data:
  `tsdb_tap` and the recipe windows (`experiments/dev-stack-recipe.md`
  "A production-shaped journal DB"), with a local test in `tests/` that
  reproduces the fault first.
- The frontend is verified on the page, against the backend on `tsdb_tap`,
  for a window that spans a layout change.
