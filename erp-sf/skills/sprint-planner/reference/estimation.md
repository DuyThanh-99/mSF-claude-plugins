# Story point estimate (step 6)

LT points child issues on the scale **1, 2, 3, 5** in `customfield_10026`. Score every proposed **Feature**. **Demo** is always **1**.

## 1. Find what each story touches

For each Feature, read its ACs and locate the code they change: search the repo (`erp-salesforce`) for the objects, fields, components and classes the PRD names, and note the module and package (Main `packages/<module>`, Ext `packages/<module>-ext`). When nothing in the repo matches, score from the PRD alone and mark the row `PRD-only`.

## 2. Score five drivers, 0–2 each

| Driver | 0 | 1 | 2 |
| --- | --- | --- | --- |
| **Breadth** | 1–3 files, one layer | one module, several layers (metadata + Apex + UI) | several modules, Main and Ext with boundary work, or a large shared component |
| **Logic** | config, labels, metadata only | CRUD, UI validation, simple mapping | batch or queueable, bulk cross-object mapping, date or period splitting, idempotent re-runs, partial-failure handling |
| **Integration** | none | reuses an existing backend sync or contract | new backend contract or field, callout, Lightning Out, cross-package call |
| **Uncertainty** | copies an existing pattern in the repo | one open question with a likely answer | blocking open question, missing PRD wording, or unknown backend behaviour |
| **Verification** | Apex/Jest tests only | UI check of one flow | several UI paths with data evidence, a shared-org run, billing or performance checks |

When several stories share one engine (for example period splitting), the first story in PRD order carries the engine's Breadth and Logic. Later stories score only their own delta.

## 3. Map the total to points

| Total (0–10) | Points | Calibration (LT tickets) |
| --- | --- | --- |
| 0–2 | **1** | LT-115173 missing related list (bug fix) |
| 3–4 | **2** | LT-113321 metadata for cloning products |
| 5–6 | **3** | LT-114506 recreate source package associations; LT-114803 move clone UI to order-ext |
| 7–8 | **5** | LT-113322 clone product data logic; LT-113325 clone UI and validation |
| 9–10 | **5, split suggested** | Propose in the preview how to split it (which ACs go where). Add rows only if the user accepts |

The scale stops at 5; never propose 8. A spike, QA or other extra row is a suggestion in the preview notes, never an automatic proposal row: the fixed rule stays one Feature per User Story plus one Demo.

## 4. Show it in the preview

Add the driver scores and the main driver to the review table:

```text
| Proposed child | Type | Parent | Summary | B | L | I | U | V | SP | Main driver | Sprint | PRD source |
```

Below the table, list:
- the total points, and a sprint-fit note when the total looks large for one sprint;
- each row scored 9 or more, with its split suggestion;
- open questions that would move a row up a bucket if they resolve badly.

The user may override any SP in the review; re-render the table with their value and keep the score columns as written.
