# Price stages — contract notes held for the executor

Status: Draft · Pass 0 · Updated 2026-11-16 · Linear: OPS-684

> What this is: the traces and README notes on the two-stage price and
> the hourly dispatch contract, kept here while the scada and maker PRs
> are open, and moved to their executor homes at merge: the maker's rows
> and traces to the marketmaker executor (`executor/traces/` and the
> YAML rows), the contract lifecycle to the scada executor's
> contract-lifecycle sub-spec, which that move opens, and the
> outside-sources how-to to each repo's README. Nothing links here.

## Traces

Open. One trace per provocation scenario as the run produces it: the
messages in order with their stage, status and plant time.

## README notes

Open. The outside-sources section for `gridworks-marketmaker` and
`gridworks-price-forecast` (ISO-NE Web Services, location 43790
LD.KEENE_RD44; the Versant A-1 sheet, page and revision) and the how-to
a reader outside GridWorks follows to reproduce one published number.

## The rules of engagement

Open. What the first dispatch terms say in words, for the signed text:
one amendment, the Provisional binding at 240 s with no Final, the
reduce-only rule for a bidder acting on a Provisional.
