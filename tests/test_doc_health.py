"""Wiki health checks — enforce the conventions in GridWorks_CLAUDE.md.

Run from the wiki root:  `uv run pytest`  (or `pytest`).

Checks:
- every wiki markdown doc carries a status stamp
  (`Status: <Draft|Accepted|Verified> · Pass <n> · Updated <date>[ · Reviewed ...]`),
  except for a small exempt set: changelogs, READMEs, the live navigation
  hubs (DESIGN_INDEX), vocabulary canon (glossary), operational state
  (active-claims*), and the test infra itself.
- a design at Accepted or Verified maturity has Pass >= 1.
- no doc exceeds the 1000-line cap (split it into a hub + sub-specs).

Each doc is its own parametrized case, so a failure names the exact file.
"""

import re
from pathlib import Path

import pytest

WIKI = Path(__file__).resolve().parent.parent

# Status-stamp line: "Status: ... Draft|Accepted|Verified ... Pass <n> ..."
STAMP_RE = re.compile(r"Status:.*\b(Draft|Accepted|Verified)\b.*\bPass\s*\d+")
MATURITY_RE = re.compile(r"Status:[^\n]*\b(Draft|Accepted|Verified)\b")
PASS_RE = re.compile(r"\bPass\s*(\d+)\b")
MAX_LINES = 1000

# Files exempt from the stamp requirement:
#   - changelog.md: per-domain commit narrative; its own format.
#   - README.md:    navigation / cold entry; not designed content.
#   - DESIGN_INDEX.md: live navigation hub; not designed content.
#   - glossary.md:  vocabulary canon; no Draft→Verified arc.
#   - active-claims*.md: operational state.
STAMP_EXEMPT_NAMES = {
    "changelog.md",
    "README.md",
    "DESIGN_INDEX.md",
    "glossary.md",
    "active-claims.md",
    "active-claims-template.md",
}

# Top-level directories whose contents are exempt entirely from stamp
# requirements (test infrastructure + operational tool scripts are not
# designed content).
STAMP_EXEMPT_TOPLEVEL = {"tests", "tools"}


def _md_files() -> list[Path]:
    return sorted(p for p in WIKI.rglob("*.md") if ".git" not in p.parts)


def _stamp_scope() -> list[Path]:
    """All wiki markdown that must carry a status stamp.

    Universal scope minus the explicit name exemptions above and the
    top-level dir exemptions (tests/).
    """
    out: list[Path] = []
    for p in _md_files():
        if p.name in STAMP_EXEMPT_NAMES:
            continue
        parts = p.relative_to(WIKI).parts
        if parts and parts[0] in STAMP_EXEMPT_TOPLEVEL:
            continue
        out.append(p)
    return out


def _designs_scope() -> list[Path]:
    """Every markdown file under a designs/ folder — for the
    Accepted-requires-Pass>=1 stamp check (applies to spokes too)."""
    return [
        p
        for p in _md_files()
        if "designs" in p.relative_to(WIKI).parts[:-1]
        and p.name not in STAMP_EXEMPT_NAMES
    ]


def _design_roots() -> list[Path]:
    """The design *roots* that map 1:1 to a Linear issue: a flat
    `.../designs/<slug>.md`, or a fractal hub `.../designs/<slug>/primary.md`.
    A fractal *spoke* (`.../designs/<slug>/<other>.md`) is part of one design,
    not a root — it shares the hub's issue, so it is NOT a root and is never
    required to carry its own Linear id. This is the structural definition of
    the design↔issue bijection unit (not name-matching on spokes)."""
    roots: list[Path] = []
    for p in _md_files():
        if p.name in STAMP_EXEMPT_NAMES:
            continue
        if p.parent.name == "designs":
            roots.append(p)
        elif p.name == "primary.md" and p.parent.parent.name == "designs":
            roots.append(p)
    return roots


def _rel(p: Path) -> str:
    return str(p.relative_to(WIKI))


@pytest.mark.parametrize("doc", _stamp_scope(), ids=_rel)
def test_wiki_docs_have_status_stamp(doc: Path) -> None:
    text = doc.read_text(encoding="utf-8", errors="replace")
    assert STAMP_RE.search(text), (
        f"{_rel(doc)} is missing a status stamp "
        "(Status: Draft|Accepted|Verified · Pass <n> · Updated <date>). "
        "Stamps now apply to all wiki markdown except the exempt set in "
        "tests/test_doc_health.py."
    )


@pytest.mark.parametrize("doc", _designs_scope(), ids=_rel)
def test_accepted_designs_have_pass_at_least_one(doc: Path) -> None:
    """Per designs-process.md: a design ratified to Accepted (or Verified)
    requires Pass >= 1 — at least one meaningful human-LLM iteration. Pass 0
    Claude-solo designs may only sit in Draft maturity.
    """
    text = doc.read_text(encoding="utf-8", errors="replace")
    m_mat = MATURITY_RE.search(text)
    if not m_mat:
        return  # missing-stamp case already caught by the stamp test
    if m_mat.group(1) not in ("Accepted", "Verified"):
        return
    m_pass = PASS_RE.search(text)
    assert m_pass and int(m_pass.group(1)) >= 1, (
        f"{_rel(doc)}: maturity {m_mat.group(1)} requires Pass >= 1 "
        "(at least one human-LLM iteration). Either bump Pass or demote to Draft."
    )


LINEAR_ID_RE = re.compile(r"Linear:\s*[A-Z]+-\d+")


def _stamp_line(text: str) -> str:
    """The doc's Status-stamp line, tolerating a `> ` blockquote prefix and
    leading indentation. Returns the original line (framing intact) so callers
    can regex its content; returns "" if there is no stamp line.
    """
    return next(
        (ln for ln in text.splitlines() if ln.lstrip("> \t").startswith("Status:")),
        "",
    )


def _slugify(title: str) -> str:
    """Canonical projection from a Linear issue title to a wiki design slug:
    lowercase, replace every run of non-alphanumeric chars with one hyphen,
    strip leading/trailing hyphens. A design's Linear issue title MUST project
    to the design's file slug (the design↔issue bijection). The live check
    (apply this to each stamped design's actual Linear title) belongs in
    precheck-design-bijection.sh once a Linear API token is wired; here we pin
    the projection itself.
    """
    return re.sub(r"[^a-z0-9]+", "-", title.lower()).strip("-")


@pytest.mark.parametrize(
    "title,slug",
    [
        ("Untangle market.type.name", "untangle-market-type-name"),
        ("Simulated test environment", "simulated-test-environment"),
        ("Circulator pump 0-10V models", "circulator-pump-0-10v-models"),
        ("Shrink gwproto to proactor surface!", "shrink-gwproto-to-proactor-surface"),
        ("  Leading/trailing -- junk  ", "leading-trailing-junk"),
    ],
)
def test_slug_normalization(title: str, slug: str) -> None:
    assert _slugify(title) == slug


@pytest.mark.parametrize(
    "stamp",
    [
        "Status: Accepted · Pass 1 · Updated 2026-06-08 · Linear: OPS-1",
        "> Status: Accepted · Pass 2 · Updated 2026-06-08 · Linear: OPS-380",
        "  Status: Verified · Pass 3 · Updated 2026-06-08 · Linear: GRI-9",
    ],
)
def test_stamp_line_tolerates_blockquote(stamp: str) -> None:
    """A blockquoted or indented stamp is still found, and its Linear id read —
    regression for a false negative where `> Status:` defeated the lookup."""
    doc = f"# Title\n\n{stamp}\n\nbody text\n"
    assert LINEAR_ID_RE.search(_stamp_line(doc))


@pytest.mark.parametrize("doc", _design_roots(), ids=_rel)
def test_accepted_designs_have_linear_id(doc: Path) -> None:
    """Per designs/linear-integration.md: a design MUST have a Linear issue by
    the time it is Accepted. The bijection is REQUIRED at Accepted/Verified
    (optional at Draft, where it would sit in Linear Backlog). This enforces the
    wiki side — the design ROOT's Status line carries `· Linear: <ID>` (e.g.
    `· Linear: OPS-142`). Runs over design *roots* only (flat `<slug>.md` or
    fractal `<slug>/primary.md`); fractal spokes share the hub's issue and carry
    no id of their own. The Linear-side half (the issue exists and is
    `design`-tagged) is checked by a script when a Linear API token is wired.
    """
    text = doc.read_text(encoding="utf-8", errors="replace")
    m_mat = MATURITY_RE.search(text)
    if not m_mat or m_mat.group(1) not in ("Accepted", "Verified"):
        return  # Draft designs may be doc-only or in Linear Backlog.
    status_line = _stamp_line(text)
    assert LINEAR_ID_RE.search(status_line), (
        f"{_rel(doc)}: an Accepted/Verified design MUST carry a Linear id in its "
        "Status line (e.g. '· Linear: OPS-142'). Add it to Linear (Todo) and "
        "stamp the id, or demote to Draft."
    )


@pytest.mark.parametrize("doc", _md_files(), ids=_rel)
def test_no_doc_exceeds_line_cap(doc: Path) -> None:
    n = sum(1 for _ in doc.open(encoding="utf-8", errors="replace"))
    assert n <= MAX_LINES, (
        f"{_rel(doc)} has {n} lines (cap {MAX_LINES}); split it into a hub + sub-specs."
    )


# --- DESIGN_INDEX.md ↔ filesystem -----------------------------------------
# DESIGN_INDEX.md is a hand-maintained flat directory of every file under a
# designs/ or explorations/ folder anywhere in the wiki. These tests fail if it
# drifts from what's actually on disk — a design/exploration added, removed, or
# renamed without updating the index (or an index entry pointing at nothing).
# When the regen-design-index.sh tool lands these become its conformance check.

INDEX = WIKI / "DESIGN_INDEX.md"
_LINK_TARGET_RE = re.compile(r"\]\(([^)]+)\)")


def _index_section_targets(header: str) -> set[str]:
    """First markdown link target on each bullet under a '## <header>' section
    of DESIGN_INDEX.md (the canonical path), up to the next '## ' header."""
    text = INDEX.read_text(encoding="utf-8", errors="replace")
    targets: set[str] = set()
    in_section = False
    for line in text.splitlines():
        if line.startswith("## "):
            in_section = line.strip() == f"## {header}"
            continue
        if in_section and line.lstrip().startswith("- "):
            m = _LINK_TARGET_RE.search(line)
            if m:
                targets.add(m.group(1))
    return targets


def _fs_under_dir(dirname: str) -> set[str]:
    """Rel-path of every file that is an index entry under a `<dirname>/`
    folder: a flat `.../<dirname>/<slug>.md`, or a fractal hub
    `.../<dirname>/<slug>/primary.md`."""
    out: set[str] = set()
    for p in _md_files():
        if p.parent.name == dirname:
            out.add(_rel(p))  # flat: <dirname>/<slug>.md
        elif p.name == "primary.md" and p.parent.parent.name == dirname:
            out.add(_rel(p))  # fractal: <dirname>/<slug>/primary.md
    return out


def _index_drift(header: str, dirname: str) -> tuple[set[str], set[str]]:
    on_disk = _fs_under_dir(dirname)
    in_index = _index_section_targets(header)
    return on_disk - in_index, in_index - on_disk


def test_design_index_designs_match_filesystem() -> None:
    missing, extra = _index_drift("Designs", "designs")
    assert not missing and not extra, (
        "DESIGN_INDEX.md '## Designs' is out of sync with the filesystem.\n"
        f"  on disk but NOT in the index (add them):        {sorted(missing)}\n"
        f"  in the index but NOT on disk (remove/rename):   {sorted(extra)}"
    )


def test_design_index_explorations_match_filesystem() -> None:
    missing, extra = _index_drift("Explorations", "explorations")
    assert not missing and not extra, (
        "DESIGN_INDEX.md '## Explorations' is out of sync with the filesystem.\n"
        f"  on disk but NOT in the index (add them):        {sorted(missing)}\n"
        f"  in the index but NOT on disk (remove/rename):   {sorted(extra)}"
    )


# --- intra-wiki link resolution -------------------------------------------
# Every relative `](path)` / `[[wikilink]]` that should resolve inside the wiki
# must. External, cross-repo, `wiki/`-prefixed (umbrella-relative),
# `(Open)`/`(TBD)`-marked, and code-span links are excluded by the shared
# resolver (tools/check_wiki_links.py — also used by the session-end hook).
# A planned-but-unwritten spoke must carry an `(Open)` marker after the link.
def test_no_intra_wiki_danglers() -> None:
    import sys as _sys

    _tools = str(WIKI / "tools")
    if _tools not in _sys.path:
        _sys.path.insert(0, _tools)
    from check_wiki_links import find_danglers

    danglers = find_danglers(WIKI)
    assert not danglers, (
        "Intra-wiki links that don't resolve — fix the path, or mark a "
        "planned-but-unwritten target `(Open)`:\n"
        + "\n".join(f"  [{kind}] {rel}  ->  {target}" for rel, kind, target in danglers)
    )
