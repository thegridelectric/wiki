# Create words + validation stubs — what the legacy ceremony teaches

Status: Draft · Pass 0 · Updated 2026-07-08

> What this is: the open design question of how GNodes enter the registry —
> which Sema word(s), which parties, what gets validated when — grounded in a
> review of the legacy `g-node-factory` creation machinery. Feeds the
> `apply_create` work in the standup design.

## What the legacy actually did (reviewed 2026-07-08)

Sources: `legacy/g-node-factory` (`gnf_db.py`, `types/`, `rest_api.py`), the
Milestone 1 Writeup.v2, and the flow diagrams (`terminal-asset-creation.png`,
`ta-validator-cert-flow.png`, `TaDaemon.png`, `ta-deed-transfer.png`,
`g-node-alias-update.png`, all in `legacy/old_words/`).

- **Creation was per-class words, each sent by a different principal.**
  `basegnode.{scada,terminalasset,ctn,marketmaker,other}.create` plus the cert
  flows. The TerminalAsset flow was initiated by the **TaValidator** (after the
  owner asked for certification); the Scada flow by the **TaOwner** (who
  generated a key, put it on the device, and registered its public address);
  the ConductorTopologyNode flow by a **Discoverer** holding a DiscoveryCert.
- **Creation was two-phase: Pending → Active, and the phases carried different
  data.** `create_pending_terminal_asset` recorded no location; the lat/lon
  arrived at **activation**, in the validator's transfer payload, after the
  physical site visit ("Molly goes to Holly's house and verifies metering and
  location"). For CTNs, activation is also what flipped the parent-child
  edges. Our `GNodeStatus` SM (Pending → Active) inherits this shape.
- **Implicit parent creation existed:** creating a pending TA silently created
  and activated its AtomicMeteringNode parent. Convenient, but it hides a
  write the caller never named.
- **The "on behalf" role was real and named: TaDaemon.** It holds the TaDeed
  for the homeowner and passes TaTradingRights to the ATN — an agent acting
  for the TerminalAsset owner, with its own key. The owner never had to
  operate infrastructure.
- **Authorization axioms were declared but stubbed.** `basegnode.scada.create`
  carried "Axiom 1: TaOwner is SignedProof signer" and "Axiom 2: TaAlias
  matches TaDeed" — both `TODO` in code. The shape was the contract; the
  enforcement was deferred.
- **Signature/key material was frozen into chain-specific formats**
  (`AlgoAddressStringFormat`, `AlgoMsgPackEncoded` SignedProof — "will be
  replaced by composite transactions in next gen code"). All of it is now dead
  plumbing — the DROP list. Same lesson as the content-address exploration:
  proof formats are machinery of the chosen substrate, not vocabulary.
- **No bulk create.** Dev bootstrap used explicit bypass words
  (`tadeed.specs.hack`, `terminalasset.certify.hack`) — evidence that
  bootstrap needs its own honest path, not that bulk creation is needed.

## The proposed shape (to grill)

- **One generic registrar word at the gnr boundary: `g.node.create.cmd`** —
  the new node as a `g.node.gt` (+ optional `Proof` seam field, string, like
  `g.node.forest`). One node per command, parents-first; no implicit parent
  creation; no bulk word (ingest loops; rebuild is command-log replay, not
  bulk create). Per-node commands keep the command log's provenance and
  idempotency meaningful.
- **The multi-party ceremony lives upstream, in the TaValidator/deed plane,
  and *results in* registrar commands.** Legacy GNF was registry and ceremony
  engine in one; our split keeps gnr the record of authority. The per-class,
  per-principal words (certify, opt-in, deed transfer, the TaDaemon agent)
  return with that plane — they feed `g.node.create.cmd`/status-change
  commands rather than replacing them.
- **MVP ingest creates nodes `Active` directly** (the deployed fleet already
  operates; bootstrap-era grandfathering). The Pending → Active ceremony
  binds when the validator plane exists.
- **Ingest is the write path, not a projection load.** Even though it copies
  fleet data that already exists elsewhere (`tlayouts` outputs), it
  *establishes* truth in the authority, so it must enter as authorized
  commands through the handler core. The mirror-image operation — `gw_data`
  receiving the same nodes as `g.node.forest` broadcasts (OPS-443) — is a
  projection: no authority, no authorization, rebuildable at will. The
  distinction is canonical in the executor, *Write path & egress* ("A write
  is not a projection").
- **No sema format for signed keys now.** `Proof` stays an opaque optional
  string; the format word is minted when the auth / distributed-authority
  model lands (standup-design remaining item (d)).

## Guard-rail stubs (fail loudly, fill in later)

Boot- and write-time checks in gnr, mostly `NotImplementedError` seams:

1. `GNR_UNIVERSE` **required** (no default); format: single alphanumeric
   word, first char in `{d, h, w}`.
2. **`w`-universe boot refusal:** a production-universe registry SHALL refuse
   to boot while its prod requirements are stubs — Proof verification,
   the validation-cert plane, encrypted positions. Production cannot be stood
   up accidentally or prematurely; dev/hybrid runs today.
3. **Write path:** every command's aliases must carry segment-0 =
   `GNR_UNIVERSE`; `validate_registry` checks every row.
4. **Positions:** the coordinate write path is a stub raising
   `NotImplementedError` (TaValidator encryption plane) in every universe —
   `position_points` stays empty by construction, not by convention.
5. **Proof:** carried, ignored-with-log in dev/hybrid; required-and-verified
   (stub) on the prod path.

## Open (the grill targets)

- ~~Tree edges: stored or derived?~~ **Resolved: `connectivity_edges` is
  reserved for non-tree copper** (ties, loops, meshed feeds — they WILL
  exist); the tree is the alias structure, never stored as edges. Canonical
  in the executor (*Intended invariants*, "Edges are non-tree only"). The
  create/reparent words are unaffected (neither carries edges).
- ~~Create-as-Active at ingest?~~ **Resolved: the fleet enters `Pending`.**
  Activation rides the TaValidator / encryption step — the same step that adds
  the GPS positions — via the future status-change command. This keeps the
  legacy two-phase shape from day one. Coupling to hold: a Pending node fails
  `assert_active`, so activation must precede or accompany the mTLS+FIS
  enforcement cutover.
- Does the generic-registrar-word / upstream-ceremony split hold, or does any
  class (Scada key registration?) need its own word sooner? **The settled
  anchor is now canonical in the vision**
  ([`../../vision/data-meaning-sovereignty.md`](../../vision/data-meaning-sovereignty.md)
  "Sovereignty of the person"): the TaOwner holds the keys and is a
  first-class signing principal in the eventual ceremony; the registrar split
  stands for the MVP. What remains open here is the mechanism — which words,
  which parties, in what order.
- Proof semantics when it does bind: who signs a create (MarketMaker of the
  parent subtree? the validator? the registrar)?
