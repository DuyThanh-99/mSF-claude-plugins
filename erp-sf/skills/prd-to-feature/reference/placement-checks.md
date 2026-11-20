# Placement checks (Phase 2)

The rules are in [`package-placement.md`](../../../reference/package-placement.md) (in this plugin; read the whole file). These are the checks that caught real problems in past features.

## Latest develop first

- Before placing anything, compare the files you will touch with `git log --oneline HEAD..origin/develop -- <paths>`. A recent move into `packages/*-ext` (for example LT-114803 moving the clone UI) changes where your edits belong.
- If your branch predates such a move: back up (`git diff > patch`, tar the untracked files), stash only the feature paths, fast-forward to `origin/develop`, `git stash apply` (not pop). Git follows renames, so edits usually land on the `…Ext` files; resolve the rest by hand, then `git reset -q` to leave the tree unstaged as it was.

## What can and cannot leave Main

| Component | Usually | Why |
| --- | --- | --- |
| Fields, objects, labels, non-layout translations, list views | Main | Objects and fields never move |
| List view button (web link) on a Main object, its VF page and page controller | Main | The Main object's `searchLayouts.listViewButtons` names the button; a Main object cannot list an Ext button. Ext web links only appear on Ext FlexiPage action lists |
| LWC / Aura reached only from Ext or through Lightning Out strings | Ext | Same as the clone UI |
| `@AuraEnabled` controller for Ext UI | Ext clone `…Ext` | `@AuraEnabled` members cannot take `@NamespaceAccessible` |
| Service called only by Ext code | Ext | Make Main stop calling it: give Ext its own batch or entry point that calls annotated Main members (Ext → Main only). Avoid Main interfaces implemented by Ext classes (no precedent) |
| Main code that Main metadata still calls (page controllers, job bookkeeping) | Main | Keep only what Main needs; do not keep dead `@AuraEnabled` endpoints |

## Boundary rules to check in the plan

- **Annotations.** List every Main class and member Ext will call. Each needs `@NamespaceAccessible` on the class and on the member (static finals, constructors and inner classes too). Ext tests count: use plain SOQL instead of unannotated Main helpers (for example a Main `lockJob`).
- **Test data.** Ext tests cannot rely on Main `@IsTest` fixtures unless the class and members are annotated (`MockMasterDataTest` is). Give Ext its own fixture when needed.
- **Main without Ext.** Main tests must pass and reach 75 % coverage with no Ext installed; test Main logic with given inputs instead of calling Ext.
- **Release window.** Main installs before Ext. Make a Main-first window fail safe: give new Ext Lightning Out apps and hosts their own names, so a new Main page cannot open an old Ext component in the wrong mode. Shared components must reject unknown modes instead of defaulting.
- **Golden rule.** No Main metadata names an Ext component. The only accepted exception is a runtime string (Lightning Out app names in a VF page), following `CloneProductsToNextAY.page`.
- **Permission sets.** Packaged sets with `<license>` can take new grants; changing the `<license>` tag itself is what broke upgrades before.
- **v1 users.** Ext Apex reaches v2 users only (`*_Extension_Access` sets are assigned to nobody). Record it as an open question when the feature needs Ext Apex.
