#!/usr/bin/env bash
# PreToolUse(Bash): ask before any command that writes to a Salesforce org other than a
# local scratch org (alias prefix from the local_org_prefixes option, default local_, or a
# username ending in @example.com).
# Writes: deploy/validate, delete source, package install/version create, data writes,
# anonymous Apex and Apex test runs, permission-set assignment, sandbox create/delete/refresh,
# non-GET REST calls, changing the default org or an alias, repo scripts, make targets that
# deploy/sync/load, and mlocal steps.
# Every org the command names must be local: -o/--target-org values, `sf config set target-org X`,
# `sf alias set a=X`, ORG=/ORG_ALIAS= assignments, and script arguments that are known org aliases,
# usernames or shared org names. A write that names no org is checked against the default org
# (SF_TARGET_ORG, then .sf/config.json walking up, then ~/.sf; ORG_ALIAS from config.env for mlocal).
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
# Changing what the default org or an alias points at redirects every later command.
config_set="${bin}((force:)?config${T}set|alias${T}set|force:alias:set)"
script_run="${S}([^[:space:]\"'\`;|&()]*/)?scripts/[^[:space:]\"';|&]+\.(bash|sh)([[:space:]]|$)"
make_write="${S}make([[:space:]]+[^[:space:];|&]+)*[[:space:]]+([[:alnum:]_.][^[:space:];|&=]*)?(deploy|push|sync|start|seed|load|import|assign|install|setup|data|delete)[^[:space:];|&=]*([[:space:]]|$)"
mlocal_write="${S}([^[:space:]\"'\`;|&()]*/)?mlocal[[:space:]]+(all|perm|permissions|cert|creds|credentials|data|fix|fixups|sync|student|reset)([[:space:]]|$)"

is_write() {  # $1 = command text
  [[ "$1" =~ $sf_write || "$1" =~ $config_set || "$1" =~ $script_run || "$1" =~ $make_write || "$1" =~ $mlocal_write ]] && return 0
  [[ "$1" =~ $api_call && "$1" =~ $api_write ]] && return 0
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

# Lookups loaded once: hooks run on every Bash call and must stay fast on large commands
# (a hook that hits its timeout lets the command through).
alias_map=""   # lines "alias<TAB>username"
[[ -f "$HOME/.sfdx/alias.json" ]] && alias_map=$(jq -r '.orgs // {} | to_entries[] | "\(.key)\t\(.value)"' "$HOME/.sfdx/alias.json" 2>/dev/null)
known_orgs=$'\n'
while IFS=$'\t' read -r a _; do [[ -n "$a" ]] && known_orgs+="$a"$'\n'; done <<<"$alias_map"
IFS=',' read -r -a shared <<<"${CLAUDE_PLUGIN_OPTION_SHARED_READ_ORGS:-staging,preprod}"
for a in ${shared[@]+"${shared[@]}"}; do a="${a// /}"; [[ -n "$a" ]] && known_orgs+="$a"$'\n'; done
IFS=',' read -r -a prefixes <<<"${CLAUDE_PLUGIN_OPTION_LOCAL_ORG_PREFIXES:-local_}"
is_org_name() { [[ "$1" == *@* || "$known_orgs" == *$'\n'"$1"$'\n'* ]]; }

is_local() {
  local t=$1 username=$1 a u pre
  if [[ "$t" != *@* ]]; then
    while IFS=$'\t' read -r a u; do [[ "$a" == "$t" ]] && { username=$u; break; }; done <<<"$alias_map"
  fi
  [[ "$username" == *@example.com ]] && return 0
  for pre in ${prefixes[@]+"${prefixes[@]}"}; do
    pre="${pre// /}"; [[ -n "$pre" && "$t" == "$pre"* ]] && return 0
  done
  return 1
}

# Each org the command names is checked once, as soon as it is found.
seen=$'\n'
add_target() {  # $1 = raw value, $2 = where it came from
  local v=$1
  v=${v#\"}; v=${v%\"}; v=${v#\'}; v=${v%\'}
  [[ -z "$v" || "$seen" == *$'\n'"$v"$'\n'* ]] && return
  seen+="$v"$'\n'
  [[ "$v" == *'$'* || "$v" == *'`'* ]] && ask "erp-sf guard: the org in $2 comes from a variable or substitution ('$1'), so it cannot be checked. Confirm it is a local scratch org."
  is_local "$v" || ask "erp-sf guard: this writes to Salesforce and names '$v' ($2), which is not a local scratch org. Shared orgs (staging, preprod, partner sandboxes, prod) are read-only unless you confirm."
}
val='("[^"]*"|'"'"'[^'"'"']*'"'"'|[^[:space:];|&)]+)'
collect() {  # $1 = regex whose last group is the value, $2 = label; one grep pass over the command
  local m n
  while IFS= read -r m; do
    [[ "$m" =~ $1 ]] || continue
    n=${#BASH_REMATCH[@]}
    add_target "${BASH_REMATCH[$((n - 1))]}" "$2"
  done < <(grep -oE -- "$1" <<<"$cmd" 2>/dev/null)
}
# -o / --target-org anywhere in the command (quoted or not, = or space)
collect "(^|[[:space:]])(--target-org|--org|--targetusername|-o|-u)[=[:space:]]+${val}" "a target flag"
# sf config set target-org X / defaultusername=X
collect "(target-org|defaultusername)[=[:space:]]+${val}" "config set"
# ORG=x / ORG_ALIAS=x / TARGET_ORG=x (make variables, env prefixes for mlocal and scripts)
collect "(^|[[:space:]])[A-Z_]*(ORG|ORG_ALIAS|USERNAME)=${val}" "an ORG= assignment"

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
mlocal_org() {
  local f="${ML_HOME:-$HOME/.manabie-local}/config.env" o=""
  [[ -f "$f" ]] && o=$(sed -nE "s/^ORG_ALIAS=[\"']?([^\"'[:space:]#]*).*/\1/p" "$f" | tail -1)
  echo "${ORG_ALIAS:-${o:-local_manabie}}"
}

# Per segment: a write that names no org of its own goes to the default org.
# grep keeps only the segments that can be writes, so long commands are not walked line by line in bash.
seg_flag='(^|[[:space:]])(--target-org|--org|--targetusername|-o|-u)[=[:space:]]|(^|[[:space:]])[A-Z_]*(ORG|ORG_ALIAS|USERNAME)='
needs_default=0
mlocal_seen=0
while IFS= read -r seg; do
  is_write "$seg" || continue
  if [[ "$seg" =~ $config_set ]]; then
    # sf alias set a=X b=Y: every username an alias will point at (config set values were collected above)
    if [[ "$seg" =~ alias${T}set || "$seg" =~ alias:set ]]; then
      read -r -a words <<<"$seg"
      for w in ${words[@]+"${words[@]}"}; do
        [[ "$w" == [A-Za-z_]*=* && "$w" != -* ]] && add_target "${w#*=}" "alias set"
      done
    fi
    continue
  fi
  if [[ "$seg" =~ $mlocal_write ]]; then
    [[ "$seg" =~ (^|[[:space:]])--dry-run([[:space:]]|$) ]] && continue   # data plan and checks only
    if [[ $mlocal_seen -eq 0 ]] && ! [[ "$seg" =~ $seg_flag ]]; then mlocal_seen=1; add_target "$(mlocal_org)" "mlocal config.env"; fi
    continue
  fi
  [[ "$seg" =~ $seg_flag ]] && continue
  if [[ "$seg" =~ $script_run ]]; then  # scripts take the org as a positional argument
    named=0
    read -r -a words <<<"${seg#*"${BASH_REMATCH[0]}"}"
    for w in ${words[@]+"${words[@]}"}; do
      w=${w#\"}; w=${w%\"}; w=${w#\'}; w=${w%\'}
      [[ "$w" == -* || -z "$w" ]] && continue
      [[ "$w" == *'$'* ]] && add_target "$w" "a script argument"
      is_org_name "$w" && { add_target "$w" "a script argument"; named=1; }
    done
    [[ $named -eq 1 ]] && continue
  fi
  needs_default=1
done < <(awk 'BEGIN { RS = "\001" } { gsub(/&&|\|\||[;|&\n]/, "\n"); print }' <<<"$cmd" \
         | grep -E -e "$sf_write" -e "$config_set" -e "$script_run" -e "$make_write" -e "$mlocal_write" -e "$api_call" 2>/dev/null)
if [[ $needs_default -eq 1 ]]; then
  d=$(default_org)
  [[ -z "$d" ]] && ask "erp-sf guard: this writes to a Salesforce org but no target org could be resolved. Confirm the target is a local scratch org."
  add_target "$d" "the default org"
fi
exit 0
