---
name: sprint-planner
description: Use when planning PRD-backed Feature and Demo children for LT epics, either by discovering eligible current-user epics or by directly targeting an Epic key supplied by the user, with preview and explicit approval before Jira writes.
---

# Sprint Planner
## Purpose
Find PRD-backed child issues for LT epics. In discovery mode, find the current user's LT epics that do not yet have any child issue created by that user. In direct-target mode, process an explicitly supplied Epic key even if it is outside the discovery window, assigned to someone else, or already has children. Both modes are preview-first Jira workflows: never create or modify Jira issues until the user has reviewed the generated children and explicitly approved creation.
## Fixed project rules
-   Jira site: `manabie.atlassian.net`
-   Project: `LT` (Learning and Teaching)
-   Board: `69`
-   Resolve the current user dynamically with `atlassianUserInfo`; use `currentUser()` in JQL where supported. Never hardcode an account ID.
-   “My created child tasks” means child issues whose `creator.accountId` is the current user's account ID. Assignee is not a substitute for creator.
-   In discovery mode, an eligible epic has zero children created by the current user; children created by other users do not disqualify it. Direct-target mode intentionally bypasses this candidate filter, but never bypasses child auditing, duplicate detection, or approval.
-   Each PRD User Story produces one Jira **Feature** child.
-   Each selected epic produces exactly one additional Jira **Non-functional** child with summary `Demo`.
-   Each selected epic produces exactly one Jira **Non-functional** child with summary `Add TDD & review test cases` (Story Points `1`, precedent LT-115412). It always goes in the first sprint the epic's children use. Its description links the epic's TDD and test-case review page, which live in the Confluence folder the user names (default: `https://manabie.atlassian.net/wiki/spaces/CC/folder/3022094338/Thanh`); write `TDD: TBD` when no page exists yet.
-   **Sprint load:** every sprint that receives generated children must carry at least **20 Story Points** for the current user: the proposed children in that sprint plus the user's existing issues already in it (`sprint = <id> AND assignee = currentUser()`). When a sprint is under 20, move rows into it from a later sprint first; if it is still under 20, flag it in the preview and ask the user.
-   Every generated child defaults to the resolved next sprint. During review, the user may explicitly choose `No sprint`; that choice applies to every generated child.
-   The parent Epic itself never receives a Sprint value.
-   Every Feature child gets Story Points estimated from task complexity on the scale 1, 2, 3, 5 ([reference/estimation.md](reference/estimation.md)); the Demo and TDD children are always `1`. Story Points use LT's `customfield_10026` field.
-   Every generated child is **assigned to the current user** by default (the account ID from `atlassianUserInfo`); the user may pick another assignee in the review.
-   Do not automatically change status, priority, labels, or the Epic. Show these as unchanged unless the user explicitly edits them in the review.
-   Discovery mode scopes candidate Epic discovery to a rolling window from one month before through one month after execution time, using Jira's dynamic `created` date functions. Direct-target mode uses the explicitly supplied Epic key and does not apply this scope predicate. Child-count queries remain unrestricted by date.
## Required tools
Use the plugin's `atlassian` MCP server (Atlassian Rovo MCP, v2 endpoint `https://mcp.atlassian.com/v2/mcp`; tools are `mcp__plugin_erp-sf_atlassian__*`). Load the ones you need with one ToolSearch `select:` call. If they're missing or unauthenticated, ask the user to run `/mcp` and authenticate `atlassian`. Tools that aren't listed directly are deferred: find them with `discover` and run them with `executeRead` (reads) or `executeWrite` (writes). Tools used:
-   `atlassianUserInfo`
-   `searchJiraIssuesUsingJql`
-   `getJiraIssue`
-   `listJiraIssueRemoteIssueLinks` when the Jira description does not contain the PRD URL
-   `getConfluenceContent` for the PRD page
-   `listJiraProjectIssueTypesMetadata` or `getJiraIssueTypeMetaWithFields` when issue-type or field IDs need confirmation
-   `listJiraBoardSprints` for the next sprint
-   `createJiraIssue` only after final approval
If `createJiraIssue` is unavailable, stop before any write and tell the user that the Jira MCP configuration must expose it. Do not bypass MCP with tokens, curl, or an unapproved integration.
## Workflow
### 1. Preflight and identity
1. Load the Atlassian tools (see Required tools).
2. Call `atlassianUserInfo` and capture the account ID and display name.
3. Confirm the Jira MCP connection can perform read operations.
4. Resolve the next sprint before proposing any issue. Never silently assume a sprint.
### 2. Resolve the next sprint
Use the board from the fixed project context, not a sprint from another LT board. Prefer the board's own sprint list: `listJiraBoardSprints` with `boardId = 69`, `state = future` (find it with the Atlassian `discover` tool, run it with `executeRead`). It returns every future sprint with its ID, name and dates in one call. Fall back to the JQL below only when that operation is unavailable:

```jql
project = LT AND sprint in futureSprints() ORDER BY updated DESC
```

Inspect `fields.customfield_10020[]` in the results and retain only sprints where `boardId = 69` and `state = future`. Choose the future sprint with the earliest `startDate`. Capture:

-   Sprint ID
-   Sprint name
-   Board ID
-   Start date
-   End date

If no future sprint for board 69 is discoverable, stop and ask the user which sprint ID to use. If multiple candidates have the same earliest start date, show them and ask the user to choose. Always display the selected sprint in the epic selection and final preview.

### Direct Epic target

When the user explicitly supplies an Epic key, use direct-target mode instead of candidate discovery:

- Fetch the key with `getJiraIssue`, verify it is an Epic, and treat it as the only target; do not reject it for assignment, creation date, or existing children.
- Query and render its complete child audit, including total children, current-user-created children, issue types, keys, and summaries.
- Do not recreate an existing child with the same issue type and normalized summary; mark that proposal row as already satisfied.
- Skip the interactive Epic selector, but keep all PRD resolution, issue-type/field validation, complete preview, final approval, revalidation, and no-Epic-write safeguards. Example: direct target `LT-108504` is audited and previewed even if it is outside the window and already has children.

### 3. Find eligible epics (discovery mode)

Search all assigned LT epics within the dynamic ±1-month creation window, with pagination:

```jql
project = LT AND issuetype = Epic AND assignee = currentUser()
AND created >= startOfDay("-1M") AND created <= endOfDay("1M")
ORDER BY rank ASC, key ASC
```

Report the evaluated window start and end dates. The child query remains unrestricted by date so total and current-user-created child counts are complete.

For every returned epic, capture its key, summary, status, priority, description, and total child count. Then query children for all epic keys in batches:

```jql
project = LT AND parent in (<EPIC-KEYS>)
ORDER BY parent ASC, key ASC
```

Paginate until `isLast` is true. Compare each child's `creator.accountId` to the current user's account ID. Do not infer child ownership from assignee, reporter, or issue links.

Display only epics where the current-user-created child count is zero in discovery mode. Include total child count and current-user-created child count so the result is auditable. Render every eligible epic in a plain-text or Markdown table before opening an interactive selector; the table is the source of truth. Never truncate the list, omit trailing rows, or assume a picker displayed all options. If the selector has an option/count limit, ask for selected Epic keys as comma-separated text, in batches if necessary, and verify every selected key is present in the full table. If there are no eligible epics, report that and stop without asking for creation approval.

### 4. Ask the user to select epics

Show the evaluated Epic date window and resolved next sprint for discovery mode, then ask the user to choose one or more eligible epics by key. In direct-target mode, show the supplied Epic's audit instead and continue without a selector. Do not create issues at this stage. Remind the user that the Epic will remain unsprinted while all generated children receive the selected sprint. Do not treat a truncated or dismissed picker response as a selection; direct-target mode still requires an explicit Epic key.

### 5. Fetch and parse each PRD

For each selected epic, resolve the PRD in this order:

1. Confluence URL in the Jira description.
2. Confluence URL in remote issue links.
3. A linked PBT issue only when it provides the PRD source.
4. A Confluence page found by exact epic/PRD title search, only when the match is unambiguous.

Fetch the full page as Markdown with `getConfluenceContent`. Cache page content by page ID during the run.

Extract, in source order:

-   The PRD URL.
-   Each `User Story` entry under `Requirements`.
-   The complete User Story statement (`As`, `I want`, `so that`).
-   Its acceptance-criteria rows, preserving Given / When / Then wording.

Do not manufacture a User Story from a heading, epic summary, or acceptance criterion. If the PRD cannot be found, cannot be fetched, or has no identifiable User Story entries, mark that epic as blocked in the preview and do not create children for it. Never fill missing requirements with assumptions.

### 6. Build the review proposal

For each extracted User Story, propose one Feature child in PRD order:

-   **Issue type:** `Feature` (confirm the LT issue-type ID before writing)
-   **Summary:** `[US1] <concise capability title>`, then `[US2] ...`
-   **Parent:** selected epic key
-   **Description:** the User Story statement, its PRD-derived acceptance criteria, and the PRD link
-   **Story Points:** `customfield_10026` = the estimate from [reference/estimation.md](reference/estimation.md) (1, 2, 3 or 5), with its five driver scores
-   **Sprint:** resolved next-sprint ID in `customfield_10020`; if the user explicitly chooses `No sprint`, show that value and omit the field from the create payload
-   **Assignee:** the current user (from `atlassianUserInfo`) unless the user picks someone else in the preview
-   **Status/priority/labels:** unchanged unless the user edits them in the preview

For each selected epic, propose exactly one TDD child:

-   **Issue type:** `Non-functional` (confirm the LT issue-type ID before writing)
-   **Summary:** `Add TDD & review test cases`
-   **Parent:** selected epic key
-   **Description:** one line on the work (write the TDD, review test cases with QA), the TDD link or `TDD: TBD`, the Confluence folder for the TDD and review page, and the PRD link
-   **Story Points:** `customfield_10026 = 1`
-   **Sprint:** the first sprint any child of this epic uses

For each selected epic, propose exactly one Demo child:

-   **Issue type:** `Non-functional` (confirm the LT issue-type ID before writing)
-   **Summary:** `Demo`
-   **Parent:** selected epic key
-   **Description:** a concise demo scope listing the generated User Story children and linking to the PRD; do not invent acceptance criteria
-   **Story Points:** `customfield_10026 = 1`
-   **Sprint:** the same resolved next-sprint ID in `customfield_10020`; if the user explicitly chooses `No sprint`, show that value and omit the field from the create payload

Check the sprint load before rendering: for each sprint used, sum the proposed Story Points and the current user's existing issues in that sprint. Rebalance or flag any sprint under 20 points (see Fixed project rules).

Score every Feature with [reference/estimation.md](reference/estimation.md) before rendering: locate the code each story touches, score the five drivers, and map the total to points. The step is done when every Feature row has driver scores, points and a main driver, and every row that scored 9 or more has a split suggestion.

Show a complete review table before any `createJiraIssue` call:

```text
Next sprint: <name> | ID <id> | Board 69 | <start> – <end>
Sprint assignment: <selected sprint name or No sprint>
Assignee: <current user display name> (all children, unless edited)
Epic sprint change: none

| Proposed child | Type | Parent | Summary | B | L | I | U | V | SP | Main driver | Sprint | PRD source |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| US1 | Feature | LT-... | [US1] ... | 2 | 2 | 1 | 1 | 1 | 5 | <one line> | <sprint name or No sprint> | <URL> |
| US2 | Feature | LT-... | [US2] ... | 0 | 1 | 1 | 0 | 1 | 2 | <one line> | <sprint name or No sprint> | <URL> |
| TDD | Non-functional | LT-... | Add TDD & review test cases | — | — | — | — | — | 1 | fixed | <first sprint> | <URL> |
| Demo | Non-functional | LT-... | Demo | — | — | — | — | — | 1 | fixed | <sprint name or No sprint> | <URL> |

Sprint load: <sprint>: <proposed> + <existing> = <total> points (≥ 20 required), one line per sprint.
Total: <sum> points. <split suggestions, sprint-fit note, questions that would move a bucket>
```

Also show each proposed description or an expandable/full-text equivalent. Ask the user to review and allow edits to summaries, descriptions, story points, sprint selection including `No sprint`, or assignee. Issue types are fixed: User Story children are `Feature` and the single Demo is `Non-functional`; do not substitute another type. Re-render the complete proposal after edits.

### 7. Final approval gate

Ask a separate, explicit question such as:

> Create these `<N>` child issues under `<epics>` and assign them to `<sprint name>`, or leave them unsprinted as explicitly shown? The Epic records will not be changed.

A selection, “looks good”, or review comment is not approval. Treat cancel, uncertainty, or silence as rejection. On rejection, perform zero Jira writes.

### 8. Revalidate and create

After approval and immediately before writing:

1. Re-run the child query for every selected epic.
2. For discovery-mode epics, if any current-user-created child now exists, exclude that epic and tell the user why before creating anything for it. For a direct target, do not exclude it solely because children exist; compare the proposal against the fresh child audit and omit exact same-type/same-summary duplicates.
3. Revalidate the selected sprint ID, or the explicit `No sprint` choice, issue types, parent keys, and Story Points field.
4. If the proposal changed after approval, show the new proposal and obtain approval again.

Create only proposal rows that are not already satisfied by an existing same-type/same-summary child. Create issues sequentially with `createJiraIssue`: the TDD child first, then Features in PRD order, then Demo last for each epic. Use the MCP tool's current schema; do not guess field payload shapes. Pass the parent epic, set `assignee_account_id` to the approved assignee, and set `customfield_10026` on every created child. Set `customfield_10020` on every created child only when a sprint was selected; when the user selected `No sprint`, omit `customfield_10020` entirely. Never set `customfield_10020` on the Epic.

If one creation fails, stop creating children for that epic, preserve the already-created keys, report the exact error, and do not retry automatically. Re-query after successful creation and report each created key with a Jira link.

## Safety rules

-   Preview is mandatory; there is no implicit write mode.
-   Never call `createJiraIssue` while resolving epics, fetching PRDs, parsing stories, or rendering a preview.
-   Never edit or assign a sprint to an Epic.
-   If a sprint is selected, assign it to every generated child, including `Demo`; if the user explicitly selects `No sprint`, omit the Sprint field from every generated child.
-   Never create a child from a missing or ambiguous PRD.
-   Never duplicate children after a partial run or direct targeting; revalidate current children and compare issue type plus normalized summary before writing.
-   Never use a hardcoded current-user ID or hardcoded sprint as the runtime source of truth.
-   Never create a substitute Task issue type when the required LT types are unavailable; stop and report the mismatch.

## Verification checklist

Before reporting a run as complete, verify:

-   Current user was resolved dynamically.
-   In discovery mode, the Epic discovery window was evaluated dynamically as one month before through one month after execution time; in direct-target mode, the supplied key was fetched and confirmed as an Epic.
-   Every displayed discovery-mode eligible Epic has zero children created by that user; every direct target has a complete child audit.
-   Every selected PRD User Story has exactly one proposed Feature.
-   Every selected epic has exactly one proposed Demo and exactly one proposed `Add TDD & review test cases` child in its first sprint.
-   Every sprint that receives children shows a sprint load of at least 20 points, or the shortfall is flagged and the user decided.
-   Every proposed Feature has five driver scores and Story Points 1, 2, 3 or 5 mapped by [reference/estimation.md](reference/estimation.md) (or the user's explicit override); the Demo has `1`; every row that scored 9 or more shows a split suggestion.
-   Every proposed child has the selected sprint, or is explicitly marked `No sprint`.
-   Every created child has the approved assignee (the current user by default), confirmed in the post-create query.
-   No Epic was modified.
-   User approved the exact final proposal before any write.
-   Created issue keys were re-fetched or confirmed by a post-create query.
-   Partial failures, skipped epics, and already-satisfied duplicate proposal rows are explicitly reported.
