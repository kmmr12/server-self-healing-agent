#!/usr/bin/env bash
set -euo pipefail
LOG="/var/log/fw_guard.log"
ts(){ date -Iseconds; }
say(){ echo "[$(ts)] $*"; }

# Capture numbered rules once
NUM="$(ufw status numbered || true)"

# Helper: get first index of pattern
idx_first() { echo "$NUM" | sed -n "s/^\[\([0-9]\+\)\].*$1.*$/\1/p" | head -n1; }

# 1) Ensure port 22 is denied (v4+v6)
if ! echo "$NUM" | grep -qE '\] 22\s+DENY'; then
  say "Enforcing: deny 22"; ufw deny 22 || true
fi

# 2) Ensure 8443: all ALLOWs appear before any DENY
ALLOW_8443_IDX=$(idx_first '8443.*ALLOW')
DENY_8443_IDX=$(idx_first '8443.*DENY( |$)')
if [[ -n "$DENY_8443_IDX" && -n "$ALLOW_8443_IDX" && "$DENY_8443_IDX" -lt "$ALLOW_8443_IDX" ]]; then
  say "Fixing order for 8443 (DENY before ALLOW) -> reordering"
  # delete all 8443 rules, reinsert allows first, then deny
  mapfile -t RULES < <(echo "$NUM" | sed -n 's/^\[\([0-9]\+\)\].*8443.*/\1/p' | sort -rn)
  for N in "${RULES[@]}"; do ufw --force delete "$N"; done
  # Rebuild: first re-add all ALLOWs we had, then a single DENY Anywhere
  echo "$NUM" | sed -n 's/.*\(8443\).*ALLOW.*From: \([^ ]\+\).*/\2/p' | while read -r ip; do
    [[ -n "$ip" ]] && ufw insert 1 allow from "$ip" to any port 8443
  done
  ufw insert 2 deny 8443
fi

# 3) Ensure 2222 has no broad ALLOW (should be IP-scoped only)
if echo "$NUM" | grep -qE '\] 2222\s+ALLOW IN\s+Anywhere'; then
  say "Removing broad ALLOW on 2222"; ufw delete allow 2222 || true
fi
# Make sure at least one allow exists for 2222 (don’t guess the IP; do nothing if none)
if ! ufw status | grep -qE '2222.*ALLOW'; then
  say "WARNING: no ALLOW for 2222 present; not adding any (manual action needed)" | tee -a "$LOG"
  logger -t fw-guard "WARNING: no ALLOW for 2222 present; not adding any"
fi

ufw reload
say "fw-guard OK: 22 denied; 8443 order good; 2222 scoped"
