#!/bin/bash
# Stop hook: the gwsproto package carries a vendored copy of the tlayouts
# sema snapshot registry (the layout-word closure), and its conformance
# sweep checks every closure word has a gwsproto twin. The copy is only
# useful while it matches the snapshot, so at the end of each turn compare
# the two byte for byte and block when they differ.
#
# Scope-aware: only fires for a session whose Scope claims tlayouts/ or
# gridworks-scada/ (an unidentified session checks unconditionally).
# Override: ~/.claude/.bulk-stop-override(.<session>) silences it.

set -e

UMBRELLA=/Users/jessica/GridWorks
SNAPSHOT="$UMBRELLA/tlayouts/src/tlayouts/sema/definitions/registry.yaml"
VENDORED="$UMBRELLA/gridworks-scada/packages/gridworks-scada-protocol/sema_closure/registry.yaml"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)
# shellcheck source=_session-scope.sh
. "$UMBRELLA/wiki/tools/_session-scope.sh"
resolve_session_scope "$SESSION_ID"
if [ -n "$SESSION_NAME" ] && [ -f "$HOME/.claude/.bulk-stop-override.$SESSION_NAME" ]; then
  exit 0
fi
if [ -f "$HOME/.claude/.bulk-stop-override" ]; then
  exit 0
fi
if [ -n "$SCOPE_PATHS" ] && ! echo "$SCOPE_PATHS" | grep -qxE "tlayouts|gridworks-scada"; then
  exit 0
fi

[ -f "$SNAPSHOT" ] || exit 0
if [ -f "$VENDORED" ] && cmp -s "$SNAPSHOT" "$VENDORED"; then
  exit 0
fi

reason="Snapshot-closure sync (Stop hook): the gwsproto vendored copy of the
tlayouts snapshot registry differs from the snapshot.

  snapshot: tlayouts/src/tlayouts/sema/definitions/registry.yaml
  vendored: gridworks-scada/packages/gridworks-scada-protocol/sema_closure/registry.yaml

Per GridWorks_CLAUDE.md \"Engineering maxims\" (layout closure mirrored in
gwsproto): whenever the tlayouts snapshot regenerates, refresh the copy
in the same wave and run the scada conformance test, which names every
closure word still missing a gwsproto twin:

  cp tlayouts/src/tlayouts/sema/definitions/registry.yaml \\
     gridworks-scada/packages/gridworks-scada-protocol/sema_closure/registry.yaml
  (cd gridworks-scada && gw_spaceheat/venv/bin/python -m pytest \\
     tests/named_types/test_gwsproto_sema_conformance.py -q)

Surface this to the user; do the refresh in the scada cluster that
carries the new mirrors."

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
