# Evidence queries

Lines for [`org-queries.sh`](org-queries.sh) (`<name> | soql|tooling|installed|describe | <body>`). Replace `<…>`; keep each query narrow (record IDs, a time window). Custom objects and fields carry the `MANAERP__` namespace in subscriber orgs.

## Version

```
installed | installed
```
Then on the Dev Hub (`pbo_manabie`, stays connected), for each `04t…` ID:
```
pkgver_main | tooling | SELECT Package2.Name, MajorVersion, MinorVersion, PatchVersion, BuildNumber, Tag, Branch, CreatedDate FROM Package2Version WHERE SubscriberPackageVersionId = '<04t…>'
```
`Tag` (e.g. `20261118055704.de4524e2`) is a git tag here; `Branch` shows a hotfix line. `git tag --contains <commit>` tells whether a fix is in that version.

## Records

```
records | soql | SELECT Id, Name, <fields from the symptom>, LastModifiedBy.Name, LastModifiedDate FROM MANAERP__<Object>__c WHERE Id IN ('<id>', '<id>')
history | soql | SELECT ParentId, Field, OldValue, NewValue, CreatedBy.Name, CreatedDate FROM MANAERP__<Object>__History WHERE ParentId IN ('<id>') ORDER BY CreatedDate
```
Standard objects use `<Object>History` (e.g. `ContactHistory`). History exists only for tracked fields; `describe` shows which.

## The module's logs and errors

List the log, error and history objects in the code: `ls packages/*/main/default/objects | grep -iE 'log|error|history'`. Pick the module's, describe one, then query by related record and time window:
```
log | soql | SELECT Id, <status/message fields>, CreatedDate FROM MANAERP__<Log_Object>__c WHERE CreatedDate >= <ISO time> ORDER BY CreatedDate DESC LIMIT 50
```

## Jobs, setup changes, access

```
jobs   | soql | SELECT ApexClass.Name, JobType, Status, ExtendedStatus, NumberOfErrors, CreatedBy.Name, CreatedDate FROM AsyncApexJob WHERE Status = 'Failed' AND CreatedDate = LAST_N_DAYS:14 ORDER BY CreatedDate DESC LIMIT 50
audit  | soql | SELECT Action, Section, Display, CreatedBy.Name, CreatedDate FROM SetupAuditTrail WHERE CreatedDate = LAST_N_DAYS:30 ORDER BY CreatedDate DESC LIMIT 100
user   | soql | SELECT Id, Username, Profile.Name, IsActive, LanguageLocaleKey, TimeZoneSidKey FROM User WHERE Id = '<user id>'
psa    | soql | SELECT PermissionSet.Name, PermissionSetGroup.DeveloperName FROM PermissionSetAssignment WHERE AssigneeId = '<user id>'
```

Debug logs (`ApexLog`) exist only while a trace flag is set, and setting one is a write: propose it with the user, the duration and the steps to reproduce.
