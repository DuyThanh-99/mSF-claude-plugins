---
name: prd-to-feature
description: Take a PRD or Jira epic (e.g. /erp-sf:prd-to-feature LT-110982) through spec, package placement, implementation, local verification with per-AC evidence, and PR handoff in erp-salesforce.
disable-model-invocation: true
argument-hint: <epic key | PRD Confluence URL> [feature-slug]
---

Deliver the feature in `$ARGUMENTS` from PRD to a reviewed, verified, staged change in `erp-salesforce`. Work in phases. Each phase ends on its **done** line, and phases marked **gate** stop for the user's approval before the next one starts.

Three ideas run through every phase:
- **Trace**: every PRD acceptance criterion (AC) maps to code, a test and evidence. The AC table you build in Phase 1 is the spine of the work; keep it current.
- **Boundary**: Main (Core) and Ext are separate packages in one namespace. Place every file by [`package-placement.md`](../../reference/package-placement.md), and remember the local org cannot see boundary errors; only the CI managed build does.
- **Evidence**: a claim is done when it has a test result, a query result or a screenshot on disk, named by AC.

## Guardrails

- Commit, push, and open or update PRs only when the user asks. Staging is not permission to commit.
- On shared orgs (dev-staging, staging, preprod, prod) run read-only queries and reports only.
- Ask before any action that writes test data to a shared backend (local_manabie syncs to staging).
- Keep existing stashes. Back up before you stash, rebase or reset.
- Keep docs out of staged changes: `CLAUDE.md`, `GLOSSARY.md`, `docs/adr/`, `.scratch/`, and personal files.
- Keep the build and release flow as it is (`build_package.bash`, pre/post-install scripts, workflows). Raise flow problems with the user instead of editing them in a feature PR.

## Phase 0: Intake

1. Fetch the epic (`getJiraIssue`) and the PRD in full (markdown). Record scope, out of scope, prerequisites, every AC id, validation messages, and the EN/JP translation table.
2. Find related tickets the epic depends on and their state (merged, open PR, not started).
3. `git fetch origin develop`, then `git log --oneline HEAD..origin/develop`. Read any recent commit that touches the same module, especially moves into `packages/*-ext`. Work from the latest develop.
4. Create `.scratch/<feature-slug>/` (see [`issue-tracker.md`](../../reference/issue-tracker.md)).

**Done:** the AC list (ids, one line each) and the dependency states are written at the top of `.scratch/<feature-slug>/spec.md`.

## Phase 1: Spec (gate)

Write `.scratch/<feature-slug>/spec.md` from the PRD and the code you read, using the spec template in [`../to-spec/SKILL.md`](../to-spec/SKILL.md) (Problem, Solution, User Stories, Implementation Decisions, Testing Decisions, Out of Scope, Further Notes; read it, skip its publishing step), plus:
- **AC trace table**: AC id → behaviour → module that implements it → test seam.
- **Code placement table**: every new or changed file → Main / Ext / outside → one-line reason (the "Decide" questions).
- **Open questions**: gaps between the PRD and the code (missing wording, permission conflicts, backend contracts). Never invent JP text silently; mark it for PM confirmation.

Agree the test seams with the user (the highest seam that works, ideally one per module).

**Done:** the user approves the spec, seams and open questions.

## Phase 2: Placement check (gate)

Re-check the placement table against the code you are about to touch. Read [reference/placement-checks.md](reference/placement-checks.md) and apply each check.

**Done:** every file has a target and reason, nothing in Main will name an Ext component, and every Main member Ext will call is listed for `@NamespaceAccessible`. The user approves the table.

## Phase 3: Implement

Split the work into **slices**: one module or one AC group whose files do not overlap with another slice. Hand each slice to the `erp-sf:sf-feature-builder` subagent (Agent tool, `subagent_type: "erp-sf:sf-feature-builder"`, from the erp-sf plugin). It builds test-first and calls the matching Salesforce skill for each kind of file. Brief it with pointers, not copies: the spec path, the slice's AC ids, its placement rows and test seam. Run slices that touch different files in parallel; run a slice that depends on another's Main members after it.

Review each report before the next phase: placement, annotations, tests, open questions. Bring any open question to the user. Slices follow the same rules you do:
- Keep each AC's behaviour traceable: name tests after the behaviour, and note the AC id in the spec table.
- Labels and translations: EN and JP word for word from the PRD; new UI text not in the PRD goes on the open-questions list.
- Grants: every new class, page, field and tab in the 3 v2 sets (CI `permission-set-check`); Main grants only in Main sets.
- Every new class declares `with sharing` (or a deliberate alternative with a comment).

**Done:** all ACs in the trace table have code and a test, and Phase 4 is green.

## Phase 4: Static checks

Run every check in [reference/salesforce-checks.md](reference/salesforce-checks.md) § Static checks: Jest, Prettier on touched files only, XML lint, permission-set check, sharing scan, golden-rule grep, annotation audit.

**Done:** every check passes, or each failure is explained as pre-existing with its evidence.

## Phase 5: Deploy and Apex tests on local_manabie

Deploy with the temp-project method and run the feature's test classes with coverage ([reference/salesforce-checks.md](reference/salesforce-checks.md) § Deploy, § Apex tests).

**Done:** all feature test classes pass. Coverage of each new or changed class is recorded. Main tests alone cover the Main classes at 75 % or more (Main must pass without Ext).

## Phase 6: Code review (gate)

Run `/code-review medium` on the working tree. For every finding, check the code and sort it: real and ours, inherited from develop, by design (cite the PRD or spec), or not feasible (say why). Present the table with a recommendation per row.

**Done:** the user chooses which findings to fix; the fixes are made (by `erp-sf:sf-feature-builder`, one brief listing the chosen findings) and Phases 4–5 are green again.

## Phase 7: Verify every AC (gate)

Follow [reference/verification.md](reference/verification.md) with the `erp-sf:verify` skill. Run the real flows in the UI, including the success path, re-runs and failure paths, and save evidence per AC.

**Done:** `.scratch/<feature-slug>/evidence/` holds the evidence, and you have shown the user the AC checklist: every AC marked ✅ / ⚠️ with its evidence type (UI, Data, Apex) and file names, plus what was not seen in the UI and why.

## Phase 8: Handoff

1. Stage the feature files only (`git add packages outside-packages* …`), leaving docs out. Show the staged summary by area.
2. On request, write the PR body with the `erp-sf:pr` skill (placement table, golden-rule result, file counts or TBD, release order). For the TDD, tell the user to run `/erp-sf:create-tdd <epic>` (it is user-invoked).
3. When CI fails, read the job and the deploy report before changing code. Known false positives are in [`../../reference/ci-gotchas.md`](../../reference/ci-gotchas.md).

**Done:** the user has the staged summary, the open questions still waiting on others, and the release notes (Main and Ext in one window, anything manual).
