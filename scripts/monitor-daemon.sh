#!/bin/bash

# ========================================
# Monitoring Daemon Script
# Continuously monitor system metrics and services
# ========================================

set -euo pipefail

MONITOR_LOG="/logs/monitor-daemon.log"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-60}"

log_monitor() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MONITOR_LOG"
}

# Main monitoring loop
log_monitor "Starting monitoring daemon (interval: ${MONITOR_INTERVAL}s)"

while true; do
    # Run system monitor
    /scripts/monitoring/system-monitor.sh
    
    # Check service health
    if ! /scripts/health-check.sh >/dev/null 2>&1; then
        log_monitor "WARNING: Health check failed"
    fi
    
    # Sleep until next check
    sleep "$MONITOR_INTERVAL"
done
