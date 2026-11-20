# mlocal - personal local-org bootstrap (code in the erp-sf plugin; config in ~/.manabie-local)

After `make delete-scratch && make start`:

    mlocal all          # permissions, cert, credentials, sample-data gap fill, fixups, sync, synced student, verify
    mlocal verify       # status checks only

Steps can be run alone: perm | cert | creds | data [--dry-run] | fix | sync [--map-only] | student [LocId] | verify

Before every action that hits the Manabie staging backend (Save as Draft, submit...): `mlocal sync`.

One-time: put the keystore password in config.env (JKS_PASSWORD). If the cert import UI changes, `mlocal cert --manual`.
Fresh scratch org: enable Identity Provider first (Setup > Identity Provider > Enable), otherwise the keystore import ends on "Data Not Available" and the cert step fails.

Academic year: the repo sample data uses partner id `dev_2026`, which staging tenant 100016 does not have, so every product offering push failed ("Academic year id ... not be founded in Manabie master data"). `40-data.py` maps it to the existing staging row `2026 Local Only` (`PARTNER_ID_REMAP`). On an org loaded before that, `preventChangePartnerInternalID` blocks the edit: deactivate the rule, update the field, reactivate. `make sync-local-data` then re-points that staging row at this org (last writer wins).
Logs and screenshots: ~/.manabie-local/logs. Nothing here touches the repo working tree.
