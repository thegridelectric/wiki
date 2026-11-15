# gridworks-price-forecast — rebuild spec

Status: Accepted · Pass 0 · Updated 2026-11-14

> What this is: the executor hub for the price-forecast service, the
> GNode that forecasts the price a MarketMaker will publish, slot by
> slot. The repo README says what the service is and what it speaks;
> this hub says what a future session must hold that the repo cannot
> show. Where it runs and how it is operated is
> `gridworks-infra/forecast/instance-README.md`.

## The forecast is a publication, not a reply

The service notices an ISO-NE day-ahead posting, builds one forecast
document from it, emits it once, and serves views of it until the next
posting. The document is `gw.price.forecast` 000: one price per slot for
one market (`MarketMakerAlias`, `ProductName`), as `PriceX1000` integers
with a `PriceUnit`, under one `ForecastUid` minted when the document is
built. The price is the full price a bidder on that market faces, the
day-ahead LMP at the market's pricing node plus the tariff's delivery
price, with no parts: the FLO optimizes against the sum and the actual
price's parts belong to `latest.price`.

- **Publication-driven fetch.** ISO-NE's `hourlylmp/da/final/info`
  returns the latest posted operating day and its posting time. From
  12:30 ET the service polls it every few minutes until tomorrow is
  posted, then fetches the day; before 12:30 and after a fetch it checks
  hourly, so a late posting is still caught (`src/gwpf/forecast.py`
  `poll_interval_s`, `PublicationWatcher`). A day not posted by 13:30
  is late; the service keeps polling and raises nothing.
- **One document per posting, stable id.** The kept document is the
  next 72 hours from the next full hour (`DOCUMENT_HOURS`), the
  published hours first and the rest repeated by hour of day
  (`extend_by_hour_of_day`). The view both HTTP routes serve is its next
  48 hours (`VIEW_HOURS`, `view`) under the same `ForecastUid`; a new
  id appears only when ISO-NE posts, when the kept document can no
  longer fill a view, or when the service starts with nothing kept.
- **Broadcast.** Each new document is published once on the hw1 broker
  (`price_actor.py`), as the weather service publishes its forecasts,
  and the journalkeeper journals it on its own id and clock. The HTTP
  routes stay for the LTN's pull; the legacy path the LTN calls serves
  the same word.
- **The basis beside the document.** The word states the price and
  nothing about its making, so the service keeps a small basis file
  beside the kept document (`BASIS_FILE`): the posting it was built from
  and how many of its hours ISO-NE itself published. A basis word keyed
  by `ForecastUid`, journaled beside the forecast, retires the file
  ("Open").
- **The delivery price** comes from a hand-kept copy of the Versant
  Rate A-1 table at the Seventeenth Revision (`src/gwpf/tariff.py`),
  with a note naming the tariff word that retires it; the MarketMaker
  keeps the same table for the `Delivery` part of `latest.price`.

## When ISO-NE posts

Three sources agree (2026-11-11). ISO-NE posts the day-ahead results
for the next operating day around 13:00 ET: of 148 days of journaled
LTN requests from 2025-11 to 2026-11 whose "tomorrow" prices changed,
66 first showed real prices at the LTN's 12:57 fetch and 71 at 13:57;
the current service's six days on oak split three and three across
13:00. The `/info` endpoint gives the posting time directly (operating
day 2026-11-11 was posted 2026-11-10 at 13:10:05 ET). The
`/day/latest/location/{id}` path answers 500 and an unposted day is an
empty `HourlyLmp` list, so the service reads `/info` and asks for the
day by date.

## Open

- The executor proper (delivery, record lifecycle, traces) is written
  with OPS-437, against the service's standing as a gwbase GNode; the
  service's broker auth posture is that hub's question.
- The basis word: which posting a forecast came from, how many hours
  are ISO-NE's own and how many repeats, the tariff revision behind the
  delivery price, later a model's inputs. Keyed by `ForecastUid`,
  journaled beside the forecast. Until it exists the journal tells a
  forecast built before a posting from one built after it only by
  `CreatedMs`.
- The 25-hour and 23-hour days at the DST changes: ISO-NE labels the
  repeated fall hour `02X` in its reports; how the Web Services API
  represents it is unverified. Slot starts in UTC seconds leave the
  word nothing to say about it.
- The actor has no test in CI (it needs a broker), and CI does not run
  mypy.
