#!/bin/bash
# precheck-sema-aligned.sh — PreToolUse (Edit|Write) advisory. When a
# .py file is edited in a sema-consuming repo, inject the sema-aligned
# coding maxim once per day per repo (GridWorks_CLAUDE.md "Sema is
# mandatory at every durable-data and inter-app boundary").
#
# A repo counts as sema-consuming when it carries a vendored snapshot
# (src/*/sema) — plus gridworks-scada by name: gwsproto speaks sema
# without a vendored snapshot, and the discipline applies there in full.

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$FILE" in
  *.py) ;;
  *) exit 0 ;;
esac

DIR=$(dirname "$FILE")
ROOT=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || exit 0
NAME=$(basename "$ROOT")

if ! ls "$ROOT"/src/*/sema >/dev/null 2>&1 && [ "$NAME" != "gridworks-scada" ]; then
  exit 0
fi

MARKER="${TMPDIR:-/tmp}/gw-sema-aligned-$(date +%Y%m%d)-$NAME"
[ -f "$MARKER" ] && exit 0
touch "$MARKER"

cat <<EOF
Sema-aligned coding (GridWorks_CLAUDE.md maxim) — this repo speaks sema:
- durable data and inter-app messages ride generated snapshot classes,
  never hand-built dicts
- vocabulary-shaped values take property formats (SpaceheatName,
  LeftRightDot, UTCMilliseconds...), never bare str
- dispatch with isinstance on word classes, never hasattr
- narrow every codec decode (assert isinstance(x, Word)) before use
- facts a sema record carries are read from the record, not DB columns,
  filenames, or hand-kept copies (hand-code only WITH a note naming the
  missing word)
Run the repo's ci.sh before suggesting a commit — pyright gates this.
EOF
exit 0
