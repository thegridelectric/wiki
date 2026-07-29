#!/bin/bash
# sessionstart-dep-staleness.sh — ADVISORY: flag GridWorks package pins that
# trail the latest published release. Never blocks, never edits — staying
# behind must be a decision, not unnoticed drift. Silence a deliberate pin
# by putting the phrase "pinned deliberately" in a comment on the dep's
# line in pyproject.toml.
#
# Register under SessionStart in .claude/settings.json.

UMBRELLA="/Users/jessica/GridWorks"

python3 - <<'PYEOF' 2>/dev/null
import json, pathlib, re, urllib.request

umbrella = pathlib.Path("/Users/jessica/GridWorks")
latest_cache: dict[str, str | None] = {}


def latest(pkg: str) -> str | None:
    if pkg not in latest_cache:
        try:
            with urllib.request.urlopen(
                f"https://pypi.org/pypi/{pkg}/json", timeout=3
            ) as r:
                latest_cache[pkg] = json.load(r)["info"]["version"]
        except Exception:
            latest_cache[pkg] = None
    return latest_cache[pkg]


def vtuple(v: str):
    return tuple(int(x) for x in re.findall(r"\d+", v)[:3])


notes = []
for py in sorted(umbrella.glob("*/pyproject.toml")):
    text = py.read_text()
    for line in text.splitlines():
        m = re.search(r'"(gridworks[a-z-]*)\s*>=\s*([0-9.]+)', line)
        if not m or "pinned deliberately" in line:
            continue
        pkg, floor = m.group(1), m.group(2)
        cur = latest(pkg)
        if cur and vtuple(cur)[:2] > vtuple(floor)[:2]:
            notes.append(
                f"{py.parent.name}: pins {pkg}>={floor}; latest is {cur} — "
                "consider whether this session should include the upgrade "
                "(faithful pins are fine; mark the line 'pinned deliberately' "
                "to silence)."
            )

if notes:
    print("GridWorks dependency staleness (advisory):")
    for n in notes:
        print(f"  - {n}")
PYEOF
exit 0
