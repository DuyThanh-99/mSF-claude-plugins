---
name: local-org
description: Set up and keep the local_manabie scratch org usable with mlocal. Use after `make start` or a new scratch org, before any action that reaches the Manabie staging backend (Save as Draft, submit, clone-link Run, student sync), when certificate, named-credential or callout auth fails, and when setting mlocal up on a new machine.
---

# Local org (mlocal)

`mlocal` finishes `local_manabie` after `make start`: permissions, staging signing cert, credentials, sample data, fixups, staging sync, a synced student. Its code ships in this plugin (`mlocal` is on the Bash PATH); each machine keeps its own `~/.manabie-local/config.env` with the keystore password, outside git. The full guide, troubleshooting table included, is [`../../mlocal/GUIDE.md`](../../mlocal/GUIDE.md).

Run every command from the erp-salesforce repo root. Every step is idempotent.

## Branches

- **New or reset org:** `make start`; ask the user to enable Identity Provider (Setup > Identity Provider > Enable) on a fresh org; then `mlocal all`. Done when `mlocal verify` passes.
- **Before a staging-backend action:** `mlocal sync`. Staging's mapping is shared and last writer wins, so sync right before each Save as Draft, submit or clone-link Run.
- **New metadata deployed:** permission sets in `outside-packages` or `outside-packages-ext` are not in the School Admin group; assign them to the admin user in `local_manabie`.
- **Callout or cert failure:** `mlocal verify`, then the GUIDE's troubleshooting table (`mlocal cert`, then `mlocal creds`).
- **New machine, or `mlocal` says config.env is missing:** follow the GUIDE's "Set up a new machine". The keystore and its password come from the user; ask for them.

`mlocal` writes only to `local_manabie`, plus the staging sync the user asked for. Staging master data is read-only: check it with queries and ask before inserting anything there.
