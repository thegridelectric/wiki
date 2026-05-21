# GridWorks glossary & legacy-naming canon

Cross-repo vocabulary that spans more than one project. The **single source of
truth** for informal terminology and legacy→current naming. Collaborators and
agents should treat this file as authoritative; do not keep private copies
(e.g. in an agent's project memory) — point here instead.

**Defers to Sema for formal types.** Anything that is a formal Sema vocabulary
word (a `left.right.dot` type/enum/format) is defined in `sema/` — Sema is the
authority over meaning. This file holds only the *informal* and *transitional*
naming canon that Sema does not govern.

## Legacy → current naming

These terms are **always legacy** wherever they appear in code or in-repo docs.
Read them as their current replacement.

| Legacy term | Read as / replaced by | Notes |
|---|---|---|
| `atn`, `AtomicTNode` | **LeafTransactiveNode (LTN)** | The LTN is being separated out of `gridworks-scada` into a rabbit-native extension of gridworks-base; its presence there (`ltn_app.py`, `actors/ltn/`) is temporary, not a permanent actor subpackage. |
| `ASL`, `Application Shared Language` | **Sema** | Sema is the current boundary-infrastructure language for serialized-JSON contracts. See `sema/CLAUDE.md` and `sema/docs/`. |

## How to extend

Add a row when you find a term in code/docs that has been superseded but still
appears. If the term is a *formal* Sema type, define it in Sema and (optionally)
cross-reference it here rather than redefining it.
