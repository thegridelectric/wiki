# The repo README

Status: Draft · Pass 0 · Updated 2026-10-18

> What this is: how a GridWorks code repo's `README.md` is written. The
> README is the one document in a repo for a person, it stands alone,
> and it does not cite the wiki (`GridWorks_CLAUDE.md` "Repos do not
> know about the wiki"). It is finalized before the domain's executor
> is built, since the executor's Domain Summary is copied from it
> (`executor-CLAUDE.md` "README first").

## Two parts, in this order

First the language-independent text. It opens with a summary for a
person: what the domain does and where it sits in GridWorks, with no
code words, no box names and no file paths. Then what the domain
speaks, its processes, and how it is operated.

Then one language-dependent section at the end, as small as it can
be: install, environment, running the tests, the CI entrypoint.

The order puts what the domain is ahead of how to run it. A reader
who wants install scrolls to the end; the README is short enough that
this costs little, and the first part is what a port keeps
(`rulebook/rebuild.md`).

## Open

- Whether the order is right for every repo, or only for the services
  with an executor. A library a developer installs and reads code from
  may want its quick start first.
