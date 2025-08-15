#!/bin/bash
# Alert Management Script

set -euo pipefail

ALERT_LOG="/logs/alerts.log"
WEBHOOK_URL="${ALERT_WEBHOOK:-}"
EMAIL="${ALERT_EMAIL:-}"

send_alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$timestamp] [$level] $message" >> "$ALERT_LOG"

    # Send webhook notification
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST "$WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "{\"level\":\"$level\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}" \
            >/dev/null 2>&1 || true
    fi

    # Send email notification (if configured)
    if [[ -n "$EMAIL" ]] && command -v mail >/dev/null; then
        echo "$message" | mail -s "[$level] TrueNAS Alert" "$EMAIL" || true
    fi
}

# Check system health
check_system_health() {
    # Check disk space
    local disk_usage=$(df /truenas 2>/dev/null | tail -1 | awk '{print $5}' | cut -d'%' -f1)
    if [[ ${disk_usage:-0} -gt 90 ]]; then
        send_alert "CRITICAL" "مساحة القرص منخفضة: ${disk_usage}%"
    elif [[ ${disk_usage:-0} -gt 80 ]]; then
        send_alert "WARNING" "مساحة القرص: ${disk_usage}%"
    fi

    # Check services
    if ! curl -sf http://truenas/api/v2.0/system/info >/dev/null; then
        send_alert "CRITICAL" "خدمة TrueNAS لا تستجيب"
    fi

    # Check FTP connectivity
    if ! timeout 10 lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "quit" 2>/dev/null; then
        send_alert "WARNING" "مشكلة في الاتصال بخادم FTP"
    fi
}

# Run health checks every 5 minutes
while true; do
    check_system_health
    sleep 300
done
