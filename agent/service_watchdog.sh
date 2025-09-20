#!/usr/bin/env bash
set -euo pipefail
LOG="/var/log/agent/service_watchdog.log"
ts(){ date -Iseconds; }
say(){ echo "[$(ts)] $*"; }
services=(apache2 mariadb fail2ban psa)   # psa == Plesk panel meta-service

for s in "${services[@]}"; do
  if ! systemctl is-active --quiet "$s"; then
    say "WARN: $s is NOT active -> restarting..." | tee -a "$LOG"
    systemctl restart "$s" || true
    sleep 2
    systemctl is-active --quiet "$s" && say "OK: $s back up" | tee -a "$LOG"
  fi
done
