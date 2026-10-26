Status: Draft · Pass 0 · Updated 2026-10-26 · Linear: OPS-603

**EDD: yes** verified when a request over the weather façade returns
last winter's Open-Meteo forecasts as issued and a station's actuals for
Millinocket, both as archive words read from the eventstore, and the
spruce slab fit (`experiments/spruce-radiant-slab/`) runs from those
words with its gzipped CSV gone.

# Weather history archive: long records from named outside sources

## What this is

The weather service keeps every forecast it emits, and JournalKeeper
journals its observation and forecast broadcasts, so from go-live the
fleet's own weather record is complete. Nothing holds what came before
go-live or what an outside source said about the past: the service
keeps only the latest pulled product per acquisition, overwritten on
each fetch, and a long pull from an outside source today ends as a CSV
in an experiment folder, gzipped if it fits. Two uses need that history
as sema words in our own immutable store, readable on request: scoring
a forecaster (how did its day-ahead forecasts do against what was
measured, over a winter), and evaluating performance, real or
simulated, of a controller that acted on those forecasts (replay an
LTN's winter against the forecasts it would have seen and the weather
that came). This design adds the vocabulary for a long record from one
named outside source, a pull that writes such records to the
eventstore once, and the read requests that return them.

## Facts the design rests on

- The eventstore key grammar names a sema word per file:
  `<subject>-<condition?>-<type.name>-<version>.json`. A long record
  needs a word to be stored at all.
- The service's `SourceProductSql` is keyed by acquisition (method +
  locator) and upserted: the pulled product is the latest revision
  only. The emitted forecasts are all kept (`forecasts` table).
- JournalKeeper persists `gw.weather.observation` and
  `gw.weather.forecast` into the journal DB (`sema_message_persistor.py`).
  Fleet actuals exist there from 2026-10-25, when the service went live,
  for the one location: `kmlt` temperature and windspeed under
  `hw1.isone.weather`; the `kmemilli18` irradiance channel has no
  reading yet (OPS-621).
- Open-Meteo serves forecasts as issued (Previous Runs API) and
  reanalysis actuals (Historical Weather API, ERA5) at any coordinates;
  both free tier, non-commercial, CC BY 4.0. NWS publishes no archive
  of its gridpoint forecasts. Station actuals: USCRN Old Town (82 km),
  and the personal station KMEMILLI18 in Millinocket behind the
  weather.com PWS history endpoint the wunderground dashboard reads,
  an unofficial API that may stop.
- The read façade pattern (`api-pattern.md`): a request-shaped read is a
  POST of a request word returning a word, under
  `/<hyphenated-alias>/<type-with-hyphens>`; bodies are words, never
  ad-hoc scalars.
- Sema words are flat; no inheritance between words. A word with a
  Kind switch and fields that apply only to some kinds is the smell
  that rule exists to catch.

## Vocabulary

Two record words, one per shape, both owned by gridworks-energy and
anchored on the existing place and channel words.

**`gw.weather.observed.series`**: one measured series from one named
source over a long window. LocationAlias; the observed channel it
targets (Name of a `gw.weather.channel.gt`, so Quantity and Unit come
from the record); Source (an LRD naming the outside source and
station, `uscrn.old.town`, `wunderground.kmemilli18`, `era5`); Method
and SourceLocator as on the forecast channel word; Start and PeriodS
with Values as scaled integers on a uniform grid, a null where the
source has no value; PulledTime and a Provenance string (the request
as made). Irregular station reports are binned to the grid at the
pull, and the bin rule is part of Method.

**`gw.weather.issued.forecasts`**: one forecaster's forecasts as
issued, over a long window of issue times. The forecast channel it
belongs to (Name of a `gw.weather.forecast.channel.gt`); Source,
Method, SourceLocator; IssuePeriodS and FirstIssueTime; HorizonSlices
and SlicePeriodS; Values as a list of lists, one row per issue time,
each row the horizon from that issue, nulls where the source has no
run; PulledTime and Provenance.

Both words are big by design (a winter of hourly values is 4,000
integers; a winter of day-ahead forecasts at hourly issue is 170,000)
and that is fine in the eventstore, which has no per-file cap. The
2 MB cap is the experiments repo's.

Open branches, to grill before authoring: whether `Values` as a list of
lists is acceptable sema or the issued word should be one instance per
issue time (small words, many files, the key grammar's `condition`
segment as the issue time); whether a station's native irregular
reports deserve their own shape or binning at the pull is the right
line; whether Source is a new format word or an LRD with a naming
rule in `vocabulary.md` "Naming".

## The pull

A command in the weather service, not a cron: `gwwf archive` with the
source, the channel, and the window. It calls the source adapter's
long-pull function (Open-Meteo Previous Runs and Historical Weather,
USCRN's hourly files, the PWS history endpoint), bins or shifts to the
channel's grid as the adapter already does for live pulls, builds the
record word, and writes it to the eventstore under the key grammar.
The record is immutable once written; a re-pull over the same window
writes a new file with its own PulledTime, never overwrites. The
service's live loop does not change; it keeps emitting from the latest
product.

## The reads

Two request words on the façade, each returning the record word, so
a consumer never reaches into the eventstore or the service DB:

- `POST /d1-weather/gw-weather-observed-series-request` with
  LocationAlias, channel Name, Source, window → `gw.weather.observed.series`.
  The service answers from the eventstore for archived windows and from
  the journal's fleet record for windows after go-live, stitched into
  one word.
- `POST /d1-weather/gw-weather-issued-forecasts-request` with the
  forecast channel Name, Source, window of issue times →
  `gw.weather.issued.forecasts`. Archived windows from the eventstore;
  the service's own emitted forecasts from go-live, re-shaped to the
  same word.

The interactive docs at `/docs` are the human interface; a teammate
evaluating a forecaster or a simulated winter asks there or with one
`curl`, and gets a word the sema runtime decodes.

## The slab experiment

`experiments/spruce-radiant-slab/` holds `irradiance-kmemilli18.csv.gz`
and `pull_irradiance.py` pulling the KMEMILLI18 five-minute solar
highs for three windows, with the record typed in the script and a
note naming the missing word. When the observed-series word exists:
`gwwf archive` pulls the same windows from the same endpoint into a
`gw.weather.observed.series` at the station's native grid or a
five-minute bin; the fit's `load_solar` reads the word through the
façade (or the file from the eventstore, bytes intact, under the
folder's 2 MB cap as a sema instance); the gzipped CSV and the
script's own record type go. The README's "Folder contents" entry for
the evidence changes from external bytes to a sema instance with its
key.

## Do this next

1. Grill the vocabulary branches above to a decision (plan mode,
   `/grill-me`), then author the two record words and the two request
   words, staging, through the sema gate.
2. `gwwf archive` for Open-Meteo Previous Runs (irradiance, day-1 and
   day-2, last November to March, Old Town and Millinocket) and for the
   USCRN Old Town hourly actuals; the OPS-597 scoring pull then reads
   from the archive instead of pulling itself.
3. The two façade reads, with the journal stitch for post-go-live
   windows.
4. The slab experiment's irradiance evidence re-pulled as a word; the
   gz removed.

## Open

- **Licence.** Open-Meteo's historical endpoints fall under the same
  free-tier, non-commercial terms as the forecast; confirm the archive
  use is within them before a bulk pull.
- **Who writes the eventstore.** The service writes archive files
  directly, or hands them to the uploader. The second keeps one writer
  per store; the first is simpler. Decide at step 2.
- **Journal stitch.** Whether the service reads the journal DB (another
  service's database, which the consumption idiom forbids) or
  JournalKeeper grows its own read for these windows. Decide at step 3;
  until then the reads answer from the eventstore only.
- **OPS-597 dependency.** The solar design's scoring step (its "Do this
  next" 5) is step 2 here; the two designs name each other by issue.
