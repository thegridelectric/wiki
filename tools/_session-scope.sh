# Sourceable: resolve the calling session's claims-table identity + scope.
#
# Usage:
#   . "$(dirname "$0")/_session-scope.sh"
#   resolve_session_scope "$SESSION_ID"
#
# Sets two variables:
#   SESSION_NAME — the friendly name from active-claims (empty if the
#                  session cannot be identified)
#   SCOPE_PATHS  — newline-separated claimed paths, trailing slashes
#                  stripped (empty if no claim row)
#
# Identification order:
#   1. The active-claims row whose hash column matches the session id's
#      first six characters — the claims table is the protocol's source
#      of truth for who a session is.
#   2. ~/.claude/.session-by-id/<id> — the SessionStart init's cache;
#      fallback only, because a continued session regenerates its
#      friendly name there while its claims row keeps the original.
#
# Hooks that nag about in-flight work should scope to SCOPE_PATHS: only
# the claiming session can disposition its clusters, so flagging them in
# other sessions is pure noise. When SESSION_NAME resolves empty, callers
# SHOULD fall back to umbrella-wide checking (unclaimed sessions stay
# protected).

resolve_session_scope() {
  local sid="$1"
  local claims="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/wiki/active-claims.md"
  SESSION_NAME=""
  SCOPE_PATHS=""
  [ -n "$sid" ] || return 0
  if [ -f "$claims" ]; then
    SESSION_NAME=$(grep -E "^\| [a-z-]+ · ${sid:0:6} " "$claims" 2>/dev/null \
      | head -1 | awk -F'[| ]+' '{print $2}')
  fi
  if [ -z "$SESSION_NAME" ] && [ -f "$HOME/.claude/.session-by-id/$sid" ]; then
    SESSION_NAME=$(cat "$HOME/.claude/.session-by-id/$sid")
  fi
  [ -n "$SESSION_NAME" ] || return 0
  local row scope_cell
  row=$(grep "^| $SESSION_NAME " "$claims" 2>/dev/null | head -1)
  [ -n "$row" ] || return 0
  scope_cell=$(echo "$row" | awk -F'|' '{print $4}')
  SCOPE_PATHS=$(echo "$scope_cell" | awk '{gsub(/<br>/, "\n"); print}' \
    | sed 's|^ *||;s| *$||;s|/$||' | grep -v '^$' || true)
}
