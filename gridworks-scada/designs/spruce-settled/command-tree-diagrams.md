# command-tree-diagrams (unsorted item)

Status: Draft · Pass 0 · Updated 2026-09-10 · Linear: OPS-392

> What this is: an unsorted item; hub [`primary.md`](primary.md).

**Good-looking command-tree diagrams for the executor (2026-09-10).**
The command tree changes shape with every top-state transition (admin
takes the tree, LocalControl and LeafAlly hold it, five-v-boss cuts the
5 V and reparents the cycler and vdc-relay, hp-boss owns the heat pump's
sub-tree), and today the only pictures of it are the ASCII trees drawn
for a terminal window. Those serve one session; they are not
documentation. The executor wants proper rendered diagrams, one per
tree shape and one showing the transitions between shapes, so a reader
of `executor/control-hierarchy.md` sees every shape the tree can take
and which event moves it from one to the next.

Not settled: the drawing tool (mermaid renders in the wiki and needs no
asset files; an SVG can be laid out by hand and looks better), how many
shapes there are once the fall layouts arrive, and whether the
transition view is one diagram or a matrix. The `command-tree-matrix`
spoke's state-transition rows are the source of truth for the
transitions; the diagrams illustrate them, they do not define them.
