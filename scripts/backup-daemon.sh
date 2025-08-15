#!/bin/bash
# Automated Backup Daemon

set -euo pipefail

BACKUP_DIR="/backups"
RETENTION_DAYS=${BACKUP_RETENTION:-7}
BACKUP_LOG="/logs/backup.log"

log_backup() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_LOG"
}

create_backup() {
    local backup_name="truenas-backup-$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"

    log_backup "بدء إنشاء النسخة الاحتياطية: $backup_name"

    mkdir -p "$backup_path"

    # Backup configuration
    tar -czf "$backup_path/config.tar.gz" \
        /workspace/.env \
        /workspace/docker-compose*.yml \
        /workspace/config/ \
        2>/dev/null || log_backup "تحذير: فشل في نسخ بعض ملفات التكوين"

    # Backup TrueNAS data (metadata only, not actual files)
    tar -czf "$backup_path/truenas-metadata.tar.gz" \
        --exclude="*.zip" --exclude="*.rar" --exclude="*.tar*" \
        /truenas/downloads/ /truenas/uploads/ \
        2>/dev/null || log_backup "تحذير: فشل في نسخ بيانات TrueNAS"

    # Backup logs
    tar -czf "$backup_path/logs.tar.gz" /logs/ 2>/dev/null || true

    # Create backup manifest
    cat > "$backup_path/manifest.json" << EOF
{
  "backup_name": "$backup_name",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "version": "${SCRIPT_VERSION:-unknown}",
  "files": [
    "config.tar.gz",
    "truenas-metadata.tar.gz",
    "logs.tar.gz"
  ]
}
EOF

    log_backup "تمت النسخة الاحتياطية: $backup_name"

    # Upload to S3 if configured
    if [[ "${S3_BACKUP_ENABLED:-false}" == "true" && -n "${S3_BUCKET:-}" ]]; then
        upload_to_s3 "$backup_path"
    fi

    # Cleanup old backups
    cleanup_old_backups
}

upload_to_s3() {
    local backup_path="$1"

    if command -v aws >/dev/null 2>&1; then
        log_backup "رفع النسخة الاحتياطية إلى S3"
        aws s3 sync "$backup_path" "s3://${S3_BUCKET}/backups/$(basename "$backup_path")/" \
            --delete 2>/dev/null || log_backup "فشل في رفع النسخة الاحتياطية إلى S3"
    fi
}

cleanup_old_backups() {
    log_backup "تنظيف النسخ الاحتياطية القديمة (أكثر من $RETENTION_DAYS أيام)"
    find "$BACKUP_DIR" -type d -name "truenas-backup-*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true
}

# Setup cron job
setup_cron() {
    local schedule="${BACKUP_SCHEDULE:-0 2 * * *}"
    echo "$schedule /scripts/backup-daemon.sh create" | crontab -
    log_backup "تم تعيين جدولة النسخ الاحتياطية: $schedule"
}

# Main execution
case "${1:-daemon}" in
    "create")
        create_backup
        ;;
    "setup")
        setup_cron
        ;;
    "daemon")
        setup_cron
        # Keep daemon running
        while true; do
            sleep 3600  # Check every hour
        done
        ;;
    *)
        echo "Usage: $0 {create|setup|daemon}"
        exit 1
        ;;
esac
