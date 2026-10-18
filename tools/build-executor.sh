#!/usr/bin/env bash
# build-executor.sh — wrapper: session.sh executor --include-sema [claude args...]
# An executor is a rebuild from the spec plus the vocabulary, so the sema
# protocol is always appended.
exec "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/session.sh" executor --include-sema "$@"
