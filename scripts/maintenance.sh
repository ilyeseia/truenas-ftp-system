#!/bin/bash
# System Maintenance Script

set -euo pipefail

MAINTENANCE_LOG="/logs/maintenance.log"

log_maintenance() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MAINTENANCE_LOG"
}

# Cleanup temporary files
cleanup_temp_files() {
    log_maintenance "تنظيف الملفات المؤقتة"

    # Clean temp directories
    find /truenas/temp -type f -mtime +1 -delete 2>/dev/null || true
    find /tmp -name "*.tmp" -mtime +1 -delete 2>/dev/null || true

    # Clean old log files
    find /logs -name "*.log" -mtime +30 -delete 2>/dev/null || true

    # Clean Docker unused resources
    docker system prune -f >/dev/null 2>&1 || true

    log_maintenance "تم تنظيف الملفات المؤقتة"
}

# Optimize database
optimize_database() {
    log_maintenance "تحسين قاعدة البيانات"

    # PostgreSQL optimization
    docker exec -it postgres psql -U truenas -d truenas -c "VACUUM ANALYZE;" 2>/dev/null || true

    log_maintenance "تم تحسين قاعدة البيانات"
}

# Update system statistics
update_statistics() {
    log_maintenance "تحديث الإحصائيات"

    local stats_file="/logs/system-stats.json"
    local total_files=$(find /truenas -type f | wc -l)
    local total_size=$(du -sb /truenas 2>/dev/null | cut -f1)
    local disk_usage=$(df /truenas 2>/dev/null | tail -1 | awk '{print $5}' | cut -d'%' -f1)

    cat > "$stats_file" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "total_files": $total_files,
  "total_size_bytes": ${total_size:-0},
  "disk_usage_percent": ${disk_usage:-0},
  "uptime_seconds": $(cat /proc/uptime | cut -d' ' -f1 | cut -d'.' -f1)
}
EOF

    log_maintenance "تم تحديث الإحصائيات"
}

# Main maintenance routine
run_maintenance() {
    log_maintenance "بدء الصيانة الدورية"

    cleanup_temp_files
    optimize_database
    update_statistics

    log_maintenance "انتهت الصيانة الدورية"
}

# Schedule maintenance
if [[ "${1:-}" == "schedule" ]]; then
    # Run maintenance every night at 3 AM
    echo "0 3 * * * /scripts/maintenance.sh run" | crontab -
    log_maintenance "تم جدولة الصيانة الدورية"
elif [[ "${1:-}" == "run" ]]; then
    run_maintenance
else
    echo "Usage: $0 {run|schedule}"
    exit 1
fi
