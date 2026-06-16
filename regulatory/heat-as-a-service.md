Status: Draft · Pass 0 · Updated 2026-05-29

> What this is: research-supported brief on Maine regulatory precedents
> potentially applicable to the Knifes Edge **HOA-as-single-customer +
> heat-as-service** structure.

## Selling heat is unregulated

A HOA can buy electricity from
a utility as a **single commercial customer**, owns all the
electrically-driven heating equipment (heat pumps + resistive +
thermal store), and sells **heat** (not electricity) to homeowners.
The key legal facts:

- **Selling heat to homeowners is not regulated by the Maine PUC.**
  Title 35-A's utility-status jurisdiction does not reach a
  non-utility entity that sells thermal energy to its customers.
  Confirmed by Todd Griset at the 2026-05-28 meeting; see
  [Selling heat is not regulated](#selling-heat-is-not-regulated)
  below.
- **The HOA is a normal Versant commercial customer.** No special
  utility-status exemption is needed for the HOA to *consume*
  electricity through its own equipment.

The above could be relevant in a campus setting where the developer owned their own set of electrical lines to each house, AND put in the infrastructure for their own master meter. This would also provide the IOU with a very simple way of ensuring interruptable services (open a relay above the PCC) without impacting heating services to the houses (circulator pumps on the standard IOU lines).

Unfortunately right now there are no attractive higher-voltage delivery tariffs in Versant territory. The Rate D-4 (Primary Power Large – Time-Of-Use) as it stands right now would likely have a per-kWh cost of over 16/kWh. This **could drop to 4 cents** if thermal storage was allowed to qualify for opting in to Coincident Peak (CP) demand charges - an option currently onlyl allowed for batteries. 

 The HOA can be a normal Versant commercial customer, own the heating equipment, sell heat
as a service to homeowners, and the PUC has no jurisdiction over that customer-to-customer transaction. The **The contractual layer** -- including include HOA→homeowner heat-service agreements, comfort guarantees, paid overrides, Maine real-estate disclosures — is governed by Maine real-estate and contract law, **not** by the PUC.


## 35-A MRSA §102(20-B) — landlord-tenant / abutting-parcel exemption

**This exemption is load-bearing only in the *expanded* variant
where the HOA distributes electricity to homeowners.** In the
heat-only variant Todd recommended (HOA owns the heating equipment,
sells heat-as-a-service, never sells electricity), no electricity
distribution to homeowners occurs and §102 is not needed. The
analysis below applies to the contingent expansion case.

Statutory text (the operative clause): the definition of
"transmission and distribution utility" *excludes* an entity
distributing electricity through privately owned property "for the
purpose of providing service to: (A) itself, (B) its tenants who are
not end-use customers of an unaffiliated transmission and distribution
utility, or (C) commercial or industrial consumers located on the same
parcel of property … or on an abutting parcel."
([§102 via FindLaw](https://codes.findlaw.com/me/title-35-a-public-utilities/me-rev-st-tit-35-a-sect-102))

Customer-protection implementing rules: **MPUC Chapter 320**
([MPUC docref](https://mpuc-cms.maine.gov/CQM.Public.WebUI/Common/ViewDoc.aspx?DocRefId=%7B98706BA4-0CEA-4CA3-9532-300E4854D859%7D)).

**Decision-relevance for Knifes Edge.** Probably the load-bearing
hook. Two questions to nail down:

- *Are homeowners "tenants" of the HOA?* The cleanest read is an
  **HOA-as-landlord master-lease structure** where the HOA holds
  electricity-distribution easements over each lot. "Fee-simple
  homeowner" is *not* a tenant; the structure has to introduce a
  landlord–tenant relationship limited to the electricity-distribution
  surface. Worth a direct ask to Todd: is a recorded master easement
  + service agreement enough, or does title structure need to change?
- *Are the 100 lots "abutting"?* Strict construction — "abutting"
  means **shared boundary, not across a road**. Any internal *public*
  road through the development breaks the exemption parcel-by-parcel.
  If the development's internal roads are private (developer-owned →
  HOA-owned), this is preserved; if any are public, the exemption
  fragments. **The road-classification choice is a regulatory decision
  hidden in the site-plan submittal** and Matt may not realize it yet.

Also note the unusual statutory text: §102(20-B) includes a "north of
the Town of Chester" geographic carve-out that looks tailor-made for
an Aroostook biomass arrangement. This is almost certainly the
codification of the late-1980s Boralex-era doctrine — see below.

## 35-A MRSA §3351 — new microgrid statute

[35-A §3351](https://www.mainelegislature.org/legis/statutes/35-a/title35-Asec3351.html)
defines "new microgrid" as able to "connect and disconnect from the
electric grid" and "operate in both … grid-connected mode and …
island mode," and requires "standby electric service, *as defined by
the commission by rule*, when … operating in island mode."

Origin: [LD 13, 129th Legislature, 2019](https://legislature.maine.gov/legis/bills/bills_129th/billtexts/HP001401.asp).

**The statute itself sets no minimum kW or load fraction for island
mode**; both "island mode" parameters and "standby electric service"
are explicitly delegated to MPUC rulemaking. **No implementing chapter
has been adopted** as of this writing (the
[MPUC rules page](https://www.maine.gov/sos/rulemaking/agency-rules/public-utilities-commission-rules)
shows no Chapter governing §3351 microgrids).

**Decision-relevance for Knifes Edge.** Helpful — the *absence* of a
binding minimum supports Todd's "minimal proof-of-life island"
reading (small PCC inverter + small battery powering only minimal
loads; thermal store carries actual heating value). The right move,
*if* §3351 is the path, is a petition with a **stipulated** island-mode
definition that the petitioner proposes and the PUC adopts in the
order — rather than waiting for general rulemaking. But: Todd's
preferred path is the §102(20-B) HOA-as-single-customer route, which
**avoids §3351 entirely**. §3351 sits as the fallback to the fallback.

## LD 1173 / P.L. 2019 ch. 205 — direct-sale-of-electricity enabler

The Maine statute that explicitly enabled the Our Katahdin / One
North arrangement (and analogous BTM direct-sale structures): **LD
1173, 129th Legislature, sponsored by Sen. Lawrence, enacted as P.L.
2019 ch. 205 on June 5, 2019**.
([Maine Legislature LD 1173](https://legislature.maine.gov/legis/bills/display_ps.asp?LD=1173&snum=129))


**Needs de minimus grid pass-through**
LD 1173's structure presumes the seller has *generation sufficient to
cover the buyer's load* with only **de minimis** grid pass-through —
that is exactly the test Todd said Knifes Edge **fails**, because the
HOA would be passing grid power through. So LD 1173 in its primary
form **is not our path**. But it's the policy backdrop that animates
Todd's instinct: PUC has tolerated structures that route around the
utility monopoly when the public-interest case is concrete. §102(20-B)
is the route that doesn't need LD 1173.

## Pre-2019 doctrine — Boralex / neighbor-to-neighbor (~1986–1989)

A Maine PUC ruling from the late 1980s authorized one entity to sell
electricity directly to an adjacent neighbor — Boralex (Quebec-based
biomass generator with northern-Maine plants at Stratton 1989, Ashland
1992-93, Fort Fairfield ~1986) is the likely subject; the case may
involve a lumber mill adjacent to a Boralex plant. This became the
basis for current Maine BTM direct-sale arrangements and is the
likely policy origin of §102(20-B)'s "north of the Town of Chester"
clause.

**No specific docket found via web search.** MPUC CMS indexes only
~2000-onward reliably; the 1980s docket is not web-indexable.

The ruling itself
is superseded by codified §102(20-B).

## Consumer-owned utility pathway — MRRA / Brunswick Landing precedent

Brunswick Landing's electricity service is provided by **Brunswick
Landing Electric Utility District**, which the PUC **recognized as a
not-for-profit consumer-owned utility** rather than under any §102
exemption.
([MRRA / Brunswick Landing](https://brunswicklanding.us/about-mrra/))



## Open follow-ups

- **§102(20-B)(C) "abutting" interpretive history** — has PUC ever
  ruled on whether a private road inside a development breaks the
  abutting test? Crucial for the site-plan decision.
- **HOA-as-landlord master-lease precedent** — has any Maine PUC
  matter tested whether an HOA can claim §102(20-B)(B) "tenants"?
- **PUC triennial direct-sale report** (35-A MRSA §3203, post-LD
  1173, due starting 2022). The report itself wasn't findable via
  web; would list every PUC-approved direct-sale arrangement.
