# The maker's store

Status: Draft · Pass 0 · Updated 2026-11-15

> What this is: why the MarketMaker, which keeps nothing today, gets a
> local database next, and what goes in it first.

The maker keeps no state. Its gate holds the last fetched wholesale
price and the last published slot in memory; a restart begins cold,
passes over the open slot, and a fetch failure in the first hour after
a restart has no price to fall back on, so the houses get a fault and
no price. The journal is the record of what it published.

A local database changes three things:

- **The fallback survives a restart.** The last published price, read
  back at start, lets a maker restarted mid-hour publish the stale
  price with its fault rather than nothing.
- **A restart can know what it published.** Whether the open slot's
  price went out before the restart is a fact in the store, so the
  rule "the open slot at start gets no publish" can become "the open
  slot gets a publish only if none went out".
- **The book.** The full maker takes bids, acks them into contracts
  and clears; the book of bids and contracts per slot is a store, and
  the stopgap's store is where it starts.

What the store keeps is `latest.price` words and, later, bids and acks,
whole, read back as the words; the Words table gets stored rows and the
Boundaries table a store row when it comes.
