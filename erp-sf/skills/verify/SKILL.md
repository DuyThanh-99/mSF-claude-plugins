---
name: verify
description: Drive a change end-to-end in the local_manabie scratch org UI (headless Playwright via sf frontdoor login). Use when verifying Salesforce UI/Apex changes at runtime.
---

# Verify in the local scratch org

## Login (headless, no Chrome extension needed)
- The repo's Playwright (`node_modules/playwright`) expects a browser revision that is not downloaded.
  Launch with the cached Chrome for Testing instead:
  `chromium.launch({ headless: true, executablePath: '~/Library/Caches/ms-playwright/chromium-1248/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing' })`
- Log in like `tests/utils/auth.ts`: `sf org open -o local_manabie --path "<path>" --url-only --json` and `page.goto(result.url)`. Never print the URL (it carries a session).
- Run scripts from the repo root with `NODE_PATH=$PWD/node_modules node <script>` (keep the script in the scratchpad).

## Org gotchas
- The org is namespaced (`MANAERP`): queries and anonymous Apex need `MANAERP__` prefixes; list view
  `filterName=All` fails, use the ListView Id (`SELECT Id FROM ListView WHERE SobjectType = 'MANAERP__Product__c'`).
- Fields deployed via Metadata API get no FLS: grant read through a temporary permission set
  (`Tmp_<ticket>_FLS`, deployed with `--metadata-dir`) and `sf org assign permset`.
- The org can lag develop; deploy explicit `--source-dir` lists. Source tracking may reference files
  from other branches (`TypeInferenceError` on preview) — don't rely on `deploy preview`/`make push`.
- `packages/order-ext` is not in any sfdx-project file: deploy its layouts via a temp metadata dir
  (+ `Profile` `Admin` with only `layoutAssignments`). Flexipages need separate activation.
- Anonymous Apex is case-insensitive: a variable `fee` clashes with a constant `FEE`.
- `School_Admin` grants every custom permission to the admin, so "permission denied" paths cannot be
  exercised as this user.

## Driving Lightning
- List view rows: `tr[data-row-key-value="<recordId>"] .slds-checkbox_faux` to select.
- List-view buttons beyond the first few are under `getByRole('button', { name: 'Show more actions' })` → `[role=menuitem]`.
- VF pages render in an iframe: pick `page.frames()` by URL (e.g. `/apex/<PageName>`), not by `[role=dialog]`
  (the Lightning shell has hidden dialogs).
- Record page related lists lazy-load; read Files/attachments through the API
  (`sf api request rest /services/data/v62.0/sobjects/ContentVersion/<id>/VersionData`).
- Notifications: click `getByRole('button', { name: /Notifications/ })` and read the panel text.
