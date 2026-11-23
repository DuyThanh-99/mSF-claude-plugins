# Investigation report

Shared format for `erp-sf:ci-fix` and `erp-sf:org-investigate`. Save it as `.scratch/<ticket or branch>/<ci-fix|investigation>-<YYYY-MM-DD>.md` in the repo and show the summary in chat.

```markdown
# <ticket or CI run>: <one-line symptom>

**Cause:** one or two sentences, naming the file, component, record or setting.
**Ours?** caused by this branch / already on develop / org on an older package version / org data or config / CI infrastructure.

## Evidence
Each item: the command or query, and the lines of output that prove it. Record IDs only; no customer names, emails or free-text data.

## Fix
Files changed (not committed), or the proposed change when nothing was changed yet. For org data or config, the exact steps for a human to run.

## Verification
What ran and its result: local test class, golden-rule, erp-sf:verify, a reproduction on local_manabie.

## Next step
Re-run CI / push the fix / upgrade the org to <version> / hand to prd-to-feature / ask <person>.

## Open questions
```

Done when every claim in Cause has an Evidence item behind it.
