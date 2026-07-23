# Changelog

A reverse-chronological log of WHY we made each commit **in the
`gridworks-ear` code repo**. The matching git commit (in
`gridworks-ear`) holds the WHAT (the diff). Each entry's date and
one-line title mirror the corresponding code-repo commit.

This changelog does NOT track wiki edits — those live in the wiki
repo's git history.

Newest at the top.

---

## 2026-07-23 — S3 endpoint_url, aws → s3 rename, service-deployment pattern, witness = service alias, repo sweep <!-- pending commit -->

**What:** four moves in one redeploy-shaped cluster. (1) `endpoint_url` on
the S3 settings model (default empty = AWS); the boto3 resource passes it
through, so the same client aims at any S3-compatible host — the seed ear's
target is Backblaze B2 (`s3.us-east-005.backblazeb2.com`, bucket
`gw-seedstore`). Model renamed `AwsClient` → `S3TypeClient` AND the field
renamed `aws` → `s3` (env wire `EAR_S3__*`) — allowed because both
production instances redeploy fresh when the ear moves off EC2 onto the gnr
box. (2) The gwbase service-deployment pattern in-repo: `service/` with `ear.service` +
`gnr-ear.service` units (logins `ear` / `gnrear`, one per instance),
per-login aliases (`ear*` / `gnrear*`), and per-instance env templates; the
old `ear service install` indirection (venv symlink, unit shipped inside
the package) deleted. (3) README rewritten repo-only: what the ear is, the
storage-key grammar with examples, config table, CLI, deployment —
box/ops content moved to gridworks-infra (`persistent-storage/ear.md`).
(4) Sweep: readthedocs/sphinx docs skeleton, flake8-era configs
(`.flake8`, `.darglint`), `codecov.yml`, cookiecutter remnants, dead
coverage/isort/ruff-exclude pyproject sections, and the docs-stack dev deps
all deleted; `rich` moved from dev to runtime deps (it's imported by the
CLI); `click` held `<8.2` (typer 0.12 breaks against newer click — the uv
resolve had silently broken `ear --help`). (5) Witness identity is the
**service alias**, not an fqdn: `my_fqdn` deleted; the object key's last
segment is now `g_node_alias` (`hw1.ear` / `hw1.gnr.ear`) — one identity
per instance regardless of machine, which two ears on one box made
necessary. Pre-2026-07 objects carry `ear.electricity.works` in that
slot: same grammar, earlier convention. README opening rewritten to the
where-meaning-lives position (actors + claimed Sema TypeNames, validity
deliberately unchecked) with the routing-key pattern explained, including
the `gw` category's inner-TypeName subtlety.

**Why:** the ear becomes a first-class service-deployment-pattern citizen on the gnr Hetzner box —
two instances, one codebase, config-only divergence — and the repo sheds a
poetry/hypermodern skin that no longer described it.
**Verified:** both env postures resolve (`ear_tx`/`gwdev`/AWS default;
`gnr_ear_tx`/`gw-seedstore`/B2 override); `ear --help` exercises the CLI
build; pre-commit gate + CI-mode suite green after `uv lock`.

## 2026-07-22 — poetry → uv migration (`e714fd4`, PR #140)

**What:** PEP-621 `[project]` + hatchling replace `[tool.poetry]`; `uv.lock`
replaces `poetry.lock`; **pins translated faithfully, not modernized**
(`gridworks-base>=0.2.4,<0.3`, `gridworks>=1.4.1,<2` — the actor code's
era; upgrades are a separate deliberate change). Deleted: `noxfile.py`, the
workflow `constraints.txt`, and `release.yml` (already dead — it triggered
on a branch named `foo` and was welded to poetry). `tests.yml` becomes the
simple uv gate: pre-commit + pytest jobs, keeping the rabbitmq service
action. All 15 stale dependabot PRs (#110–#139) superseded/closed — every
one targeted the deleted machinery. OPS-458.

**Why:** the seed-ear deploys to the uv-shaped gnr box, and uv cannot
install a `[tool.poetry]` project; the fossilized lock wouldn't even build
locally; the red CI *was* the poetry/nox layer cake.
**Verified:** `uv lock`/`sync` clean (107 packages); imports + `EarSettings`
green on gwbase 0.2-era; CI-mode suite 1 passed; full pre-commit gate green
under uv. Honest note: the single test's local-broker mode hangs >90s —
pre-existing (CI self-skips it; this Mac never had a buildable env under
poetry). Prod ear's installed env untouched.

## 2026-07-22 — update CI tools (`22b9100`)

**What:** `tests.yml` bumps — `upload-artifact` v3→v4 (the one that
mattered), `checkout` v3→v4, `setup-python` v4→v5, `cache` v3→v4.

**Why:** GitHub auto-fails any workflow referencing `upload-artifact@v3`
(deprecated), killing both the pre-commit and tests jobs in seconds before
running anything — the configurable-exchange push was the first to hit it.
The v4 artifact-name uniqueness catch doesn't apply: the coverage
download job is commented out.

## 2026-07-21 — Configurable consume exchange (seed-ear ready) (`8e942b0`)

**What:** `EarSettings.consume_exchange` (default `ear_tx` — the production
ear is byte-identical unconfigured); `ear.py`'s three hardcoded literals now
read it, and the bind log names the queue correctly. README documents the
second-instance pattern: the **seed ear** — same proven code pointed at
`gnr_ear_tx` (the registry's fabric-defined slice, gwbase 0.5.7) writing to
the `gw-seedstore` bucket.

**Why:** the fleet's topology record shouldn't drown in the telemetry
torrent; a scoped second instance of the trusted witness captures the
meaning-bearing stream into its own small store — no new capture code, all
config, all in git.
**Verified:** py_compile + env-override reasoning locally (the poetry env
doesn't build on this Mac); the repo's Actions suite verifies on push, and
the prod ear is untouched until the seed-ear unit deploys.

---

## 2024-11-01 — update to better mqtt version (`1a3ce0d`)

**What:** Bumps `gridworks-base` from `^0.2.3` to `^0.2.4` in
`pyproject.toml` (regenerating `poetry.lock` to match) and adds an
operations section to `README.md` — how to SSH into the prod ear instance
(`hw1-1-s3-ear.electricity.works` via `gridworks-main.pem`), the `ear
service` commands, and where the live `state.txt` log tails
(`~/.local/state/gridworks/ear/log`).

**Why:** gridworks-base 0.2.4 carries the improved MQTT support ("better
mqtt version"); pinning it lets ear consume the newer broker behaviour. The
README ops notes capture the prod runbook inline so an operator doesn't
have to rediscover the instance + log locations. Pre-dates the current wiki
convention by a year — logged now as part of the changelog cleanup so the
repo's dormant HEAD resolves to an entry.
