---
name: ci-fix
description: Find the cause of a failing erp-salesforce CI run (GitHub Actions link or pasted log), fix it on the branch without committing, and report with evidence.
disable-model-invocation: true
argument-hint: "<GitHub Actions run/job URL | pasted log>"
---

# CI fix

Input: `$ARGUMENTS`, a GitHub Actions run or job URL (erp-salesforce or manabie-com/backend, which builds and installs the packages) or a pasted log. Work from the erp-salesforce repo root.

The report format is [`../../reference/investigation-report.md`](../../reference/investigation-report.md); known failures are in [`../../reference/ci-gotchas.md`](../../reference/ci-gotchas.md).

## Steps

1. **Fetch** the failing log. For a URL: `gh run view <run-id> --repo <owner>/<repo> --log-failed` (or `--job <job-id>` from a `/job/<id>` URL), plus `gh run view <run-id> --repo … --json headBranch,headSha,event,jobs` for the branch, commit and which jobs ran. For a pasted log, use it as given. Save the relevant lines; they are evidence.
2. **Classify.** Name the workflow and job (`tiered.pre_merge`, `validate-sf-bundle`, `tbd.sf-scanner`, `permission-review`, a backend-repo package build or install) and the failure kind: metadata deploy, Apex test or coverage, package boundary (Main naming Ext), permission-set-check, scanner, package install/upgrade, or CI infrastructure. Then match it against `ci-gotchas.md`. A match decides the fix; say which row.
3. **Ours?** Compare with develop: `gh run list --repo <owner>/<repo> --branch develop --workflow <file> --limit 5 --json conclusion,headSha,createdAt`, and `git diff --stat $(git merge-base HEAD origin/develop)` for the files the branch touched. Decide one: caused by this branch, already failing on develop, or infrastructure/flaky.
4. **Reproduce** on `local_manabie` only: deploy the failing components or run the failing test class with the temp-project method in [`../prd-to-feature/reference/salesforce-checks.md`](../prd-to-feature/reference/salesforce-checks.md) (§ Deploy, § Apex tests). A CI-only failure (labels, deploy marker, job wiring, shared CI user) is reproduced by reading the workflow file in `.github/workflows/` instead.
5. **Fix** on the current branch (a new `fix/LT-…` branch only when the user asks), following `erp-sf:package-placement` for any metadata. Then run `golden-rule` and `/erp-sf:verify` for the touched area. When the fix belongs to another team or to the build scripts, write it as a proposal instead of changing it.
6. **Report** in the shared format and stop. Say whether to re-run CI, push the fix, or hand it on. Commit only when the user says so.
7. **Learn.** When the failure was new, add a row to `ci-gotchas.md` in this plugin (run `erp-sf-root` for its folder) and tell the user it changed.

When step 4 cannot reproduce the failure and step 2 found no match, switch to the `erp-sf:diagnosing-bugs` loop with the evidence gathered so far.

## Done

The report's Cause is backed by log lines or a reproduction, the Ours? line is decided, and either the fix is in the working tree with golden-rule and verify results, or a proposal names who owns it.
