#!/usr/bin/env bash
# GridWorks SessionStart hook  (committed in the wiki repo, version-controlled).
#
# This script is **self-locating** — it derives the umbrella directory from its
# own path (it lives at <umbrella>/wiki/tools/gridworks-session-init.sh). So any
# collaborator who clones the wiki into their own GridWorks umbrella can wire it
# in with no per-user customization.
#
# What it does:
#  - Launched in a GridWorks SUB-repo: warn to relaunch from the umbrella.
#  - Launched in the UMBRELLA: generate a friendly name + first-6 session hash;
#    append a starter row to wiki/active-claims.md (cols: Session · Focus ·
#    Scope · Since); surface name to user (systemMessage) and identity + "ask
#    user for Focus on first response" + drift-watch + any STALE rows (>2 days)
#    to Claude (additionalContext).
#  - Otherwise: silent (not a GridWorks session).
#
# Setup (see wiki/README.md "Setup" → "SessionStart hook"):
#   Add to ~/.claude/settings.json:
#     "hooks": { "SessionStart": [{ "hooks": [{
#       "type": "command",
#       "command": "<your-umbrella>/wiki/tools/gridworks-session-init.sh",
#       "statusMessage": "GridWorks session init"
#     }]}]}
#
# GW_ACTIVE_CLAIMS env var overrides the active-claims path (used by tests).
set -uo pipefail

# Self-locate the umbrella: script lives at <GW>/wiki/tools/<this-file>.
GW="$(cd "$(dirname "$0")/../.." && pwd)"
ACTIVE_CLAIMS="${GW_ACTIVE_CLAIMS:-$GW/wiki/active-claims.md}"

cwd=$(jq -r '.cwd // empty' 2>/dev/null); [ -z "$cwd" ] && cwd="$PWD"

case "$cwd" in
  "$GW")        : ;;                  # umbrella — fall through
  "$GW"/*)
    jq -n --arg d "$cwd" --arg gw "$GW" '{
      systemMessage: ("⚠️  GridWorks: launched in sub-repo \($d). Quit and relaunch from \($gw) for cross-repo work, project memory, and active-claims coordination."),
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: ("Session launched in GridWorks sub-repo \($d) instead of the umbrella \($gw). Remind the user to relaunch.")
      }
    }'
    exit 0 ;;
  *) exit 0 ;;                        # outside GridWorks — silent
esac

# Umbrella case. Generate name, hash, today's date.
ADJ=(awkward bold breezy brisk bright calm clever cosmic crisp curious dapper deft eager elegant fancy fierce fluffy frosty gentle gleaming graceful gruff happy hardy hidden honest jolly keen lively lucid lush mellow merry mighty misty modest noisy nosy patient peppy plucky polished prickly quick quiet rapid restless rosy rugged sassy savvy serene shaggy sharp shiny silent silly snappy sneaky snug sparkling speedy spirited spry stalwart steady steely stoic stormy subtle sunny sweet swift tame tangy thirsty thrifty tidy tiny tireless tranquil trusty unruly upbeat valiant vigilant vivid warm weary whimsical wild winsome witty wooly wry zesty)
NOUN=(acorn anvil arrow badger banjo basil beacon beaver bison bramble briar brick bundle cactus capon cedar cinder clover comet copper cricket dahlia dandelion drift ember falcon fennel ferret finch flagon flame frost gable garnet gem ginger glade glimmer goose granite gull harbor harvest hawthorn heron hickory horizon iris jasper kettle kit lantern larch lichen linnet lobster lupin marble marlin meadow mink mistral moss nectar nimbus oak orchid otter owl panda parchment pebble penguin pickle piper plover plum quail quartz quill rabbit raccoon raven reed ridge robin rosemary sage salmon sapling shale sparrow spruce squirrel stork talon tern thistle thorn thrush tulip vale violet warbler willow wisteria wolf wren yarrow yew)

NAME="${ADJ[$RANDOM % ${#ADJ[@]}]}-${NOUN[$RANDOM % ${#NOUN[@]}]}"
HASH="${CLAUDE_CODE_SESSION_ID:0:6}"
[ -z "$HASH" ] && HASH="(no-id)"
TODAY=$(date +%Y-%m-%d)

# Bootstrap active-claims.md from the committed template (single source of
# truth for the protocol bullets). The template lives next to the hook in the
# wiki repo, so this works for any collaborator who clones the wiki.
TEMPLATE="$GW/wiki/active-claims-template.md"
if [ ! -f "$ACTIVE_CLAIMS" ] || ! grep -q '^| Session ' "$ACTIVE_CLAIMS"; then
  mkdir -p "$(dirname "$ACTIVE_CLAIMS")"
  cp "$TEMPLATE" "$ACTIVE_CLAIMS"
fi

# Stale-row detection (Since older than 2 days ago) — BEFORE appending mine.
THRESHOLD=$(date -v-2d +%Y-%m-%d 2>/dev/null || date -d '2 days ago' +%Y-%m-%d 2>/dev/null)
STALE=""
if [ -n "$THRESHOLD" ]; then
  STALE=$(awk -v T="$THRESHOLD" '
    /^\|---/ { next }
    /^\| *[A-Za-z]/ {
      if (match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) {
        d = substr($0, RSTART, RLENGTH)
        if (d < T) print $0
      }
    }' "$ACTIVE_CLAIMS")
fi

# Insert the starter row at the END of the table (right after the last line
# starting with "|"). This keeps the row inside the table and preserves the
# blank line that separates the table from the "## Protocol" section.
ROW=$(printf '| %s · %s | _(Claude: ask for Focus)_ | _(set scope)_ | %s |' \
  "$NAME" "$HASH" "$TODAY")
awk -v r="$ROW" '
  { lines[NR] = $0 }
  /^\|/      { last = NR }
  END {
    for (i = 1; i <= NR; i++) {
      print lines[i]
      if (i == last) print r
    }
    if (!last) print r
  }
' "$ACTIVE_CLAIMS" > "$ACTIVE_CLAIMS.tmp" && mv "$ACTIVE_CLAIMS.tmp" "$ACTIVE_CLAIMS"

# Record session_id → friendly_name so other hooks can derive their
# session name for per-session features (e.g., the bulk-stop override
# at ~/.claude/.bulk-stop-override.<name>).
if [ -n "$CLAUDE_CODE_SESSION_ID" ]; then
  mkdir -p "$HOME/.claude/.session-by-id"
  echo "$NAME" > "$HOME/.claude/.session-by-id/$CLAUDE_CODE_SESSION_ID"
fi

# Build additionalContext for Claude.
CTX="You are session ${NAME} (hash ${HASH}). Your starter row was inserted into wiki/active-claims.md.

**Read wiki/active-claims.md now** for the full multi-session protocol (it lives below the table in that file). The key first-turn action: **ASK the user for the session Focus** — a 1-line statement of intent (e.g., \"Decouple Sema from Transport\") — and fill the Focus column."

if [ -n "$STALE" ]; then
  CTX+="

**Stale rows in active-claims.md (Since > 2 days old — may be closed sessions):**
${STALE}

Ask the user whether any of these sessions have ended; if so, remove their rows."
fi

jq -n --arg n "$NAME" --arg h "$HASH" --arg c "$CTX" '{
  systemMessage: ("Session: " + $n + "  ·  " + $h + "  — Claude will ask for your Focus."),
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $c
  }
}'
