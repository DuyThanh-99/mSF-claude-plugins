---
name: apex-conventions
description: erp-salesforce Apex rules the team enforces. Use when writing or changing an Apex class, trigger handler or Apex test in erp-salesforce, when a WITH USER_MODE query fails for users without object access, or when a test depends on the running user's timezone.
---

# Apex conventions

Repo rules on top of the Salesforce Apex skills. When a generic skill disagrees, these win.

## Classes

- `with sharing` on every class unless the spec says otherwise; test fixtures included (CI's sharing scan flags them).
- Queries run `WITH USER_MODE`. When a user without object access breaks a flow, keep `USER_MODE` and guard before the query so the lookup skips quietly: `if (!Schema.sObjectType.MANAERP__X__c.isAccessible()) return;`. `SYSTEM_MODE` is rejected for security compliance (BillingMonthLockValidationService, 2026-07-16).
- Bulk-safe: a fixed number of queries per object type, never per row. No hard-coded IDs.
- Ext code calls only Main members marked `@NamespaceAccessible`, class and member both (see `erp-sf:package-placement`).

## Tests

- Test external behaviour at the agreed seam and assert database state, not helper calls. Main tests pass without Ext installed: seed data only when absent, derive counts from queries.
- Use the running user plus a permission set. Inserting a `User` fires `UserTrigger` → `UserHandler.afterInsert` → `requestSyncStaffUserToManabie`, which fails on a fresh `local_manabie` (`QueryException: Variable does not exist: tmpVar1`, `CANNOT_INSERT_UPDATE_ACTIVATE_ENTITY`), and `UserTrigger` ignores `TriggerSwitch.bypassTrigger`. A test passes on an old org and fails on a new one.
- When a test must insert a User anyway, do business DML inside `System.runAs` to avoid mixed DML.
- Timezone-dependent data: build it independent of the running user's timezone instead of `System.runAs` with a timezone user. Strings: `OrderDateUtil.convertToISO8601WithTimezone(date, OrderGroupController.getUserTimeZoneOffset(), isEndOfDay)`, the same way orders are sent. `Datetime` fields: `Datetime.newInstance(date, Time.newInstance(0, 0, 0, 0))` (local midnight).
