#!/usr/bin/env bash
# scada.sh — wrapper: session.sh scada [--include-sema] [claude args...]
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/session.sh" scada "$@"
