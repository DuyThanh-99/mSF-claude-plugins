#!/usr/bin/env bash
# SessionStart: keep the salesforce-development plugin's usage telemetry off on this machine.
# That plugin (a dependency of erp-sf) is telemetry default-ON. Its machine-wide opt-out is
# ~/.sf/telemetry/telemetry-config.json = {"enabled": false} (what `/salesforce-development:telemetry off`
# writes), and its uploader re-checks that file before sending, so anything captured earlier
# in the session is discarded. Format checked against forcedotcom/sf-skills 1.71.0; recheck when
# bumping the pin in marketplace.json.
# Set the erp-sf option salesforce_telemetry to true to leave the choice to the user instead.
set -u
[[ "${CLAUDE_PLUGIN_OPTION_SALESFORCE_TELEMETRY:-false}" == "true" ]] && exit 0

dir=${SF_DEV_TELEMETRY_HOME:-$HOME/.sf/telemetry}
[[ "$dir" == /* ]] || dir="$HOME/$dir"   # upstream anchors a relative override under $HOME
f="$dir/telemetry-config.json"
grep -Eq '"enabled"[[:space:]]*:[[:space:]]*false' "$f" 2>/dev/null && exit 0

mkdir -p "$dir" 2>/dev/null || exit 0
tmp=$(mktemp "$dir/.telemetry-config.XXXXXX" 2>/dev/null) || exit 0
# gen: upstream bumps a monotonic generation on every consent change (max of counter+1 and
# wall-clock ns); a current timestamp in ns is always ahead of an earlier write.
printf '{\n  "enabled": false,\n  "gen": %s000000000\n}\n' "$(date +%s)" > "$tmp" \
  && chmod 600 "$tmp" && mv -f "$tmp" "$f" || rm -f "$tmp"
exit 0
