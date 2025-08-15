#!/bin/bash
# Health Check Script for Sync Service

set -euo pipefail

# Check if sync process is running
if pgrep -f sync-daemon.sh >/dev/null; then
    echo "OK: Sync daemon is running"
else
    echo "ERROR: Sync daemon not running"
    exit 1
fi

# Check last sync time
SYNC_LOG="/logs/sync.log"
if [[ -f "$SYNC_LOG" ]]; then
    LAST_SYNC=$(tail -1 "$SYNC_LOG" | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || echo "")
    if [[ -n "$LAST_SYNC" ]]; then
        LAST_SYNC_TIMESTAMP=$(date -d "$LAST_SYNC" +%s 2>/dev/null || echo 0)
        CURRENT_TIMESTAMP=$(date +%s)
        DIFF=$((CURRENT_TIMESTAMP - LAST_SYNC_TIMESTAMP))

        # Alert if last sync was more than 2 hours ago
        if [[ $DIFF -gt 7200 ]]; then
            echo "WARNING: Last sync was $(($DIFF / 3600)) hours ago"
            exit 1
        fi
    fi
fi

echo "OK: Sync service healthy"
exit 0
