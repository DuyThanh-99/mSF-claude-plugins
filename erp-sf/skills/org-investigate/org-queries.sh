#!/usr/bin/env bash
# Read-only evidence collection from a shared or customer Salesforce org.
#   org-queries.sh <alias> <queries-file> <out-dir> [login-url]
# Logs in first when <alias> is not connected (opens the browser; the user signs in), then runs every
# query in the same process, because some orgs (preprod) expire CLI sessions within minutes.
# queries-file lines:  <name> | soql | SELECT ...
#                      <name> | tooling | SELECT ...
#                      <name> | installed
#                      <name> | describe | <SObject API name>
# Anything else is refused: this script never writes to the org.
set -uo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:$PATH"
nvm_bin=$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | sort -V | tail -1); [ -n "$nvm_bin" ] && export PATH="$PATH:$nvm_bin"

alias_="${1:?alias}"; qfile="${2:?queries file}"; out="${3:?out dir}"; url="${4:-}"
mkdir -p "$out"
if ! sf org display -o "$alias_" --json >/dev/null 2>&1; then
  [ -n "$url" ] || { echo "Org '$alias_' is not connected; pass its login URL as the 4th argument." >&2; exit 2; }
  echo "Signing in to $alias_ at $url: finish the login in the browser." >&2
  sf org login web -a "$alias_" -r "$url" >/dev/null || { echo "Login failed." >&2; exit 2; }
fi

fail=0
while IFS='|' read -r name kind body; do
  name=$(echo "$name" | xargs); kind=$(echo "$kind" | xargs); body=$(echo "$body" | sed -E 's/^ +| +$//g')
  [[ -z "$name" || "$name" == \#* ]] && continue
  f="$out/$name.json"
  case "$kind" in
    soql|tooling)
      if ! [[ "$body" =~ ^[[:space:]]*[Ss][Ee][Ll][Ee][Cc][Tt][[:space:]] ]]; then echo "refused (not a SELECT): $name" >&2; fail=1; continue; fi
      flag=(); [ "$kind" = tooling ] && flag=(--use-tooling-api)
      sf data query -o "$alias_" ${flag[@]+"${flag[@]}"} --json -q "$body" > "$f" 2>&1 ;;
    installed) sf package installed list -o "$alias_" --json > "$f" 2>&1 ;;
    describe)  sf sobject describe -o "$alias_" -s "$body" --json > "$f" 2>&1 ;;
    *) echo "refused (unknown kind '$kind'): $name" >&2; fail=1; continue ;;
  esac
  st=$(jq -r '.status // 1' "$f" 2>/dev/null); n=$(jq -r '.result.totalSize // (.result|length) // ""' "$f" 2>/dev/null)
  if [ "$st" = 0 ]; then echo "ok    $name ${n:+($n)}"; else echo "FAIL  $name: $(jq -r '.message // empty' "$f" 2>/dev/null | head -c 200)"; fail=1; fi
done < "$qfile"
exit $fail
