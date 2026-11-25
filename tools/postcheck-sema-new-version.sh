#!/usr/bin/env bash
# PostToolUse hook: when a session writes a sema word's version file
# (sema/definitions/types/<word>/<NNN>.yaml) or runs `sema promote <word> <NNN>`,
# run sema_readers.py for that word and version and hand the session the
# table: every repo that decodes the word and what each needs (regen, seed
# edit, hand edit). The list of repos a version change has to reach comes
# from the repos, at the moment the version is authored or promoted.
#
# Once per session per word and version. Self-locating: lives at
# <umbrella>/wiki/tools/<this-file>; the YAML parser comes from the sema venv.
set -uo pipefail
GW="$(cd "$(dirname "$0")/../.." && pwd)"
PY="$GW/sema/.venv/bin/python"
input=$(cat 2>/dev/null || true)
[ -x "$PY" ] || exit 0

tool=$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)
word="" version=""
case "$tool" in
  Write|Edit)
    path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    if [[ "$path" =~ /sema/definitions/types/([a-z0-9.]+)/([0-9]{3})\.yaml$ ]]; then
      word="${BASH_REMATCH[1]}" version="${BASH_REMATCH[2]}"
    fi
    ;;
  Bash)
    cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)
    if [[ "$cmd" =~ sema[[:space:]]+promote[[:space:]]+([a-z0-9.]+)[[:space:]]+([0-9]{3}) ]]; then
      word="${BASH_REMATCH[1]}" version="${BASH_REMATCH[2]}"
    fi
    ;;
esac
[ -n "$word" ] || exit 0

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-nosession}"
marker="$HOME/.claude/.sema-readers.$sid.$word.$version"
[ -f "$marker" ] && exit 0

report=$("$PY" "$GW/wiki/tools/sema_readers.py" "$word" "$version" 2>&1) || exit 0
mkdir -p "$HOME/.claude" && : > "$marker"
CTX="A version of a sema word was written or promoted: ${word} ${version}. Every repo that decodes the word, read at its default branch by wiki/tools/sema_readers.py, and what each needs to decode ${version}:

${report}

Every repo with an action other than none is part of this change: plan, branch and merge it with the senders, and deploy the journal before any sender emits ${version}. Re-run \`sema/.venv/bin/python wiki/tools/sema_readers.py ${word} ${version} --fetch\` to check progress. (This fires once per session for each word and version.)"
jq -n --arg c "$CTX" '{hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $c}}'
