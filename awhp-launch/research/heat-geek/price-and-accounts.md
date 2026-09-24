# Heat Geek (UK): install prices, performance and how the investors earn

What this is: desk research on whether Heat Geek's installs are cheaper or better than the UK market, and where the money is made. Companion to [`business-model.md`](business-model.md), which holds the corporate history, funding rounds and revenue lines.

Status: Draft · Pass 0 · Updated 2026-09-23

Provenance tags: **[read]** page or document fetched and the quoted text seen; **[fetch-summary]** quote returned by a summarizing fetch, spot-check before public citation; **[snippet]** search-engine summary only, unverified; **[computed]** arithmetic on read data.

## 1. Prices against the market

**Baseline.** The Boiler Upgrade Scheme median for an air-source install rose "from £12,973 to £13,041" between 2024/25 and 2025/26, before grant (Nesta, [fetch-summary]). DESNZ Apr–Jun 2026: median £12,908, with 6–8 kW systems at about £12.2k and 12–14 kW at about £15.4k [snippet].

**Heat Geek's claim.** "At Heat Geek our average install price is £3,000 (after the grant)." (Heat Pump Guide 2026, Wayback, [read]). With the £7,500 BUS grant that is roughly £10,500 gross, about 19% under the median [computed]. No sample size, period or system size is given. The ZeroDisrupt launch claimed installs "up to 60% cheaper, 50% faster" and "50% less time on site, typically a few days instead of one-to-two weeks" (Renewable Heating Hub quoting the launch [read]; Refurb & Retrofit [fetch-summary]). The ZeroDisrupt article itself could not be read (HTTP 429, no archive capture).

**The one independent test.** Renewable Heating Hub ran the ZeroDisrupt quote tool on an 80 m² bungalow with a 5 kW Vaillant aroTHERM [read]:

> "With a single radiator upgrade and targeting their guaranteed 340% efficiency, the quoted price came in at £10,000 (£2,500 from the homeowner plus the £7,500 BUS grant)"

Four radiator upgrades: £10,900 at 370%; all seven: £11,950 at 400%; a cylinder adds £1,150–1,700. So a small-house ZeroDisrupt job is £10.0k–£12.0k gross, at or a little under the 6–8 kW median. The offer is a price-for-efficiency menu with a 3.4 SCOP floor; higher guaranteed SCOP costs more.

**Monitored installs.** HeatpumpMonitor.org public data (downloaded 2026-09-23; the `heatgeek` flag means the installer holds Heat Geek Mastery training, not that Heat Geek Installations Ltd did the job) [computed]: self-reported cost before grant, Heat Geek-trained median **£16,513 (n=10)** against **£11,120 (n=35)** for the rest. Tiny self-selected samples; no cost advantage visible, if anything the reverse.

**Verdict.** Heat Geek's installs sit at or modestly below the market price for small systems. There is no evidence of a structural price break, and no independent measurement of labour days per job.

## 2. Performance

The performance advantage is real in the public data. HeatpumpMonitor.org last-365-day combined COP (heating and hot water, systems with at least 290 days of data and no data flag) [computed]: Heat Geek-trained installs **median 4.09 (n=213)** against **3.77 (n=279)** for other monitored systems. Both populations are monitored enthusiasts, so this is a within-enthusiast comparison, well above the 2.8 average of the UK Electrification of Heat trial that Heat Geek's own material cites [snippet]. The Next Web reported "The average COP across a year for a sample of Heat Geek certified heat pump installations is 4.44" in May 2024, from 41 monitored pumps [fetch-summary]. No SCOP data specific to ZeroDisrupt or Installations Ltd jobs was found.

## 3. Where the money is made (Companies House, FY to 31 March 2025)

All four entities file small-company accounts with no income statement ("In accordance with Section 444 of the Companies Act 2006, the Income Statement has not been delivered." [read]), so turnover and gross margin are not public. Results below are inferred from the change in retained earnings, assuming no dividends [computed].

| Entity | Retained earnings 31.3.24 → 31.3.25 | Implied FY25 result | Notes |
|---|---|---|---|
| Heat Geek Installations Ltd (14797942) | £86,586 → £496,693 | about **+£410k** | "The average number of employees during the year was NIL." Work in progress £1,113,823; trade debtors £509,944; trade creditors £642,185; other creditors £932,833 |
| Heat Geek Technologies Ltd (14317488) | (£2,034,708) → (£4,643,171) | about **−£2.61m** | 20 employees (2024: 10); owes the group £6,738,674; going concern relies on group support |
| Heat Geek Ltd (11887015) | (£26,901) → (£574,393) | about **−£547k** | net current liabilities £571,681 |
| Heat Geek Group Ltd (14316058) | (£2,522) → (£2,549) | holding company | share premium £4,243,515 → £4,741,695; new "Other reserves" £2,000,000; debtors £6,738,674 (the Technologies loan) |

Reading (inference, not stated anywhere): the contracting entity earns the spread on each install and the platform burns it. Installations Ltd has no employees, so every job is subcontracted to the local engineer; its profit is the difference between the customer price (including the BUS grant Heat Geek claims on the customer's behalf) and the subcontract plus kit. The £1.1m of work in progress and £0.9m of other creditors (plausibly customer deposits and BUS receipts) point to a few million pounds of install turnover, undisclosed. Group-wide FY25 result about −£2.75m. The £2m "other reserves" at Group is unexplained in the filings read.

The per-install take rate or fee was not found in any interview, release or filing. Investor theses from Transition and Carrier Ventures were not retrieved.

## What this means for GridWorks

- The venture thesis is ownership of the install transaction. Content and training recruit engineers; the platform routes them leads and parts; the contractor of record takes the margin on every job. Training is the funnel, not the business.
- Heat Geek made installs measurably better (about 0.3 SCOP over other monitored installs) and made the customer experience routine. It did not make them much cheaper, which matches the wider finding that Britain's flat grant has barely moved installed cost.
- The defensible claim for a GridWorks installer on-ramp is therefore "trained, monitored installers deliver higher measured efficiency", cited to HeatpumpMonitor.org. Cost reduction has to rest on other things: pre-packaged assembly and program design.
- A margin-taking contractor of record is the installer-capture position GridWorks is trying to design out of its muni programs. Grant money should fund training, reference material and a measured performance guarantee, not a lead-and-margin platform.

## Sources

| URL | What it gave | Verbatim snippet |
|---|---|---|
| http://web.archive.org/web/20260620213948/https://www.heatgeek.com/heat-pump-guide-2026 | Own average price [read] | "At Heat Geek our average install price is £3,000 (after the grant)." |
| https://renewableheatinghub.co.uk/are-we-sleepwalking-into-another-race-to-the-bottom/ | Independent ZeroDisrupt quotes [read] | "the quoted price came in at £10,000 (£2,500 from the homeowner plus the £7,500 BUS grant) for a 5kW Vaillant aroTHERM" |
| https://www.nesta.org.uk/blog/four-years-boiler-upgrade-scheme-four-charts/ | BUS median [fetch-summary] | "rose slightly this year, from £12,973 to £13,041" |
| https://www.refurbandretrofit.com/nathan-gambling-teased-it-its-big-zero-disrupt-from-the-geeks/ | ZeroDisrupt launch claims [fetch-summary] | "50 % less time on site - typically a few days instead of one-to-two weeks." |
| https://www.ecocosts.com/heat-pumps/heat-pump-installers/heat-geek/ | One job price [fetch-summary] | "approximately £13,421 before BUS grant" |
| https://heatpumpmonitor.org/system/list/public.json | Cost and COP data [read, computed] | schema field `installation_Cost` = "Installation Cost (before subtracting grant)" |
| https://raw.githubusercontent.com/openenergymonitor/heatpumpmonitor.org/main/www/Modules/system/system_schema.php | Field meanings [read] | `heatgeek` = "Heat Geek Mastery" |
| https://forums.moneysavingexpert.com/discussion/6551444/heat-geeks | Customer notes, Sept 2024 [fetch-summary] | "Heat Geek Assured has only done 200 installs nationwide so far" |
| https://thenextweb.com/news/heat-geek-startup-heat-pumps-brits | Sample COP, May 2024 [fetch-summary] | "The average COP across a year for a sample of Heat Geek certified heat pump installations is 4.44" |
| https://find-and-update.company-information.service.gov.uk/company/14797942/filing-history | Installations Ltd accounts FY25 [read] | "The average number of employees during the year was NIL (2024 - NIL)." |
| https://find-and-update.company-information.service.gov.uk/company/14317488/filing-history | Technologies Ltd accounts FY25 [read] | "the Income Statement has not been delivered" |
| https://find-and-update.company-information.service.gov.uk/company/11887015/filing-history | Heat Geek Ltd accounts FY25 [read] | quote not captured; read before citing |
| https://find-and-update.company-information.service.gov.uk/company/14316058/filing-history | Group accounts FY25 [read] | quote not captured; read before citing |
