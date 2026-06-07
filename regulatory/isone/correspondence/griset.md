Griset, Todd J 

<TGriset@preti.com>

## 20260603 11:06 am Todd Griset to Jessica / George	
Wed, Jun 3, 11:06 AM (1 day ago)
	
	
to George, Matthew, me
Hi all — here are responses to your questions. The questions and answers cover a fair amount of ground, so I'd be happy to discuss if it would help.

At a high level, it may be helpful to distinguish between two separate paths:

 - A retail construct, in which the heat pump load is separately metered and served by a competitive electricity provider; and
  - A wholesale construct, in which the same load is aggregated and operated as a dispatchable resource for ISO participation.


The A‑1 bonus meter can support the first pathway relatively directly (assuming Versant's billing systems can handle split-supplier arrangements). The second pathway requires additional capabilities (control, telemetry, settlement coordination) and utility participation, and cannot be achieved solely through metering structure.

**1. Different suppliers serving the two meters under Versant Rates A and A-1?**

Short answer: likely yes, but subject to tariff/implementation constraints.

Conceptually, each meter is a distinct “service” for retail supply purposes. In Maine’s competitive supply framework, the supplier is tied to the customer account/meter, not to the premises as a whole. On that basis, the Rate A meter could remain on Standard Offer, and the A‑1 bonus (TOU) meter could be enrolled with a CES. However, Versant’s tariff structure and billing system configuration may assume a single supplier across the premise or across related meters (this is an implementation constraint, not a legal prohibition per se), and supplier enrollment, switching, and billing would need to be supported at the meter level for the A‑1 configuration. Versant's A-1 tariff and "bonus meter" structure is different from most other tariffs in that it does not impose a separate customer charge for the A-1 service. Versant may argue that the A‑1 service is structured as an adjunct to Rate A service, which may lead the utility to treat the two meters as a single retail service for supplier enrollment purposes.
So I think this is legally supportable, but would require confirming that Versant (and its EDI/billing framework) actually supports split-supplier configurations for paired residential meters.

**2. Prospects for interval settlement data from the bonus meter within next 12 months?**

Short answer: uncertain and, in my view, unlikely on that timeline without a targeted effort.

While the A‑1 meter is TOU-enabled, that does not necessarily mean it is:

 - validated for ISO settlement, or
 - integrated into Versant’s wholesale settlement reporting systems

Utilities tend to prioritize ISO settlement-grade interval data for large C&I meters and assets participating in ISO markets. A residential program-specific meter (like A‑1 bonus) is typically not configured as a wholesale settlement asset. Absent a regulatory or programmatic driver, or a specific request tied to ISO market participation, I would expect a low likelihood of Versant enabling ISO-facing interval settlement for this meter within the next 12 months.

**3. Use of ISO-NE Tariff §III.6.4(f) (DER Aggregator / Assigned Meter Reader)?**

This provision could be helpful when it takes effect on November 1, but I would frame it as enabling, not self-executing. Importantly, this framework applies to participation as a wholesale market resource (e.g., demand response), not to the retail assignment of supply to a separately metered load.

ISO-NE adopted this tariff section in response to FERC Order No. 2222, which generally requires organized wholesale markets to enable market participation by aggregations of distributed energy resources. In general, Order No. 2222 focuses on DER aggregations participating in wholesale markets as supply resources (whether as portfolios of small-scale generation or as dispatchable loads capable of demand response). This could enable the aggregator to earn revenues (for example by reducing heat pump load during dispatch events), but it is not necessarily a path to substituting a private meter for the utility's meter for purposes of T&D charges or load settlement.

When it takes effect, §III.6.4(f) will allow a DER Aggregator (or its agent) to act as the Assigned Meter Reader, provided that the DER Aggregator complies with ISO metering/telemetry standards and enters into coordination agreements with the Host Utility. This means you could propose a structure where GridWorks (or a competitive energy provider/aggregator) provides settlement-quality data — but you cannot bypass the host utility; you will need bilateral agreements with Versant; and the data ultimately must still be reconciled through the Host Participant / utility framework. So this opens a door — but does not eliminate the need for utility participation.

**4. Duplicate reporting?**

Short answer: no — ISO-NE does not operate a dual-submission model; a single Assigned Meter Reader must be designated.

Even under §III.6.4(f), there is still an identified Assigned Meter Reader for settlement, and data flows must be coordinated, and submitted in prescribed formats/timelines, including delivery to the Host Participant. The tariff explicitly contemplates coordination agreements and a defined pathway for data submission. It does not contemplate parallel, uncoordinated reporting with ISO selecting between sources. This means that Versant cannot be “out of the loop”, and you would need an agreed-upon designation of the Assigned Meter Reader with corresponding obligations.

**5. What §III.6.4(f) obligates the host utility to do**

Importantly, the provision imposes relatively limited affirmative obligations on the Host Utility. Where a Distributed Energy Resource Aggregator requests direct participation, this section requires the Host Utility to enter into coordination agreements addressing loss/residual load adjustments, data transmission coordination, and customer data protections. But it does not require the host utility to accept any and all third-party metering configurations, modify its systems on demand, or serve as a passive recipient of externally defined data streams. I would thus characterize the utility’s role as a necessary counterparty who retains meaningful discretion in the terms of participation.

**6. Third-party revenue grade meter / tariff implications**

As I understand your concept,  you would keep Versant’s A‑1 bonus meter for delivery/retail billing, while adding a privately owned revenue-grade meter for settlement. In general, I expect Versant would likely object to relying on a privately owned meter for any utility-facing purpose (or would require clear regulatory direction before accepting this). Versant would likely say that its A-1 tariff assumes utility-owned, utility-read metering, and that using a third-party revenue-grade meter for billing or settlement purposes would very likely require either tariff modification or explicit regulatory waiver. This also raises reconciliation issues if the ISO settlement values and the utility billing determinants diverge. Because the utility must continue to rely on its own meter for state-tariffed distribution charges, the introduction of a second settlement meter creates a structural mismatch that would need to be resolved through utility acceptance and lkely regulatory approval.

At the highest level, if the objective is to avoid parallel wires while enabling CES supply of heat pump load, the most viable near-term pathway is to use the A‑1 bonus meter as the single authoritative meter for both competitive retail supply enrollment and any future settlement use (if enabled). This would require confirming that Versant can handle a split-supplier scenario across the two meters. This is a gating issue but likely solvable. With Versant's agreement (or Maine PUC direction), you could do this as a state-law retail construct without needing full ISO-NE participation. You could revisit ISO participation in the future once A‑1 metering capabilities and data pathways are clearer. If direct ISO-NE participation is essential, you should expect a structured arrangement with Versant, including designation of the Assigned Meter Reader and a formal coordination agreement under §III.6.4(f), but this would be iterative and utility-driven.

Happy to discuss any or all of these points if it would be helpful to you — or to help you approach Versant to ask about the split-supplier approach to Rates A and A-1.


Best regards,
Todd
