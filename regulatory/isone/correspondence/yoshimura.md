## 2025-10-10 1:24 pm Henry to Jessica

Henry Yoshimura <henryyoshimura@gmail.com>
	
Oct 10, 2024, 1:24 PM
	
	
to me, George
That is correct — the DERA metering referred to in Section III.6.4(f) cited below is for "Distributed Energy Resource Aggregations that include Generator Assets or Load Assets."  Generator Assets (things that inject energy into the grid) and Load Assets (things that withdraw energy from the grid) participate in the wholesale Energy Market and are settled (i.e., paid or charged) at the LMP.  Because payments to Generator Assets equal charges to Load Assets, the market clears.  A DARD is a form of Load Asset.  

Demand Response Resources — which are settled vis a vis Order 745 — are a separate set of assets, which by necessity are settled outside of the Energy Markets.  Because a Demand Response Resource is paid for reducing load (relative to a calculated baseline) and the retail supplier serving the customers comprising the Demand Response Resource is charged at the actual, lower load amount, payments to Demand Response Resources plus payments to Generator Assets exceed charges to Load Assets.  Overall payments exceed charges by the amount paid to Demand Response Resources.  Therefore, payments to Demand Response Resources must be separately allocated to loads outside of the normal market-clearing process so that total payments and charges are equal.  

Because Demand Response Resources don't clear through the Energy Market, Demand Response Resources have no impact on how a Host Participant Meter Reader (the utility) does its job of figuring out how much energy to allocate to each retail supplier in each interval.  This allows for non-utility metering of the facilities comprising a Demand Response Resource and no coordination between the demand response meter reader and the utility.  Thus, utilities are indifferent to Order 745 style demand response as it has no impact on how they do their job.  Alternatively, if an aggregation of retail customers is to be billed directly based on their aggregate consumption in each interval, that impacts Host Participant Meter Readers and they start getting excited.  

Hence, doing the right thing is harder....

Henry

## 2025-10-10 12:09 pm Jessica to Henry

Hi Henry -

One clarification - the DERA metering would also be for direct wholesale market participation, instead of 745-style participation?

You know the story of why I started VCharge? I thought it was a shame that the Alternative Technology Regulation pilot existed with only Beacon as a participant.

This has a similar flavor ... it is a shame that nobody apparently wants to create a DARD consisting of an aggregation of individually small, dispatchable loads ....

J

ps
George and I  just got off a zoom call with a couple colleagues associated with LBNL (Peter Grant and Jonathan Woolley). Right now the CEC and Cal Flex Hub is implementing "prices to devices" as an alternative approach for getting demand to change. A company called Olivine is creating the prices for them. There is no bidding by demand. The prices are just guessed-at as a way to "get the load curve they want."

This is driving me a little nuts, and I am concerned about New England utilities adopting this in some way before it has fully crashed and burned.  Which is also adding to my company-starting urge ....


## 2025-10-10 Henry to Jessica & George
Henry Yoshimura <henryyoshimura@gmail.com>
	

One small correction — the FERC approved the metering requirements on September 5, 2024 (not 2025).  But as I mentioned before, the approved provisions are to go into effect on November 1, 2026.  As you noted Jessica, the time is now to start getting the technology in place — I suspect you were referring to Gridworks plans.  Of course, the same is true for the region's electric distribution companies and the ISO — the infrastructure and operating procedures/rules allowing more widespread use of non-utility interval metering of dispatchable loads in wholesale market settlement needs to be in place and tested before 11/1/26 so that this could go live on 11/1/26.  

This presents both a risk and an opportunity.  The risk is that the utilities and perhaps even the ISO fall behind on implementation since, with few asking for the required infrastructure, it becomes a lower priority in the grand scheme of things.  The demand response providers (the set of market participants with the loudest voice in this space) are certainly not asking for it, nor are the retail suppliers.  If implementation falls behind as a result, they will likely petition for a later effective date arguing that scarce resources need to be spent on higher priority projects.  The opportunity is to drive the implementation such that the utilities and the ISO see that there is demand — that someone wants to form DARDs consisting of an aggregation of individually small, dispatchable loads — and an implementation pathway that solves problems as opposed to creating insurmountable new problems.  


## 
## 2024-10-08 Henry to Jessica & George
 I did a little research and found that the FERC recently approved (on September 5, 2025) the following metering requirements for Distributed Energy Resource Aggregations (DERAs) for ISO New England (see the excerpted section of the ISO's Tariff below).  Your aggregation of customers with controllable heating and thermal storage would be considered a DERA.  The approved provisions go into effect on November 1, 2026, about two years from now.  

Relevant to what we discussed yesterday, the Distributed Energy Resource Aggregator (not the utility) may designate itself, an agent acting on its behalf, or the Host Utility to act as the Assigned Meter Reader for its aggregation — see subsection (f) below.  But the utility (i.e., the Host Participant Assigned Meter Reader) also needs the meter data of any separately metered and settled Generator or Load Asset located within its footprint (i.e., its "meter domain").  The Host Participant Assigned Meter Reader needs this data to accurately allocate all of the energy consumed in its meter domain by interval among the various retail energy suppliers serving customers in its meter domain for wholesale settlement purposes.  

The region's electric distribution companies would have to set up systems to accommodate these provisions — I should mention that it is unclear what happens if an electric distribution company (which is subject to state regulation) does not comply with the ISO Tariff (which is subject to Federal regulation).  The region's electric distribution companies will not implement anything unless and until state regulators approve cost recovery associated with new metering infrastructure and operating procedures to implement the ISO Tariff.  However, we are in New England, which is generally favorable to Distributed Energy Resources.  So I suspect that the region's electric distribution companies and state regulators will cooperate and implement these provisions.


III.6.4 Metering and Telemetry Requirements

Distributed Energy Resource Aggregations must meet the following metering and telemetry requirements. 

(a) Distributed Energy Resource Aggregations participating as a Generator Asset, Binary Storage Facility, or Continuous Storage Facility, must comply with the metering and telemetry requirements in Sections III.3.2.1 and III.3.2.2. 

(b) Distributed Energy Resource Aggregations participating as an Alternative Technology Regulation Resource must comply with the metering and telemetry requirements in Section III.14.2. 

(c) Distributed Energy Resource Aggregations participating as Demand Response Resources or Demand Response Distributed Energy Resource Aggregations must comply with the metering and telemetry requirements in Section III.3.2.2. The metering and communication equipment associated with each participating Distributed Energy Resource must meet the requirements in Section III.3.2.2 and ISO New England Operating Procedure No. 18, Metering and Telemetering. 

(d) Metering for each Distributed Energy Resource participating in a Distributed Energy Resource Aggregation shall meet all applicable state and Host Utility requirements and be located at, a Retail Delivery Point, or point of interconnection as applicable. A Distributed Energy Resource’s point of interconnection may be located behind a Retail Delivery Point to the extent that the pertinent Host Participant Assigned Meter Reader can accommodate such a configuration. 

(e) If a Distributed Energy Resource’s point of interconnection is located behind a Retail Delivery Point it shall be reported such that its output or load does not impact the load reported for the Retail Delivery Point. A Distributed Energy Resource Aggregator may only propose a metering location behind a Retail Delivery Point if the Host Utility confirms in writing to the Distributed Energy Resource Aggregator that the appropriate metering and associated system upgrades are in place to support load and generation reporting and any necessary reconstitution. Proof of such written confirmation from the Host Utility should be provided as part of the attestation as referenced in Section III.6.7(c)(i)2. 

(f) A Distributed Energy Resource Aggregator, as the entity responsible for providing any required metering information to the ISO, may designate itself, an agent acting on its behalf, or the Host Utility to act as the Assigned Meter Reader for Distributed Energy Resource Aggregations that include Generator Assets or Load Assets. Where the Distributed Energy Resource Aggregator designates itself or an agent acting on its behalf as the Assigned Meter Reader, the Distributed Energy Resource Aggregator or its agent shall: 

 1) be subject to all obligations applicable to an Assigned Meter Reader that is not the Host Participant, as detailed in the ISO’s Tariff and other Operating Documents, including, but not limited to Operating Procedure 18 – Metering and Telemetry Criteria and Manual M-28 – Market Rule 1 Accounting, where such requirements may differ for Distributed Energy Resource Aggregations that include Generator Assets or Load Assets, and which may include adjustments for losses and/or residual unmetered load as appropriate; and 

 2) enter into applicable coordination agreements with the relevant Host Utility, which may include, but need not be limited to agreements required by the Host Utility or the relevant electric retail regulatory authority regarding: i) specific requirements related to adjustments for losses and/or residual unmetered load for any Load Asset metering data; ii) coordination of data transmittal; and iii) protection of retail customer information. 

Where a Distributed Energy Resource Aggregator designates itself or an agent acting on its behalf as the Assigned Meter Reader for its Distributed Energy Resource Aggregation, it shall provide, or cause to be provided, all data necessary for settlement (1) to the Host Participant Assigned Meter Reader by 0800 of the next Business Day following the Operating Day or at a later time as mutually agreed, and (2) to the ISO by 1300 on the second Business Day after the Operating Day. If the data provided includes any Profiled Load Asset data, as determined by the Host Participant, the Host Participant Assigned Meter Reader shall submit the Profiled Load Asset meter data directly to the ISO for settlement after appropriate adjustment for losses and/or residual unmetered load. 

(g) The Distributed Energy Resource Aggregator shall retain metering data for each participating Distributed Energy Resource for a period of six years for purposes of auditing.

## 2024-09-05 Henry to Jessica

 Hello everyone — I hope you all are doing well and had a good summer!  Here are my thoughts regarding the questions that Jessica posed to me:
[Can] non-utility Assigned Meter Readers [] be:

(1) Under the purview of PUCs?  

HYY response:  Assigned Meter Readers are a wholesale market construct that is subject to FERC oversight — see ISO New England Tariff Section III.6.4 (for convenience, I included that section below).  I believe that this section (or portions of it) is still being reviewed by the FERC and a final order accepting this section is still pending — see https://www.iso-ne.com/static-assets/documents/100012/filing_to_comply_with_april_2024_order_re_order_2222.pdf.  Assigned Meter Readers provide energy consumption/production data of specific Resources to ISO New England to enable wholesale market settlement.  An Assigned Meter Reader of a Resource, such as a Distributed Energy Resource Aggregation, can be a utility or a non-utility.  The Distributed Energy Resource Aggregator can designate itself, an agent acting on its behalf, or the Host Utility to act as the Assigned Meter Reader for its Distributed Energy Resource Aggregation.  The Host Participant Assigned Meter Reader, which is usually the Host Utility, has additional duties — in addition to being the Assigned Meter Reader for tie-lines and for some of the Resources in its footprint, they also take the energy consumption/production data from all the non-utility Assigned Meter Readers with Resources located in their footprint and do the math to allocate losses and other residual unmetered load to each Load Asset (load serving entity) in their footprint.  This requires the metering and communication of data between any non-utility Assigned Meter Reader and the Host Participant Assigned Meter Reader, which may be subject to PUC oversight.  If the Distributed Energy Resource Aggregation involves sales to retail customers, those retail sales and the entities making those sales would be subject to PUC oversight — however, the Assigned Meter Reader function for wholesale purchases and sales remain under FERC oversight.  

(2) Necessary for "renewables-balancing demand" (as opposed to "peak-shaving demand") to access the same local prices that curtailed wind and solar face, under the regulatory structure of aggregators signing up as Dispatchable Asset Related Demand)?

HYY response:  All wholesale Load Assets (i.e., different aggregations of energy consumers each served by a different retail supplier or load-serving entity) are charged the Locational Marginal Price (LMP) just as wholesale Resources supplying that energy are paid the same LMP — so in each interval, charges to Load Assets equal payments to Resources resulting in the market clearing with no excess or deficient cash.   A set of retail customers that actively adjusts its load by reducing it when wholesale prices are high and increases it when wholesale are negative would certainly reduce the average cost of serving load and reduce the charges that the retail supplier receives in its wholesale market bill.  But if these price-responsive customers were part of the same Load Asset as other non-responsive customers, the reduction in cost is diluted (especially if the non-responsive customers were more numerous) with the price-responsive customers sharing the cost savings they created with the non-responsive customers.  Separating the price-responsive customers into a separate and distinct Load Asset — such as a Dispatchable Asset Related Demand, which is a type of Load Asset — would provide a more direct financial incentive for price-responsiveness.  The average cost of serving price-responsive loads would be lower relative to other, non-responsive customers, so it would follow that retail charges to price-responsive customers would also be lower.   That is, separating the price-responsive customers into its own Load Asset, such as an Dispatchable Asset Related Demand, would allow those customers more direct access to the savings they create by responding to the LMP. 

Regards,
Henry