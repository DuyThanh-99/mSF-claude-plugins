# Package placement

Decide the package of every new component (Apex, trigger, LWC, Aura, object, field, record type, permission set, quick action, tab, FlexiPage, layout, flow, label) **before** writing it, and follow the matching playbook when moving existing ones. Core (`Manabie All In One`) is near Salesforce's 10,000-file limit per package version; every file placed in Core spends that budget.

The step is done when every new or moved file has a target and a one-line reason, written in the TDD "Code placement" section and the PR description.

## Sources

The rules follow the official pages in the ERP space, folder [Package Split Items](https://manabie.atlassian.net/wiki/spaces/ERP/folder/2809200644/Package+Split+Items). When they disagree, the newer page wins:

| Page | Updated | Covers |
| --- | --- | --- |
| [Action Overrides Migration Strategy](https://manabie.atlassian.net/wiki/spaces/ERP/pages/2807955491) | 2026-10-09 | Aura/LWC action overrides, Ext UI clusters, Ext controllers |
| [Trigger & Apex Class Migration Strategy](https://manabie.atlassian.net/wiki/spaces/ERP/pages/2808119326) | 2026-08-27 | Triggers, handlers, `@NamespaceAccessible`, Ext Apex setup, rollback |
| [FlexiPage & Layout Migration Strategy](https://manabie.atlassian.net/wiki/spaces/ERP/pages/2186969091) | 2026-03-26 | FlexiPages, layouts, assignment YAML, layout translations |

Supporting material, which is analysis rather than rules:
- Epic [LT-105927](https://manabie.atlassian.net/browse/LT-105927).
- [LT-108021](https://manabie.atlassian.net/browse/LT-108021): the action-override pipeline, and its [design page](https://manabie.atlassian.net/wiki/spaces/ERPPlatform/pages/2799796227).
- [LT-112025](https://manabie.atlassian.net/browse/LT-112025): component references in customer FlexiPages.
- The per-module **move plans** in the ERPPlatform space, for example [order](https://manabie.atlassian.net/wiki/spaces/ERPPlatform/pages/2713747538). They stand in for the Drive candidate analysis, which isn't readable here.
- The [permission-set handling](https://manabie.atlassian.net/wiki/spaces/ERPPlatform/pages/2716696649) proposal.
- `scripts/flexipage-assignment-update/README.md`.

Lines marked **(repo)** were verified in this repository and aren't covered by the official pages.

## Package facts

| Package | Source | Depends on |
| --- | --- | --- |
| Manabie All In One (**Main**, also called Core) | `packages/*` without `-ext` | FormTitan, DLRS |
| Manabie All In One Ext (**Ext**) | every `packages/*-ext` folder, built into one package version | Main |

Both packages use the `MANAERP` namespace. Ext depends on Main, never the reverse, so:
- Main can't reference anything in Ext.
- Main always installs or upgrades first.
- `packages/*-ext` folders are source folders, not separate packages, and a file may live in only one of them.

## Decide

Walk the questions in order and stop at the first match.

1. **Does it fold into an existing Main file?** Fields, picklist values, compact layouts, labels, non-layout object translations, and edits to existing Main code. → **Main.** *"All other metadata (fields, objects, flows, non-layout translations, etc.) continues to live in the base package."* Objects and fields are never moved.
2. **Is it a FlexiPage, a layout, or a layout translation?** → **Ext**, named `_Ext`. Assign it in the team's YAML file, never in `object-meta.xml` or `app-meta.xml`. See "FlexiPages and layouts".
3. **Is it a record type on a packaged object?** → **`outside-packages/access-control/main/default/objects/`** (repo, LT-115104). A record type added by either managed package fails upgrades in orgs that have their own picklists on that object (Salesforce W-18241309). The YAML step can't assign pages to an unpackaged record type, so show its content on the fallback page with a `{!Record.RecordType.DeveloperName}` visibility rule.
   - Main metadata must never name it: no `recordTypeVisibilities`, layout assignment or FlexiPage assignment in Main. Grant it from the outside sets instead (see "Access").
   - Main Apex and tests that use it must check `getRecordTypeInfosByDeveloperName().containsKey(...)` first (as `ProductRequestDraftService.isRecordTypeAvailable()` does). It doesn't exist until the outside post-install runs, except in the package build org, which deploys `outside-packages/access-control`.
4. **Is it a trigger, or a class that exists only to serve that trigger?** → **Ext**, under the same name. *"If other things call it, it stays in main."* A helper that other code shares stays in Main and gets `@NamespaceAccessible`.
5. **Is it UI (LWC or Aura) that is reached only from Ext?** That means an Ext FlexiPage, Ext quick action, Ext app, or an action override assigned through YAML. → **Ext**, named `…Ext`.
   - Move the **complete dependency cluster**: clone the same-module Main LWCs it uses into Ext as `…Ext`. *"Do not move a partial dependency cluster. If it cannot move safely as a complete cluster, keep it in Main."*
   - If it needs `@AuraEnabled` Apex, clone the controller and its test into Ext as `…Ext` and point the Ext UI at the clone (repo practice: every Ext LWC calls Ext Apex). Prefer Lightning Data Service (`getRecord`, GraphQL) when it covers the need, because it needs no class grant.
   - If anything that stays in Main references the UI, it stays in Main.
6. **Is it a service, repository, factory, constant, controller called from Main, or a test-data factory?** → **Main.** *"Everything else stays where it is."* If Ext needs it, add `@NamespaceAccessible`.
7. **Is it org-specific configuration?** For example standard-object overrides, sharing rules, sites, or things admins customise. → the matching **`outside-packages/<area>`** folder (repo). Outside Apex can call only `global` Main Apex, and `global` is permanent.
8. **Is it a permission grant?** → see "Access".
9. **Is it a feature flag?** → **`outside-packages/feature-flags/main/<env>`** (repo).
10. **Otherwise: Main**, with a TDD note on what rules out Ext.

Before moving an existing component, find it in the module's move plan, where each component is marked MOVE, CLUSTER or KEEP. Raise anything that isn't listed there instead of moving it.

## Naming

| Thing | Moved or new in Ext | Example |
| --- | --- | --- |
| Trigger, Apex class, test | **Same name** | `SectionTriggerHandler` stays `SectionTriggerHandler` |
| LWC, Aura | camelCase `…Ext` (an LWC name can't end in `_` or contain `__`) | `buttonOverrideNewExam` → `buttonOverrideNewExamExt` |
| FlexiPage, layout | `_Ext` | `Exam_Assessor_Record_Page` → `Exam_Assessor_Record_Page_Ext` |
| Cloned Apex controller | `…Ext` | `EntranceExamInfoFormController` → `EntranceExamInfoFormControllerExt` |
| Ext permission set | a different API name from any Main set | `Order_Extension_Access`; `Edit_Exam` → `Edit_Exam_Ext` |
| Quick action (repo, LT-115104) | `_Ext` | `Contact.Add_Product_Request` → `Contact.Add_Product_Request_Ext` |

**Why the rules differ:**
- **Apex classes and triggers keep their name.** When Main upgrades without a class, Salesforce deletes the class from the org, and Ext then brings it back under the same name.
- **UI components, pages, layouts, quick actions and permission sets are deprecated, not deleted.** The old copy stays in subscriber orgs as an orphan, so Ext must use a new name. Never reuse those names.
- **Moving Apex back to Main needs a new name** (see "Rollback").

**Three namespace-prefix conventions:**

| Where | Prefix | Example |
| --- | --- | --- |
| Permission sets outside the owning package (`outside-packages-ext/access-control`) | `MANAERP__` | `MANAERP__SectionTriggerHandler` |
| Test suites | `MANAERP.` (a dot) | `MANAERP.SectionTriggerHandlerTest` |
| A permission set inside the same package, and `apexTestAccess` | none | `Grade_Dev_Extension_Access` |
| FlexiPage and action-override YAML | `MANAERP__` on page, object and record-type names that belong to either package. None for outside pages | `MANAERP__Exam__c` |

## Access (permission sets)

| The grant references | Put it in | Why |
| --- | --- | --- |
| Main metadata | A packaged Main set, or the sets in `outside-packages/access-control` | Normal case |
| An Ext class, page or flow (functional: `@AuraEnabled`, a VF page, a flow) | 1. The module's in-package Ext set (no prefix). 2. The **3 v2 sets** in `outside-packages-ext/access-control` (`full_access_v2`, `full_access_v2_restricted`, `center_level_edit_v2`, with the `MANAERP__` prefix) | A packaged Main set can't name Ext metadata, because the Main build fails |
| An Ext trigger handler, or a class called only inside a transaction | No grant needed; delete any old Main grant | Triggers run in system context |
| A record type in `outside-packages/access-control` (repo) | The sets in `outside-packages/access-control`, e.g. `SPU_Admin_Permission_OOP` / `SPU_Non_Admin_Permission_OOP` for v1 groups | The record type exists in both builds |
| Classes, VF pages, flows or tabs in `outside-packages/order` (repo) | The sets in `outside-packages/access-control` | The managed build's `scripts/remove_outside_order_access.cjs` strips those grants (precedent LT-114022) |

- **When moving a component:** remove its `classAccesses`, `pageAccesses` and `flowAccesses` entries from every packaged Main set before moving it. The Main build fails on a Main→Ext reference.
- **`outside-packages/access-control` can't grant Ext metadata (repo).** Both the Main and Ext builds deploy it as `unpackagedMetadata` (`sfdx-project.build.managed.json`), and the Main build org has no Ext classes. The older permission-set proposal and the move plans say "unpackaged sets may grant Ext freely". That's true for `outside-packages-ext`, not for this folder.
- **v1 permission-set users get no Ext Apex grant (repo).**
  - The Ext in-package sets (`*_Extension_Access`) are assigned to nobody. They're listed only in `apexTestAccess`.
  - The proposed fix, a companion `_Ext` set plus `PermissionSetPostInstallScript.assignExtPermissionSetsFromMain`, is **not on develop**, and adding it would change the post-install flow.
  - So Ext UI that needs Apex reaches v2 users only. For v1 users, choose one: keep the UI in Main, use LDS, or document a manual assignment step for PS/admins.
- **Packaged sets tied to the Customer Community Plus license are frozen** (repo, commit `9bffd9bfd9`). Changing one marks it removed on orgs without that license, and the next Main upgrade fails with "Duplicate Name". Leave the licensed originals byte-for-byte unchanged and grant through their license-free replacements.
- **Packaged sets with the `Salesforce Platform` license take new grants as usual** (repo). `Platform_Access_Order_Classes` gets class grants routinely: #23833, #23878, #24032, #24139, #24314. It also grants the Main order-editor Apex (`ManageOrderGroupProducts`, `OrderCustomSettingConfigurations`, `ProductController`), so new Main `@AuraEnabled` classes for that editor belong in it too. Never add, remove or change a `<license>` tag.
- **CI gate `permission-set-check`** (pre-merge): every **newly added** class, VF page, tab, app, record type, custom permission, object or field under `packages/` must be granted in all 3 v2 sets. Test classes and custom-setting fields are skipped. The rules are in `scripts/permission-set-check/config.json`.

## Cross-package Apex

| Declaration | Own package | Other package, same namespace | Subscriber org |
| --- | --- | --- | --- |
| `public` | yes | **no** | no |
| `public` + `@NamespaceAccessible` | yes | **yes** | no |
| `global` | yes | yes | **yes**: a permanent API commitment |

- **Annotate the class and each member that Ext calls.** The annotation isn't inherited, and static variables need their own (for example `TriggerSwitch.bypassTrigger`). Once Ext depends on a member, removing its annotation breaks the Ext build.
- **If the overload you call isn't annotated, adapt the call** instead of widening the annotated surface. Example: `BaseDML.doInsert(new List<SObject>{ rec }, false)[0]`. When a class would need many annotations, give Ext its own small utility (precedent: `GradeDevExtDatabaseUtil`).
- **Prefer `@NamespaceAccessible` over `global`.** `@AuraEnabled` members can't take the annotation, so an Ext UI gets a cloned `…Ext` controller instead.
- **An Ext LWC can't import a Main `c/` module or extend a Main LWC.** Clone the helper into Ext. Main custom labels do work from Ext.

## Playbooks

### New feature (most PRs)

1. Classify every new file with "Decide". Record its target and reason in the TDD and the PR.
2. Put the UI in Ext only when nothing in Main references it and its users can get access (see "Access").
3. Run the golden-rule check: nothing that stays in Main may name an Ext item.
   ```bash
   git grep -n -w <ExtName> -- packages/ ':(exclude)packages/*-ext/**'   # expect no hits
   ```
4. Grant new metadata in the 3 v2 sets, as `permission-set-check` requires.

### Move a trigger and its Apex to Ext

**One-time setup per Ext module, before its first Apex.** If you skip step 3, the Ext package version fails to build.
1. Add an in-package permission set in `packages/<pkg>-ext/main/default/permissionsets/`, with no prefix.
2. Add a test suite: `packages/<pkg>-ext/main/default/testSuites/<Pkg>extTestSuite.testSuite-meta.xml`.
3. Register the set under `apexTestAccess.permissionSets` for `Manabie All In One Ext` in `sfdx-project.build.managed.json`.
4. Don't copy `invoice-ext` as a template: it has no suite and only part of its access registered.

State on develop (repo, checked 2026-11-14):

| Ext module | In-package set registered in `apexTestAccess` | Test suite |
| --- | --- | --- |
| `grade-dev-ext` | `Grade_Dev_Extension_Access` | yes |
| `order-ext` | `Order_Extension_Access` | yes |
| `user-ext` | `User_Extension_Access` | yes |
| `timesheet-ext` | `Timesheet_Extension_Access` | yes |
| `econtract-ext` | `SPU_Admin_Permission_EContract` | yes |
| `lesson-ext` | `Lesson_Extension_Access` | **no** |
| `invoice-ext` | only `Platform_Edit_Juku_Subsidy_Application_Ext` of its 4 sets | **no** |
| `event-ext` | **none**: its 18 classes test with the Main set `SPU_Admin_Permission_Event` | **no** |

**Each move:**
1. Confirm the component is a candidate in the module's move plan.
2. `git mv` the trigger, handler, helper and tests, with their `-meta.xml` files, into `<pkg>-ext`.
   - Don't change any logic: git should report a similarity index of 99% or more.
   - Any `classes/` subfolder flattens to `classes/` in Ext. Examples: grade-dev `classes/trigger-handler/`, order `classes/TriggerHandlers/` (#24295 moved `TriggerHandlers/ProductPriceHandler.cls` to `order-ext/.../classes/ProductPriceHandler.cls`).
3. List every Main class the moved code calls. Add `@NamespaceAccessible` to each class **and** to each method or static variable it uses.
4. Remove the class's grants from the Main permission sets. If the grant is functional, add `MANAERP__<Class>` to the 3 v2 sets.
5. Move the test from the Main suite to the Ext suite (`MANAERP.<Test>`).
6. **Main tests must pass without Ext installed.** Seed data only if it's absent, derive counts from queries, and set the fields that the moved trigger used to fill (precedent PR #21952).
7. Build Main first, then Ext. Each package needs at least 75% coverage.

### Move an LWC or Aura action override to Ext

Covers `<type>LightningComponent</type>` overrides only. Leave `Default`, `Flexipage` and `Visualforce` overrides alone.
1. Move the Aura or LWC bundle to `packages/<module>-ext`, renamed `…Ext`. Move the complete UI cluster, and update imports, tags, Jest mappings and `controller=` references.
2. If the UI uses `@AuraEnabled` Apex, clone the controller and its test as `…Ext`. **Keep the Main controller and test** until a later compatible release. Grant the clone in the Ext set and the v2 sets; don't grant test classes.
3. Extract the override into `packages/<module>-ext/main/default/assignments/action_overrides_<module>-ext.yaml` and add the old→new row to `packages/common-ext/main/default/assignments/action_overrides_rename.csv`:
   ```bash
   node scripts/flexipage-assignment-update/migrate-action-overrides.mjs \
     --root packages/<module> --objects <ObjectApiName> --delete-old
   ```
4. If customer-owned FlexiPages may embed the old LWC, add an exact row to `packages/common-ext/main/default/assignments/flexipage_component_renames.csv`.
5. The YAML is the source of truth: never add a migrated override back to Main `object-meta.xml`. Guard it with `node scripts/flexipage-assignment-update/check-no-main-lightning-component-overrides.mjs`, which is also on the PR template checklist.
6. Release Main before Ext, then validate the override and any affected customer FlexiPages.

Pending module moves: `Application__c`/`buttonOverrideNewApplication` is LT-108719. Until it lands, that override and its component stay in Main.

### FlexiPages and layouts

- They live only in `*-ext`, renamed `_Ext`. Add new assignments only to `packages/<team>-ext/main/default/assignments/flexipage_assignments_<team>-ext.yaml`. The supported scopes are `OrgDefault`, app default, and `AppProfileRecordType`.
- Applying assignments is additive: an existing assignment with the same scope, app, object, action, form factor, profile and record type is skipped.
- **Translations are split by package.** The base file keeps field labels, case values and other non-layout entries. The Ext file has the same path and holds only the `<layouts>` entries. Keep translations inside the packages, not outside, so customers can still override them.
- **Old→new renames:** FlexiPage renames go in `packages/common-ext/main/default/assignments/flexipages_rename.csv`. The official page also names a `layouts_rename.csv` for a one-time layout migration, but develop has no such file, so ask Platform before relying on it.
- **Page-layout assignments are not packaged.** The team assigns every new layout in each org.
- The apply step runs after the Ext deploy through `scripts/ext-package-post-install.bash` → `scripts/apply_flexipage_assignments_from_yaml.bash`, and locally on `make push` / `make start`. One retrieve and one deploy handle the FlexiPage, action-override and customer-FlexiPage YAML and CSV files.

### Rollback

- **Apex or a trigger moved to Ext: a revert commit fails.** Main installs first and would re-add a name that Ext still holds. Move the code back under a `V2` name instead (`SectionTrigger` → `SectionTriggerV2`, `SectionTriggerHandlerV2Test`), and in the same change:
  - update every reference;
  - move the grants back (`MANAERP__…V2` in Main sets) and the suite entry back;
  - delete the Ext files.

  The original name can be reclaimed once every org is past the Ext versions that contained it.
- **Action override:** confirm the old Main component still exists, then run
  ```bash
  node scripts/flexipage-assignment-update/revert-action-overrides-from-csv.mjs \
    --org <alias> --rename-csv packages/common-ext/main/default/assignments/action_overrides_rename.csv --dry-run
  ```
  Review the result, then run it again without `--dry-run`.
- **Customer FlexiPage component references:** apply a reviewed copy of the CSV with the columns reversed, using `apply-flexipage-assignments-from-yaml.mjs --flexipage-component-rename-csv <csv> --dry-run`.

## Release and deploy

| Folder | Ends up in | Deployed by (repo) |
| --- | --- | --- |
| `packages/<domain>` | Main | Main version install |
| `packages/*-ext` | Ext | **Staging:** every deploy. **Preprod/prod:** `tbd.deploy-salesforce-ext` (a backend-repo workflow, not in `.github/workflows` here), after Main, only when `packages/*-ext` changed |
| `outside-packages/{override-standard,application,order,access-control,static-resource,site,dlrs}` | Unpackaged | `outside-package-post-install.bash`, after Main |
| `outside-packages/econtract-web-form` | Unpackaged | `outside-package-post-install.bash`, only when the org already has `SendWebFormQueueWriter.queueSendRequestsReturningRows` |
| `outside-packages/{settings,pre-install}` and the picklists in `override-standard/.../objects` | Unpackaged | `outside-package-pre-install.bash` / `build_package.bash` (`unpackaged/pre-install`), **before** Main |
| `outside-packages/order-form` | Its own `sfdx-project.json` | Separate `order-form-package` CI job (`tiered.pre_merge.yml`) |
| `outside-packages/{connections,inquiry}` | Unpackaged | Local scripts only (`start.bash`, `deploy_inquiry.bash`) |
| `outside-packages-ext/*` | Unpackaged | `ext-package-post-install.bash`, after Ext. On preprod/prod it ships only with an Ext release. Only `access-control` exists today |
| `outside-packages/feature-flags/main/<env>` | Unpackaged | `tbd.feature-flags.yaml`. Envs: `default`, `preproduction`, `production` |

- **Upgrade order:** Main → Ext → post-install steps, in one maintenance window. Between the Main and Ext upgrades, a moved trigger doesn't fire and a moved override may still point at the old component. Keep the window short.
- **A Main release must work with the previous Ext version.**
- **Staging installs unlocked packages, preprod and prod install managed ones (repo).** Passing on staging doesn't prove preprod or prod, which can hit failures staging can't:
  - Duplicate Name errors on Customer Community Plus–licensed sets;
  - `apexTestAccess` failures;
  - deprecation behaviour.

  The package build in CI is the only check of the package boundary. A scratch org deploys every package into one namespace, so it can't catch boundary errors.
- **Keep the build and release flow as it is:** `build_package.bash`, the pre-install and post-install scripts, and the workflows. When something can't be expressed in an existing step, write it as a manual PS/admin step in the runbook.

## CI and review gates

| Gate | State |
| --- | --- |
| `permission-set-check` in `tiered.pre_merge.yml` (new metadata granted in the v2 sets) | On develop |
| PR template line plus `check-no-main-lightning-component-overrides.mjs` | On develop (manual) |
| Ext package build with `apexTestAccess` | On develop (managed build) |
| Check that no FlexiPages, layouts or layout translations are added to base packages | Planned in the FlexiPage page; **not on develop** |

## Verify placement in the PR

With the erp-sf plugin, three commands cover this: `file-count --compare` (Main and Ext file counts, before and after; builds in a temporary worktree), `golden-rule` (no Main hits) and `perm-check` (CI's permission-set check on the branch's added files). Main tests must still pass without Ext.
