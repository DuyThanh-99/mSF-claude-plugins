# Verification and evidence (Phase 7)

Drive the UI with the `erp-sf:verify` skill (headless Playwright, `sf org open --url-only`, never print the URL). Save every script you write next to its evidence so the run can be repeated.

## Before any run that syncs to staging

- local_manabie syncs order master data and orders to the **staging** backend. Run `PATH=/usr/bin:$PATH make sync-local-data` right before each such run (Save as Draft, submit, Clone/Link Run, order saves). `mlocal sync` and `make sync-local-data` fail with Homebrew Python (no `requests`); the `PATH` prefix fixes it for that command only.
- Ask the user before creating data that will sync to staging, and offer the options: seed with `TriggerSwitch.bypassTrigger` (no sync), real UI flow (syncs), or Apex only.
- Check staging read-only before mapping anything to it: Hasura `run_sql` with `"read_only": true` and a `SELECT` (`.env.local` endpoints, `requests` from `/usr/bin/python3`; plain `urllib` gets 403).
- A new local academic year needs a `Partner_Internal_Id__c` that exists in staging tenant 100016 for sync to work. Never reuse another org's or developer's partner id: the sync `UPDATE`s that staging row to point at your org. Use a `<year> Local Only` style id; sync of that year's products then fails harmlessly on staging.

## Seeding test data

- Prefer anonymous Apex in the scratchpad (`sf apex run -f <file>`), namespaced (`MANAERP__…`, `MANAERP.TriggerSwitch`). Bypass triggers only for setup rows that are not under test; run the feature itself through the real UI.
- `School_Admin` grants every custom permission to the admin, so "no permission" paths are Apex-only evidence unless a second user exists.
- Note every record you create so you can offer clean-up at the end.

## What to capture per AC

| AC kind | Evidence |
| --- | --- |
| Entry point, dialog, messages, toasts | Screenshot of the dialog and of the list view toast after Run (catch the toast within ~20 s) |
| Background job | Job record page screenshot; query of status and counts; `AsyncApexJob` class, status and errors |
| Created or changed data | Queries proving each field rule (dates, lookups, integration IDs, counts before/after) |
| Re-run / idempotency | A second run on the same records: counts unchanged, tracking fields moved |
| Notifications | Open the bell (`getByRole('button', {name: /Notifications/})`), screenshot each relevant `li`, then click one and capture the record it opens |
| Files (CSV) | Two-step query: `ContentDocumentLink` → `ContentVersion` (`IsLatest = true`), then `sf api request rest /services/data/v62.0/sobjects/ContentVersion/<id>/VersionData`; save the file |
| List views | Screenshot plus the row text and header columns |
| Hard-to-cause failures (limit errors, crashes) | Simulate through the same service methods the error handler calls, on a dedicated test record; label it "simulated" in the checklist |

Save under `.scratch/<feature-slug>/evidence/` (for example `acceptance/`, `success-path/`), with file names that start with the AC id.

## AC checklist

End with one table per PRD section: AC, status (✅ met, ⚠️ met with a caveat, ❌ not met), evidence type (UI / Data / Apex) and file names. Then list what was not seen in the UI and why, and the test data left in the org.

When a UI check disagrees with the code, check the org first: the local org often lags the branch (an old FlexiPage, an undeployed layout). Fix the org, not the code, and say so.
