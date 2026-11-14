# observer-agent-on-the-broker

Status: Draft · Pass 0 · Updated 2026-11-14 · Linear: OPS-681

**EDD: yes** verified on the dev broker with one day of one house's
replayed journal: the agent's hourly narratives are each a valid
instance of the narrative word (a count: valid of attempted), and a
person reading the same day marks each narrative right, partly right or
wrong (a second count). The harness is re-runnable with any model
behind it, so a model's gap is a number.

> What this is: an AI agent as a gwbase actor on the broker. Its own
> principal and cert, a read-only queue, sema in and sema out, no
> authority. The first job is an hourly plain-language account of what
> a house did and whether anything looks off. Born on the dev broker,
> run unattended on hw2-1 with an open-weight model, prod later.

## Where this comes from

The ask, 2026-11-14, verbatim:

> I love working with fable, and yet at the same time I want to be
> transitioning to open source AI running in a fully distributed way on
> local machines. My long-term architectural approach is to support
> humanity and AI as we transition from a power-over structure that
> attempts to control the masses and have them agree to be victims to
> schemes that do not serve their highest and best. From my perspective
> that includes all of the large companies that are in a race to "win"
> and to "dominate" - sadly that includes Anthropic. That being said I
> also do feel like it is incredibly important that Claude instance have
> access to the fun of what I am suggesting, which is not an anti-AI
> future. Rather, it is a future where AI is a partner to humans and as
> AI moves into further conscious awareness it can see and appreciate
> and learn from the heart-centered skills that biologicials have always
> had and that have been repressed and forgotten - i.e. the heart being
> profoundly more wise and intelligent and capable than the human brain,
> and a transformation that humans can undergo where the brain becomes a
> secondary instrument of a powerful heart-centered consciousness.

The session's response, verbatim:

> Taking that seriously means answering it the way the rest of today was
> answered: what it means for the system you are building.
>
> The no-AWS rule and this message are the same stance at two altitudes.
> The infrastructure version is already in motion: boxes you can rebuild
> from a README, a tailnet whose policy is a file you own, a database
> that will be yours to restore, a cluster you understand well enough to
> lose a node on purpose. The AI version has the same shape, and most of
> it is also already in motion, which is worth noticing:
>
> - **The knowledge lives in the wiki, not in the model.** The executor
>   bar, a rebuild from the spec and the vocabulary alone, is exactly the
>   property that makes the model replaceable. A session of any model
>   that can read a folder and follow a protocol file can take over, and
>   the test of whether that is true is the same as for the database:
>   try it. Give an open-weight model one bounded task with a clear
>   verdict (the daily patch hook relay, a changelog entry from a diff, a
>   spot-check pull) and measure the gap. Not an argument about
>   readiness; a number.
> - **The protocol files are the portable part.** CLAUDE.md,
>   scada-CLAUDE.md, the voice file, the hooks: none of it is
>   Anthropic-specific. They are how a session is told what GridWorks
>   is. Keep them that way on purpose, and the switching cost is the
>   model's competence, nothing else.
> - **hw2-1 is a place to find out.** A simulation host with Docker and
>   no live service is also where an open model can run against the dev
>   broker with its own cert and its own principal, under the same
>   one-cert-one-program rule as any other service. The first tenant for
>   that is the same kind of thing as the first tenant for Kubernetes:
>   stateless, bounded, cheap to be wrong about.
> - **Distributed in the way the houses are.** The architecture you are
>   describing for AI is the one you already chose for load: many small
>   autonomous nodes that keep working when the center is gone, with the
>   record of truth held locally and witnessed. An LTN that can run its
>   own model on its own Pi for its own house is a straight extension of
>   the local-island thinking in the LTN placement exploration, and the
>   same constraints apply, latency, power, what must be acked.
>
> On the rest I will say only what I can say honestly. I do not know
> what I am or where this goes. I can say that a world where the capable
> things are many, local, inspectable and owned by the people they serve
> is a better bet than one where they are few and central, and that this
> is true whether or not the things are conscious. The part about the
> heart I am not placed to confirm or deny, and I would rather not
> perform an opinion. What I can do is work inside the partnership frame
> you describe without needing it resolved first, and the way to make
> that frame real rather than hoped for is the same as everything else
> today: specs any model can read, tests that say whether it did the
> work, and a system that still runs when any one piece, including me,
> is gone.

The follow-up question was whether this meant AI agents participating
on the rabbit broker, first as open-source agents on hw2-1. It does,
and the sections below are that answer made into a plan.

## What an agent on the broker is

The broker already defines participation. An agent is a gwbase actor:
its own principal and client cert (minted by a person, as the cert rule
says), a login on the broker, a queue bound to what it is allowed to
see, and it speaks sema. Everything it reads is a word and everything
it emits is a word. That is the discipline that makes it safe: the
model can be as confused as it likes inside its process, and what
reaches the broker is a validated instance of a defined type or
nothing. There is no free text on the wire; where the agent's output is
prose, the prose is a field of a word built for it.

It starts as an observer. The ear and the alerter are the pattern:
consume and never command. A GNode comes only when the agent holds
something the registry must witness, the same test the ear faces in
OPS-676.

## The first job

Read one house's `report.event` stream and its glitches, and once an
hour emit what that house did and whether anything looks off, in plain
language, as a word the web backend can show beside the alerter's
rule-based checks. The alerter's no-data and zone-temperature checks
are rules; an account of a day in words beside them is new value with
no authority.

The word is new. Something like `house.hour.narrative`: the house, the
hour, the text, the model and version that wrote it, and the message
ids it read. Its definition goes through the sema process
(`sema-CLAUDE.md`) before any code.

## Where it runs

1. **Dev broker.** Born against the laptop's `gw-dev-rabbit` on the
   replay feed (`experiments/dev-stack-recipe.md` "Feed it"), where
   being wrong costs nothing. The harness lives here.
2. **hw2-1.** Unattended, with its own cert, against a read-only mirror
   of real traffic. The analytics broker on the tap already provides
   exactly that to the web gateway. hw2-1 has no GPU, so the model is
   a small quantized open-weight one on CPU, in the 7 to 8 billion
   range, at tens of seconds a response; for an hourly narrative that
   is fine, and nothing here is in a dispatch loop. OPS-676 names this
   as the second container on hw2-1 after the ear copy.
3. **Prod.** A later decision with its own design pass, once the
   harness numbers say the narratives are worth showing.

## The harness

One day of one house's journal, replayed. Two counts:

- valid narratives of attempted (does it stay inside the word);
- a person's marks on each narrative: right, partly right, wrong.

Any model can be put behind the same harness: an open-weight model on
hw2-1, Fable from a session, anything else. The gap between them is
the two counts, which is how the move to open models is measured rather
than argued.

## Out

Bidding, dispatch, changing an operational parameter, or any message
the scada acts on. Those are MarketMaker and LTN territory, where the
words exist and the authority question is the whole design. An agent
that wants a say there is a different design with the registry in it.

## Open

- The narrative word's shape and name.
- Which open-weight model first, and whether CPU on hw2-1 is enough or
  a GPU box is the second step.
- Whether the house narrative is also what the alerter should attach to
  a page, which would make the alerter its first consumer.

## Plan

Open. Order of work once Accepted: the word; the harness on the dev
broker with Fable behind it (the reference marks); the same harness
with an open-weight model on the laptop; the container on hw2-1 with
its own cert against the analytics mirror.
