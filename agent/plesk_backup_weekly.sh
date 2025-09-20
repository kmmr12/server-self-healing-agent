#!/usr/bin/env bash
set -euo pipefail
OUTDIR="/var/backups/plesk"
stamp="$(date +%F)"
file="${OUTDIR}/server-${stamp}.tar"
# Full server backup; adjust if you prefer incremental or exclude dirs.
plesk bin pleskbackup server -f "$file"
# Keep only the most recent backup (delete older than 8 days)
find "$OUTDIR" -type f -name 'server-*.tar' -mtime +8 -delete
