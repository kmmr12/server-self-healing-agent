import os
#!/bin/bash
set -euo pipefail
OUT="/var/log/dfs/daily_report_$(date -u +%F).log"
{
echo "[Report] $(date -u)"
echo "Active DFS services:"; systemctl list-units --type=service | grep dfs_ || echo "none"
echo "Ports:"; ss -tulnp | grep -E '5193|5194|5902|5917' || echo "none"
sqlite3 os.environ.get(DFS_DB,/opt/dfs_agent/db/dfs_agent.db) "PRAGMA integrity_check;"
du -sh /opt/dfs_* /var/log/dfs 2>/dev/null
echo "[Report] done"
} | tee -a "$OUT"
