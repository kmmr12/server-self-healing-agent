#!/usr/bin/env bash
set -euo pipefail
OUT="/var/log/agent/dns_auth_audit.json"
mkdir -p /var/log/agent
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }
command -v dig >/dev/null 2>&1 || { echo "dnsutils (dig) required"; exit 1; }
DOMAINS="$(plesk bin domain --list 2>/dev/null || true)"

tmp="$(mktemp)"; echo "[]" > "$tmp"
append_json() { local obj="$1"; jq -Mc --argjson item "$obj" '. += [$item]' "$tmp" > "${tmp}.new" && mv "${tmp}.new" "$tmp"; }

for d in $DOMAINS; do
  [[ -z "$d" ]] && continue
  SPF="$(dig +short TXT "$d" 2>/dev/null | tr -d '"' | tr '\n' '|' )"
  DMARC="$(dig +short TXT _dmarc."$d" 2>/dev/null | tr -d '"' | tr '\n' '|' )"
  DKIM="$(dig +short TXT default._domainkey."$d" 2>/dev/null | tr -d '"' | tr '\n' '|' )"

  spf_ok=false;   echo "$SPF"   | grep -qi 'v=spf1'   && spf_ok=true
  dmarc_ok=false; echo "$DMARC" | grep -qi 'v=DMARC1' && dmarc_ok=true
  dkim_ok=false;  echo "$DKIM"  | grep -qi 'p='       && dkim_ok=true

  note=""
  [[ "$spf_ok"   == true ]] || note="${note}missing SPF; "
  [[ "$dmarc_ok" == true ]] || note="${note}missing DMARC; "
  [[ "$dkim_ok"  == true ]] || note="${note}missing DKIM; "
  [[ -z "$note" ]] && note="auth ok"

  obj="$(jq -n --arg d "$d" --arg spf "${SPF:-}" --arg dmarc "${DMARC:-}" --arg dkim "${DKIM:-}" \
            --arg note "$note" --argjson spf_ok "$spf_ok" --argjson dmarc_ok "$dmarc_ok" --argjson dkim_ok "$dkim_ok" \
            '{domain:$d,spf:$spf,spf_ok:$spf_ok,dmarc:$dmarc,dmarc_ok:$dmarc_ok,dkim:$dkim,dkim_ok:$dkim_ok,note:$note}')"
  append_json "$obj"
done

jq -n --arg now "$(date -Iseconds)" --slurpfile arr "$tmp" \
  '{checked_at:$now,domains:$arr[0]}' > "$OUT"
rm -f "$tmp"

cp -f "$OUT" /opt/reports/ 2>/dev/null || true
jq . "$OUT" 2>/dev/null || cat "$OUT"
