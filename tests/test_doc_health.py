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
    """Designs only — for the Accepted-requires-Pass>=1 check."""
    return [
        p
        for p in _md_files()
        if "designs" in p.relative_to(WIKI).parts[:-1]
        and p.name not in STAMP_EXEMPT_NAMES
    ]


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


@pytest.mark.parametrize("doc", _md_files(), ids=_rel)
def test_no_doc_exceeds_line_cap(doc: Path) -> None:
    n = sum(1 for _ in doc.open(encoding="utf-8", errors="replace"))
    assert n <= MAX_LINES, (
        f"{_rel(doc)} has {n} lines (cap {MAX_LINES}); split it into a hub + sub-specs."
    )
