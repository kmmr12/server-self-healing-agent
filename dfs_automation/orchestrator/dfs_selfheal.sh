#!/bin/bash
set -euo pipefail
LOG="/var/log/dfs/selfheal_$(date -u +%F_%H%M).log"
{
echo "[Selfheal] $(date -u)"
for s in dfs_advisor_dashboard dfs_auto_ingest dfs_auto_validate dfs_intelligence; do
  systemctl is-active --quiet "$s" 2>/dev/null || systemctl restart "$s" 2>/dev/null || echo "⚠️  $s restart failed"
done
echo "[Selfheal] complete"
} | tee -a "$LOG"
