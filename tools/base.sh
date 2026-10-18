#!/usr/bin/env bash
# base.sh — wrapper: session.sh base [--include-sema] [claude args...]
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/session.sh" base "$@"
