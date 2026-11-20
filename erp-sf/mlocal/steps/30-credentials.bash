#!/usr/bin/env bash
# External credential + named credentials for the Manabie staging callouts, deployed from a temp project
# (never touches the repo working tree).
set -euo pipefail
source "${ML_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/common.bash"
log "Credentials: external credential, named credentials, principal access"

n=$(sfq_tooling "SELECT Id FROM Certificate WHERE DeveloperName='$CERT_NAME'" | jq -r '.result.totalSize // 0')
[ "$n" -ge 1 ] || die "certificate $CERT_NAME missing - run: mlocal cert"

SRC="$REPO_ROOT/outside-packages/connections/main/default"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
D="$TMP/force-app/main/default"; mkdir -p "$D/externalCredentials" "$D/namedCredentials"
cat > "$TMP/sfdx-project.json" <<JSON
{"packageDirectories":[{"path":"force-app","default":true}],"namespace":"MANAERP","sourceApiVersion":"62.0"}
JSON
EC="$D/externalCredentials/SF_Manabie_JWT.externalCredential-meta.xml"
cp "$SRC/externalCredentials/SF_Manabie_JWT.externalCredential-meta.xml" "$EC"
# certificate + kid
sed -i '' "s#SelfSignedCert_05Feb2024_061735#$CERT_NAME#g" "$EC"
# iss
sed -i '' "s#https://staging-manabie.my.salesforce.com#$JWT_ISS#" "$EC"
# org id and manabie id claims
sed -i '' 's#{!$Organization.Id}#'"$JWT_ORG_ID"'#' "$EC"
sed -i '' 's#{!$User.MANAERP__Manabie_Id__c}#'"$JWT_MANABIE_ID"'#' "$EC"
for nc in SF_Admin_Manabie_JWT SF_WebAPI_Manabie_JWT; do
  f="$D/namedCredentials/$nc.namedCredential-meta.xml"
  cp "$SRC/namedCredentials/$nc.namedCredential-meta.xml" "$f"
done
sed -i '' "s#https://admin.staging.manabie.io1#$ADMIN_URL#" "$D/namedCredentials/SF_Admin_Manabie_JWT.namedCredential-meta.xml"
sed -i '' "s#https://web-api.staging-green.manabie.io1#$WEBAPI_URL#" "$D/namedCredentials/SF_WebAPI_Manabie_JWT.namedCredential-meta.xml"
( cd "$TMP" && sf project deploy start -o "$ORG_ALIAS" -d force-app --ignore-conflicts --wait 10 --json 2>/dev/null ) \
  | jq -e '.result.status=="Succeeded"' >/dev/null || die "credential deploy failed"
ok "external + named credentials deployed"

# principal access: own permission set (not in repo), assigned to the admin user
PS="$TMP/ps"; mkdir -p "$PS/force-app/main/default/permissionsets"
cp "$TMP/sfdx-project.json" "$PS/"
cat > "$PS/force-app/main/default/permissionsets/Local_Manabie_JWT_Access.permissionset-meta.xml" <<XML
<?xml version="1.0" encoding="UTF-8"?>
<PermissionSet xmlns="http://soap.sforce.com/2006/04/metadata">
    <externalCredentialPrincipalAccesses>
        <enabled>true</enabled>
        <externalCredentialPrincipal>MANAERP__SF_Manabie_JWT-NamedPrincipalSF_Manabie_JWT</externalCredentialPrincipal>
    </externalCredentialPrincipalAccesses>
    <hasActivationRequired>false</hasActivationRequired>
    <label>Local Manabie JWT Access</label>
</PermissionSet>
XML
( cd "$PS" && sf project deploy start -o "$ORG_ALIAS" -d force-app --ignore-conflicts --wait 10 --json 2>/dev/null ) \
  | jq -e '.result.status=="Succeeded"' >/dev/null || die "permission set deploy failed"
n=$(sfq_count "SELECT Id FROM PermissionSetAssignment WHERE PermissionSet.Name='Local_Manabie_JWT_Access' AND Assignee.Profile.Name='System Administrator'")
if [ "$n" -lt 1 ]; then
  sf org assign permset -o "$ORG_ALIAS" -n Local_Manabie_JWT_Access >/dev/null 2>&1 || die "assign Local_Manabie_JWT_Access failed"
fi
ok "principal access via Local_Manabie_JWT_Access"
