---
name: order-group-import
description: Order Group batch import and Bulk Add Student Course in erp-salesforce. Use when preparing or debugging an Import Order Group By Batch or bulk-add-course CSV, a slot-based product failing on import, or bill item course names that come back empty.
---

# Order Group import

## Import Order Group By Batch

`ImportOrderGroupByBatch` (job object `Create_Order_Group_Job__c`). The CSV header is `OrderUtils.HEADER_IMPORT_ORDER_GROUP_V2`; read it from `packages/order/main/default/classes/OrderUtils.cls`, today:

```
username,product_id,location_id,start_date,discount_id,course_ids,slots,academic_year_id,end_date,remarks,override_price
```

- Rows become **one Order Group per `username`**.
- `course_ids`: several `Course_Offering__c` IDs in one cell, separated by `;`.
- `slots`: also `;`-separated, **aligned by position to `course_ids`** (one slot per course). Apex does not validate it; it goes straight to the Go backend. Blank slots on a slot-based product fail with `rpc error … FailedPrecondition … Course item for slot base is missing slot field`.
- The academic-year prefix in bill item descriptions (LT-103760, `OrderGroupBillItemService.alignCourseNamesWithRequest`) applies only to rows with `course_ids`: it sets each `courseName` to `Course_Offering__c.Name`, which carries the `[YYYY]` prefix.
- Check results in `Order_Group_Bill_Item__c.Billing_Item_Description__c` (JSON, `courseItems[].courseName`).

## Bulk Add Student Course: empty course names

`ImportBulkAddCourseByBatch` calls the payment-service endpoint `import_order_group_for_update`, which returns course items with `sfCourseOfferingId` but an empty `courseName`. `import_order_group` (the batch import above) returns them named from the same IDs-only CSV (pre-prod, 2026-09-03: 1500/1500 named vs 14/14 and 16/16 blank for ODG-729876 and ODG-729873).

- Salesforce fills the names in two places: `ImportBulkAddCourseByBatch.enrichResponseCourseNames` (the Order Group product) and `OrderGroupBillItemService.alignCourseNamesWithRequest` (`Order_Group_Bill_Item__c`).
- `Bill_Item__c` is synced verbatim by `SyncBillItemHandler.transformBillItem`, so it keeps the blank.
- So when a bulk-add-course field is empty, first check whether it derives from `Bill_Item__c.Billing_Item_Description__c`. A name column in the CSV or the request DTO does not help; the gap is in the backend's update endpoint.
