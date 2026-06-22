#!/bin/bash
# precheck-design-bijection.sh — enforce the design ↔ Linear-issue bijection
# from designs/linear-integration.md "Naming + bijection".
#
# A design root (flat `.../designs/<slug>.md` or fractal hub
# `.../designs/<slug>/primary.md`) maps 1:1 to a `design`-labeled Linear
# issue whose title PROJECTS to the slug (lowercase → non-alphanumeric runs →
# single hyphen → strip ends; the canonical `_slugify` in
# tests/test_doc_health.py). Spokes (`.../designs/<slug>/<other>.md`) are NOT
# roots — they share the hub's issue.
#
# Two modes, by hook event:
#   - UserPromptSubmit  → sweep every design root, emit advisory context.
#   - PreToolUse (Edit/Write/NotebookEdit on wiki/**/designs/**) → catch a
#     mis-named / colliding NEW design file at write-time (permissionDecision
#     "ask").
#
# Two depths, by environment:
#   - WIKI-SIDE (always): slug well-formedness, slug collisions, and the
#     Accepted/Verified-needs-a-Linear-id rule (mirrors the pytest check, but
#     live).
#   - LINEAR-SIDE (only when $LINEAR_API_KEY is set): query `design`-labeled
#     issues and flag (a) a wiki slug with no issue, (b) a `design` issue with
#     no wiki slug, (c) a Status-line id whose issue title doesn't project to
#     the slug. The MCP is Claude-facing (not shell-callable), so the shell
#     path uses the Linear GraphQL API directly via a token.
#
# Override: ~/.claude/.bulk-stop-override(.<session>) silences this hook.
# Claude MUST NOT create that file; the user does via `bulk-on`.

set -e

UMBRELLA=/Users/jessica/GridWorks
WIKI="$UMBRELLA/wiki"

input=$(cat)

# --- session-aware bulk override (per-session, then global) ----------------
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

[ -d "$WIKI/.git" ] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

event=$(echo "$input" | jq -r '.hook_event_name // ""')

# Canonical slug projection — matches tests/test_doc_health.py::_slugify.
slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

# The doc's Status-stamp line, tolerating a `> ` blockquote prefix and leading
# indentation — mirrors tests/test_doc_health.py::_stamp_line (it strips a
# leading run of `>`, space, tab, then matches `Status:`). Echoes the original
# line (framing intact) so callers can grep its content; empty if none. A bare
# `grep '^Status:'` would silently skip a blockquoted stamp and miss the
# Accepted-missing-id check the pytest catches.
stamp_line() {  # $1 = file path
  awk '{ s = $0; sub(/^[> \t]+/, "", s); if (s ~ /^Status:/) { print; exit } }' \
    "$1" 2>/dev/null
}

# Emit every design root as "slug<TAB>relpath". A root is a flat
# `designs/<slug>.md` or a fractal `designs/<slug>/primary.md`.
design_roots() {
  while IFS= read -r abs; do
    [ -z "$abs" ] && continue
    rel="${abs#"$WIKI"/}"
    base="$(basename "$abs")"
    parent="$(basename "$(dirname "$abs")")"
    grand="$(basename "$(dirname "$(dirname "$abs")")")"
    if [ "$parent" = "designs" ]; then
      printf '%s\t%s\n' "${base%.md}" "$rel"
    elif [ "$base" = "primary.md" ] && [ "$grand" = "designs" ]; then
      printf '%s\t%s\n' "$parent" "$rel"
    fi
  done < <(find "$WIKI" -type f -name '*.md' -path '*/designs/*' 2>/dev/null)
}

# --- WIKI-SIDE checks (always) ---------------------------------------------
wiki_side_findings() {
  local roots malformed="" collisions="" missing_id=""
  roots="$(design_roots | sort)"
  [ -z "$roots" ] && return 0

  # (1) malformed slug — file slug must already be canonical.
  while IFS=$'\t' read -r slug rel; do
    [ -z "$slug" ] && continue
    if [ "$slug" != "$(slugify "$slug")" ]; then
      malformed="${malformed}  - $rel  (slug \"$slug\" is not canonical → \"$(slugify "$slug")\")
"
    fi
  done <<< "$roots"

  # (2) slug collisions — same slug across two+ design roots.
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    local paths
    paths="$(echo "$roots" | awk -F'\t' -v s="$slug" '$1==s{print $2}' | paste -sd', ' -)"
    collisions="${collisions}  - slug \"$slug\" used by: $paths
"
  done < <(echo "$roots" | cut -f1 | sort | uniq -d)

  # (3) Accepted/Verified root must carry a Linear id on its Status line.
  while IFS=$'\t' read -r slug rel; do
    [ -z "$slug" ] && continue
    local status
    status="$(stamp_line "$WIKI/$rel")"
    if echo "$status" | grep -qE 'Accepted|Verified'; then
      if ! echo "$status" | grep -qE 'Linear: *(OPS|GRI)-[0-9]+'; then
        missing_id="${missing_id}  - $rel  ($status)
"
      fi
    fi
  done <<< "$roots"

  local out=""
  [ -n "$malformed" ]   && out="${out}Malformed design slug(s) (not canonical — rename the file first, then the Linear title):
$malformed"
  [ -n "$collisions" ]  && out="${out}Duplicate design slug(s) — the bijection requires one slug per design:
$collisions"
  [ -n "$missing_id" ]  && out="${out}Accepted/Verified design(s) missing a Linear id on the Status line (· Linear: OPS-NNN):
$missing_id"
  printf '%s' "$out"
}

# --- LINEAR-SIDE checks (only with a token) --------------------------------
# Returns extra findings text; silent (and skipped) when $LINEAR_API_KEY unset.
linear_side_findings() {
  [ -n "${LINEAR_API_KEY:-}" ] || return 0
  command -v curl >/dev/null 2>&1 || return 0

  local q resp issues
  q='{"query":"{ issues(filter:{labels:{name:{eq:\"design\"}}}, first:250){ nodes{ identifier title } } }"}'
  resp="$(curl -s --max-time 8 -X POST https://api.linear.app/graphql \
            -H "Authorization: $LINEAR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$q" 2>/dev/null || true)"
  echo "$resp" | jq -e '.data.issues.nodes' >/dev/null 2>&1 || return 0

  # Linear slug set: project each design issue title to a slug.
  local linear_slugs roots wiki_slugs no_issue="" no_wiki=""
  linear_slugs="$(echo "$resp" | jq -r '.data.issues.nodes[] | "\(.identifier)\t\(.title)"' \
                  | while IFS=$'\t' read -r id title; do printf '%s\t%s\n' "$(slugify "$title")" "$id"; done)"
  roots="$(design_roots | sort)"
  wiki_slugs="$(echo "$roots" | cut -f1 | sort -u)"

  # (a) wiki slug with no design issue.
  while IFS= read -r slug; do
    [ -z "$slug" ] && continue
    echo "$linear_slugs" | cut -f1 | grep -qxF "$slug" || \
      no_issue="${no_issue}  - $slug  (wiki design has no \`design\`-labeled Linear issue)
"
  done <<< "$wiki_slugs"

  # (b) design issue with no wiki slug.
  while IFS=$'\t' read -r slug id; do
    [ -z "$slug" ] && continue
    echo "$wiki_slugs" | grep -qxF "$slug" || \
      no_wiki="${no_wiki}  - $id  (title projects to \"$slug\" — no matching wiki/**/designs/ file)
"
  done <<< "$linear_slugs"

  local out=""
  [ -n "$no_issue" ] && out="${out}Wiki design(s) with no Linear issue:
$no_issue"
  [ -n "$no_wiki" ]  && out="${out}\`design\`-labeled Linear issue(s) with no wiki design:
$no_wiki"
  printf '%s' "$out"
}

emit_context() {
  local body="$1"
  local msg="design ↔ Linear bijection check (designs/linear-integration.md):

$body
Resolve before relying on the cross-link. To rename a slug: edit the wiki
FILE first (it is canonical), then re-point the Linear title. See
\"Naming + bijection\"."
  jq -n --arg ctx "$msg" \
    '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
}

case "$event" in
  PreToolUse)
    # Catch a mis-named / colliding NEW design file at write-time.
    tool_name=$(echo "$input" | jq -r '.tool_name // ""')
    case "$tool_name" in Edit|Write|NotebookEdit) ;; *) exit 0 ;; esac
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
    [ -n "$file_path" ] || exit 0
    case "$file_path" in /*) abs="$file_path" ;; *) abs="$PWD/$file_path" ;; esac
    case "$abs" in *"/designs/"*.md) ;; *) exit 0 ;; esac

    base="$(basename "$abs")"; parent="$(basename "$(dirname "$abs")")"
    if [ "$parent" = "designs" ]; then slug="${base%.md}"
    elif [ "$base" = "primary.md" ]; then slug="$(basename "$(dirname "$abs")")"
    else exit 0; fi

    problem=""
    if [ "$slug" != "$(slugify "$slug")" ]; then
      problem="slug \"$slug\" is not canonical (should be \"$(slugify "$slug")\")."
    else
      # collision with an existing DIFFERENT root path?
      existing="$(design_roots | awk -F'\t' -v s="$slug" '$1==s{print $2}')"
      relnew="${abs#"$WIKI"/}"
      other="$(echo "$existing" | grep -vxF "$relnew" || true)"
      [ -n "$other" ] && problem="slug \"$slug\" already used by: $(echo "$other" | paste -sd', ' -)."
    fi
    [ -z "$problem" ] && exit 0

    reason="New/edited design file breaks the design↔Linear bijection: $problem
The slug is the canonical name and must be unique + canonical. Pick a
distinct, already-canonical slug (lowercase, hyphen-separated) before writing.
See designs/linear-integration.md \"Naming + bijection\"."
    jq -n --arg r "$reason" \
      '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
    ;;
  *)
    # UserPromptSubmit (default): full sweep, advisory.
    findings="$(wiki_side_findings)"
    findings="${findings}$(linear_side_findings)"
    [ -z "$findings" ] && exit 0
    emit_context "$findings"
    ;;
esac
