#!/usr/bin/env bash
# Creates a student that syncs to staging (unique username, Main Location, grade) and waits for the sync log.
set -uo pipefail
source "${ML_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/common.bash"
LOC="${1:-TLocation2026Local1}"
log "Student: create + sync (location $LOC)"
TS=$(date +%s)
sed -e "s/__TS__/$TS/g" -e "s/__GRADE__/$STUDENT_GRADE_PID/" -e "s/__LOC__/$LOC/" "$ML_CODE/steps/60-student.apex" > "$ML_HOME/logs/60-student.run.apex"
id=$(apex_report "$ML_HOME/logs/60-student.run.apex" | sed -n 's/^student|//p')
[ -n "$id" ] || die "student not created"
for i in $(seq 1 20); do
  s=$(sfq "SELECT MANAERP__Status__c, MANAERP__Error_Message__c FROM MANAERP__Contact_Sync_To_Manabie_Log__c WHERE MANAERP__Contact__c='$id' ORDER BY CreatedDate DESC LIMIT 1" | jq -r '.result.records[0].MANAERP__Status__c // "pending"')
  [ "$s" = "Success" ] && { ok "synced: $id"; break; }
  sleep 3
done
[ "$s" = "Success" ] || die "student $id not synced (latest log: $s) - see Contact_Sync_To_Manabie_Log__c"
url=$(sf org open -o "$ORG_ALIAS" -r --url-only --json 2>/dev/null | jq -r '.result.url' | sed 's#/secur/.*##')
echo "Student: $url/lightning/r/Contact/$id/view"
