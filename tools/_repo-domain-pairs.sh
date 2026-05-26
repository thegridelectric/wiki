# Sourceable: REPO_DOMAIN_PAIRS — code-repo dir name : wiki domain dir name.
#
# Hooks that need to map a sibling code repo to its matching
# wiki/<domain>/changelog.md should source this file rather than
# duplicating the list.
#
# Usage:
#   . "$(dirname "$0")/_repo-domain-pairs.sh"
#   for pair in $REPO_DOMAIN_PAIRS; do
#     repo="${pair%%:*}"
#     domain="${pair##*:}"
#     ...
#   done
#
# Add new pairs here as code repos gain a matching wiki domain.

REPO_DOMAIN_PAIRS="
sema:sema
gridworks-base:gridworks-base
gridworks-data:gridworks-data
gridworks-journalkeeper:gridworks-journalkeeper
gridworks-weather-forecast:gridworks-weather-forecast
gridworks-scada:gridworks-scada
gridworks-fleet-index-service:gridworks-fleet-index-service
gridworks-ear:ear
"
