# onboard-cedar — the EDD run

Status: Accepted · Pass 1 · Updated 2026-10-15 · Linear: OPS-473

> What this is: the third spoke of the disentangle-installations hub and
> the design's verification. Cedar (a new Millinocket house, Ridgeline's
> "House 5") enters the registry and gridworks-pii through the new path.
> Runs after pii-store and retire-installations are live.

## Do this next

Nothing until the two spokes before it are live. Then run the sequence
below in one sitting and record the result here.

## The sequence

1. The operator runs `gnregistrar create` and enters the pending
   TerminalAsset `hw1.isone.me.versant.keene.cedar.ta`. The registry
   mints its GNodeId and a random `position_point_id`. Nothing about a
   person enters the open system.
2. Minutes later the operator runs `add-customer <that GNodeId>` with
   the name, street, city, state, ZIP, email and phone, and the installer.
   The CLI mints cedar's HH label and prints it for Ridgeline. The
   change record names the operator.
3. The scada and LTN GNodes, the layout, and the rest of provisioning
   follow as they do today, none of it touching the store.
4. Later, when the validator plane exists, TaValidation reads the address
   from the store to produce coordinates, writes them encrypted into
   gnr, issues the TaDeed and TaTradingRights, and the TA goes Active.
   The store is unchanged by validation. Step 4 is not part of this
   run; it is recorded so the sequence is whole.

## What pass means

- The pending TA is visible in the registry's read façade with a
  `position_point_id` and no position.
- `show <GNodeId>` on the CLI returns the customer, the installer and the
  HH label; the change record has one row for the add.
- The dashboard lists cedar by display name; its Status and Hardware
  sections render once the scada reports; Address and Contact show
  according to whether OPS-600 has shipped.
- A grep of the journal's `messages` table, the ear's archive window for
  the hour, and gw_data's remaining tables finds neither the customer's
  name nor the street.
- Ridgeline's folder for the house is renamed to the HH label and
  contains no alias.

## Result

Not yet run.
