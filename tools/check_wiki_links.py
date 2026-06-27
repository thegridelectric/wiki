#!/usr/bin/env python3
"""Resolve every intra-wiki markdown link `](path)` and `[[wikilink]]` against
the filesystem and report danglers. Shared by tests/test_doc_health.py (whole
wiki) and tools/stop-dangler-check.sh (changed files only).

A "dangler" is a link whose target SHOULD resolve inside the wiki but does not.
The following are intentionally NOT danglers and are skipped:
  - external links (http(s)://, mailto:, protocol-relative, pure #anchors)
  - cross-repo / out-of-wiki links (resolve to a path outside the wiki root)
  - `wiki/`-prefixed targets (authored relative to the umbrella dir, e.g. the
    symlinked GridWorks_CLAUDE.md)
  - links immediately followed by an `(Open)` or `(TBD)` marker — the
    hub-and-spoke convention's planned-but-unwritten spokes
  - links inside inline code spans or fenced code blocks (examples/placeholders
    such as `Concern: [[this]]`)
  - targets git **ignores** (e.g. the per-session `active-claims.md`, the
    gitignored `knifes-edge-development/` private materials): present in a working
    tree but absent in a clean checkout like CI, so a missing-but-ignored target
    is a legitimate runtime/local reference, not a broken link.

Usage:
  check_wiki_links.py [WIKI_ROOT] [--changed f1.md f2.md ...] [--quiet]
Exit status is 1 when danglers are found, else 0.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

_MD_LINK = re.compile(r"\]\(([^)]+)\)")
_WIKILINK = re.compile(r"\[\[([^\]]+)\]\]")
_FENCE = re.compile(r"^```.*?^```", re.DOTALL | re.MULTILINE)
_INLINE_CODE = re.compile(r"`[^`\n]*`")
_OPEN_MARKER = re.compile(r"\s*\((Open|TBD)\)", re.IGNORECASE)


def _strip_code(text: str) -> str:
    """Blank out fenced blocks + inline code so example/placeholder links there
    are not scanned. Replace with spaces to preserve offsets for marker checks."""
    text = _FENCE.sub(lambda m: " " * len(m.group(0)), text)
    text = _INLINE_CODE.sub(lambda m: " " * len(m.group(0)), text)
    return text


def _is_external(t: str) -> bool:
    return (
        t.startswith(("http://", "https://", "mailto:", "#", "//"))
        or "://" in t
        or t.startswith("wiki/")  # umbrella-relative (symlinked top docs)
    )


def _gitignored(wiki_root: Path, rel_paths: list[str]) -> set[str]:
    """Subset of `rel_paths` that git ignores — so they may be absent in a clean
    checkout (e.g. CI) yet present in a working tree. Empty if git is
    unavailable, so behavior degrades to plain existence checking."""
    paths = [p for p in rel_paths if p]
    if not paths:
        return set()
    import subprocess

    try:
        r = subprocess.run(
            ["git", "-C", str(wiki_root), "check-ignore", "--stdin"],
            input="\n".join(paths), capture_output=True, text=True,
        )
    except Exception:
        return set()
    if r.returncode not in (0, 1):  # 0 = some ignored, 1 = none; anything else = error
        return set()
    return {ln.strip() for ln in r.stdout.splitlines() if ln.strip()}


def find_danglers(wiki_root: Path, files: list[Path] | None = None):
    """Return a sorted list of (relpath, kind, raw_target) danglers.
    `files` limits the scan to those paths (used by the changed-files hook)."""
    wiki_root = wiki_root.resolve()
    all_md = sorted(wiki_root.rglob("*.md"))
    by_stem = set()
    by_suffix = set()
    for p in all_md:
        by_stem.add(p.stem)
        rel = p.relative_to(wiki_root).as_posix()
        by_suffix.add(rel)
        by_suffix.add(rel[:-3])
    scan = [p.resolve() for p in (files or all_md)]
    danglers = []
    for p in scan:
        if not p.exists() or p.suffix != ".md":
            continue
        rel = p.relative_to(wiki_root).as_posix()
        text = _strip_code(p.read_text(encoding="utf-8", errors="replace"))
        for m in _MD_LINK.finditer(text):
            if _OPEN_MARKER.match(text, m.end()):
                continue
            target = m.group(1).strip().split("#")[0].split(" ")[0].strip()
            if not target or _is_external(target):
                continue
            dest = (p.parent / target).resolve()
            # out-of-wiki (cross-repo) → cannot verify, skip
            if wiki_root not in dest.parents and dest != wiki_root:
                continue
            if not dest.exists():
                danglers.append((rel, "md", m.group(1), dest.relative_to(wiki_root).as_posix()))
        for m in _WIKILINK.finditer(text):
            if _OPEN_MARKER.match(text, m.end()):
                continue
            target = m.group(1).split("|")[0].split("#")[0].strip()
            if not target:
                continue
            cand = (p.parent / (target if target.endswith(".md") else target + ".md")).resolve()
            if cand.exists():
                continue
            stem = Path(target).name
            stem = stem[:-3] if stem.endswith(".md") else stem
            if stem in by_stem or target in by_suffix or target.lstrip("./") in by_suffix:
                continue
            danglers.append((rel, "wiki", m.group(1), ""))
    # Missing-but-gitignored targets (active-claims.md, knifes-edge materials, …)
    # exist locally but not in a clean CI checkout — not real danglers.
    ignored = _gitignored(wiki_root, [d[3] for d in danglers if d[3]])
    danglers = [(r, k, raw) for (r, k, raw, dest_rel) in danglers if dest_rel not in ignored]
    return sorted(danglers)


def _git_show(wiki_root: Path, relpath: str) -> str:
    """HEAD content of relpath, or '' if it didn't exist at HEAD."""
    import subprocess

    try:
        return subprocess.run(
            ["git", "-C", str(wiki_root), "show", f"HEAD:{relpath}"],
            capture_output=True, text=True, check=True,
        ).stdout
    except Exception:
        return ""


def new_danglers(wiki_root: Path, files: list[Path]):
    """Danglers in `files` whose link text is NOT present in the file's HEAD
    version — i.e. links introduced this session, not pre-existing debt."""
    wiki_root = wiki_root.resolve()
    out = []
    for rel, kind, target in find_danglers(wiki_root, files):
        needle = f"]({target})" if kind == "md" else f"[[{target}]]"
        if needle not in _git_show(wiki_root, rel):
            out.append((rel, kind, target))
    return out


def _main(argv: list[str]) -> int:
    args = list(argv)
    quiet = "--quiet" in args
    if quiet:
        args.remove("--quiet")
    files = None
    new_only = False
    for flag in ("--changed", "--new-in"):
        if flag in args:
            i = args.index(flag)
            files = [Path(a) for a in args[i + 1:]]
            new_only = flag == "--new-in"
            args = args[:i]
            break
    wiki_root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
    danglers = new_danglers(wiki_root, files) if new_only else find_danglers(wiki_root, files)
    if danglers:
        if not quiet:
            label = "NEW DANGLERS" if new_only else "DANGLERS"
            print(f"{label} ({len(danglers)}):")
            for rel, kind, t in danglers:
                print(f"  [{kind}] {rel}  ->  {t}")
        return 1
    if not quiet:
        print("OK — no intra-wiki danglers")
    return 0


if __name__ == "__main__":
    raise SystemExit(_main(sys.argv[1:]))
