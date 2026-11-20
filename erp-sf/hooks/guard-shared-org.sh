#!/usr/bin/env bash
# PreToolUse(Bash): ask before any command that writes to a Salesforce org other than a
# local scratch org (alias prefix from the local_org_prefixes option, default local_, or a
# username ending in @example.com).
# Writes: deploy/validate, delete source, package install/version create, data writes,
# anonymous Apex and Apex test runs, permission-set assignment, sandbox create/delete/refresh,
# non-GET REST calls, and repo scripts or make targets given an explicit --org / --target-org / -o.
# Every explicit target in the command must be local; a write with no target of its own is
# checked against the default org (SF_TARGET_ORG, then .sf/config.json walking up, then ~/.sf).
# Runs under macOS /bin/bash 3.2: no associative arrays, no mapfile.
set -u
export PATH="/usr/bin:/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

json_str() {  # JSON string literal without jq
  local s=$1
  s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/ }; s=${s//$'\r'/ }; s=${s//$'\t'/ }
  printf '"%s"' "$s"
}
ask() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":%s}}\n' "$(json_str "$1")"
  exit 0
}

S='(^|[^[:alnum:]_.-])'      # start-of-word guard
T='[[:space:]:]+'            # sf accepts both "project deploy start" and "project:deploy:start"
bin="${S}([^[:space:]\"'\`;|&()]*/)?(sf|sfdx)[[:space:]]+"
sf_verbs="(project${T}(deploy${T}(start|validate|quick|resume)|delete${T}source)|package${T}(install|uninstall|version${T}(create|promote))|(texei${T})?data${T}(create|update|delete|upsert|import|bulk|tree${T}import)|apex${T}run|org${T}(assign|(create|delete|refresh|resume|clone)${T}sandbox|delete${T}scratch)|community${T}publish)"
force_verbs="force:(source:(deploy|push|delete)|mdapi:deploy|package:(install|uninstall|version:create)|data:|apex:execute|apex:test:run|user:permset:assign|org:delete)"
sf_write="${bin}(${sf_verbs}|${force_verbs})"
api_call="${bin}api${T}request${T}(rest|graphql)"
api_write="(--method|-X)[=[:space:]]+[\"']?(POST|PUT|PATCH|DELETE)|mutation"
script_with_org="${S}(make[[:space:]]|(\./)?scripts/[^[:space:]]+\.(bash|sh)).*(--org|--target-org|[[:space:]]-o)[[:space:]=]"

is_write() {  # $1 = command text
  [[ "$1" =~ $sf_write ]] && return 0
  [[ "$1" =~ $api_call && "$1" =~ $api_write ]] && return 0
  [[ "$1" =~ $script_with_org ]] && return 0
  return 1
}

input=$(cat)

# Without jq the command cannot be parsed: ask whenever the raw input looks like an org write.
if ! command -v jq >/dev/null 2>&1; then
  is_write "$input" && ask "erp-sf guard: jq is not installed, so the target org cannot be checked. Install jq (brew install jq). Confirm this command does not write to a shared org."
  exit 0
fi

cmd=$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)
cwd=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null)
[[ -z "$cmd" ]] && exit 0
is_write "$cmd" || exit 0

# Package builds always use the shared Dev Hub and its quota.
if [[ "$cmd" =~ package${T}version${T}(create|promote) || "$cmd" =~ package:version:create ]]; then
  ask "erp-sf guard: package version builds run on the shared Dev Hub. Confirm this build is intended."
fi

if [[ "$cmd" =~ (SF_TARGET_ORG|SFDX_DEFAULTUSERNAME|SF_DEFAULTUSERNAME|SFDX_TARGET_ORG)= ]]; then
  ask "erp-sf guard: this command sets the target org through ${BASH_REMATCH[1]}. Confirm the target is a local scratch org."
fi

# Every explicit target flag anywhere in the command (quoted or not, = or space).
flag_re='(^|[[:space:]])(--target-org|--org|--targetusername|-o|-u)([=[:space:]]+)("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:];|&)]+)'
targets=""
rest=$cmd
while [[ "$rest" =~ $flag_re ]]; do
  v=${BASH_REMATCH[4]}
  rest=${rest#*"${BASH_REMATCH[0]}"}
  v=${v#\"}; v=${v%\"}; v=${v#\'}; v=${v%\'}
  [[ -z "$v" || "$v" == *'$'* || "$v" == *'`'* ]] && ask "erp-sf guard: the target org comes from a variable or substitution ('${BASH_REMATCH[4]}'), so it cannot be checked. Confirm it is a local scratch org."
  targets+="$v"$'\n'
done

# A write segment with no target flag of its own goes to the default org.
default_org() {
  local org=${SF_TARGET_ORG:-${SFDX_DEFAULTUSERNAME:-}} d=${cwd:-$PWD} f
  [[ -n "$org" ]] && { echo "$org"; return; }
  while [[ -n "$d" ]]; do
    f="$d/.sf/config.json"
    if [[ -f "$f" ]]; then org=$(jq -r '.["target-org"] // empty' "$f" 2>/dev/null); [[ -n "$org" ]] && { echo "$org"; return; }; fi
    [[ "$d" == / ]] && break
    d=$(dirname "$d")
  done
  f="$HOME/.sf/config.json"
  [[ -f "$f" ]] && jq -r '.["target-org"] // empty' "$f" 2>/dev/null
}
seg_flag='(^|[[:space:]])(--target-org|--org|--targetusername|-o|-u)[=[:space:]]'
needs_default=0
while IFS= read -r seg; do
  is_write "$seg" && ! [[ "$seg" =~ $seg_flag ]] && needs_default=1
done < <(awk 'BEGIN { RS = "\001" } { gsub(/&&|\|\||[;|&\n]/, "\n"); print }' <<<"$cmd")
if [[ $needs_default -eq 1 ]]; then
  d=$(default_org)
  [[ -z "$d" ]] && ask "erp-sf guard: this writes to a Salesforce org but no target org could be resolved. Confirm the target is a local scratch org."
  targets+="$d"$'\n'
fi

is_local() {
  local t=$1 username=$1 pre prefixes
  if [[ "$t" != *@* && -f "$HOME/.sfdx/alias.json" ]]; then
    username=$(jq -r --arg a "$t" '.orgs[$a] // empty' "$HOME/.sfdx/alias.json" 2>/dev/null)
  fi
  [[ "$username" == *@example.com ]] && return 0
  IFS=',' read -r -a prefixes <<<"${CLAUDE_PLUGIN_OPTION_LOCAL_ORG_PREFIXES:-local_}"
  for pre in "${prefixes[@]}"; do
    pre="${pre// /}"; [[ -n "$pre" && "$t" == "$pre"* ]] && return 0
  done
  return 1
}

while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  is_local "$t" || ask "erp-sf guard: this writes to Salesforce and names '$t', which is not a local scratch org. Shared orgs (staging, preprod, partner sandboxes, prod) are read-only unless you confirm."
done <<<"$targets"
exit 0
