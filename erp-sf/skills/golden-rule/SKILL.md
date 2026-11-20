---
name: golden-rule
description: Check that nothing in Main names an Ext component, plus the Main LightningComponent-override guard. Pass --all to check the whole repo instead of the branch.
disable-model-invocation: true
argument-hint: "[--all]"
---

Run `golden-rule $ARGUMENTS` (on the Bash PATH) from the erp-salesforce repo root.

Report the result in this shape:
- **Scope** and how many Ext names were checked.
- **Violations**: each Ext component with its Main file:line hits. For each, say whether it is a compile-time reference (breaks the Main build) or a runtime string (breaks only when Ext is absent), and the fix the placement rules give (move the referrer to Ext, clone it as `…Ext`, or drop the reference).
- **Override guard** result.

Clean means exit 0. Leave fixes to the user unless they ask.
