#!/usr/bin/env bash
set -euo pipefail
EMAIL="${LE_EMAIL:-admin@uplymedia.com}"
RENEW_THRESHOLD="${RENEW_THRESHOLD:-20}"   # renew when < 20 days left
DO_RENEW="${DO_RENEW:-true}"               # set to "false" to audit only
SERVER_IP="${SERVER_IP:-$(hostname -I | awk '{print $1}')}"
DOMAINS="$(plesk bin domain --list 2>/dev/null || true)"

jq_begin='{"checked_at":null,"server_ip":null,"domains":[]}'
jq_add='.|.checked_at=now|.server_ip=env.SERVER_IP'

: > "$LOG_JSON"; echo '{}' | jq -Mc "$jq_begin" > "$LOG_JSON"
tmp=$(mktemp); echo '[' > "$tmp"; first=1

for d in $DOMAINS; do
  [[ -z "$d" ]] && continue

  # A record (IPv4)
  AREC="$(dig +short A "$d" 2>/dev/null | head -n1)"

  # pull cert info served publicly
  END_RAW="$(openssl s_client -connect ${d}:443 -servername ${d} </dev/null 2>/dev/null \
            | openssl x509 -noout -enddate | cut -d= -f2 || true)"
  SUBJ="$(openssl s_client -connect ${d}:443 -servername ${d} </dev/null 2>/dev/null \
            | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=//')"
  ISSU="$(openssl s_client -connect ${d}:443 -servername ${d} </dev/null 2>/dev/null \
            | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer=//')"

  DAYS="unknown"
  if [[ -n "$END_RAW" ]]; then
    END_TS=$(date -d "$END_RAW" +%s 2>/dev/null || echo "")
    if [[ -n "$END_TS" ]]; then
      NOW_TS=$(date +%s); DAYS=$(( (END_TS - NOW_TS)/86400 ))
    fi
  fi

  # attempt renewal if close to expiry *and* A-record points here
  RENEWED="no"; RENEW_REASON=""
  if [[ "$DO_RENEW" == "true" && "$DAYS" != "unknown" && "$DAYS" -lt "$RENEW_THRESHOLD" ]]; then
    if [[ "$AREC" == "$SERVER_IP" ]]; then
      WWW=""
      dig +short A "www.$d" >/dev/null 2>&1 && WWW="-d www.$d"
      if plesk bin extension --exec letsencrypt cli.php -d "$d" $WWW -m "$EMAIL" >/dev/null 2>&1; then
        RENEWED="yes"; RENEW_REASON="threshold<$RENEW_THRESHOLD and A=$AREC matches SERVER_IP"
      else
        RENEWED="failed"; RENEW_REASON="letsencrypt-cli failed"
      fi
    else
      RENEW_REASON="skipped: A($d)=$AREC != $SERVER_IP"
    fi
  fi

  row=$(jq -Mc --arg d "$d" --arg a "${AREC:-}" --arg days "$DAYS" --arg end "${END_RAW:-}" \
              --arg subj "${SUBJ:-}" --arg iss "${ISSU:-}" \
              --arg renewed "$RENEWED" --arg reason "$RENEW_REASON" \
        '{domain:$d,a_record:$a,days_left:($days|tonumber? // $days),not_after:$end,subject:$subj,issuer:$iss,renewed:$renewed,renew_reason:$reason}')
  if [[ $first -eq 1 ]]; then echo "$row" >> "$tmp"; first=0; else echo ",$row" >> "$tmp"; fi
done

echo ']' >> "$tmp"
jq -Mc --slurpfile arr "$tmp" "$jq_begin|$jq_add|.domains=\$arr[0]" > "$LOG_JSON"
rm -f "$tmp"

# copy latest report into the repo snapshot (best effort)
cp -f "$LOG_JSON" /opt/reports/ 2>/dev/null || true

# pretty print to stdout if jq available
jq . "$LOG_JSON" 2>/dev/null || cat "$LOG_JSON"
