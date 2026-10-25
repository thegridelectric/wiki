#!/usr/bin/env bash
# backend.sh — wrapper: session.sh backend [--include-sema] [claude args...]
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/session.sh" backend "$@"
