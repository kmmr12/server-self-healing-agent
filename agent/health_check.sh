#!/usr/bin/env bash
set -euo pipefail
LOG_JSON="/var/log/agent/health.json"
WEBHOOK_FILE="/root/.secrets/discord_webhook"
DISCORD_WEBHOOK="$( [ -s "$WEBHOOK_FILE" ] && cat "$WEBHOOK_FILE" || echo "" )"
ts(){ date -Iseconds; }

# Domains from Plesk
DOMS="$(plesk bin domain --list 2>/dev/null || true)"
[ -z "$DOMS" ] && exit 0

# Prepare JSON
tmp="$(mktemp)"; echo '{"checked_at":"","items":[]}' > "$tmp"
jq -r --arg t "$(ts)" '.checked_at=$t' "$tmp" > "${tmp}.n" && mv "${tmp}.n" "$tmp"

fail_count=0
while IFS= read -r d; do
  [ -z "$d" ] && continue
  for scheme in https http; do
    code=$(curl -ksS -o /dev/null -w '%{http_code}' --max-time 15 "${scheme}://$d/")
    obj=$(jq -nc --arg domain "$d" --arg scheme "$scheme" --arg code "$code" \
      '{domain:$domain, scheme:$scheme, http_code:($code|tonumber)}')
    jq -Mc --argjson item "$obj" '.items += [$item]' "$tmp" > "${tmp}.n" && mv "${tmp}.n" "$tmp"
    if [ "$scheme" = "https" ] && [ "$code" -ge 400 -o "$code" -eq 000 ]; then
      fail_count=$((fail_count+1))
    fi
  done
done <<<"$DOMS"

mv "$tmp" "$LOG_JSON"

# Alert if any HTTPS failures and webhook configured
if [ "$fail_count" -gt 0 ] && [ -n "$DISCORD_WEBHOOK" ]; then
  txt="Health check: ${fail_count} site(s) returning non-200 on HTTPS."
  curl -sS -H "Content-Type: application/json" -d "$(jq -nc --arg c "$txt" '{content:$c}')" "$DISCORD_WEBHOOK" >/dev/null || true
fi
