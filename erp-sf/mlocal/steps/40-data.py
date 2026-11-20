#!/usr/bin/env python3
"""Gap-fill loader for the repo's checked-in sample data (scripts/data/data/*.json).

Unlike `sf texei data import` it is idempotent: records already in the org are matched by a natural key
and only the missing ones are created, so it works on an empty org and on a half-loaded one.
Dry-run by default; pass --apply to write.
"""
import collections, glob, json, os, re, subprocess, sys, tempfile

ORG = os.environ.get("ORG_ALIAS", "local_manabie")
ROOT = os.environ.get("REPO_ROOT") or subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True).stdout.strip()
APPLY = "--apply" in sys.argv
API = "v62.0"
os.chdir(ROOT)

REF_RE = re.compile(r"^[A-Za-z_]+Ref\d+$")
KEY_CANDIDATES = ["MANAERP__Partner_Internal_Id__c", "Email", "Name", "LastName"]
SKIP_TYPES = {"MANAERP__Back_Office_Information__c"}  # org singletons / not needed for local testing
# Partner ids in the repo sample data that staging tenant 100016 (Salesforce Manabie Dev) does not have.
# Product offering sync looks the academic year up by partner id, so an unknown one fails every product push
# ("Academic year id ... not be founded in Manabie master data"). Map them to an existing staging row.
PARTNER_ID_REMAP = {("MANAERP__Academic_Year__c", "dev_2026"): "2026 Local Only"}


def sf(args, body=None):
    cmd = ["sf"] + args + ["--target-org", ORG, "--json"]
    out = subprocess.run(cmd, capture_output=True, text=True)
    try:
        return json.loads(out.stdout, strict=False)
    except Exception:
        raise RuntimeError("sf failed: %s\n%s" % (" ".join(cmd[:6]), out.stdout[:400] + out.stderr[:400]))


def query(q):
    r = sf(["data", "query", "--query", q])
    if r.get("status") != 0:
        raise RuntimeError("query failed: %s -> %s" % (q, r.get("message")))
    return r["result"]["records"]


def describe(t):
    return {f["name"]: f for f in sf(["sobject", "describe", "--sobject", t])["result"]["fields"]}


def create_batch(t, records):
    """composite sobjects create, duplicate rules bypassed; returns [(ok, id_or_error)]"""
    with tempfile.NamedTemporaryFile("w", suffix=".json", delete=False) as f:
        json.dump({"allOrNone": False, "records": [dict(r, attributes={"type": t}) for r in records]}, f)
        path = f.name
    out = subprocess.run(
        ["sf", "api", "request", "rest", "/services/data/%s/composite/sobjects" % API, "--method", "POST",
         "--body", "@" + path, "-H", "Sforce-Duplicate-Rule-Header: allowSave=true", "--target-org", ORG],
        capture_output=True, text=True)
    os.unlink(path)
    res = json.loads(out.stdout, strict=False)
    return [(x.get("success"), x.get("id") or "; ".join(e.get("message", "") for e in x.get("errors", []))) for x in res]


# ---- load source in plan order ------------------------------------------------------------------
def file_order(f):
    return int(re.match(r"(\d+)-", os.path.basename(f)).group(1))

source = collections.OrderedDict()
for f in sorted(glob.glob("scripts/data/data/*.json"), key=file_order):
    for r in json.load(open(f))["records"]:
        t = r["attributes"]["type"]
        fields = {k: v for k, v in r.items() if k != "attributes"}
        remap = PARTNER_ID_REMAP.get((t, fields.get("MANAERP__Partner_Internal_Id__c")))
        if remap:
            fields["MANAERP__Partner_Internal_Id__c"] = remap
        source.setdefault(t, []).append((r["attributes"]["referenceId"], fields))

admin_id = query("SELECT Id FROM User WHERE IsActive=true AND Profile.Name='System Administrator' ORDER BY CreatedDate LIMIT 1")[0]["Id"]
resolved = {}      # referenceId -> org Id
report = []
admin_taken = bool(query("SELECT Id FROM Contact WHERE MANAERP__Salesforce_User__c = '%s' LIMIT 1" % admin_id))

for t, items in source.items():
    if t in SKIP_TYPES:
        continue
    d = describe(t)
    rts = {}
    if any(f["name"] == "RecordTypeId" for f in d.values()):
        rts = {r["DeveloperName"]: r["Id"] for r in query("SELECT Id, DeveloperName FROM RecordType WHERE SObjectType='%s'" % t)}

    def build(rid, r):
        """returns (fields, unresolved_ref) ; fields only include createable columns"""
        out = {}
        for k, v in r.items():
            f = d.get(k)
            if f is None or v is None or not f.get("createable") or f["type"] in ("address", "location"):
                continue
            if k == "RecordTypeId":
                v = rts.get(v, v)
            elif isinstance(v, str) and REF_RE.match(v):
                if v not in resolved:
                    return out, v
                v = resolved[v]
            out[k] = v
        return out, None

    ref_fields = {k for k in d if d[k]["type"] == "reference"}
    cols = {k for _, r in items for k in r if k in d and d[k]["type"] not in ("address", "location") and not d[k].get("calculated")}
    # RecordTypeId takes part in matching only when every source value is a DeveloperName that
    # build() maps to this org's Id; an Id from another org would never match.
    if "RecordTypeId" in cols and not all(r.get("RecordTypeId") in rts for _, r in items if r.get("RecordTypeId") is not None):
        cols.discard("RecordTypeId")
    pick = ["Id"] + sorted(cols)
    existing = []
    try:
        existing = query("SELECT %s FROM %s" % (",".join(pick), t))
    except Exception:
        pick = ["Id"] + [k for k in sorted(cols) if k in KEY_CANDIDATES or k in ref_fields]
        existing = query("SELECT %s FROM %s" % (",".join(pick), t))
    # Both sides of the signature use the same columns: queried, and kept by build() (createable).
    sig_cols = {k for k in pick if k != "Id" and d[k].get("createable")}

    def norm(v):
        if isinstance(v, bool) or v is None:
            return v
        if isinstance(v, (int, float)):
            return float(v)
        s = str(v).strip()
        try:
            return float(s)
        except ValueError:
            pass
        m = re.match(r"^(\d{4}-\d{2}-\d{2})(T\d{2}:\d{2})?", s)
        return (m.group(1) + (m.group(2) or "")) if m else s

    key_field = next((k for k in KEY_CANDIDATES if all(k in r and r[k] is not None for _, r in items)), None)

    def sig(fields):
        if key_field:
            return ("k", key_field, norm(fields.get(key_field)))
        return ("s",) + tuple(sorted((k, norm(v)) for k, v in fields.items() if k in sig_cols and v is not None))

    index = collections.defaultdict(list)
    for row in existing:
        index[sig({k: row.get(k) for k in sig_cols})].append(row["Id"])

    org_count = len(existing)
    to_create, pending = [], list(items)
    matched = 0
    for _ in range(3):  # self-references need extra passes
        again = []
        for rid, r in pending:
            fields, unresolved = build(rid, r)
            if unresolved:
                again.append((rid, r))
                continue
            # special matches
            if t == "Account" and fields.get("MANAERP__Location_Type__c") == "Org":
                org_rows = query("SELECT Id FROM Account WHERE MANAERP__Location_Type__c='Org' LIMIT 1")
                if org_rows:
                    resolved[rid] = org_rows[0]["Id"]; matched += 1; continue
            hits = index.get(sig(fields))
            if hits:
                resolved[rid] = hits.pop(0); matched += 1
            else:
                to_create.append((rid, fields))
                if not APPLY:
                    resolved[rid] = "DRY:" + rid  # lets dependants be evaluated in a dry run
        pending = again
        if not pending:
            break
    unresolved_n = len(pending)

    # collision rules
    if t == "MANAERP__Grade__c":
        used = {int(float(x["MANAERP__Sequence__c"])) for x in query("SELECT MANAERP__Sequence__c FROM MANAERP__Grade__c WHERE MANAERP__Sequence__c != null")}
        nxt = max(used | {0}) + 1
        for _, f in to_create:
            s = f.get("MANAERP__Sequence__c")
            if s is None or int(float(s)) in used or int(float(s)) > 999:
                f["MANAERP__Sequence__c"] = nxt; nxt += 1
            used.add(int(float(f["MANAERP__Sequence__c"])))
    if t == "MANAERP__Academic_Year__c":
        has_current = bool(query("SELECT Id FROM MANAERP__Academic_Year__c WHERE MANAERP__Current_Academic_Year__c = true LIMIT 1"))
        for _, f in to_create:
            if has_current:
                f["MANAERP__Current_Academic_Year__c"] = False
            has_current = has_current or bool(f.get("MANAERP__Current_Academic_Year__c"))
    if t == "Contact":
        for _, f in to_create:
            if f.get("MANAERP__Salesforce_User__c") == "SfdxOrgUser":
                if admin_taken:
                    f.pop("MANAERP__Salesforce_User__c")
                else:
                    f["MANAERP__Salesforce_User__c"] = admin_id; admin_taken = True

    # never duplicate: if the org already holds as many rows as the source, only map, don't create
    if to_create and org_count >= len(items) and not key_field:
        report.append((t, len(items), matched, 0, "skipped create: org already has %d rows (no natural key)" % org_count))
        continue

    created = failed = 0
    note = ""
    if to_create and APPLY:
        for i in range(0, len(to_create), 200):
            chunk = to_create[i:i + 200]
            for (rid, _), (ok, val) in zip(chunk, create_batch(t, [f for _, f in chunk])):
                if ok:
                    resolved[rid] = val; created += 1
                else:
                    failed += 1; note = note or val[:140]
    elif to_create:
        created = len(to_create)
        note = "dry-run " + ", ".join(str(f.get(key_field or "Name") or sorted(f)[:2]) for _, f in to_create[:4])
    report.append((t, len(items), matched, created, ("failed %d: %s" % (failed, note)) if failed else note + (" unresolved-refs=%d" % unresolved_n if unresolved_n else "")))

print("%-44s %6s %7s %7s  %s" % ("object", "source", "matched", "create", "notes"))
for r in report:
    print("%-44s %6d %7d %7d  %s" % r)
sys.exit(1 if any(str(r[4]).startswith("failed") for r in report) else 0)
