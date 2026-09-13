# Front door (spoke)

Status: Draft · Pass 0 · Updated 2026-09-13 · Linear: OPS-538

> What this is: the one page a stranger reads first. The README already
> holds most of the material (why it matters, adding a type, adding a
> version, snapshots, CLI, contributing). This spoke decides what that
> page promises and checks that each promise is true for someone with no
> access to us.

## The promises

- **Why.** Meaning declared once, versioned, checkable; the reason a
  language wants speakers. One paragraph, not the essay.
- **Read.** Every word is at its schema URL; the spec is in the repo (and
  at `spec.electricity.works` when that ships).
- **Author.** Topic branch from `dev`, one word per branch, pull request.
  The governance spec says what a reviewer checks and what promotion
  means.
- **Vendor.** A seed request and a snapshot build give a repo its own
  runtime; the drift check proves it stays honest.
- **Ask.** GitHub issues.

## What a stranger cannot do today

- Resolve a schema URL.
- Know whether a pull request will be reviewed, by whom, or on what
  schedule. Governance names the registration process but not the
  turnaround; say something honest, even "best effort, weekly".
- Vendor without a sema checkout beside their repo: the CLI locates its
  repo tree at import time. The clone-and-`uv run` route works and should
  be the documented one until the package is installable.

## Do this next

Walk the README as a stranger after the schemas host is live, and fix
each promise that is not yet true or say plainly that it is not.
