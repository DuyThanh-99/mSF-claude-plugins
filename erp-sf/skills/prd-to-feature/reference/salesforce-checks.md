# Salesforce checks (Phases 4–5)

Run commands from the repo root unless a step says otherwise. Keep scripts and outputs in the session scratchpad. Run `sf` reads from `/private/tmp` when the repo's source tree is not needed: a tracked translation (`packages/order/.../User_Custom_Settings__c-ja/Allow_Soft_Delete_Contact__c.fieldTranslation-meta.xml`) breaks any `sf` command that resolves the repo tree (`TypeInferenceError`).

## Static checks

| Check | Command | Pass |
| --- | --- | --- |
| Jest | `npx jest <lwc folder>` for each touched component (and `npx jest packages/<pkg>-ext`) | All pass |
| Prettier | `npx prettier --check <touched files>`; `--write` only files you changed | Clean. If `--write` reflows lines you did not change (for example an HTML file develop never formatted), restore develop's file and re-apply only your edit |
| XML | `xmllint --noout <touched xml>` | No output |
| Permission sets | `/usr/bin/python3 scripts/permission-set-check/validate_access_xml.py` and `/usr/bin/python3 scripts/permission-set-check/check_permission_sets.py --changed-files <file listing added paths>` (`git ls-files --others --exclude-standard -- packages` plus added tracked files) | "passed". Homebrew Python lacks expat; use `/usr/bin/python3` |
| Sharing scan | `bash .github/scripts/run-sharing-security-scan.bash --path packages --output <scratch>/sharing.csv --max-violations 0` | 0 violations (public classes, test fixtures included, need `with sharing`) |
| Golden rule | `grep -rnw -E '<Ext names…>' packages \| grep -v '^packages/[a-z-]*-ext/'` | Only accepted runtime strings. Use `grep -r`, not `git grep`: new files are untracked |
| Annotation audit | Build the Main class list: `find packages -path '*-ext/*' -prune -o -name '*.cls' -print \| xargs -n200 basename \| sed 's/\.cls$//' \| sort -u`. Intersect with the identifiers in your Ext classes (`grep -oE '\b[A-Z][A-Za-z0-9_]*\b' … \| sort -u`, then `comm -12`). For each hit, check the class and each member used carry `@NamespaceAccessible` (watch overloads: a private overload can sit above the public one) | Every hit annotated |
| Controller parity | When a Main controller and its `…Ext` clone both exist: `diff <(sed 's/XExt/X/' XExt.cls) X.cls` | Only intended differences |

## Deploy to local_manabie (temp project)

`packages/*-ext` is in no `sfdx-project` file, and the repo tree triggers the `TypeInferenceError` above. Deploy through a temp project:

1. In the scratchpad: `deploy/sfdx-project.json` = `{"packageDirectories":[{"path":"force-app","default":true}],"namespace":"MANAERP","sourceApiVersion":"<from sfdx-project.json>"}`.
2. Copy the files to deploy under `deploy/force-app/main/default/<type>/` (classes with their meta files, pages, aura/lwc bundles, test suites, permission sets; a labels file holding only the new labels; FlexiPages and layouts when the UI check needs them).
3. From `deploy/`: `sf project deploy start -o local_manabie --source-dir force-app --ignore-conflicts --wait 45 --json > ../deploy.json`. Run it in the background; local deploys can queue for 10–20 minutes. Watch `SELECT Status FROM DeployRequest` (tooling API, from `/private/tmp`) when it hangs.
4. Parse `result.status`, `numberComponentsDeployed/Total`, `details.componentFailures`. Strip any text before the first `{` (CLI update warnings).

Single-class redeploys: `sf project deploy start -o local_manabie --metadata ApexClass:<Name> --ignore-conflicts` from `deploy/` after copying the file in.

The local org lags develop: deploy the Ext FlexiPages and layouts your feature changed before judging the UI.

## Apex tests

From `/private/tmp`:

```bash
sf apex run test -o local_manabie --class-names MANAERP.<TestA> --class-names MANAERP.<TestB> \
  --code-coverage --result-format json --wait 60 > <scratch>/tests.json
```

Report `summary.outcome/testsRan/passing/failing`, each failing test's message and stack, and `coverage.coverage[].coveredPercent` for every new or changed class. Run the Main test classes alone as well and confirm the Main classes reach 75 %.

Common failures:
- `MIXED_DML_OPERATION`: test inserts a User or permission set assignment and a business record in one transaction. Create the user first, then do the business DML inside `System.runAs(new User(Id = UserInfo.getUserId()))`.
- Picklist defaults apply on insert: to test "blank" legacy values, set the field to null and update after insert.
