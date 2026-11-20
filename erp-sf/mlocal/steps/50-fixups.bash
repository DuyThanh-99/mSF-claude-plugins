#!/usr/bin/env bash
set -uo pipefail
source "${ML_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/common.bash"
log "Fixups: current AY, product links, billing dates, student sync switch"
sed "s/__GRADE__/$STUDENT_GRADE_PID/" "$ML_CODE/steps/50-fixups.apex" > "$ML_HOME/logs/50-fixups.run.apex"
res=$(apex_report "$ML_HOME/logs/50-fixups.run.apex"); echo "$res"
echo "$res" | grep -q "^fix-error" && warn "some fixups failed (see above)"
exit 0
