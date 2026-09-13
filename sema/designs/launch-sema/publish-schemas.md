# Publish the schemas (spoke)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-538

> What this is: make every `Sema:` URL resolve. The spec already defines a
> word as published when it is served at `https://schemas.electricity.works`
> (`sema/spec/primary.md:45`), and every generated runtime docstring and
> `$id` carries that URL; the host does not exist yet.

## What is served

The published subset of `indexes/public_registry.yaml`, one static file
per word version at the path the `$id` names
(`/formats/<name>`, `/enums/<name>/<version>`, `/types/<name>/<version>`),
content identical to the definition file. Staging words are not served:
they are mutable and run on dev brokers only. Draft words carry the
parallel `/draft/...` prefix in the spec and are also not served at
launch.

Immutability is the contract: a served file never changes. A correction
is a new version. This is the same rule the registry already enforces
for `published` status, made visible on the web.

## How it is served

Static hosting, generated from the sema repo on push, no server. The spec
publication note already chose GitHub Pages for `spec.electricity.works`
for the same reasons (zero ops, free for a public repo); the schemas host
is the sibling. Open whether both live in one Pages site with two DNS
names or two sites.

## Validation API

Beside the static schemas, one POST route that validates a payload:
the body is the JSON instance, the response is the same verdict the CLI
prints (`OK: <TypeName> (version <v>)` or `INVALID: <error>`), computed by
the same `sema.runtime.validate.validate` function. The existing FastAPI
schema server (`sema/src/sema/interfaces/api/schema_server.py`) serves
schemas by GET and has no validate route; this adds one and deploys the
server beside the static host, at the same published subset. It is the
front-door form of `sema validate`: a stranger, or a non-Python
participant, can try a message before installing anything. A running
consumer never calls it; its own vendored snapshot validates its traffic.

## Open

- Build step: a script under `sema/src/sema/tools/` that lays the
  published subset out as the URL tree, run by CI on push to the
  publishing branch. Which branch publishes (`main`, or a `published`
  branch cut from `dev` at each promotion wave) is the one real decision.
- Content type and a JSON rendering: definitions are YAML on disk;
  serve YAML, JSON, or both under content negotiation.
- An index page per kind so a browser can find words without knowing the
  name.

## Do this next

Write the layout script and run it locally against the current registry;
look at the tree. Then wire Pages and DNS, and deploy the schema server
with the validate route beside them.
