#!/usr/bin/env bash
# Maps this org's ids onto staging (repo's sync-local-data), then pushes billing master + product offerings.
# Run right before any action that hits the Manabie backend.
set -uo pipefail
source "${ML_CODE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/lib/common.bash"
log "Sync: make sync-local-data"
out=$(cd "$REPO_ROOT" && make sync-local-data 2>&1); rc=$?
echo "$out" | tail -4
if [ $rc -ne 0 ]; then
  if echo "$out" | grep -q "sf_course_offering_pk"; then warn "course offering step hit known duplicate key (ignored)"
  else die "sync-local-data failed"; fi
fi
if [ "${1:-}" = "--map-only" ]; then exit 0; fi
log "Sync: staging knows our ids? push billing + product offerings"
res=$(apex_report "$ML_CODE/steps/70-sync.apex")
batch=$(mktemp -t mlocal-offerings).apex
off=0; while [ $off -lt 40 ]; do
  sed "s/__OFFSET__/$off/" "$ML_CODE/steps/71-offerings.apex" > "$batch"
  r=$(apex_report "$batch")
  res="$res"$'\n'"$r"
  echo "$r" | grep -q "seen=5|" || break
  off=$((off + 5))
done
rm -f "$batch" "${batch%.apex}"
echo "$res"
echo "$res" | grep -q "offering-" && warn "some offerings failed (see above)"
echo "$res" | grep -E "^known" | grep -vF 'missing=()' | grep -q . && warn "staging does not know some ids (missing=...)"
exit 0
