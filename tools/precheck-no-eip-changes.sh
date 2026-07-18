#!/bin/bash
# PreToolUse hook on Bash: hard-DENY any elastic-IP mutation by Claude.
# Re-associating an EIP is a production traffic cutover — the user's
# exclusive purview (established 2026-07-18 during the rabbit 4.x
# blue/green flip; memory `feedback_user_runs_traffic_cutovers`).
# Claude prepares the exact command and observes; the user runs it.
#
# Matches the AWS CLI EIP mutations wherever they appear in a command:
# - `aws ec2 associate-address ...`
# - `aws ec2 disassociate-address ...`
# - `aws ec2 release-address ...`
# (read-only `describe-addresses` and allocation of a NEW address are
# not blocked; only operations that move or destroy live addressing.)
#
# No override file — same posture as precheck-no-claude-commits.sh:
# if an exception is ever wanted, the user disables the hook locally.

set -e

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // ""')

if echo "$command" | grep -Eq '(associate-address|disassociate-address|release-address)'; then
  reason="Claude is hard-blocked from elastic-IP mutations — moving an EIP is
a production traffic cutover, and cutovers are the user's exclusive
purview (memory \`feedback_user_runs_traffic_cutovers\`).

Planned command:
  $command

What to do instead:
- Hand the user the exact command to run and stand by to observe
  and verify the result."

  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
fi

exit 0
