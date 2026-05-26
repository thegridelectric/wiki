#!/bin/bash
# PreToolUse hook on Edit / Write: if the target file is in a CODE
# REPO (not wiki), require a pending changelog entry
# (`<!-- pending commit -->`) in the matching
# wiki/<domain>/changelog.md before the edit can proceed.
#
# The pending entry IS the topic declaration for the work about to
# happen. Forcing it up-front means every code-repo commit has a
# named cluster from the first keystroke.
#
# Wiki edits are always allowed (wiki changes are not cluster-checked).
#
# Override: ~/.claude/.bulk-stop-override silences this hook too.
# Use `bulk-on` (see wiki/tools/bulk-aliases.sh) to enable.

set -e

UMBRELLA=/Users/jessica/GridWorks

input=$(cat)

# Session-aware override check. Per-session takes precedence; global is
# a rare "silence everything" fallback.
SESSION_ID=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null || true)
SESSION_NAME=""
if [ -n "$SESSION_ID" ] && [ -f "$HOME/.claude/.session-by-id/$SESSION_ID" ]; then
  SESSION_NAME=$(cat "$HOME/.claude/.session-by-id/$SESSION_ID")
fi
if [ -n "$SESSION_NAME" ] && [ -f "$HOME/.claude/.bulk-stop-override.$SESSION_NAME" ]; then
  exit 0
fi
if [ -f "$HOME/.claude/.bulk-stop-override" ]; then
  exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
case "$tool_name" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
[ -n "$file_path" ] || exit 0

# Convert to absolute path under the umbrella for clean matching.
case "$file_path" in
  /*) abs="$file_path" ;;
  *)  abs="$PWD/$file_path" ;;
esac

# Wiki edits: always allowed.
case "$abs" in
  "$UMBRELLA/wiki/"*) exit 0 ;;
esac

# Map the absolute path to one of the known code repos.
# shellcheck source=_repo-domain-pairs.sh
. "$UMBRELLA/wiki/tools/_repo-domain-pairs.sh"

matched_repo=""
matched_domain=""
for pair in $REPO_DOMAIN_PAIRS; do
  [ -z "$pair" ] && continue
  repo="${pair%%:*}"
  domain="${pair##*:}"
  case "$abs" in
    "$UMBRELLA/$repo/"*)
      matched_repo="$repo"
      matched_domain="$domain"
      break
      ;;
  esac
done

# Not in any known code repo → silent (e.g. starter-scripts, tlayouts,
# anything outside the cluster-checked set).
[ -n "$matched_repo" ] || exit 0

changelog="$UMBRELLA/wiki/$matched_domain/changelog.md"
if [ -f "$changelog" ] && grep -q "pending commit" "$changelog" 2>/dev/null; then
  exit 0
fi

reason="No pending changelog entry for code-repo edit.

Repo:    $matched_repo
Target:  $file_path
Changelog: wiki/$matched_domain/changelog.md (missing \`<!-- pending commit -->\`)

Per umbrella CLAUDE.md \"Working-tree hygiene\": every code-repo commit
SHALL be preceded by a pending changelog entry that declares the
topic. The entry IS the cluster declaration.

Before this edit can proceed, EITHER:
- Add a \`<!-- pending commit -->\` entry to wiki/$matched_domain/changelog.md
  naming the topic (one-line title + why paragraph), OR
- Enable bulk-mode override via \`bulk-on\` (in your own terminal;
  Claude MUST NOT create the override file)."

jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
