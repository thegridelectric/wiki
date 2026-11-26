#!/usr/bin/env bash
# UserPromptSubmit hook, ADVISORY and TEMPORARY: for every code repo in THIS
# session's active-claims Scope that vendors a sema snapshot, check that the
# repo's CI runs the snapshot's staging check. The posture is:
#
#   1. the snapshot ships check_staging.py (a regen from current sema adds it);
#   2. ci.sh runs it against the committed seed;
#   3. a GitHub workflow, where the repo has any, runs ci.sh or the check.
#
# Silent when every claimed repo passes. Speaks once per distinct set of
# findings per session, so a Scope change or a fix is heard and a standing
# gap is not repeated on every prompt. Never blocks, never edits.
#
# Retire it when the fleet of consumers has converged: delete this file and
# its entry under UserPromptSubmit in .claude/settings.json.
#
# Self-locating: lives at <umbrella>/wiki/tools/<this-file>.
# GW_ACTIVE_CLAIMS overrides the active-claims path (tests).
set -uo pipefail

GW="$(cd "$(dirname "$0")/../.." && pwd)"
ACTIVE_CLAIMS="${GW_ACTIVE_CLAIMS:-$GW/wiki/active-claims.md}"

input=$(cat 2>/dev/null || true)

sid=$(printf '%s' "$input" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$sid" ] && sid="${CLAUDE_CODE_SESSION_ID:-}"
[ -z "$sid" ] && exit 0
hash="${sid:0:6}"

[ -f "$ACTIVE_CLAIMS" ] || exit 0
row=$(grep -F "· ${hash} |" "$ACTIVE_CLAIMS" 2>/dev/null | head -1)
[ -z "$row" ] && exit 0
scope=$(printf '%s' "$row" | awk -F'|' '{print $4}')

# Repos excused for now, each with its reason. Remove a name to check it.
#   experiments: a lab that no box deploys from; its snapshots allow staging
#                words on purpose and it has no CI gate.
#   tlayouts:    has no ci.sh at all; the staging check goes in with its
#                first CI gate.
EXCUSED="experiments tlayouts"

# Claimed code repos: Scope entries one directory deep that are git repos.
# The sema repo is the snapshot's source, and the wiki has no snapshot.
repos=$(printf '%s' "$scope" | sed 's/<br>/\n/g' | tr -d ' `' \
  | grep -E '^[A-Za-z0-9._-]+/?$' | sed 's|/$||' | sort -u)

findings=""
for repo in $repos; do
  case "$repo" in sema|wiki) continue ;; esac
  case " $EXCUSED " in *" $repo "*) continue ;; esac
  [ -d "$GW/$repo/.git" ] || continue

  snapshots=$(find "$GW/$repo" -maxdepth 7 \
    \( -name .venv -o -name venv -o -name node_modules -o -name .git -o -name output \) -prune \
    -o -type f -path '*/sema/indexes/versions.yaml' -print 2>/dev/null \
    | sed 's|/indexes/versions.yaml$||')
  [ -z "$snapshots" ] && continue

  for snap in $snapshots; do
    rel="${snap#"$GW/$repo/"}"
    if [ ! -f "$snap/check_staging.py" ]; then
      findings+="  - $repo: $rel has no check_staging.py; regenerate the snapshot from current sema, then wire the check into ci.sh."$'\n'
      continue
    fi
    if [ ! -f "$GW/$repo/ci.sh" ]; then
      findings+="  - $repo: no ci.sh, so nothing runs $rel/check_staging.py."$'\n'
      continue
    fi
    if ! grep -q 'check_staging\.py' "$GW/$repo/ci.sh"; then
      findings+="  - $repo: ci.sh does not run $rel/check_staging.py."$'\n'
    fi
  done

  workflows=$(find "$GW/$repo/.github/workflows" -maxdepth 1 -type f \
    \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null)
  if [ -f "$GW/$repo/ci.sh" ] && [ -n "$workflows" ]; then
    if ! printf '%s\n' "$workflows" | xargs grep -qE 'ci\.sh|check_staging\.py'; then
      findings+="  - $repo: no GitHub workflow runs ci.sh or check_staging.py."$'\n'
    fi
  fi
done

# Once per distinct findings per session; a clean state clears the marker so
# a later regression is heard.
marker="$HOME/.claude/.staging-check-posture.$sid"
if [ -z "$findings" ]; then
  rm -f "$marker"
  exit 0
fi
digest=$(printf '%s' "$findings" | shasum | awk '{print $1}')
[ -f "$marker" ] && [ "$(cat "$marker")" = "$digest" ] && exit 0
mkdir -p "$HOME/.claude" && printf '%s' "$digest" > "$marker"

CTX="Sema staging-check posture (advisory): a repo in your active-claims Scope vendors a sema snapshot whose staging check CI does not run.

${findings}
The posture, as gridworks-flo and gridworks-journalkeeper have it: a ci.sh step after pyright,

  step \"sema snapshot staging check\" uv run python -P \\
    <vendor-dir>/check_staging.py <committed seed> --deploy-branch main

and a workflow that runs ci.sh (or the same step). A seed needs a \`staging: allow: [...]\` block only when it allows a staging word. Tell the user about the gap and ask whether to close it in this session; do not fold it into other work unasked."

jq -n --arg c "$CTX" \
  '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $c}}'
