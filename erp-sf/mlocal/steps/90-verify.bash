#!/usr/bin/env bash
set -uo pipefail
source "${ML_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/common.bash"
log "Verify"
fails=0
chk() { if [ "$2" = "1" ]; then ok "$1"; else printf '\033[1;31m  FAIL\033[0m %s\n' "$1"; fails=$((fails+1)); fi; }
p=$(apex_report "$ML_CODE/steps/90-probe.apex")
echo "$p" | grep -q "probe|400|.*missing_student_id" && r=1 || r=0; chk "authenticated callout (JWT) -> 400 missing_student_id" $r
[ "$(sfq_count "SELECT Id FROM MANAERP__Academic_Year__c WHERE MANAERP__Current_Academic_Year__c=true")" = "1" ] && r=1 || r=0; chk "exactly one current academic year" $r
[ "$(sfq_count "SELECT Id FROM MANAERP__Product__c WHERE MANAERP__Available_Until__c >= TODAY AND MANAERP__Academic_Year__r.MANAERP__Current_Academic_Year__c=true")" -ge 1 ] && r=1 || r=0; chk "products on current AY, still available" $r
[ "$(sfq_count "SELECT Id FROM MANAERP__Billing_Period__c WHERE MANAERP__Start_Date__c <= TODAY AND MANAERP__End_Date__c >= TODAY")" -ge 1 ] && r=1 || r=0; chk "billing period covers today" $r
[ "$(sfq_count "SELECT Id FROM MANAERP__Product_Location__c WHERE MANAERP__Account__r.MANAERP__Location_Type__c='Center'")" -ge 1 ] && r=1 || r=0; chk "product locations at a Center" $r
[ "$(sfq_count "SELECT Id FROM MANAERP__Grade__c WHERE MANAERP__Partner_Internal_Id__c='$STUDENT_GRADE_PID'")" -ge 1 ] && r=1 || r=0; chk "grade $STUDENT_GRADE_PID exists" $r
[ "$(sfq_count "SELECT Id FROM Contact WHERE MANAERP__Main_Location__c != null")" -ge 1 ] && r=1 || r=0; chk "test student exists (run: mlocal student)" $r
[ "$(sfq_count "SELECT Id FROM MANAERP__Contact_Sync_To_Manabie_Log__c WHERE MANAERP__Status__c='Success'")" -ge 1 ] && r=1 || r=0; chk "a student synced successfully" $r
exit $fails
