# shellcheck shell=bash
ML_HOME="${ML_HOME:-$HOME/.manabie-local}"
ML_CODE="${ML_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export ML_HOME ML_CODE
# shellcheck disable=SC1091
source "$ML_HOME/config.env"
ORG_ALIAS="${ORG_ALIAS:-local_manabie}"
REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
export ORG_ALIAS REPO_ROOT
mkdir -p "$ML_HOME/logs"
export SF_DISABLE_TELEMETRY=true
log()  { printf '\033[1;34m[mlocal]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m  %s\n' "$*"; }
warn() { printf '\033[1;33m  warn\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m  FAIL\033[0m %s\n' "$*" >&2; exit 1; }
sfq()  { sf data query -o "$ORG_ALIAS" --json -q "$1" 2>/dev/null; }
sfq_tooling() { sf data query -o "$ORG_ALIAS" --use-tooling-api --json -q "$1" 2>/dev/null; }
sfq_count() { sfq "$1" | jq -r '.result.totalSize // 0'; }
apex_file() { sf apex run -o "$ORG_ALIAS" -f "$1" 2>&1; }
# run an apex file and print only the MLOCAL debug lines, decoded
apex_report() {
  local out; out=$(sf apex run -o "$ORG_ALIAS" -f "$1" 2>&1) || true
  echo "$out" | grep -E "COMPILE_ERROR|Error \(executeRuntimeFailure" | head -3 >&2 || true
  echo "$out" | grep "USER_DEBUG.*MLOCAL" | sed -e 's/^.*USER_DEBUG|\[[0-9]*\]|DEBUG|//' -e 's/&#124;/|/g' -e 's/^MLOCAL|//'
}
