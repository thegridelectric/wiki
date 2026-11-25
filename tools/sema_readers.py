#!/usr/bin/env python3
"""sema_readers.py: every repo that decodes a sema word, and what each needs
to decode a given version of it.

Usage:
    wiki/tools/sema_readers.py <type.name> <version> [--fetch] [--before <time>]

For each git repo beside the sema repo, read at its default branch on the
remote (origin/HEAD, else origin/main, origin/master, origin/dev), so the
answer is what is merged and not what a working tree happens to hold:

  - seeds: every sema_seed_request.yaml that names the word, and how it picks
    versions (include_all_versions, an explicit versions list, the bare latest
    published version), plus whether staging.allow names it;
  - vendored snapshots: the versions of the word the snapshot's generated
    classes hold (types/<word>.py and types/old_versions/<word>_NNN.py);
  - hand-kept copies: source files outside any vendored snapshot and outside
    tests that spell the word's TypeName as a literal beside Version literals
    (a zod schema, a hand-written pydantic twin), with the versions they pin.

Each repo gets an action for the version: none (it decodes it already),
regen, seed edit + regen, or hand edit. A repo that holds the word only
through another word's closure is reported too, since its regen brings the
new version in once the referring word moves to it.

`--fetch` runs `git fetch` in each repo first. `--before` reads each repo's
default branch as it stood at that time (anything `git rev-list --before`
takes), to replay an earlier wave. The version's status (staging
or published) is read from the sema registry on origin/dev, else from the sema
working tree, where a new version is authored before it is pushed. The
umbrella is this file's grandparent's parent.
"""

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple

try:
    import yaml
except ImportError:
    # The YAML parser comes from the sema repo's venv; re-run under it.
    VENV_PYTHON = Path(__file__).resolve().parents[2] / "sema" / ".venv" / "bin" / "python"
    os.execv(VENV_PYTHON, [str(VENV_PYTHON), *sys.argv])

GW = Path(__file__).resolve().parents[2]
SEED_NAME = "sema_seed_request.yaml"
SKIP_REPOS = {"sema", "wiki", "scratch", "admin", "esoteric", "legacy"}
TEST_PARTS = ("/tests/", "/test/", "/__tests__/", "/fixtures/")
VERSION_LITERAL = re.compile(r"""[Vv]ersion\W.*?['"](\d{3})['"]""")


class SeedUse(NamedTuple):
    """How one seed request names the word."""

    path: str
    mode: str  # "include_all_versions" | "versions [...]" | "latest published" | "closure only"
    vendored: bool  # a vendored snapshot sits under the seed's directory
    listed: tuple[str, ...]  # the versions an explicit list names
    allowed_staging: bool


class HandPin(NamedTuple):
    """A source file that spells the word's TypeName and pins versions."""

    path: str
    versions: tuple[str, ...]


class RepoReport(NamedTuple):
    """One repo's relation to the word and the action the version needs."""

    repo: str
    ref: str
    seeds: tuple[SeedUse, ...]
    held: tuple[str, ...]  # versions the vendored snapshots' classes hold
    hand: tuple[HandPin, ...]
    actions: tuple[str, ...]


def git(repo: Path, *args: str) -> str:
    out = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=True)
    return out.stdout if out.returncode == 0 else ""


def default_ref(repo: Path) -> str | None:
    head = git(repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD").strip()
    if head:
        return head
    for name in ("origin/main", "origin/master", "origin/dev"):
        if git(repo, "rev-parse", "--verify", "--quiet", name).strip():
            return name
    return None


def word_status(type_name: str, version: str) -> str:
    """The version's status in the sema registry on origin/dev, else in the
    sema working tree (a version authored and not yet pushed)."""
    sema = GW / "sema"
    texts = [git(sema, "show", "origin/dev:definitions/registry.yaml")]
    try:
        texts.append((sema / "definitions" / "registry.yaml").read_text())
    except OSError:
        pass
    for where, text in zip(("sema origin/dev", "sema working tree"), texts):
        if not text:
            continue
        data = yaml.safe_load(text) or {}
        for section in ("types", "enums", "formats"):
            v = ((data.get(section) or {}).get(type_name) or {}).get("versions", {}).get(version)
            if v:
                return f"{v.get('status', 'unknown')} in {where}"
    return "in neither the sema origin/dev nor the working-tree registry"


def seed_use(path: str, text: str, type_name: str, held: bool, vendored: bool) -> SeedUse | None:
    try:
        seed = yaml.safe_load(text) or {}
    except yaml.YAMLError:
        return None
    targets = seed.get("initial_targets") or {}
    allow = (seed.get("staging") or {}).get("allow") or []
    allowed = type_name in allow
    for section in ("types", "enums"):
        spec = (targets.get(section) or {}).get(type_name)
        if spec is None and type_name not in (targets.get(section) or {}):
            continue
        spec = spec or {}
        if spec.get("include_all_versions"):
            return SeedUse(path, "include_all_versions", vendored, (), allowed)
        if spec.get("versions"):
            listed = tuple(str(v) for v in spec["versions"])
            return SeedUse(path, f"versions {list(listed)}", vendored, listed, allowed)
        return SeedUse(path, "latest published", vendored, (), allowed)
    if held:
        return SeedUse(path, "closure only", vendored, (), allowed)
    return None


def scan(repo: Path, type_name: str, version: str, before: str | None) -> RepoReport | None:
    ref = default_ref(repo)
    if ref is None:
        return None
    if before:
        sha = git(repo, "rev-list", "-1", "--first-parent", f"--before={before}", ref).strip()
        if not sha:
            return None
        ref = f"{ref}@{sha[:8]}"
        files_ref = sha
    else:
        files_ref = ref
    files = git(repo, "ls-tree", "-r", "--name-only", files_ref).splitlines()
    module = type_name.replace(".", "_")
    snapshot_dirs = sorted(
        f[: -len("/indexes/versions.yaml")] for f in files if f.endswith("/indexes/versions.yaml")
    )

    held_by_dir: dict[str, set[str]] = {}
    for snap in snapshot_dirs:
        found: set[str] = set()
        latest = f"{snap}/types/{module}.py"
        if latest in files:
            m = re.search(r"""version:\s*Literal\[['"](\d{3})['"]\]""", git(repo, "show", f"{files_ref}:{latest}"))
            if m:
                found.add(m.group(1))
        old = re.compile(rf"{re.escape(snap)}/types/old_versions/{re.escape(module)}_(\d{{3}})\.py")
        found.update(m.group(1) for m in map(old.fullmatch, files) if m)
        if found:
            held_by_dir[snap] = found

    seeds: list[SeedUse] = []
    for f in files:
        if not f.endswith(SEED_NAME):
            continue
        seed_dir = f.rsplit("/", 1)[0] if "/" in f else ""
        held_here = any(s.startswith(seed_dir) for s in held_by_dir)
        vendored = any(s.startswith(seed_dir) for s in snapshot_dirs)
        use = seed_use(f, git(repo, "show", f"{files_ref}:{f}"), type_name, held_here, vendored)
        if use:
            seeds.append(use)

    hand: list[HandPin] = []
    literal = re.escape(type_name)
    grep = git(repo, "grep", "-l", "-E", f"""['"]{literal}['"]""", files_ref, "--", "*.py", "*.ts", "*.tsx")
    for line in grep.splitlines():
        path = line.split(":", 1)[1] if ":" in line else line
        if any(path.startswith(s + "/") for s in snapshot_dirs) or any(p in f"/{path}" for p in TEST_PARTS):
            continue
        lines = git(repo, "show", f"{files_ref}:{path}").splitlines()
        named = re.compile(rf"""(TypeName|type_name)\W.*['"]{literal}['"]""")
        pins: set[str] = set()
        for i, text in enumerate(lines):
            if named.search(text):
                # The word's own Version literal sits beside its TypeName; a
                # file may pin other words' versions further away.
                for near in lines[max(0, i - 2) : i + 4]:
                    pins.update(VERSION_LITERAL.findall(near))
        if pins:
            hand.append(HandPin(path, tuple(sorted(pins))))

    held = tuple(sorted(set().union(*held_by_dir.values()))) if held_by_dir else ()
    if not seeds and not hand and not held:
        return None

    actions: list[str] = []
    for s in seeds:
        if not s.vendored or (version in held and s.mode != "closure only"):
            continue
        if s.listed and version not in s.listed:
            actions.append(f"seed edit: add {version} to {s.path}, then regen")
        elif s.mode == "closure only":
            if version not in held:
                actions.append(f"regen once the word that refers to it moves to {version} ({s.path})")
        elif version not in held:
            actions.append(f"regen ({s.path})")
    pinned = sorted({v for h in hand for v in h.versions})
    if hand and version not in pinned:
        newest = max(hand, key=lambda h: max(h.versions))
        actions.append(f"hand edit: no hand-kept file pins {version}; the newest is {newest.path} at {max(newest.versions)}")
    return RepoReport(repo.name, ref, tuple(seeds), held, tuple(hand), tuple(dict.fromkeys(actions)) or ("none",))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("type_name")
    parser.add_argument("version")
    parser.add_argument("--fetch", action="store_true", help="git fetch each repo first")
    parser.add_argument("--before", help="read each default branch as it stood at this time")
    args = parser.parse_args()
    if not re.fullmatch(r"\d{3}", args.version):
        parser.error("version is three digits, e.g. 005")

    repos = sorted(
        p for p in GW.iterdir() if p.is_dir() and p.name not in SKIP_REPOS and (p / ".git").exists()
    )
    if args.fetch:
        for repo in repos:
            git(repo, "fetch", "-q", "origin")

    status = word_status(args.type_name, args.version)
    reports = [r for r in (scan(repo, args.type_name, args.version, args.before) for repo in repos) if r]
    print(f"{args.type_name} {args.version} ({status}): {len(reports)} repos read it, at each default branch")
    if status == "staging":
        print("  staging: a consumer holds it only where its seed names it in staging.allow, and main refuses it")
    for r in reports:
        print(f"\n{r.repo} ({r.ref}): holds {', '.join(r.held) or 'none'}")
        for s in r.seeds:
            allow = ", in staging.allow" if s.allowed_staging else ""
            unused = "" if s.vendored else " (no vendored snapshot beside it)"
            print(f"  seed {s.path}: {s.mode}{allow}{unused}")
        for h in r.hand:
            print(f"  hand-kept {h.path}: pins {', '.join(h.versions)}")
        for a in r.actions:
            print(f"  -> {a}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
