#!/bin/bash
# Health Check Script for FTP Client

set -euo pipefail

# Check if required commands are available
for cmd in lftp curl rsync; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Required command '$cmd' not found"
        exit 1
    fi
done

# Check FTP connectivity
if [[ -n "${FTP_HOST:-}" && -n "${FTP_USER:-}" && -n "${FTP_PASS:-}" ]]; then
    if timeout 10 lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "quit" 2>/dev/null; then
        echo "OK: FTP connection successful"
    else
        echo "ERROR: FTP connection failed"
        exit 1
    fi
fi

# Check directory accessibility
for dir in /truenas/downloads /truenas/uploads /logs; do
    if [[ ! -d "$dir" || ! -w "$dir" ]]; then
        echo "ERROR: Directory '$dir' not accessible"
        exit 1
    fi
done

echo "OK: All health checks passed"
exit 0
