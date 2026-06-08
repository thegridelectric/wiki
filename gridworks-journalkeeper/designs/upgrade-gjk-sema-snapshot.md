# Design: Upgrade gjk's vendored sema snapshot (post-untangle)

Status: Accepted · Pass 1 · Updated 2026-06-08 · Linear: OPS-379

> Nit-scale design. **Blocked by OPS-378** (sema `untangle-market-type-name`) —
> do this once that ships.

What this is: the change plan for refreshing gridworks-journalkeeper's vendored
sema snapshot after the sema `untangle-market-type-name` work lands, and removing
the manual stopgap it carries today.

## Why

gjk vendors a *restricted* sema snapshot to decode S3 messages. Today it carries
a hand-applied stopgap for the `market.type.name` / `market.slot.name` import
crash (seed the enum + patch the `property_format.py` import + add the
`enums/__init__.py` re-export). That stopgap is **not durable** — a clean
snapshot regen reverts it (the 2026-06-07 regression). OPS-378 fixes the problem
at the root in sema: a structured `gw.market.product.name`, a versioned
`gw.market.slot.name` that declares an axiom dependency on it, and the
`import_root` codegen fix. Once that ships, gjk should regenerate its snapshot to
pick up the durable fix and drop the hand-patches.

## Change (once OPS-378 is done)

- [ ] Regenerate the vendored sema snapshot from the post-untangle sema release.
      The declared axiom dep now pulls the product enum into the snapshot via the
      `gw.market.slot.name` `$ref`; the `import_root` fix ends the
      `ModuleNotFoundError`.
- [ ] Remove the manual stopgap: the hand-seeded `market.type.name` enum, the
      patched `property_format.py` import, and the `enums/__init__.py` re-export
      (now redundant — the generator emits the correct import root).
- [ ] Keep decoding historical `atn.bid` S3 messages — `atn.bid` is `frozen` in
      sema (still published/decodable), so confirm the snapshot still seeds it;
      new code paths use `ltn.bid`.
- [ ] `pytest` green, including the vendored `test_property_format.py` case that
      the regression broke.

## Done when

gjk's snapshot is regenerated from a post-OPS-378 sema, no hand-patches remain,
and the S3 importer decodes both legacy `atn.bid` and current `ltn.bid` cleanly.
