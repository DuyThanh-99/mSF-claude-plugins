---
name: create-tdd
description: Draft a Technical Design Document for a Jira epic (e.g. /erp-sf:create-tdd LT-98426) from its PRD, test cases and code, and save it as a Confluence draft for review.
disable-model-invocation: true
argument-hint: <epic key or Jira URL> [confluence folder/page id]
---

Draft a TDD for the epic in `$ARGUMENTS`, following the team template, and leave it as an **unpublished Confluence draft** for the user to review.

## Fixed references

| What | Where |
| --- | --- |
| Atlassian site (`cloudId`) | `manabie.atlassian.net`, space key `CC` |
| TDD template (structure to follow) | Confluence page `2889023502` |
| Worked example (tone, depth) | Confluence page `2976481350` (LT-112562) |
| Default parent folder for TDDs | `1351450670` (use the id from `$ARGUMENTS` if given) |

The Atlassian tools are `mcp__plugin_design_atlassian__*`. Load the ones you need with one ToolSearch `select:` call. If they're missing, start auth with `mcp__plugin_design_atlassian__authenticate` and send the user the URL.

## Steps

### 1. Gather sources

The step is done when you hold all five of these, or have recorded which one doesn't exist:

1. **Epic.** `getJiraIssue` on the key. Note summary, assignee, status, and the PRD link in the description. `atlassianUserInfo` gives the author's name and account id.
2. **PRD.** `getConfluencePage` (markdown). Read it in full: scope, out of scope, prerequisites, every AC, the Patterns tables, Design and Translation.
3. **Template and example.** Fetch both every run, because the template changes. The template is the source of truth for section order and field names.
4. **Test case page.** `searchConfluenceUsingCql` with `title ~ "<KEY>" AND space = CC AND type = page`. Note its URL, the QA owner, and the TC range.
5. **Code.** Run `git log --all --oneline -i --grep=<KEY>`. For each commit, read `git show --stat <sha>`, then read the new and changed classes, LWC, objects/fields, permission sets and labels with `git show <sha>:<path>`. The commit is often on `develop`, not the current branch. If no commit exists, explore the codebase for the components the PRD touches and write the design as **Proposed**.

Large Confluence results are written to a file. Extract the body with `python3 -I -c "import json,sys; …"` into the scratchpad and Read that.

### 2. Write the draft

Write markdown to the scratchpad as `TDD-<KEY>-<slug>.md`. Use the template's header table and every section, in template order: Context & Scope, Solution & Code Placement (2.1–2.5), Data & Configuration, APIs & Backend Integration (+ 4.1), Permissions & Security, Testing/Deployment/Recovery (6.1–6.7), Risks & Decisions, Changelog.

Rules:

- **Traceable.** Every claim about behaviour cites a PRD AC id or names the class, field or constant it came from. Link the PRD, epic, test case page and PR in the header.
- **Real numbers or TBD.** Limits, constants and chunk sizes come from code. Anything you didn't measure (CPU, heap, latency, file counts) is `TBD — measure …`.
- **Readable.** Short sentences. Break multi-step flows into numbered lists or tables, not run-on paragraphs.
- Fill 2.1 with components, source of truth per data item, main flow, transaction boundaries, partial failure, concurrency and idempotency, taken from the actual code paths.
- Fill 5.1 from the permission set diffs: every new field, class and tab, and which sets grant it.
- Raise **open questions** for gaps you found in the code against the PRD, such as missing backfills, unconfirmed backend contracts, or FLS the background job needs. These are the most valuable part for reviewers.
- Name people as plain text (`Duy Thanh Ta`), not `@name`. Markdown mentions don't render.

The step is done when every template section has content or an explicit TBD, and every code claim traces to a file you read.

### 3. Create the Confluence draft

- Run `createConfluencePage` with `contentFormat: "markdown"`, `status: "draft"`, space `CC`, the parent id, the title `Technical Design — <Epic summary> (<KEY>)`, and the body without its H1.
- **Always use `status: "draft"`.** Publish only when the user says so. Then call `updateConfluencePage` with `status: "current"` and the same body.
- Report:
  - the draft link
  - the local markdown path
  - the TBDs and open questions they need to fill
  - that mentions and checkboxes need retyping in the editor

### 4. Link the TDD from the test case page

`updateConfluencePage` replaces the whole body. The test case page belongs to QA and is large, so don't rewrite it. Give the user the TDD link to paste into the page's `TDD:` line.
