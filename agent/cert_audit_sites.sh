#!/usr/bin/env bash
set -euo pipefail

LE_EMAIL="${LE_EMAIL:-admin@uplymedia.com}"
RENEW_THRESHOLD="${RENEW_THRESHOLD:-20}"     # renew when < 20 days left
DO_RENEW="${DO_RENEW:-true}"                 # set "false" to audit-only
SERVER_IP="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"
LOG_JSON="/var/log/agent/cert_audit.json"

command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
command -v dig >/dev/null 2>&1 || { echo "dnsutils (dig) required"; exit 1; }

DOMAINS="$(plesk bin domain --list 2>/dev/null || true)"

tmp="$(mktemp)"; echo "[]" > "$tmp"
append_json() { local obj="$1"; jq -Mc --argjson item "$obj" '. += [$item]' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"; }

for d in $DOMAINS; do
  [[ -z "$d" ]] && continue

  AREC="$(dig +short A "$d" 2>/dev/null | head -n1)"

  END_RAW="$(openssl s_client -connect ${d}:443 -servername ${d} </dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2 || true)"
  SUBJ="$(openssl s_client -connect ${d}:443 -servername ${d} </dev/null 2>/dev/null | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=//')"
  ISSU="$(openssl s_client -connect ${d}:443 -servername ${d} </dev/null 2>/dev/null  | openssl x509 -noout -issuer 2>/dev/null  | sed 's/^issuer=//')"

  DAYS_JSON="null"
  if [[ -n "${END_RAW:-}" ]]; then
    if END_TS=$(date -d "$END_RAW" +%s 2>/dev/null); then
      NOW_TS=$(date +%s); DAYS=$(( (END_TS - NOW_TS) / 86400 ))
      DAYS_JSON="$DAYS"
    fi
  fi

  RENEWED="no"; RENEW_REASON=""
  if [[ "$DO_RENEW" == "true" && "$DAYS_JSON" != "null" && "$DAYS_JSON" -lt "$RENEW_THRESHOLD" ]]; then
    if [[ "$AREC" == "$SERVER_IP" ]]; then
      WWW=""
      if dig +short A "www.$d" >/dev/null 2>&1 | grep -q .; then WWW="-d www.$d"; fi
      if plesk bin extension --exec letsencrypt cli.php -d "$d" $WWW -m "$LE_EMAIL" >/dev/null 2>&1; then
        RENEWED="yes"; RENEW_REASON="threshold<$RENEW_THRESHOLD and A=$AREC matches $SERVER_IP"
      else
        RENEWED="failed"; RENEW_REASON="letsencrypt-cli failed"
      fi
    else
      RENEW_REASON="skipped: A($d)=$AREC != $SERVER_IP"
    fi
  fi

  obj="$(
    jq -n \
      --arg domain "$d" \
      --arg a_record "${AREC:-}" \
      --arg not_after "${END_RAW:-}" \
      --arg subject "${SUBJ:-}" \
      --arg issuer "${ISSU:-}" \
      --arg renewed "${RENEWED:-no}" \
      --arg renew_reason "${RENEW_REASON:-}" \
      --argjson days_left "$DAYS_JSON" \
      '{domain:$domain,a_record:$a_record,days_left:$days_left,not_after:$not_after,subject:$subject,issuer:$issuer,renewed:$renewed,renew_reason:$renew_reason}'
  )"
  append_json "$obj"
done

jq -n --arg now "$(date -Iseconds)" --arg server_ip "$SERVER_IP" --slurpfile arr "$tmp" \
  '{checked_at:$now,server_ip:$server_ip,domains:$arr[0]}' > "$LOG_JSON"
rm -f "$tmp"

cp -f "$LOG_JSON" /opt/reports/ 2>/dev/null || true
jq . "$LOG_JSON" 2>/dev/null || cat "$LOG_JSON"
