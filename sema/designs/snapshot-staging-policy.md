# snapshot-staging-policy — the seed declares what staging a snapshot may hold, and the tooling enforces it

Status: Draft · Pass 0 · Updated 2026-11-20 · Linear: OPS-702
**EDD: no** the sema suite and the key test: a seed that refuses staging
fails a build whose closure reaches a staging word, naming the word; a
seed that allows a named staging word builds with the banner; a repo's
`ci.sh` fails on a vendored snapshot that holds staging the seed does not
allow.

> What this is: whether a consumer's snapshot may hold staging words is
> decided once, in the committed seed request, instead of at every regen
> by whoever types the command. `sema snapshot` reads the policy from the
> seed, refuses what the seed does not allow, reports what it passes over,
> and one flagless command replaces the six per-repo scripts. A repo's CI
> checks its vendored snapshot against its own seed, so a staged snapshot
> can sit on a branch and cannot merge.

## The problem

Six repos vendor a snapshot through a copy of `regen_sema_snapshot.sh`.
The copies drifted into three conventions for the same choice: journalkeeper
and web-backend read `ALLOW_STAGED=1`; scada and tlayouts hard-code
`--allow-staged` because the layout and operational params words are
staging; gridworks-flo and optimal-flexibility have no option, and their
staging snapshots were built by hand with the sema commands. Handing the
flo-tuning-experimental PR to a teammate took a paragraph per repo to say
when the flag is on.

The spec's published-only pass-over (`spec/snapshot.md` "Published-only by
default") is right for its purpose, a published-only seed needs no edit when
a word stages a new version, but it is silent: a bare prepare against the
current registry produced a journalkeeper snapshot without `flo.params` 004
and without `latest.price` 002, and said nothing. A regen with the wrong
flag yields a snapshot that looks complete and is not.

Nothing checks main. A staging banner on a deployed repo's main is caught
by a reader of the README or not at all.

## The decision

1. **The seed declares the policy.** `sema_seed_request.yaml` gains a
   `staging` block: `refuse` (the default, and what a missing block means),
   or `allow` with the list of words whose staging versions the snapshot
   may hold. Scada and tlayouts list the layout and operational params
   words. The exception becomes a reviewable line in the file a PR reader
   already opens.
2. **Prepare refuses what the seed does not allow, and reports what it
   passes over.** A staging word in the closure that the seed does not
   allow fails the build and names the word. The published-only pass-over
   of `include_all_versions` stays, and the build prints each version it
   passed over, so the silent case is gone.
3. **One command, no copies.** `sema snapshot regen <seed> <vendor-dir>`
   runs prepare, build and the mirror into the consumer. Each repo's
   script becomes that one line or is deleted. There is no flag to pass.
4. **CI checks the vendored snapshot.** `sema snapshot check <seed>
   <vendor-dir>` fails when the vendored indexes hold a staging word the
   seed does not allow, or when the snapshot is not a zero-diff regen of
   the seed against the pinned sema commit. Every consumer's `ci.sh` runs
   it. A staged snapshot on a branch is fine; it cannot merge.

The `--allow-staged` flag is removed once every consumer's seed states its
policy.

## Spec change

`spec/snapshot.md` "Published-only by default" states the seed-declared
policy, the refuse rule, and the reporting of passed-over versions. The
change is discussed with the human before it is edited, per the sema
protocol.

## Repos

sema (tooling, spec, tests); then one small commit in each of the six
consumers: the seed's `staging` block, the script reduced to the one call,
`ci.sh` running the check. The frontend's hand-written zod snapshot is out
of scope until the TypeScript generator produces it.

## Plan

1. Sema: the `staging` block in the seed schema; prepare refuses and
   reports; `regen` and `check` subcommands; spec section; tests.
2. Consumers, one commit each, any order: seed block, script, ci.sh.
3. Remove `--allow-staged`.

Effort: about four hours. Not before the flo-tuning-experimental PR merges.
