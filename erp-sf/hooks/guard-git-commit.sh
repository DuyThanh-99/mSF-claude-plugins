#!/usr/bin/env bash
# PreToolUse(Bash): commits, amends and pushes are the user's to trigger, so ask first.
# Matches git by any path (/usr/bin/git), after any global options (-C dir, -c k=v,
# --no-pager, --git-dir=x, --work-tree x), and inside bash -c "..." / sh -c '...'.
set -u
export PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

input=$(cat)
if command -v jq >/dev/null 2>&1; then
  cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
else
  cmd=$input   # no jq: match on the raw JSON text, which errs toward asking
fi
[[ -z "$cmd" ]] && exit 0

re='(^|[;&|(`"'"'"'[:space:]])([^[:space:];&|()`"'"'"']*/)?git([[:space:]]+-{1,2}[^[:space:]]+([[:space:]]+[^-[:space:];&|][^[:space:];&|]*)?)*[[:space:]]+(commit|push)([[:space:];&|)"'"'"'`]|$)'
if [[ "$cmd" =~ $re ]]; then
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"erp-sf guard: git %s runs only when you asked for it in this conversation. Approve only if you did."}}\n' "${BASH_REMATCH[5]}"
fi
exit 0
