#!/bin/bash

# ==========================
# server_hardener_agent.sh
# Secure + Harden WordPress/Plesk Server
# Author: kmmr12 (GitHub verified)
# ==========================

set -euo pipefail

TODAY=$(date +%Y%m%d)
BACKUP_DIR="/mnt/volume-nbg1-1/backups/$TODAY"
mkdir -p "$BACKUP_DIR"

log() {
    echo -e "[INFO] $1"
}

err() {
    echo -e "[ERROR] $1" >&2
}

# 1. SSH SECURITY
log "Hardening SSH config..."
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
systemctl reload sshd

# 2. FAIL2BAN
log "Installing and enabling Fail2Ban..."
apt-get update && apt-get install -y fail2ban
systemctl enable --now fail2ban

# 3. UFW FIREWALL
log "Setting UFW rules..."
ufw allow 22
ufw allow 80
ufw allow 443
ufw allow 8443
ufw --force enable

# 4. PLESK HARDENING
log "Enabling Plesk ModSecurity + Fail2Ban..."
plesk bin server_pref -u -modsecurity-protection true
plesk bin server_pref -u -fail2ban true
plesk bin ip_access -u -service panel -deny all
plesk bin ip_access -u -service panel -allow 127.0.0.1

# 5. WORDPRESS HARDENING
log "Scanning WordPress sites for basic security..."
for wp in /var/www/vhosts/*/httpdocs; do
    if [[ -f "$wp/wp-config.php" ]]; then
        chown root:root "$wp/wp-config.php"
        chmod 600 "$wp/wp-config.php"
        find "$wp" -type d -exec chmod 755 {} \;
        find "$wp" -type f -exec chmod 644 {} \;
        log "Secured: $wp"
    fi
    # Optional: remove xmlrpc.php if not needed
    [[ -f "$wp/xmlrpc.php" ]] && rm "$wp/xmlrpc.php"

done

# 6. BACKUPS
log "Backing up MySQL and site files to $BACKUP_DIR..."
mkdir -p "$BACKUP_DIR/sql" "$BACKUP_DIR/files"
for db in $(mysql -e 'SHOW DATABASES;' | grep -Ev 'Database|information_schema|performance_schema|mysql|sys'); do
    mysqldump "$db" > "$BACKUP_DIR/sql/${db}.sql"
    log "Dumped DB: $db"
done

tar -czf "$BACKUP_DIR/files/www_backup.tar.gz" /var/www/vhosts

# 7. AUTO-UPDATES
log "Enabling unattended upgrades..."
apt-get install -y unattended-upgrades
systemctl enable --now unattended-upgrades

# 8. POSTFLIGHT SUMMARY
log "Postflight summary:"
echo "Backup directory: $BACKUP_DIR"
echo "SSH hardened, Fail2Ban active, UFW rules applied"
echo "WordPress sites scanned and permissions locked"
echo "Plesk ModSecurity enabled + IP lockdown enforced"
echo "Use this script in cron or run manually for periodic hardening"

exit 0
