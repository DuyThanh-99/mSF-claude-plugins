#!/usr/bin/env bash
set -euo pipefail
source "${ML_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/common.bash"
log "Permissions: School Admin group for the admin user"
( cd "$REPO_ROOT" && scripts/assign_permission_set_group_to_systemadmin.bash "$ORG_ALIAS" >/dev/null 2>&1 ) || die "assign School Admin failed"
n=$(sfq_count "SELECT Id FROM PermissionSetAssignment WHERE PermissionSetGroup.MasterLabel='School Admin' AND Assignee.Profile.Name='System Administrator'")
[ "$n" -ge 1 ] && ok "School Admin assigned" || die "School Admin not assigned"

# Access sets that live in outside-packages (not in the School Admin group): assign when present.
for ps in Product_Request_Access; do
  if [ "$(sfq_count "SELECT Id FROM PermissionSet WHERE Name='$ps'")" -ge 1 ]; then
    if [ "$(sfq_count "SELECT Id FROM PermissionSetAssignment WHERE PermissionSet.Name='$ps' AND Assignee.Profile.Name='System Administrator'")" -lt 1 ]; then
      sf org assign permset -o "$ORG_ALIAS" -n "$ps" >/dev/null 2>&1 && ok "assigned $ps" || warn "could not assign $ps"
    else ok "$ps already assigned"; fi
  fi
done
