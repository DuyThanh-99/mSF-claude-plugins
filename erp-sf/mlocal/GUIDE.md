# mlocal guide

`mlocal` is a personal tool that finishes the setup of the `local_manabie` scratch org after `make start`.
Its code ships in the erp-sf plugin (`erp-sf/mlocal/`), so inside Claude Code `mlocal` is on the Bash PATH while the plugin is enabled. This machine's settings and secrets stay outside git in `~/.manabie-local/config.env`, with logs in `~/.manabie-local/logs/`. For a terminal, symlink it: `ln -sfn <plugin>/erp-sf/mlocal/mlocal ~/.local/bin/mlocal`.

## What it fixes

`make start` builds a working org, but the org can't make real staging callouts or run realistic tests:

| Gap after `make start` | What mlocal does |
| --- | --- |
| No signing certificate, wrong `iss`/org id/`manabie_id`, named credentials point at old hosts | Imports the keystore, redeploys the external and named credentials |
| Admin user can't see the Manabie apps | Assigns the School Admin permission set group |
| Sample data fails on collisions and has gaps | Gap-fill loader: creates only what's missing |
| Current academic year, product links, billing dates are stale | Fixups |
| Staging back-office mapping is stale | `make sync-local-data` plus pushing billing master and product offerings |
| No student that syncs to staging | Creates one and waits for the sync log |

## Set up a new machine

1. Install the plugin (`/plugin marketplace add DuyThanh-99/mSF-claude-plugins`, `/plugin install erp-sf@msf-claude-plugins`), or clone the plugin repo.
2. Copy the keystore `.jks` from the old machine (or the team) to a private folder.
3. `mkdir -p ~/.manabie-local && cp <plugin>/erp-sf/mlocal/config.env.example ~/.manabie-local/config.env && chmod 600 ~/.manabie-local/config.env`, then copy the values over from the old machine's `config.env` and point `JKS_PATH` at the keystore. Leave `REPO_ROOT` blank to use the repo you run from.
4. In the repo: `npm install` (the cert step uses its Playwright), `make start`, enable Identity Provider, then `mlocal all`.

Prerequisites: `sf`, `jq`, `node`, `python3`, `git`. Without `config.env`, `mlocal` stops and prints step 3.

## One-time setup

1. Check `~/.manabie-local/config.env` (chmod 600, never commit):
   - `JKS_PATH`: path to the staging keystore (`.jks`)
   - `JKS_PASSWORD`: the keystore password (required for the cert step)
   - `CERT_NAME`, `JWT_ISS`, `JWT_ORG_ID`, `JWT_MANABIE_ID`, `ADMIN_URL`, `WEBAPI_URL`, `STUDENT_GRADE_PID`: already set
2. Playwright and Chrome for Testing come from the repo's `node_modules`. Run `npm install` in the repo if the cert step can't find them.
3. Check that `mlocal help` works. If not, make sure `~/.local/bin` is on your PATH.

## Create a fresh org

Run from the repo root, on the branch you want to test (check it out first, so its metadata is deployed):

```bash
make delete-scratch && make start     # or: mlocal reset (asks you to type "yes")
mlocal all
```

Before the cert step on a **fresh** org, enable Identity Provider once: Setup > Identity Provider > Enable.
Otherwise the keystore import ends on "Data Not Available" and the cert step fails.

If `make start` fails halfway, fix the cause and re-run `make start` (it continues on the existing org), then `mlocal all`.

## Commands

| Command | What it does |
| --- | --- |
| `mlocal all` | Runs every step in order. Safe to re-run |
| `mlocal perm` | Assigns the School Admin group, and `Product_Request_Access` if it exists |
| `mlocal cert` | Imports the keystore as `new_staging_2027`. Skips if it exists. `--manual` opens the page and waits. `--probe` only checks the UI selectors |
| `mlocal creds` | Deploys external credential `SF_Manabie_JWT` and both named credentials from a temp project. Grants the principal through permission set `Local_Manabie_JWT_Access` |
| `mlocal data [--dry-run]` | Loads `scripts/data/data/*.json`, matching by natural key. `--dry-run` prints the plan without writing |
| `mlocal fix` | Sets one current academic year, links products, sets Product Grade rows, shifts billing dates to cover today, enables the student sync switch |
| `mlocal sync [--map-only]` | Runs `make sync-local-data`, pushes billing master and product offerings, checks staging knows your locations, grades and years. `--map-only` skips the pushes |
| `mlocal student [LocationPartnerId]` | Creates a student with a unique username and Main Location, requests the sync, polls the log |
| `mlocal verify` (or `status`) | Checks the callout auth (expects `400 invalid_request_missing_student_id`), data counts and the synced student |
| `mlocal reset` | `make delete-scratch && make start && mlocal all`, after confirmation |

`mlocal all` order: perm, cert, creds, data, fix, sync, student, verify.

## Daily use

- **Before every action that reaches the staging backend** (Save as Draft, submit, clone-link Run): run `mlocal sync`.
  Other developers share the staging mapping and can overwrite yours (last writer wins).
- After deploying new metadata, an outside or Ext permission set is not in the School Admin group. Assign it to the admin user yourself.
- To test a different location, run `mlocal student <LocationPartnerId>`. Known staging locations: `TLocation2026Local1`, `TLocation2026Local2`, `org`.
- Re-run `mlocal all` any time. Every step is idempotent.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `org local_manabie not found` | Run `make start` first |
| Cert step fails | Check `JKS_PASSWORD`. On a fresh org enable Identity Provider. Look at the screenshot in `~/.manabie-local/logs/`. Fall back to `mlocal cert --manual` |
| Data table shows `failed N: ...` | Read the note column. `mlocal data --dry-run` shows the plan again |
| `Academic year id ... not found` on offering push | The sample year `dev_2026` is remapped to the staging row `2026 Local Only`. On an older org, deactivate rule `preventChangePartnerInternalID`, update the field, reactivate, then `mlocal sync` |
| Student sync log says `Fail` | Run `mlocal sync`, then `mlocal student` again. The username must be unique |
| `sf_course_offering_pk` duplicate-key error in sync | Known. It's reported as a warning |
| `verify` doesn't return the expected 400 | The certificate or credentials are wrong. Run `mlocal cert` then `mlocal creds` |

## Files

```
erp-sf/mlocal/                (plugin, in git)
  mlocal                      entry script
  config.env.example          template for a new machine
  lib/common.bash             shared helpers
  steps/                      10-permissions, 20-cert.mjs, 30-credentials, 40-data.py,
                              50-fixups, 60-student, 70-sync (+71-offerings), 90-verify
  README.md, GUIDE.md

~/.manabie-local/             (per machine, never in git)
  config.env                  your settings and the JKS password (chmod 600)
  logs/                       step output and cert screenshots
```

## Safety

- Nothing here changes the repo working tree.
- Writes go to the scratch org, and to staging only through the app's own callouts when `sync` or a student sync runs.
- Do not commit `config.env` or the keystore.
