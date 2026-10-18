# Adversarial cycle

Status: Draft · Pass 0 · Updated 2026-09-18

How planned work gets built with two models from different vendors: one plans
and builds, the other tries to break the plan and then the result. One cycle,
run at three scales.

## Cast

- **Fable** orchestrates, with ultracode. It writes the plan, checks and
  folds in review findings, directs the builders, and reviews their work.
- **Sol** is the adversarial reviewer: Codex model `gpt-5.6-sol` at
  `model_reasoning_effort = "high"`, reached through the Codex plugin for
  Claude Code. It is read-only and never fixes anything.
- **Builders** are Fable's subagents. Opus 4.8 for every builder that writes
  or changes code or tests. Sonnet only for read-only sweeps whose output
  Fable checks before using it. Haiku is not used. The cost that matters is
  verification: a confident wrong edit from a cheaper model costs a redo
  loop that outweighs the saving.

## The cycle

1. Fable writes the thing under review, or directs builders to.
2. Sol attacks it and returns a review.
3. Fable verifies each finding, folds in the ones that hold, and hands the
   result back to Sol.
4. Steps 2 and 3 repeat under the rounds rule, then Fable reports to the
   human, who holds the gate.

## The three scales

| Scale | What Sol attacks | When | Human gate |
| --- | --- | --- | --- |
| Design | The whole hub and its spokes | Before a design goes Accepted | The Pass increment |
| Slice | One "do this next": its plan, then its diff | Every build step | "go" before any edit |
| Wind-up | The design against everything that was built | Before distilling to `executor/` and deleting the design | The OK to distill and close the issue |

The cast, the rounds rule and the handling of findings are the same at every
scale. Only the review target and the gate differ.

**Design.** Sol is the fresh agent of the design loop's "run the proposal
past a fresh agent"; a model from another vendor is fresher than a second
Claude. An uncommitted design is a working-tree diff in the `wiki` repo; a
committed one is reviewed with `--base <the commit before the design>`.

**Slice.** A slice is one "do this next" of the active spoke. It is the unit
of plan and review; the commit stays the unit of the changelog, and a slice
may be more than one commit. The slice runs the cycle twice: once on the
plan, written into the spoke's "do this next", and once on the build.

- Builders build the whole plan.
- Fable reviews the build once and makes small changes before Sol sees it.
- Problems Sol finds go back to Fable, which gets builders to fix them.

**Wind-up.** The design is reviewed one spoke per round, never as one diff
of the whole branch: most of a round's cost is re-reading context, and one
giant round returns three findings. Each round asks whether the code delivers
the spoke, what in the spoke never got built, and what is durable and belongs
in `executor/`.

## Review rounds

Sol reviews at checkpoints, never once per fold: an opening round, a
pre-final round for a large slice, and the final review. Between checkpoints
Fable red-teams its own work, which catches well under half of what is wrong
with an author's own design; that is why Sol exists. Fable and Sol go back
and forth until they agree, capped at 4 rounds per cycle, then Fable reports.
The report says whether they agreed and lists anything still in dispute at
the cap.

Sol's quota is the scarce budget. It is account-wide across every concurrent
session, and most of a round's cost is re-reading context.

- **The opening round is exhaustive.** Left alone, Sol reports its top one
  to three findings and stops, and the rest arrive one round at a time. The
  opening focus text states the materiality bar, asks for every finding
  above it ("do not stop at the top three"), and says what approval means:
  no finding above the bar.
- **Fresh thread for discovery, resumed thread for fold-checks.** The
  opening round and the final review each start a fresh thread; fresh eyes
  are their purpose. A round that only checks whether Fable folded Sol's
  own recommendation MAY resume the last thread, with the plan diff inline.
- **High effort for the opening round and the final review.** Medium is
  allowed for fold-check rounds only, and only by per-run override. The
  shared `~/.codex/config.toml` is never edited to change effort: every
  concurrent session reads it.
- **Check the pin before round one.** `~/.codex/config.toml` holds
  `model = "gpt-5.6-sol"` and `model_reasoning_effort = "high"`. A missing
  or weaker pin is a silent downgrade; Fable raises it before reviewing.

## The materiality bar

A finding above the bar blocks. A finding below it is reported as a note and
does not start another round. Style, naming and "a different approach might
be nicer" are below the bar.

At the Slice and Wind-up scales a finding blocks when it could:

- put wrong data on the wire or into durable storage;
- leave hardware in a wrong or unsafe state: a relay, a valve, a house
  without heat;
- lose data that cannot be recovered;
- break a verified executor claim.

At the Design scale a finding blocks when the design cannot be built as
written, contradicts a verified spec, or leaves a decision unmade that a
builder would have to guess.

## Handling Sol's findings

- Fable verifies each finding before folding it in. Sol reads statically and
  does not know GridWorks conventions, so it will sometimes flag a deliberate
  choice as a bug, and a wrong finding folded into the plan becomes wrong
  code in the build.
- Verification is empirical where it can be: run the test, reproduce it in a
  REPL, read the actual line. The same bar applies to Fable's own claims.
- A finding Fable checks and rejects goes in the report with the reason. It
  is never dropped silently.

## The slice's test

Each slice gets a test, and the test is shown to fail when the change is
reverted. With LLM builders the usual failure is a test that passes without
reaching the code it claims to cover; reverting the change and watching the
test go red is the check. A slice that is a sweep across the codebase MAY add
a scanner test that fails while any old form remains.

## What Sol can see

Sol's read-only sandbox restricts writes, not reads: run from one repo, it
reads files in a sibling repo or the wiki by absolute path. The wiki is
never copied or linked into a code repo. The focus text of each review names
the `executor/` files that are the contract for the code under review and
tells Sol to read them first; the focus text is ephemeral, so the repo still
knows nothing of the wiki. A plan review run from `wiki/` names the code
files the same way.

## Where the review files go

`scratch/<name>/` under the umbrella directory, one folder per cycle, files
numbered by round: `plan-r1.md`, `sol-r1.md`, `fable-r1-response.md`. Sol
cannot write, so Fable writes Sol's returned review to its file. Nothing
goes in the repo under review: review files there dirty the tree for the
hooks and for other sessions. The numbered files are the record the report
points to.

## Pseudocode-first plans

A slice's plan carries function skeletons and a list of invariants, before
Sol's first round, when the slice touches:

- timing or concurrency: anything where the order of messages or a clock
  matters;
- a state machine: actor states and transitions;
- a comm path: message handling, acks, what happens when a link flaps.

Every other slice gets a prose plan. Prose gets worse under review: each
fold adds a carve-out, and the carve-out becomes the next round's finding.
Pseudocode has to say what happens in every case.

The list is short on purpose. When a slice outside it turns out to have
needed pseudocode, Fable asks the human whether its kind belongs on the list.

When a plan review starts arguing over implementation details, the plan
rounds stop: Fable writes the pseudocode or moves to build. A diff review
settles in one round what prose takes many to pin down.

## Hard rules

- **The human owns git.** Fable suggests commits; it never commits, and no
  builder or reviewer runs a git command that changes state.
- **No reviewer executes repo code.** Sol works by static analysis and
  read-only commands. A script in a GridWorks checkout can reach a live
  broker or a deployed box; running the code is the builders' job, inside
  the slice's test.
- **Every builder and review prompt carries a secrets-exclusion clause**: do
  not read, quote or return any `.env`, key, certificate or credentials
  file. Every Sol review sends what it reads to OpenAI, and the repos hold
  `.env` files with broker credentials.

## Experiments inside a slice

In an experiment-driven design the experiment is a step of the slice, not
something the slice hands off to afterwards.

- **An experiment may take the place of a review round.** When the open
  question is one reality answers faster than argument ("does this work
  against a real broker"), Fable proposes the experiment instead of another
  round with Sol. Sol is for what an experiment cannot show: the paths it
  did not exercise, the design tradeoff, the failure that has not happened
  yet.
- **An experiment's result is handled as a finding**, and it outranks both
  models. Where it contradicts something Fable and Sol agreed on, the
  experiment wins and the report says so.
- **Partial commits are allowed mid-slice** when an experiment needs
  committed code (boxes run committed code only) or the work has reached a
  sound checkpoint. Each is an ordinary commit: suggested by Fable, made by
  the human, on a `jm/` branch, with the repo's CI entrypoint green and its
  own changelog entry. A failed experiment reopens the slice; it does not
  start a new one.
- **Fable records the slice's starting commit** in the slice's scratch
  folder at "go". Sol's review of the finished slice runs with
  `--base <that commit>`, so it sees the whole slice across its partial
  commits.
- **Sol sees the finished slice once before "ship"**, however many
  experiments ran. An experiment shows that the path it exercised works and
  says nothing about the paths it did not. A small slice MAY skip this
  review; Fable states the choice so the human can override it.
- Sol never runs an experiment. It MAY review the harness code and the
  recorded results, and a review of harness code names `experiments/.env`
  in its secrets clause. The pre-flight before a run gets no Sol round: it
  is a quick check of what could make the run prove nothing or make it
  unsafe, not a document.
- The experiment's record is written right after the run, mid-slice, under
  the `experiments/README.md` conventions, whether or not the slice ever
  ships. A rerun after a reopened slice adds to the same folder.

## Go and ship

A slice has two human gates, and a discussion is never either of them.

**"go"** comes after the plan cycle and before any edit to a code repo.

**"ship"** comes after the build, its experiments and Sol's review of the
finished slice. Fable stops and gives a summary of fixed shape:

- what changed;
- Sol's findings that were folded in;
- findings Fable rejected, each with its reason;
- the suite result in one line;
- each experiment as a pointer to its `experiments/<date>-<slug>/` folder,
  the commit it ran against, and whether anything on the exercised path
  changed after that commit. Where it did, Fable reruns the experiment or
  says plainly that it did not;
- untracked files the commit needs.

The human reads the summary and decides whether the slice is one commit or
needs splitting, then says "ship". The wrap that follows is the existing
one: the commit suggestion after the repo's CI entrypoint, the changelog
entry verified against the diff, the sub-spec reconciled, and the spoke
re-oriented to its next "do this next". The executor claim an experiment
verifies, and its `Reviewed` pointer at the experiment folder, are set here,
once the code they describe is settled.

For an `EDD: no` design the bar at "ship" is the suite and the slice's own
test.

## Open

- Whether `designs-process.md` gains a line pointing here.
