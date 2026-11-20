---
name: package-placement
description: Main vs Ext package placement for erp-salesforce metadata. Use before creating or moving any Apex class, trigger, LWC, Aura, object, field, record type, permission set, quick action, tab, FlexiPage, layout, flow or label; when writing a TDD "Code placement" section or a PR placement note; and when granting access to new metadata.
---

# Package placement

Core (`Manabie All In One`, **Main**) is near Salesforce's 10,000-file package limit, and **Ext** depends on Main, never the reverse. A wrong placement passes in a scratch org and fails only in the CI managed build or on a subscriber upgrade.

The rules live in one place: [`package-placement.md`](../../reference/package-placement.md) in this plugin. Read the whole file before step 2.

## Steps

1. **List** every file you will create or move, metadata `-meta.xml` files included.
2. **Classify** each file by walking the doc's "Decide" questions in order and stopping at the first match. For a move, find the component in the module's move plan (MOVE, CLUSTER or KEEP) and raise anything not listed instead of moving it.
3. **Name** it by the doc's "Naming" table: Apex keeps its name in Ext; LWC/Aura get `…Ext`; FlexiPages, layouts, quick actions get `_Ext`; Ext permission sets get a new API name.
4. **Grant** by the doc's "Access" table. Every new class, VF page, tab, app, record type, custom permission, object or field under `packages/` goes in the 3 v2 sets (`full_access_v2`, `full_access_v2_restricted`, `center_level_edit_v2`); CI's `permission-set-check` enforces it; `perm-check` runs the same check locally.
5. **Annotate** every Main class and member that Ext calls with `@NamespaceAccessible` (class and each member; it is not inherited).
6. **Record** a placement table in the TDD "Code placement" section and the PR description:

   | File | Target | Reason |
   | --- | --- | --- |
   | `packages/order/.../FooService.cls` | Main | Service called from Main (Decide 6) |

7. **Count** with `file-count --compare` when the change adds or moves many files, and put the Main and Ext numbers in the PR.
8. **Check** the golden rule: run `golden-rule` (on the Bash PATH) from the repo root. It searches Main for every Ext component changed on the branch and runs the repo's LightningComponent-override guard.

## Done

Every new or moved file has a row with a target and a one-line reason; `golden-rule` exits 0, or each remaining hit is reported to the user with why it is safe; and every grant from step 4 is in place.

A hit that is only a runtime string (a flow URL, a custom permission name, `$Lightning.use("MANAERP:…")`) compiles but breaks when Ext is absent; `golden-rule --all` shows the ones already on develop as the baseline.
