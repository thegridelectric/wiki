# gridworks-price-forecast — rebuild spec

Status: Accepted · Pass 0 · Updated 2026-10-25

> What this is: the executor hub for the price-forecast service. The
> service running today is a stopgap, and this hub says only what a
> future session must hold about it. The repo README says what the
> service is and what it speaks; this hub does not repeat it.

## The stopgap

The deployed service serves `gw.stopgap.price.forecast` on the path the
LTNs call. It is a stopgap in both name and standing: it exists so the
LTN FLOs run this heating season, and it retires when the price-forecast
service's own forecast word exists (OPS-437). Two consumers depend on the
stopgap word, the LTN's current fetch and the web-backend's forward of it
to the visualizer's price panel, and both retire with it. The repo and
the box login are the ones the real service grows into, so OPS-437
replaces the word and the forecaster, not the deployment.

Where it runs and how it is operated is
`gridworks-infra/forecast/instance-README.md`.

## Open

The executor proper (vocabulary, delivery, record lifecycle, traces) is
written with OPS-437, against the service's own word.
