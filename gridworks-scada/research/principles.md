# Foundational principles

Commitments that constrain every SCADA design decision. These are *design
intent from Jessica*, not necessarily reflected in today's code — where the
code diverges, that is a finding, not a correction to this file.

## The SCADA acts for the customer, not the provider

The SCADA operates **on behalf of the homeowner/customer**, not on behalf of
the aggregator or service provider. This is the lens through which every
contract, heartbeat, and control-handoff decision is read.

## Whoever owns the LTN's financial choices holds the SLA

The business that owns the financial decisions of the LeafTransactiveNode
(LTN) is the one that **must hold the Service Level Agreement** with the
customer. You cannot own the upside of the trading decisions while pushing the
service obligation onto someone else.

- Concrete case: Aris (Robert Benjamin) wants the customer SLA but does not see
  himself as an aggregator. Under this principle, whoever makes the LTN's
  financial choices must carry the SLA — the role cannot be split away from the
  obligation.

## The SCADA bails on SLA breach, not on convenience

The contract between SCADA and LTN does **not** permit the SCADA to drop out
"whenever convenient to the SCADA." The SCADA terminates a contract when the
**SLA is broken** — e.g. a critical zone getting too cold — and at no other
time. (Legacy `old_words/representation-contract.md` calls this the SCADA
*suspending Representation*.) See [[liveness-and-sla]].

## Liveness must be proven by the party that can actually be offline

A heartbeat that demonstrates liveness must be between the **SCADA and the
LTN** — not between a provider's cloud and a GridWorks LTN, because a cloud
operator can fake liveness. In residential settings the SCADA genuinely goes
offline, and for many contract types an offline SCADA *means the contract is
broken*. The liveness signal has to originate where the real failure can
occur. See [[liveness-and-sla]].

## Meaning is explicit (Sema), not implicit

Per [[../../sema/research/where-meaning-lives-in-gridworks]]: semantic authority lives
in Sema. Any fact that matters for validation or composition is declared in the
Sema schema, never inferred from naming conventions or implementation details.
The SCADA's *boundary* messages obey this; its *internal* runtime need not.
See [[sema-style]].

## à-la-carte legibility is a first-class goal

The cleanup target is code (and docs) from which an LLM or human can lift a
single concept without swallowing the whole system. The GridWorks style is
"horizontal and à la carte" rather than deep inheritance hierarchies; the
legacy SCADA is not there yet (see [[sema-style]]).
