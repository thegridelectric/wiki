# Spec publication plan

Status: Draft · Pass 1 · Updated 2026-05-23

What this is: the plan for publishing the Sema specification on the public
web. Captures decisions made so a future session can pick up without
re-doing the research. Not normative — this is research/, not executor/.

## Decisions made

- **Domain:** `spec.electricity.works`. Sibling of
  `schemas.electricity.works` (the vocabulary publication endpoint). Same
  org, same authority.
- **Form:** hyperlinked HTML site as the primary form; a single-page
  render (HTML + PDF) as a secondary artifact for Ctrl-F, citation, and
  offline use. Source is the existing hub-and-spoke in `sema/spec/` — the
  publish step is a direct render, not a re-organization.
- **Spec versioning:** draft-style, like JSON Schema (`draft-1`,
  `draft-2`, …). Each draft is immutable once published. This matches the
  immutability discipline `schemas.electricity.works` already applies to
  vocabulary. The current `Version 1.0` in `sema/spec/primary.md` should
  be reconciled with this scheme when publishing begins.
- **URL scheme:** `spec.electricity.works/<draft>/...` (immutable per
  draft) + `spec.electricity.works/latest/` (alias pointing at the most
  recent published draft).
- **Tooling:** **MkDocs Material**. Smallest setup cost of the credible
  options. Ships hyperlinked nav, in-page search, draft versioning (via
  `mike`), and single-page render (via `print-site` or `mkdocs-with-pdf`)
  out of the box or via well-maintained plugins. Alternatives considered:
  Docusaurus (heavier; what JSON Schema uses), Hugo (fastest builds but
  versioning + single-page need custom work).
- **wiki/sema/primary.md continues to point at the in-repo spec files**
  (`sema/spec/...`), not the published URLs. Reason: human editors and AI
  agents working sessions need the source-of-truth files, not rendered
  HTML. The published URLs can be added as a secondary link for
  discovery once they exist.

## Why hyperlinked > monolithic for Sema

Survey of comparable protocol publications:

| Spec | Form | Notes |
|---|---|---|
| JSON Schema | Hyperlinked set | Docusaurus; immutable draft URLs (`/draft/2020-12/`) |
| OpenAPI | Single doc per version | ~30k words; anchors for sections |
| GraphQL | Single doc | Ctrl-F as the search story |
| CommonMark | Single page | ~50k words; print/PDF friendly |
| CSS (W3C) | Hyperlinked set of modules | W3C explicitly modularized after HTML4 monolith failed |
| Matrix | Hyperlinked set | Versioned; "load the module you need" |
| gRPC, Protobuf | Hyperlinked set | Standard developer-docs style |
| IETF RFCs | One doc per RFC | But RFCs are *themselves* modular |
| Bitcoin BIPs | One doc per BIP | Indexed |

Two arguments for hyperlinked-primary in Sema's case:

1. **Source already matches.** The hub-and-spoke split in `sema/spec/`
   was done for AI/edit ergonomics. Publishing as a hyperlinked set is a
   direct render. A single-doc publish would re-monolithize what was
   just modularized.
2. **The audience needs targeted loads.** Implementers writing one type
   rarely need the entire enum spec. AI agents under `/make-sema-word`
   should pull the ~200-line spoke for the kind they're touching, not
   the full 2300 lines.

Single-doc is better only when the spec is short enough for one page
(OpenAPI/GraphQL) or citation density needs everything in one document
(RFCs). Sema is neither.

## Open questions

1. **Draft numbering reconciliation.** `sema/spec/primary.md` currently
   says `Version 1.0`. Does that become `draft-1`? Is there a separate
   "Sema 1.0" milestone marker independent of draft numbers? Decide
   before first publish.
2. **Where the build runs.** GitHub Pages (push-triggered), Netlify, or
   self-hosted? Probably GitHub Pages — zero ops, free for public repos.
3. **What "published" means in immutability terms.** The spec's own
   wording ("a vocabulary definition is considered *published* when it
   is available at `https://schemas.electricity.works`") should grow a
   sibling clause for the spec itself: a draft is *published* when
   available at `https://spec.electricity.works/<draft>/`.
4. **Changelog/diff between drafts.** Need a `CHANGES.md` per draft
   listing what shifted from the prior draft. Standard practice for
   draft-style specs.
5. **Discovery and indexing.** Should the published site link out to
   `schemas.electricity.works` so readers can browse from spec → actual
   schemas? Cross-linking the two domains is cheap and valuable.

## What to do next (for the future session)

1. Reconcile draft numbering with the existing `Version 1.0` in
   `sema/spec/primary.md`.
2. Stand up MkDocs Material in the sema repo (likely
   `sema/site/mkdocs.yml` pointing at `sema/spec/` as the docs root).
3. Configure `mike` for draft-versioned URLs.
4. Configure a single-page render plugin for `/<draft>/all.html` (+ PDF).
5. Wire GitHub Pages to publish on push to a designated branch.
6. Point `spec.electricity.works` DNS at the GitHub Pages site.
7. Add a `CHANGES.md` per draft.
8. Add a discovery link from the published spec to
   `schemas.electricity.works` (and vice versa, if practical).
9. Once published, add the published URL as a secondary link in
   `wiki/sema/primary.md` (keep the in-repo pointer as primary).

## What is NOT being decided here

- The MkDocs theme details, plugin choices beyond the named ones,
  navigation tree shape — these are implementation choices for the
  future session.
- Whether to host the runtime SDK docs alongside the spec or separately.
  The runtime is a different artifact; defer.
