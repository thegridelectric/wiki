#!/usr/bin/env bash
# PreToolUse hook (matcher: Agent) — design: design-execution-economics.md (OPS-382).
#
# Injects a NON-BLOCKING advisory nudge toward economical delegation when the
# session spawns a subagent. Two prongs: (1) scope the spawn prompt to the
# load-bearing slice; (2) check whether this is independent work that belongs
# in a Workflow fan-out / fresh lean session rather than inline.
#
# Pure advisory: it ALWAYS allows the spawn (permissionDecision "allow") and
# only ever adds context — it never asks or denies (design O6). It cannot read
# cross-spawn intent, so it never tries to "detect waste"; its value is a
# well-timed pause, fired ONCE per session on the first plausibly-broad spawn.
#
# Dampener (design O3): fire at most once per session, spending the one fire on
# the first spawn that is plausibly broad —
#   subagent_type ∈ {Explore, general-purpose, Plan}  OR
#   prompt contains a broad-scope keyword (map|all|every|comprehensive|full|entire).
# A narrow/utility spawn does NOT consume the nudge (marker set only on fire).
#
# Override: ~/.claude/.bulk-stop-override(.<session>) silences this hook.
# Claude MUST NOT create that file; the user does via `bulk-on`.
set -uo pipefail

input=$(cat 2>/dev/null || true)
command -v jq >/dev/null 2>&1 || exit 0

# Only the Agent (subagent-spawn) tool, only PreToolUse.
event=$(printf '%s' "$input" | jq -r '.hook_event_name // ""' 2>/dev/null)
tool=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null)
[ "$event" = "PreToolUse" ] || exit 0
[ "$tool" = "Agent" ] || exit 0

# Session id (stdin JSON first, then env).
sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$sid" ] && exit 0

# --- session-aware bulk override (per-session name, then global) -----------
if [ -f "$HOME/.claude/.session-by-id/$sid" ]; then
  name=$(cat "$HOME/.claude/.session-by-id/$sid" 2>/dev/null || true)
  [ -n "$name" ] && [ -f "$HOME/.claude/.bulk-stop-override.$name" ] && exit 0
fi
[ -f "$HOME/.claude/.bulk-stop-override" ] && exit 0

# Fire at most once per session.
marker="$HOME/.claude/.spawn-nudge.$sid"
[ -f "$marker" ] && exit 0

# --- relevance gate: is this a plausibly-broad spawn worth the one nudge? ---
subagent_type=$(printf '%s' "$input" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null)
prompt=$(printf '%s' "$input" | jq -r '.tool_input.prompt // ""' 2>/dev/null)

relevant=0
case "$subagent_type" in
  Explore|general-purpose|Plan) relevant=1 ;;
esac
if [ "$relevant" -eq 0 ] && \
   printf '%s' "$prompt" | grep -iwqE 'map|all|every|comprehensive|full|entire'; then
  relevant=1
fi
# Not a broad spawn → stay silent AND do not consume the nudge.
[ "$relevant" -eq 1 ] || exit 0

# Fire: claim the once-per-session marker, then inject the advisory context.
mkdir -p "$HOME/.claude" && : > "$marker"

CTX="Economical-delegation check (design-execution-economics / OPS-382) — advisory, the spawn proceeds. Before you rely on this subagent, sanity-check two things:

  1. TIGHT PROMPT — does the prompt request only the load-bearing slice, or did you ask for a broad map? Name the boundary (\"only the X↔Y path\", \"just files that do Z\") and tell the agent to return CONCLUSIONS, not file dumps. An over-broad research dump sits in your context for the rest of the session whether or not you reuse it.

  2. COUPLING — is this one of N INDEPENDENT tasks that share no state? If so, prefer a Workflow fan-out (parallel()/pipeline()) or a fresh lean session over inline sequential work — and run it from a session that does NOT already carry heavy research context. Reserve inline for tightly-coupled work that shares one mental model.

(Fires once per session, on the first broad-looking spawn. Silence the hook set via \`bulk-on\`.)"

jq -n --arg c "$CTX" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "allow", additionalContext: $c}}'
