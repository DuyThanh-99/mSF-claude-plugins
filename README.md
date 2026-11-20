# mSF-claude-plugins

Private Claude Code plugins.

| Plugin | What it is for |
| --- | --- |
| `erp-sf` | Helpers for the erp-salesforce repo |

## erp-sf contents

| Piece | What it does |
| --- | --- |
| skill `package-placement` | Main vs Ext placement steps; reads the rules from `docs/agents/package-placement.md` in the repo |
| skill `golden-rule` (`/erp-sf:golden-rule [--all]`) | Runs `bin/golden-rule`: nothing in Main may name an Ext component, plus the override guard |
| skill `local-org` | When and how to run `mlocal` on `local_manabie` |
| skill `create-tdd` (`/erp-sf:create-tdd LT-xxxxx`) | Draft a TDD for a Jira epic as a Confluence draft |
| skill `prd-to-feature` (`/erp-sf:prd-to-feature`) | PRD or epic → spec → placement → build → verify → PR |
| skill `sprint-planner` (`/erp-sf:sprint-planner`) | Plan PRD-backed Feature/Demo children for LT epics, preview before Jira writes |
| skill `ci-fix` (`/erp-sf:ci-fix <run URL or log>`) | Fetch the failing CI log, classify it against `reference/ci-gotchas.md`, decide if the branch caused it, reproduce, fix without committing, report |
| skill `org-investigate` (`/erp-sf:org-investigate <ticket> [alias] [login URL]`) | Read-only root-cause investigation in a customer or shared org: pin its package version to a git tag, collect evidence, report |
| skill `verify` (`/erp-sf:verify`) | Local checks with evidence before handing work back |
| skills `grill-with-docs`, `grilling`, `domain-modeling`, `pr`, `writing-for-agents`, `to-spec`, `diagnosing-bugs` | Copied from mattpocock/skills (MIT, see `erp-sf/THIRD_PARTY_NOTICES.md`) |
| skill `ext-move-playbook` | Move a trigger, Apex or LWC/Aura override from Main to Ext, or roll it back |
| skill `apex-conventions` | Team Apex rules: sharing, USER_MODE with a graceful guard, no User inserts in tests, timezone-independent test data |
| skill `order-group-import` | Order Group batch import CSV rules and the blank courseName from bulk add course |
| skills `tdd`, `to-tickets`, `implement`, `implement-spec` | Copied from mattpocock/skills (MIT) |
| agent `placement-reviewer` | Read-only placement review of a branch before a PR |
| agent `sf-feature-builder` | Builds one slice of an approved spec, test-first |
| hook `guard-shared-org.sh` | Asks before any write to an org that isn't a local scratch org: sf deploys and data writes, `sf config set target-org`, `sf alias set`, repo scripts, deploying `make` targets and `mlocal` steps. Every org the command names (`-o`, `ORG=`, a script argument that is a known alias) must be local; a write that names none uses `SF_TARGET_ORG`, then `.sf/config.json` |
| hook `guard-git-commit.sh` | Asks before `git commit` / `git push` |
| MCP `sf-local` | Salesforce DX MCP, read/write, only the `local_org` option's org |
| MCP `sf-shared` | Salesforce DX MCP, SOQL only, the `shared_read_orgs` option's orgs |
| `bin/` | On the Bash tool's PATH: `golden-rule`, `perm-check`, `file-count [--compare]`, `mlocal`, `erp-sf-init` (writes the repo's `CLAUDE.md`), `erp-sf-root`, `sf-mcp` |
| `mlocal/` | mlocal code; per-machine config stays in `~/.manabie-local/config.env` (see `mlocal/GUIDE.md`) |

Installing `erp-sf` also installs these Salesforce plugins, re-listed here from [forcedotcom/sf-skills](https://github.com/forcedotcom/sf-skills) (Apache-2.0) and fetched from that repo: `salesforce-development`, `experience-lwc`, `salesforce-code-quality`, `dx-org-lifecycle`. To add another, list it in `.claude-plugin/marketplace.json` with a `git-subdir` source and add it to `dependencies` in `erp-sf/.claude-plugin/plugin.json`. If `erp-sf` is already installed, install the new one directly: `claude plugin install <name>@msf-claude-plugins --scope local`.

Options (`/plugin` > erp-sf > configure): `local_org` (default `local_manabie`), `local_org_prefixes` (default `local_`), `shared_read_orgs` (default `staging,preprod`).

`reference/` holds files several skills share: `package-placement.md`, `issue-tracker.md` and `domain.md` (the repo's agent docs), `CLAUDE.template.md`, `ci-gotchas.md` (known CI failures; add a row when a run teaches a new one) and `investigation-report.md`.

New clone: run `erp-sf-init` in it to write `CLAUDE.md`.

## Install

```
/plugin marketplace add DuyThanh-99/mSF-claude-plugins
/plugin install erp-sf@msf-claude-plugins
```

Choose the **local** scope to enable it only in the project you run it from.

Requires `jq` (`brew install jq`; macOS 15 and later ship it). Without it the guard hooks cannot read the target org, so they ask before anything that looks like an org write, commit or push.

## Develop

Load the plugin straight from this folder, without installing it:

```
claude --plugin-dir ~/mSF-claude-plugins/erp-sf
```

Installed from this local folder, edits apply after `/reload-plugins`. Installed from GitHub, run `/plugin marketplace update msf-claude-plugins` after pushing, then `/reload-plugins`.
