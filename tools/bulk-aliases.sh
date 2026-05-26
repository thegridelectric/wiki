#!/usr/bin/env bash
# bulk-aliases.sh — sourceable from ~/.bash_profile (or ~/.zshrc) to give
# the user one-word commands for silencing the cluster-coherence + bulk
# hooks during legitimate bulk-changes bursts.
#
# Setup (in your shell rc):
#   . /path/to/GridWorks/wiki/tools/bulk-aliases.sh
#
# Override is SESSION-SPECIFIC by default. Each Claude session has a
# friendly name (e.g. `bright-frost`); session-start surfaces it. The
# override file at ~/.claude/.bulk-stop-override.<name> silences only
# that session's hooks. A global override at ~/.claude/.bulk-stop-override
# (no suffix) silences ALL sessions — use sparingly.
#
# Claude MUST NOT create these files. They are user-controlled signals.

bulk-on() {
  local name="$1"
  if [ -z "$name" ]; then
    cat <<USAGE
Usage:
  bulk-on <session-name>     # silence one session (e.g. bulk-on bright-frost)
  bulk-on --global           # silence ALL sessions (rare; use sparingly)

Active sessions (from ~/.claude/.session-by-id):
USAGE
    ls -1 ~/.claude/.session-by-id 2>/dev/null | while read -r sid; do
      name=$(cat "$HOME/.claude/.session-by-id/$sid" 2>/dev/null)
      printf "  %s  (id %s)\n" "$name" "${sid:0:6}"
    done
    return 1
  fi
  if [ "$name" = "--global" ]; then
    touch "$HOME/.claude/.bulk-stop-override"
    echo "bulk-mode override ON  (GLOBAL — all sessions silenced)"
  else
    mkdir -p "$HOME/.claude"
    touch "$HOME/.claude/.bulk-stop-override.$name"
    echo "bulk-mode override ON  (session: $name)"
  fi
}

bulk-off() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Usage:"
    echo "  bulk-off <session-name>     # un-silence one session"
    echo "  bulk-off --global           # remove the global override"
    echo "  bulk-off --all              # remove every override (per-session + global)"
    return 1
  fi
  case "$name" in
    --global)
      rm -f "$HOME/.claude/.bulk-stop-override"
      echo "bulk-mode override OFF (global removed)"
      ;;
    --all)
      rm -f "$HOME/.claude/.bulk-stop-override"
      find "$HOME/.claude" -maxdepth 1 -name ".bulk-stop-override.*" -delete 2>/dev/null
      echo "bulk-mode override OFF for all sessions + global"
      ;;
    *)
      rm -f "$HOME/.claude/.bulk-stop-override.$name"
      echo "bulk-mode override OFF (session: $name)"
      ;;
  esac
}

bulk-status() {
  local count=0
  echo "Per-session overrides currently ON:"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    name=$(basename "$f" | sed 's/^\.bulk-stop-override\.//')
    echo "  - $name"
    count=$((count + 1))
  done < <(find "$HOME/.claude" -maxdepth 1 -name ".bulk-stop-override.*" 2>/dev/null)
  [ "$count" = "0" ] && echo "  (none)"
  if [ -f "$HOME/.claude/.bulk-stop-override" ]; then
    echo
    echo "Global override: ON  (silences ALL sessions, including new ones)"
  fi
}
