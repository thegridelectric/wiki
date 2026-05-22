"""Wiki health checks — enforce the conventions in GridWorks_CLAUDE.md.

Run from the wiki root:  `uv run pytest`  (or `pytest`).

Checks:
- every `research/` and `executor/` doc carries a status stamp
  (`Status: <Draft|Accepted|Verified> · Pass <n> · Updated <date>[ · Reviewed ...]`)
- no doc exceeds the 1000-line cap (split it into a hub + sub-specs)

Each doc is its own parametrized case, so a failure names the exact file.
"""

import re
from pathlib import Path

import pytest

WIKI = Path(__file__).resolve().parent.parent

# Status-stamp line: "Status: ... Draft|Accepted|Verified ... Pass <n> ..."
STAMP_RE = re.compile(r"Status:.*\b(Draft|Accepted|Verified)\b.*\bPass\s*\d+")
MAX_LINES = 1000

# Docs under these directory names must carry a status stamp (the convention's
# scope). Top-level meta docs, changelogs, and domain-root navigation are exempt.
STAMP_SCOPE_DIRS = {"research", "executor"}


def _md_files() -> list[Path]:
    return sorted(p for p in WIKI.rglob("*.md") if ".git" not in p.parts)


def _stamp_scope() -> list[Path]:
    return [
        p
        for p in _md_files()
        if STAMP_SCOPE_DIRS & set(p.relative_to(WIKI).parts[:-1])
    ]


def _rel(p: Path) -> str:
    return str(p.relative_to(WIKI))


@pytest.mark.parametrize("doc", _stamp_scope(), ids=_rel)
def test_research_and_executor_docs_have_status_stamp(doc: Path) -> None:
    text = doc.read_text(encoding="utf-8", errors="replace")
    assert STAMP_RE.search(text), (
        f"{_rel(doc)} is missing a status stamp "
        "(Status: Draft|Accepted|Verified · Pass <n> · Updated <date>)"
    )


@pytest.mark.parametrize("doc", _md_files(), ids=_rel)
def test_no_doc_exceeds_line_cap(doc: Path) -> None:
    n = sum(1 for _ in doc.open(encoding="utf-8", errors="replace"))
    assert n <= MAX_LINES, (
        f"{_rel(doc)} has {n} lines (cap {MAX_LINES}); split it into a hub + sub-specs."
    )
