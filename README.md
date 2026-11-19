# mSF-claude-plugins

Private Claude Code plugins.

| Plugin | What it is for |
| --- | --- |
| `erp-sf` | Helpers for the erp-salesforce repo |

## Install

```
/plugin marketplace add DuyThanh-99/mSF-claude-plugins
/plugin install erp-sf@my-plugins
```

Choose the **local** scope to enable it only in the project you run it from.

## Develop

Load the plugin straight from this folder, without installing it:

```
claude --plugin-dir ~/mSF-claude-plugins/erp-sf
```

An installed copy is cached. After pushing changes, run `/plugin marketplace update my-plugins`, then `/reload-plugins`.
