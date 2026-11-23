# Using erp-sf

erp-sf is the team's Claude Code plugin for the erp-salesforce repo. It adds:

- **Skills** for the work we repeat: planning epics, building features from a PRD, Main vs Ext placement, fixing CI, investigating bugs in customer orgs.
- **Guards** that ask before Claude writes to a shared org or commits.
- **`mlocal`**, which finishes setting up the `local_manabie` scratch org.

This guide covers setup and day-to-day use. For a one-line description of every piece, see the [README](../README.md). For mlocal in depth, see [mlocal/GUIDE.md](mlocal/GUIDE.md).

## 1. Set up

### Once per machine

1. **Install the tools.** You need `jq`, `sf`, `node`, `python3` and `git`; `jq` is the one people miss (`brew install jq`). Without `jq` the guards can't read which org a command targets, so they ask about every org write, commit and push.
2. **Install the plugin.** In Claude Code:
   ```
   /plugin marketplace add DuyThanh-99/mSF-claude-plugins
   /plugin install erp-sf@msf-claude-plugins
   ```
   Pick the **local** scope to enable it only in the erp-salesforce clone you run it from. Installing erp-sf also installs four Salesforce plugins from forcedotcom: `salesforce-development`, `experience-lwc`, `salesforce-code-quality` and `dx-org-lifecycle`.
3. **Sign in to Jira and Confluence.** Run `/mcp`, choose `atlassian`, and sign in in the browser. It uses your own Atlassian permissions. `sprint-planner`, `create-tdd` and `prd-to-feature` need it.
4. **Check the options.** Open `/plugin` > erp-sf > configure. The defaults suit most people:

   | Option | Default | Change it when |
   | --- | --- | --- |
   | `local_org` | `local_manabie` | your scratch org has another alias |
   | `local_org_prefixes` | `local_` | your scratch org aliases start with something else |
   | `shared_read_orgs` | `staging,preprod` | you need SOQL access to other shared orgs |
   | `salesforce_telemetry` | `false` | you want to decide on forcedotcom's telemetry yourself |

5. **Set up mlocal.** Follow "Set up a new machine" in [mlocal/GUIDE.md](mlocal/GUIDE.md). You'll need the keystore and its password from the team.

### Once per erp-salesforce clone

In the clone, inside Claude Code:

```
erp-sf-init
```

This writes the team `CLAUDE.md` into the clone. If one already exists, it shows the difference and leaves it alone; `erp-sf-init --force` replaces it and keeps the old one as `CLAUDE.md.bak`.

Then build the local org once:

```
make start          # in your terminal, as usual
mlocal all          # in Claude Code, or ask Claude to "set up the local org"
```

On a fresh org, turn on Identity Provider first (Setup > Identity Provider > Enable). `mlocal verify` should end with every check passing.

## 2. How you call things

There are two kinds of skills.

**Commands you run yourself.** Type them with their arguments. Claude never starts these on its own:

| Command | Use it to |
| --- | --- |
| `/erp-sf:prd-to-feature LT-110982` | Build a feature from a Jira epic or PRD URL, from spec to PR |
| `/erp-sf:create-tdd LT-98426` | Draft the epic's Technical Design Document as a Confluence draft |
| `/erp-sf:ci-fix <Actions run URL>` | Find why a CI run failed and fix it on the branch (you can paste the log instead of a URL) |
| `/erp-sf:org-investigate LT-12345 [alias] [login URL]` | Find the root cause of a bug in a customer, preprod or staging org, read-only |
| `/erp-sf:golden-rule [--all]` | Check that nothing in Main names an Ext component |

**Skills Claude loads when the work matches.** You can still call them by name, for example `/erp-sf:sprint-planner`, or just ask in plain words:

| Skill | Claude uses it when you |
| --- | --- |
| `sprint-planner` | ask to plan Feature, Demo and TDD children for LT epics |
| `package-placement` | create or move metadata and need to decide Main or Ext |
| `apex-conventions` | write or change Apex (sharing, USER_MODE, test data rules) |
| `ext-move-playbook` | move a trigger, class or override from Main to Ext, or roll a move back |
| `local-org` | need the scratch org set up, synced, or fixed after a callout or cert error |
| `verify` | want a change checked in the scratch org UI, with evidence |
| `order-group-import` | work on Order Group batch import or Bulk Add Student Course |
| `pr` | ask for a PR body |
| `tdd`, `diagnosing-bugs`, `grilling`, `to-spec`, `to-tickets`, `implement` | work test-first, debug a hard bug, stress-test a plan, or turn talk into a spec or tickets |

There are also two **agents** you can ask for by name:
- **`placement-reviewer`**, for example "run the placement-reviewer agent on this branch". It reviews new and moved metadata against the placement rules and changes nothing.
- **`sf-feature-builder`**, which `prd-to-feature` uses to build one slice of an approved spec at a time.

## 3. Common workflows

### Plan a sprint from your epics

Ask "plan my LT epics", or give a key: "plan children for LT-110982".

`sprint-planner` finds the next sprint on board 69 and reads each epic's PRD. It then proposes one Feature per user story, plus a Demo task and an "Add TDD & review test cases" task, with story points. Nothing is created in Jira until you approve the preview.

### Build a feature from an epic

```
/erp-sf:prd-to-feature LT-110982
```

The skill works in phases and stops at each **gate** for your approval:

1. **Intake:** reads the epic, the PRD and recent develop commits.
2. **Spec (gate):** writes `.scratch/<feature>/spec.md` with an AC trace table, a placement table and open questions.
3. **Placement (gate):** checks every file's Main or Ext target.
4. **Build:** `sf-feature-builder` builds each slice test-first.
5. **Static checks:** Jest, Prettier, XML lint, permission-set check, golden-rule.
6. **Deploy and test:** deploys to `local_manabie` and runs the feature's Apex tests. Main must pass without Ext.
7. **Code review (gate):** you choose which findings to fix.
8. **Verify (gate):** runs each AC in the scratch org UI and saves evidence to `.scratch/<feature>/evidence/`.
9. **Handoff:** stages the feature files. It writes a PR body only if you ask. It does **not** commit; you do that, and the commit guard asks first.

Answer the open questions it raises, especially missing EN/JP wording. It won't invent JP text.

### Write the TDD

```
/erp-sf:create-tdd LT-98426
```

This reads the epic, the PRD, the test-case page and the commits for the key, then saves a **draft** page in Confluence for you to review. To use a different parent folder, pass its id as the second argument.

### Before you open a PR

| Check | How |
| --- | --- |
| Main doesn't name Ext | `/erp-sf:golden-rule` (exit 0 means clean) |
| Permission sets cover new files | `perm-check` |
| Package file counts | `file-count --compare` (put the Main and Ext numbers in the PR) |
| Placement review | "run the placement-reviewer agent on this branch" |
| PR body | "write the PR body" (the `pr` skill) |

`golden-rule` and `perm-check` compare against `develop`. Run `git fetch origin develop` first, or they stop with exit 2.

### CI failed

```
/erp-sf:ci-fix https://github.com/.../actions/runs/123
```

It reads the failing job and checks it against known false positives in `reference/ci-gotchas.md`. Then it decides whether your branch caused the failure, reproduces it, and fixes it without committing. When a run teaches you a new false positive, add a row to `ci-gotchas.md`.

### A bug in a customer, preprod or staging org

```
/erp-sf:org-investigate LT-12345 partner_uat https://partner--uat.sandbox.my.salesforce.com
```

This is read-only. It matches the org's installed package version to a git tag, so it reads the code that is actually running there, then collects evidence and writes a report. If the org isn't connected yet, it asks you to sign in. Preprod sessions expire quickly, so it runs its queries while you sign in.

### Move a component from Main to Ext

Ask "move `<Trigger/Class/Override>` to Ext" (or "roll back the Ext move of ..."). `ext-move-playbook` covers the steps, the grants and the golden-rule check for each kind of component.

### Keep the local org working

| When | Run |
| --- | --- |
| New or reset scratch org | `make start`, enable Identity Provider, then `mlocal all` |
| Right before Save as Draft, submit or a clone-link Run against staging | `mlocal sync` (staging's mapping is shared and the last writer wins) |
| Callout or certificate errors | `mlocal verify`, then `mlocal cert` and `mlocal creds` |
| Preview what the data step would create | `mlocal data --dry-run` |

## 4. When the guards ask

When a guard asks first, Claude Code shows a confirmation with the reason. Approve it only if you meant that action.

| You'll be asked when | Approve if |
| --- | --- |
| A command writes to an org that isn't local, through `-o`, `ORG=`, a script argument, `sf config set target-org` or `sf alias set` | you meant to change that shared org. Shared orgs are read-only by default |
| A write names no org and your default org isn't local | the same; or rerun it with `-o local_manabie` |
| The target org comes from a variable (`-o $ORG`) | you know where the variable points |
| `sf package version create` | you meant to build a package on the shared Dev Hub |
| `git commit` or `git push` | you asked for it in this conversation |

The guards don't see hooks from other plugins. **Never set `SFDX_AUTO_DEPLOY=1`.** It makes the `salesforce-development` plugin deploy every edited file to your default org, sandboxes included, without asking.

Commands that only read (`sf data query`, `sf org display`, `sf project retrieve`) run without asking.

## 5. Troubleshooting

| Symptom | Fix |
| --- | --- |
| Jira or Confluence tools missing, or `sprint-planner` stops at preflight | `/mcp` > `atlassian` > sign in again |
| The guard asks on every org write and the reason mentions `jq` | `brew install jq` |
| `golden-rule` or `perm-check` exits 2: "Cannot find develop" | `git fetch origin develop` |
| `mlocal`: "REPO_ROOT ... is not the erp-salesforce repo" | run it inside the clone, or set `REPO_ROOT` in `~/.manabie-local/config.env` |
| `mlocal`: "no config.env on this machine" | "Set up a new machine" in [mlocal/GUIDE.md](mlocal/GUIDE.md) |
| `mlocal cert`: "could not start Chromium" | in the repo: `npx playwright install chromium` |
| `mlocal data` reports `unresolved-refs` | run `mlocal data` again; if the count stays, the sample data points at an object mlocal skips (`SKIP_TYPES` in `mlocal/steps/40-data.py`) |
| `mlocal sync` warns "staging does not know some ids" | the ids listed after `missing=` aren't in staging yet; ask before inserting anything there |
| `CLAUDE.md` differs from the template | `erp-sf-init` shows the diff; `--force` replaces it (the old file is kept as `.bak`) |

## 6. Updates

Get the latest plugin with `/plugin marketplace update msf-claude-plugins`, then `/reload-plugins`.

The four forcedotcom plugins are pinned to one sf-skills release. They change only when someone bumps the pin in a PR to this repo (see the README).
