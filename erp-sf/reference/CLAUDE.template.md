## Agent skills (erp-sf plugin)

The erp-sf plugin holds this repo's agent guidance; `erp-sf-root` prints its folder.

### Issue tracker

Issues and specs live as local markdown files under `.scratch/<feature>/`. Conventions: `reference/issue-tracker.md` in the plugin.

### Package placement

Before creating or moving any metadata file (Apex, trigger, LWC, Aura, object, field, record type, permission set, quick action, tab, FlexiPage, layout, flow, label), run the `erp-sf:package-placement` skill, and record each file's target and reason in the TDD and PR.

### Local org

After `make start`, use the `erp-sf:local-org` skill (`mlocal all`). Permission sets in `outside-packages` or `outside-packages-ext` are not in the School Admin group, so assign them to the admin user.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root. How to use them: `reference/domain.md` in the plugin.
