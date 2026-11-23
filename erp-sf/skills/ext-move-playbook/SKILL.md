---
name: ext-move-playbook
description: Move an existing erp-salesforce component from Main (Core) to Ext, or roll such a move back. Use when a ticket or a module move plan marks a trigger, its handler, an Apex class, or an LWC/Aura action override as MOVE or CLUSTER, or when reverting an Ext move.
---

# Ext move playbook

The steps live in [`package-placement.md`](../../reference/package-placement.md) in this plugin, under "Playbooks". Read the whole file first, then follow the section for the move:

| Moving | Section |
| --- | --- |
| A trigger, its handler, helpers and tests | "Move a trigger and its Apex to Ext" (do its one-time setup first when the Ext module has no in-package set or test suite) |
| An LWC or Aura `LightningComponent` action override | "Move an LWC or Aura action override to Ext" |
| Undoing either | "Rollback" (Apex moves back under a `V2` name; a revert commit fails) |

## Steps

1. **Confirm** the component in the module's move plan (MOVE, CLUSTER or KEEP). Anything not listed goes back to the user instead of moving.
2. **Move** with `git mv`, logic unchanged: `git diff --cached -M --stat` shows each move at 99% similarity or more. `classes/` subfolders flatten in Ext.
3. **Annotate** every Main class and member the moved code calls with `@NamespaceAccessible`, class and member both.
4. **Grants**: remove the moved class from packaged Main permission sets; add functional grants to the Ext in-package set and the 3 v2 sets. Move the test into the Ext suite (`MANAERP.<Test>`).
5. **Overrides only**: rename the bundle `…Ext`, clone `@AuraEnabled` controllers as `…Ext`, run `migrate-action-overrides.mjs --delete-old`, add the rename CSV rows.
6. **Check**, all from the repo root:
   - `golden-rule` (nothing in Main names the moved component)
   - `perm-check`
   - `file-count --compare` (Main goes down, Ext goes up by the moved files)
   - Main tests pass without Ext: seed data only when absent, set the fields the moved trigger used to fill.
7. **Record** the move in the TDD and PR: file, from, to, reason, and the release order (Main before Ext, one window).

## Done

Every moved file is at 99%+ similarity, `golden-rule` and `perm-check` exit 0, `file-count --compare` shows the shift, Main tests pass without Ext, and the TDD/PR lists each move.
