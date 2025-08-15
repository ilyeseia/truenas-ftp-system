#!/bin/bash
# System Monitoring Script

set -euo pipefail

METRICS_FILE="/logs/metrics.json"

# Collect system metrics
collect_metrics() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # System metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    local memory_usage=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
    local disk_usage=$(df /truenas 2>/dev/null | tail -1 | awk '{print $5}' | cut -d'%' -f1)

    # FTP metrics
    local active_connections=$(netstat -an | grep :21 | grep ESTABLISHED | wc -l)
    local download_count=$(find /truenas/downloads -type f -mtime -1 | wc -l)
    local total_size=$(du -sb /truenas 2>/dev/null | cut -f1)

    # Create JSON metrics
    cat > "$METRICS_FILE" << EOF
{
  "timestamp": "$timestamp",
  "system": {
    "cpu_usage": ${cpu_usage:-0},
    "memory_usage": ${memory_usage:-0},
    "disk_usage": ${disk_usage:-0}
  },
  "ftp": {
    "active_connections": $active_connections,
    "daily_downloads": $download_count,
    "total_storage_bytes": ${total_size:-0}
  },
  "services": {
    "truenas": "$(curl -sf http://truenas/api/v2.0/system/info >/dev/null && echo 'up' || echo 'down')",
    "ftp_client": "$(pgrep -f lftp >/dev/null && echo 'up' || echo 'down')"
  }
}
EOF
}

# Main monitoring loop
while true; do
    collect_metrics
    sleep ${MONITOR_INTERVAL:-60}
done
