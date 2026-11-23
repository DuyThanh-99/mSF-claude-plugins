---
name: org-investigate
description: Find the root cause of a bug ticket by investigating a connected Salesforce org (customer sandbox, preprod, staging) read-only, matching the org's installed package version to the code, and reporting with evidence.
disable-model-invocation: true
argument-hint: "<ticket key or URL> [org alias] [login URL]"
---

# Org investigate

Input: `$ARGUMENTS`: a Jira or service-desk ticket (MANACS-…, LT-…), and the org it happens in. Work from the erp-salesforce repo root; save notes and query output under `.scratch/<ticket>/`.

The org is someone else's: everything here is **read-only**. Queries, describes, installed-package lists and git reads are fine. Trace flags (needed for debug logs), data fixes, anonymous Apex, deploys and permission changes are writes: propose them in the report and run one only after the user says yes for that org. The erp-sf guard hook asks before such commands.

Report format: [`../../reference/investigation-report.md`](../../reference/investigation-report.md). Evidence queries: [`queries.md`](queries.md).

## Steps

1. **Load the ticket**: the Jira issue and any linked Confluence, Slack thread or pasted `.docx`. Write down the symptom, the affected users and records (IDs), when it happened, and what the user expected. Missing record IDs or time window: ask for them before querying.
2. **Connect.** Check `sf org display -o <alias>`. If it is not connected, ask for the login URL (`https://<my-domain>.sandbox.my.salesforce.com` or `https://test.salesforce.com`). Write every query for the step to a file and run them in one go with [`org-queries.sh`](org-queries.sh) from this folder, in the background, while the user signs in in the browser: some orgs (preprod) expire CLI sessions within minutes, so a login followed by separate commands fails.
3. **Pin the version.** From the `installed` output, take the `Manabie All In One` and `Manabie All In One Ext` `SubscriberPackageVersionId` (`04t…`) and map each to its build on the Dev Hub (`queries.md` § Version). Its `Tag` is a git tag in this repo whose suffix is the commit. Read the code at that tag (`git show <tag>:<path>`, `git diff <tag> origin/develop -- <path>`), not develop.
4. **Collect evidence** for the symptom with `queries.md`: the records and their field history, the module's own log and error objects, failed async jobs, recent setup changes, and the user's access. Describe an object before querying fields you are unsure of. Keep each output file; cite it in the report.
5. **Explain.** Trace the symptom through the code at the pinned tag to one cause. Classify: a bug still on develop; a bug already fixed on develop (name the commit and the first package version with it); org data or configuration; a missing permission or assignment; or an integration/backend issue (name the system).
6. **Reproduce** on `local_manabie` when the cause is in code: `mlocal` for a working org (see `erp-sf:local-org`), then seed the same data shape and run the flow or test.
7. **Report** in the shared format, plus a short draft reply for the ticket. Stop there: posting the reply, fixing data in the org, and starting the code fix (`/erp-sf:ci-fix` style on a branch, or `/erp-sf:prd-to-feature` for larger work) wait for the user.

## Done

The cause is classified, each claim in it has a query file or code line behind it, the org's package version is named, and nothing in the org was changed without the user's yes.
