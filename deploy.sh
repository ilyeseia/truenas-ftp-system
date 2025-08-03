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
EOF

    cat > scripts/monitoring/alert-manager.sh << 'EOF'
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
EOF
}

create_health_check_scripts() {
    cat > scripts/health-check.sh << 'EOF'
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
EOF

    cat > scripts/sync-health-check.sh << 'EOF'
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
EOF
}

create_backup_scripts() {
    cat > scripts/backup-daemon.sh << 'EOF'
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
EOF
}

create_maintenance_scripts() {
    cat > scripts/maintenance.sh << 'EOF'
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
EOF

    # Common functions script
    cat > scripts/common.sh << 'EOF'
#!/bin/bash
# Common functions for all scripts

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running in Docker
is_docker() {
    [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Wait for service to be ready
wait_for_service() {
    local service_url="$1"
    local max_attempts="${2:-30}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -sf "$service_url" >/dev/null 2>&1; then
            return 0
        fi
        
        echo "Waiting for $service_url... (attempt $attempt/$max_attempts)"
        sleep 2
        ((attempt++))
    done
    
    return 1
}

# Format file size
format_size() {
    local size=$1
    if command -v numfmt >/dev/null 2>&1; then
        numfmt --to=iec "$size"
    else
        echo "${size} bytes"
    fi
}
EOF
}

# ========================================
# SERVICE MANAGEMENT
# ========================================
start_services() {
    log_header "بدء تشغيل الخدمات"
    
    # Stop existing services
    log_info "إيقاف الخدمات الموجودة"
    docker-compose -f docker-compose-complete-optimized.yml down 2>/dev/null || true
    
    # Pull latest images
    log_info "سحب أحدث إصدارات الصور"
    docker-compose -f docker-compose-complete-optimized.yml pull
    
    # Build custom images
    log_info "بناء الصور المخصصة"
    docker-compose -f docker-compose-complete-optimized.yml build
    
    # Start core services first
    log_info "بدء الخدمات الأساسية"
    docker-compose -f docker-compose-complete-optimized.yml up -d postgres redis truenas
    
    # Wait for core services
    sleep 15
    
    # Start remaining services
    log_info "بدء باقي الخدمات"
    docker-compose -f docker-compose-complete-optimized.yml up -d
    
    # Enable monitoring profile
    log_info "تفعيل المراقبة"
    docker-compose -f docker-compose-complete-optimized.yml --profile monitoring up -d
    
    # Enable dashboard profile
    log_info "تفعيل لوحة التحكم"
    docker-compose -f docker-compose-complete-optimized.yml --profile dashboard up -d
    
    log_success "تم بدء تشغيل جميع الخدمات"
}

# ========================================
# TESTING & VALIDATION
# ========================================
run_system_tests() {
    log_header "تشغيل اختبارات النظام"
    
    local test_results=()
    
    # Test 1: Container health
    log_info "اختبار صحة الحاويات"
    local containers=$(docker-compose -f docker-compose-complete-optimized.yml ps -q)
    for container in $containers; do
        local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        local name=$(docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
        
        if [[ "$status" == "healthy" || "$status" == "unknown" ]]; then
            test_results+=("✅ $name: $status")
        else
            test_results+=("❌ $name: $status")
        fi
    done
    
    # Test 2: Service connectivity
    log_info "اختبار الاتصال بالخدمات"
    local services=(
        "http://localhost:${TRUENAS_WEB_PORT:-80}:TrueNAS"
        "http://localhost:${DASHBOARD_PORT:-8080}:Dashboard"
        "http://localhost:${PROMETHEUS_PORT:-9090}:Prometheus"
        "http://localhost:${GRAFANA_PORT:-3000}:Grafana"
    )
    
    for service in "${services[@]}"; do
        local url=$(echo "$service" | cut -d: -f1-3)
        local name=$(echo "$service" | cut -d: -f4)
        
        if curl -sf "$url" >/dev/null 2>&1; then
            test_results+=("✅ $name: متاح")
        else
            test_results+=("❌ $name: غير متاح")
        fi
    done
    
    # Test 3: FTP connectivity
    log_info "اختبار الاتصال بـ FTP"
    if docker-compose -f docker-compose-complete-optimized.yml exec -T ftp-client /scripts/health-check.sh >/dev/null 2>&1; then
        test_results+=("✅ FTP Client: يعمل")
    else
        test_results+=("❌ FTP Client: لا يعمل")
    fi
    
    # Test 4: Storage accessibility
    log_info "اختبار الوصول للتخزين"
    local storage_dirs=("downloads" "uploads" "archive" "temp")
    for dir in "${storage_dirs[@]}"; do
        if [[ -d "truenas-data/pool/$dir" && -w "truenas-data/pool/$dir" ]]; then
            test_results+=("✅ Storage $dir: متاح")
        else
            test_results+=("❌ Storage $dir: غير متاح")
        fi
    done
    
    # Display results
    echo ""
    log_info "نتائج الاختبارات:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
    
    # Count failures
    local failures=$(printf '%s\n' "${test_results[@]}" | grep -c "❌" || echo 0)
    
    if [[ $failures -eq 0 ]]; then
        log_success "جميع الاختبارات نجحت! 🎉"
        return 0
    else
        log_warning "$failures اختبار فشل"
        return 1
    fi
}

# ========================================
# INFORMATION DISPLAY
# ========================================
show_system_info() {
    log_header "معلومات النظام"
    
    echo ""
    echo -e "${ROCKET} ${WHITE}تم تثبيت نظام TrueNAS + FTP بنجاح!${NC}"
    echo ""
    
    echo -e "${CYAN}🌐 الخدمات المتاحة:${NC}"
    echo "  • TrueNAS Web UI: http://localhost:${TRUENAS_WEB_PORT:-80}"
    echo "  • Advanced Dashboard: http://localhost:${DASHBOARD_PORT:-8080}"
    echo "  • Prometheus Metrics: http://localhost:${PROMETHEUS_PORT:-9090}"
    echo "  • Grafana Monitoring: http://localhost:${GRAFANA_PORT:-3000}"
    echo ""
    
    echo -e "${CYAN}📝 الأوامر المفيدة:${NC}"
    echo "  • عرض الحالة: docker-compose exec ftp-client /scripts/health-check.sh"
    echo "  • اختبار FTP: docker-compose exec ftp-client /scripts/connect-ftp.sh"
    echo "  • تحميل ملف: docker-compose exec ftp-client /scripts/enhanced-ftp-client.sh download <file>"
    echo "  • مزامنة: docker-compose exec ftp-client /scripts/sync-truenas.sh"
    echo "  • عرض السجلات: docker-compose logs -f"
    echo ""
    
    echo -e "${CYAN}📁 المجلدات المهمة:${NC}"
    echo "  • التحميلات: ./truenas-data/pool/downloads/"
    echo "  • الأرشيف: ./truenas-data/pool/archive/"
    echo "  • السجلات: ./logs/"
    echo "  • النسخ الاحتياطية: ./backups/"
    echo ""
    
    echo -e "${CYAN}🛠️ إدارة النظام:${NC}"
    echo "  • إيقاف النظام: docker-compose down"
    echo "  • إعادة التشغيل: docker-compose restart"
    echo "  • تحديث الصور: docker-compose pull && docker-compose up -d"
    echo "  • تنظيف النظام: docker system prune -f"
    echo ""
    
    echo -e "${CYAN}🔐 بيانات الدخول الافتراضية:${NC}"
    echo "  • TrueNAS: admin / ${TRUENAS_ADMIN_PASSWORD:-admin123}"
    echo "  • Grafana: admin / ${GRAFANA_PASSWORD:-admin123}"
    echo ""
    
    echo -e "${YELLOW}⚠️  تذكير أمني:${NC}"
    echo "  • قم بتغيير كلمات المرور الافتراضية في ملف .env"
    echo "  • قم بتفعيل SSL في البيئة الإنتاجية"
    echo "  • راجع إعدادات الأمان في docker-compose.yml"
    echo ""
    
    echo -e "${GREEN}📚 للحصول على المساعدة:${NC}"
    echo "  • راجع ملف README.md"
    echo "  • تحقق من السجلات في مجلد ./logs/"
    echo "  • استخدم الأمر: $0 help"
    echo ""
}

# ========================================
# MENU SYSTEM
# ========================================
show_menu() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}              ${WHITE}🗄️  TrueNAS + FTP System Installer v${SCRIPT_VERSION}${NC}              ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}اختر العملية المطلوبة:${NC}"
    echo ""
    echo "  1️⃣   التثبيت الكامل (موصى به)"
    echo "  2️⃣   فحص المتطلبات فقط"
    echo "  3️⃣   إنشاء هيكل المجلدات"
    echo "  4️⃣   تثبيت النصوص والتكوينات"
    echo "  5️⃣   بدء الخدمات"
    echo "  6️⃣   تشغيل الاختبارات"
    echo "  7️⃣   عرض معلومات النظام"
    echo "  8️⃣   إنشاء نسخة احتياطية"
    echo "  9️⃣   تنظيف النظام"
    echo "  🔄   إعادة تشغيل الخدمات"
    echo "  📊   عرض حالة النظام"
    echo "  ❌   الخروج"
    echo ""
    echo -e "${YELLOW}💡 نصيحة: استخدم الخيار 1 للتثبيت السريع والكامل${NC}"
    echo ""
    read -p "اختيارك: " choice
}

# ========================================
# MAIN EXECUTION
# ========================================
main() {
    # Create log file
    touch "$LOG_FILE"
    
    # Handle command line arguments
    case "${1:-menu}" in
        "install"|"full")
            check_requirements || exit 1
            create_directory_structure
            generate_configuration_files
            install_enhanced_scripts
            start_services
            sleep 10
            run_system_tests
            show_system_info
            ;;
        "requirements"|"check")
            check_requirements
            ;;
        "structure"|"dirs")
            create_directory_structure
            ;;
        "config"|"configure")
            generate_configuration_files
            install_enhanced_scripts
            ;;
        "start"|"up")
            start_services
            ;;
        "test"|"tests")
            run_system_tests
            ;;
        "info"|"status")
            show_system_info
            ;;
        "backup")
            docker-compose -f docker-compose-complete-optimized.yml exec ftp-client /scripts/backup-daemon.sh create
            ;;
        "clean"|"cleanup")
            docker-compose -f docker-compose-complete-optimized.yml down -v
            docker system prune -f
            log_success "تم تنظيف النظام"
            ;;
        "restart")
            docker-compose -f docker-compose-complete-optimized.yml restart
            log_success "تم إعادة تشغيل الخدمات"
            ;;
        "logs")
            docker-compose -f docker-compose-complete-optimized.yml logs -f
            ;;
        "help"|"-h"|"--help")
            cat << 'EOF'
🗄️ TrueNAS + FTP System Installer

الاستخدام:
  ./deploy-optimized.sh [COMMAND]

الأوامر:
  install, full     - التثبيت الكامل
  requirements      - فحص المتطلبات
  structure         - إنشاء هيكل المجلدات
  config            - تكوين النظام
  start             - بدء الخدمات
  test              - تشغيل الاختبارات
  info, status      - عرض معلومات النظام
  backup            - إنشاء نسخة احتياطية
  clean             - تنظيف النظام
  restart           - إعادة تشغيل الخدمات
  logs              - عرض السجلات
  help              - عرض هذه المساعدة

أمثلة:
  ./deploy-optimized.sh install    # تثبيت كامل
  ./deploy-optimized.sh test       # اختبار النظام
  ./deploy-optimized.sh status     # عرض الحالة

EOF
            ;;
        "menu"|"")
            while true; do
                show_menu
                case $choice in
                    1|"1️⃣")
                        check_requirements || continue
                        create_directory_structure
                        generate_configuration_files
                        install_enhanced_scripts
                        start_services
                        sleep 10
                        run_system_tests
                        show_system_info
                        break
                        ;;
                    2|"2️⃣") check_requirements ;;
                    3|"3️⃣") create_directory_structure ;;
                    4|"4️⃣") 
                        generate_configuration_files
                        install_enhanced_scripts
                        ;;
                    5|"5️⃣") start_services ;;
                    6|"6️⃣") run_system_tests ;;
                    7|"7️⃣") show_system_info ;;
                    8|"8️⃣") 
                        docker-compose -f docker-compose-complete-optimized.yml exec ftp-client /scripts/backup-daemon.sh create
                        ;;
                    9|"9️⃣")
                        echo -e "${YELLOW}هل أنت متأكد من تنظيف النظام؟ (y/N)${NC}"
                        read -p "الاختيار: " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            docker-compose -f docker-compose-complete-optimized.yml down -v
                            docker system prune -f
                            log_success "تم تنظيف النظام"
                        fi
                        ;;
                    "🔄")
                        docker-compose -f docker-compose-complete-optimized.yml restart
                        log_success "تم إعادة تشغيل الخدمات"
                        ;;
                    "📊")
                        run_system_tests
                        ;;
                    "❌"|"exit"|"quit")
                        log_info "شكراً لاستخدام TrueNAS + FTP System!"
                        exit 0
                        ;;
                    *)
                        log_error "اختيار غير صحيح"
                        ;;
                esac
                echo ""
                read -p "اضغط Enter للمتابعة..."
            done
            ;;
        *)
            log_error "أمر غير معروف: $1"
            echo "استخدم '$0 help' لعرض المساعدة"
            exit 1
            ;;
    esac
}

# Trap to handle script interruption
trap 'echo -e "\n${YELLOW}تم إيقاف السكريبت${NC}"; exit 130' INT

# Run main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi#!/bin/bash

# ========================================
# Enhanced TrueNAS + FTP System Deployment Script
# Version: 2.0 - Production Ready
# Features: Health checks, monitoring, backup, security
# ========================================

set -euo pipefail

# Script configuration
SCRIPT_VERSION="2.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="truenas-ftp-system"
BACKUP_DIR="backup-$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$SCRIPT_DIR/deploy.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Emoji support
readonly ROCKET="🚀"
readonly CHECK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"
readonly GEAR="⚙️"
readonly FOLDER="📁"
readonly DOWNLOAD="📥"
readonly UPLOAD="📤"
readonly SYNC="🔄"
readonly MONITOR="📊"

# System requirements
MIN_DOCKER_VERSION="20.0"
MIN_COMPOSE_VERSION="1.27"
MIN_DISK_SPACE_GB=20
MIN_MEMORY_GB=4

# ========================================
# LOGGING FUNCTIONS
# ========================================
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}${INFO}${NC} $1"
    log "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}${CHECK}${NC} $1"
    log "SUCCESS" "$1"
}

log_warning() {
    echo -e "${YELLOW}${WARNING}${NC} $1"
    log "WARNING" "$1"
}

log_error() {
    echo -e "${RED}${CROSS}${NC} $1"
    log "ERROR" "$1"
}

log_header() {
    echo ""
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo ""
}

# Progress indicator
show_progress() {
    local current=$1
    local total=$2
    local task="$3"
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 4))
    local empty=$((25 - filled))
    
    printf "\r${CYAN}${task}${NC} ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%% (%d/%d)" $percentage $current $total
    
    if [[ $current -eq $total ]]; then
        echo ""
    fi
}

# ========================================
# SYSTEM CHECKS
# ========================================
check_requirements() {
    log_header "فحص المتطلبات الأساسية"
    local exit_code=0
    
    # Check operating system
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        log_success "نظام التشغيل: Linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        log_success "نظام التشغيل: macOS"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
        log_success "نظام التشغيل: Windows (WSL/Cygwin)"
    else
        log_error "نظام تشغيل غير مدعوم: $OSTYPE"
        exit_code=1
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if version_ge "$docker_version" "$MIN_DOCKER_VERSION"; then
            log_success "Docker: الإصدار $docker_version"
        else
            log_error "Docker: الإصدار القديم $docker_version (مطلوب $MIN_DOCKER_VERSION+)"
            exit_code=1
        fi
        
        # Check Docker daemon
        if docker info &> /dev/null; then
            log_success "Docker daemon: يعمل"
        else
            log_error "Docker daemon: لا يعمل"
            exit_code=1
        fi
    else
        log_error "Docker: غير مثبت"
        exit_code=1
    fi
    
    # Check Docker Compose
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
        if version_ge "$compose_version" "$MIN_COMPOSE_VERSION"; then
            log_success "Docker Compose: الإصدار $compose_version"
        else
            log_error "Docker Compose: الإصدار القديم $compose_version (مطلوب $MIN_COMPOSE_VERSION+)"
            exit_code=1
        fi
    else
        log_error "Docker Compose: غير مثبت"
        exit_code=1
    fi
    
    # Check disk space
    local available_gb=$(df "$SCRIPT_DIR" | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $available_gb -ge $MIN_DISK_SPACE_GB ]]; then
        log_success "مساحة القرص: ${available_gb}GB متاحة"
    else
        log_error "مساحة القرص: ${available_gb}GB (مطلوب ${MIN_DISK_SPACE_GB}GB على الأقل)"
        exit_code=1
    fi
    
    # Check memory
    local total_memory_gb
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        total_memory_gb=$(free -g | awk 'NR==2{print $2}')
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        total_memory_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
    else
        total_memory_gb=8  # Default assumption
    fi
    
    if [[ $total_memory_gb -ge $MIN_MEMORY_GB ]]; then
        log_success "الذاكرة: ${total_memory_gb}GB"
    else
        log_warning "الذاكرة: ${total_memory_gb}GB (موصى بـ ${MIN_MEMORY_GB}GB)"
    fi
    
    # Check network connectivity
    if ping -c 1 google.com &> /dev/null; then
        log_success "الاتصال بالإنترنت: متاح"
    else
        log_warning "الاتصال بالإنترنت: غير متاح (قد يؤثر على التثبيت)"
    fi
    
    # Check ports availability
    local ports=(80 443 8080 8081 2049 445 139)
    for port in "${ports[@]}"; do
        if ! netstat -tuln 2>/dev/null | grep -q ":$port "; then
            log_success "المنفذ $port: متاح"
        else
            log_warning "المنفذ $port: مستخدم (قد يحتاج تغيير)"
        fi
    done
    
    return $exit_code
}

version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

# ========================================
# DIRECTORY STRUCTURE CREATION
# ========================================
create_directory_structure() {
    log_header "إنشاء هيكل المجلدات"
    
    local directories=(
        # Main directories
        "scripts"
        "config/truenas"
        "config/nginx"
        "config/ssl"
        "config/monitoring"
        "config/grafana"
        "config/loki"
        "logs"
        "downloads"
        "uploads"
        "backups"
        "dashboard"
        
        # TrueNAS data structure
        "truenas-data/config"
        "truenas-data/boot"
        "truenas-data/pool/downloads"
        "truenas-data/pool/uploads"
        "truenas-data/pool/archive"
        "truenas-data/pool/temp"
        "truenas-data/pool/processing"
        
        # Database and cache
        "data/postgres"
        "data/redis"
        "data/prometheus"
        "data/grafana"
        "data/loki"
        
        # Plugin and extension directories
        "plugins"
        "extensions"
        "custom-scripts"
    )
    
    local total=${#directories[@]}
    local current=0
    
    for dir in "${directories[@]}"; do
        ((current++))
        show_progress $current $total "إنشاء المجلدات"
        
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            chmod 755 "$dir"
        fi
    done
    
    # Set special permissions
    chmod 700 config/ssl 2>/dev/null || true
    chmod 750 data/postgres 2>/dev/null || true
    chmod 755 truenas-data/pool/* 2>/dev/null || true
    
    log_success "تم إنشاء هيكل المجلدات بنجاح"
}

# ========================================
# CONFIGURATION FILES GENERATION
# ========================================
generate_configuration_files() {
    log_header "إنشاء ملفات التكوين"
    
    # Generate enhanced .env file
    if [[ ! -f ".env" ]]; then
        log_info "إنشاء ملف .env"
        generate_env_file
    else
        log_info "ملف .env موجود، جاري النسخ الاحتياطي"
        cp .env ".env.backup.$(date +%Y%m%d_%H%M%S)"
        update_env_file
    fi
    
    # Generate Docker configuration files
    generate_dockerfiles
    
    # Generate Nginx configuration
    generate_nginx_config
    
    # Generate monitoring configuration
    generate_monitoring_config
    
    # Generate SSL certificates (self-signed for development)
    generate_ssl_certificates
    
    log_success "تم إنشاء ملفات التكوين"
}

generate_env_file() {
    cat > .env << 'EOF'
# ========================================
# TrueNAS + FTP System Configuration
# Auto-generated by deploy script
# ========================================

# System Information
ENVIRONMENT=production
TIMEZONE=Europe/Paris
LOG_LEVEL=INFO
COMPOSE_PROJECT_NAME=truenas-ftp-system

# Security - CHANGE THESE PASSWORDS!
TRUENAS_ADMIN_PASSWORD=SecureAdmin2024!
TRUENAS_ROOT_PASSWORD=SecureRoot2024!
POSTGRES_PASSWORD=SecurePostgres2024!
REDIS_PASSWORD=SecureRedis2024!
GRAFANA_PASSWORD=SecureGrafana2024!

# FTP Configuration
FTP_HOST=ftp71.nitroflare.com
FTP_USER=your_username_here
FTP_PASS=your_password_here
FTP_PORT=21
FTP_PASSIVE=true
FTP_SSL=false

# Performance Settings
MAX_CONCURRENT_DOWNLOADS=3
DOWNLOAD_SPEED_LIMIT=0
PARALLEL_TRANSFERS=2
CHUNK_SIZE=8192

# Service Configuration
SYNC_INTERVAL=1800
MONITOR_INTERVAL=60
ARCHIVE_DAYS=7
CLEANUP_DAYS=30
BACKUP_SCHEDULE=0 2 * * *

# Network Configuration
TRUENAS_SUBNET=172.20.0.0/16
DASHBOARD_PORT=8080
TRUENAS_WEB_PORT=80
TRUENAS_HTTPS_PORT=443
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000

# Storage Configuration
MAX_ARCHIVE_SIZE=100G
COMPRESSION_ENABLED=true
DEDUPLICATION_ENABLED=true

# Monitoring & Alerts
METRICS_RETENTION=15d
ALERT_EMAIL=admin@example.com
WEBHOOK_NOTIFICATIONS=false

# SSL Configuration
SSL_ENABLED=true
EOF
    chmod 600 .env
}

update_env_file() {
    # Add new variables to existing .env if missing
    local new_vars=(
        "ENVIRONMENT=production"
        "SSL_ENABLED=true"
        "DEDUPLICATION_ENABLED=true"
        "WEBHOOK_NOTIFICATIONS=false"
    )
    
    for var in "${new_vars[@]}"; do
        local key=$(echo "$var" | cut -d'=' -f1)
        if ! grep -q "^$key=" .env; then
            echo "$var" >> .env
        fi
    done
}

generate_dockerfiles() {
    log_info "إنشاء Dockerfiles"
    
    # Enhanced FTP Client Dockerfile
    cat > Dockerfile.ftp-client << 'EOF'
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    lftp \
    curl \
    rsync \
    sshpass \
    jq \
    wget \
    nano \
    bash \
    coreutils \
    findutils \
    tar \
    gzip \
    python3 \
    py3-pip

# Install Python packages for advanced features
RUN pip3 install --no-cache-dir \
    requests \
    urllib3 \
    tqdm \
    rich

# Create directories
RUN mkdir -p /scripts /logs /workspace

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Set working directory
WORKDIR /workspace

# Health check
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
  CMD /scripts/health-check.sh || exit 1

CMD ["tail", "-f", "/dev/null"]
EOF

    # Enhanced Sync Service Dockerfile
    cat > Dockerfile.sync-service << 'EOF'
FROM alpine:latest

RUN apk add --no-cache \
    rsync \
    curl \
    jq \
    bash \
    coreutils \
    findutils \
    tar \
    gzip \
    python3 \
    py3-pip \
    cronie

# Install Python packages
RUN pip3 install --no-cache-dir \
    watchdog \
    schedule \
    psutil

# Create directories
RUN mkdir -p /scripts /logs

# Copy scripts
COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

# Setup cron
RUN echo "*/30 * * * * /scripts/sync-truenas.sh" > /etc/crontabs/root
RUN crond -b

HEALTHCHECK --interval=120s --timeout=15s --retries=3 \
  CMD /scripts/sync-health-check.sh || exit 1

CMD ["/scripts/sync-daemon.sh"]
EOF

    # Monitoring Service Dockerfile
    cat > Dockerfile.monitor << 'EOF'
FROM prom/prometheus:latest

USER root
RUN apk add --no-cache curl jq bash

# Copy configuration
COPY config/monitoring/prometheus.yml /etc/prometheus/

# Create custom scripts directory
RUN mkdir -p /scripts
COPY scripts/monitoring/ /scripts/
RUN chmod +x /scripts/*.sh

USER prometheus
CMD ["--config.file=/etc/prometheus/prometheus.yml", \
     "--storage.tsdb.path=/prometheus", \
     "--web.console.libraries=/etc/prometheus/console_libraries", \
     "--web.console.templates=/etc/prometheus/consoles", \
     "--web.enable-lifecycle"]
EOF

    # Dashboard Dockerfile
    cat > Dockerfile.dashboard << 'EOF'
FROM node:alpine AS builder

WORKDIR /app
COPY dashboard/package*.json ./
RUN npm install
COPY dashboard/ .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY config/nginx/dashboard.conf /etc/nginx/conf.d/default.conf

# Add health check endpoint
RUN echo '#!/bin/sh\necho "OK"' > /usr/share/nginx/html/health && \
    chmod +x /usr/share/nginx/html/health

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    log_success "تم إنشاء Dockerfiles"
}

generate_nginx_config() {
    log_info "إنشاء تكوين Nginx"
    
    # Main nginx configuration
    cat > config/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    # Performance
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript 
               application/x-javascript application/xml+rss 
               application/javascript application/json;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Include site configurations
    include /etc/nginx/sites.d/*.conf;
}
EOF

    # Dashboard site configuration
    cat > config/nginx/sites/dashboard.conf << 'EOF'
upstream truenas {
    server truenas:80;
}

upstream dashboard-api {
    server dashboard:3000;
}

server {
    listen 80;
    server_name localhost;
    
    # Dashboard
    location / {
        root /usr/share/nginx/html;
        index index.html;
        try_files $uri $uri/ =404;
    }
    
    # API proxy
    location /api/ {
        proxy_pass http://dashboard-api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # TrueNAS proxy
    location /truenas/ {
        proxy_pass http://truenas/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # WebSocket support
    location /ws {
        proxy_pass http://dashboard-api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF

    log_success "تم إنشاء تكوين Nginx"
}

generate_monitoring_config() {
    log_info "إنشاء تكوين المراقبة"
    
    # Prometheus configuration
    cat > config/monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'truenas'
    static_configs:
      - targets: ['truenas:80']
    scrape_interval: 30s

  - job_name: 'ftp-client'
    static_configs:
      - targets: ['ftp-client:8080']
    scrape_interval: 30s

  - job_name: 'sync-service'
    static_configs:
      - targets: ['sync-service:8080']
    scrape_interval: 60s

  - job_name: 'dashboard'
    static_configs:
      - targets: ['dashboard:80']
    scrape_interval: 30s
EOF

    # Grafana datasource configuration
    mkdir -p config/grafana/provisioning/{datasources,dashboards}
    
    cat > config/grafana/provisioning/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://monitor-service:9090
    isDefault: true
    editable: true
EOF

    # Loki configuration
    cat > config/loki/local-config.yaml << 'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

ingester:
  lifecycler:
    address: 127.0.0.1
    ring:
      kvstore:
        store: inmemory
      replication_factor: 1
    final_sleep: 0s
  chunk_idle_period: 5m
  chunk_retain_period: 30s

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 168h

storage_config:
  boltdb:
    directory: /loki/index
  filesystem:
    directory: /loki/chunks

limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: false
  retention_period: 0s
EOF

    log_success "تم إنشاء تكوين المراقبة"
}

generate_ssl_certificates() {
    log_info "إنشاء شهادات SSL للتطوير"
    
    if [[ ! -f "config/ssl/cert.pem" ]]; then
        # Generate self-signed certificate for development
        openssl req -x509 -newkey rsa:4096 -nodes -keyout config/ssl/private.key \
            -out config/ssl/cert.pem -days 365 -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" \
            2>/dev/null || {
            log_warning "فشل في إنشاء شهادة SSL، سيتم استخدام HTTP"
            echo "SSL_ENABLED=false" >> .env
        }
    fi
}

# ========================================
# ENHANCED SCRIPTS INSTALLATION
# ========================================
install_enhanced_scripts() {
    log_header "تثبيت النصوص المحسنة"
    
    # Enhanced connection script
    create_connect_script
    
    # Enhanced download script (already in artifact)
    # create_download_script
    
    # Enhanced sync script  
    create_sync_script
    
    # Enhanced monitoring scripts
    create_monitoring_scripts
    
    # Health check scripts
    create_health_check_scripts
    
    # Backup scripts
    create_backup_scripts
    
    # Maintenance scripts
    create_maintenance_scripts
    
    # Make all scripts executable
    find scripts/ -name "*.sh" -exec chmod +x {} \;
    
    log_success "تم تثبيت النصوص المحسنة"
}

create_connect_script() {
    cat > scripts/connect-ftp.sh << 'EOF'
#!/bin/bash
# Enhanced FTP Connection Script

set -euo pipefail

source "$(dirname "$0")/common.sh"

echo "=== اختبار الاتصال بخادم FTP ==="
echo "الخادم: $FTP_HOST:${FTP_PORT:-21}"
echo "المستخدم: $FTP_USER"

# Test basic connectivity
if ! ping -c 1 -W 3 "$FTP_HOST" &>/dev/null; then
    log_error "فشل في الوصول إلى الخادم $FTP_HOST"
    exit 1
fi

# Test FTP connection
lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << 'FTPEOF'
set ftp:ssl-allow no
set ftp:passive-mode on
set net:timeout 10
ls -la
pwd
quit
FTPEOF

if [[ $? -eq 0 ]]; then
    log_success "اتصال FTP ناجح"
else
    log_error "فشل اتصال FTP"
    exit 1
fi
EOF
}

create_sync_script() {
    cat > scripts/sync-truenas.sh << 'EOF'
#!/bin/bash
# Enhanced Synchronization Script

set -euo pipefail

source "$(dirname "$0")/common.sh"

SYNC_LOG="/logs/sync.log"
ARCHIVE_DAYS=${ARCHIVE_DAYS:-7}
CLEANUP_DAYS=${CLEANUP_DAYS:-30}

log_info "بدء عملية المزامنة"

# Create directories if not exist
mkdir -p /truenas/{downloads,uploads,archive,temp,processing}

# Sync local downloads to TrueNAS
if [[ -d "/downloads-local" ]] && [[ "$(ls -A /downloads-local 2>/dev/null)" ]]; then
    log_info "مزامنة: downloads-local → truenas/downloads"
    rsync -av --progress --stats /downloads-local/ /truenas/downloads/ | tee -a "$SYNC_LOG"
    
    # Move processed files
    find /downloads-local -type f -mmin +5 -exec mv {} /truenas/processing/ \;
fi

# Sync local uploads to TrueNAS  
if [[ -d "/uploads-local" ]] && [[ "$(ls -A /uploads-local 2>/dev/null)" ]]; then
    log_info "مزامنة: uploads-local → truenas/uploads"
    rsync -av --progress --stats /uploads-local/ /truenas/uploads/ | tee -a "$SYNC_LOG"
fi

# Archive old files
log_info "أرشفة الملفات القديمة (أكثر من $ARCHIVE_DAYS أيام)"
find /truenas/downloads -type f -mtime +$ARCHIVE_DAYS -exec mv {} /truenas/archive/ \; 2>/dev/null || true
find /truenas/uploads -type f -mtime +$ARCHIVE_DAYS -exec mv {} /truenas/archive/ \; 2>/dev/null || true

# Cleanup very old files
log_info "حذف الملفات القديمة جداً (أكثر من $CLEANUP_DAYS يوم)"
find /truenas/archive -type f -mtime +$CLEANUP_DAYS -delete 2>/dev/null || true
find /truenas/temp -type f -mtime +1 -delete 2>/dev/null || true

# Update statistics
TOTAL_FILES=$(find /truenas -type f | wc -l)
TOTAL_SIZE=$(du -sh /truenas 2>/dev/null | cut -f1)

log_success "المزامنة مكتملة - الملفات: $TOTAL_FILES، الحجم: $TOTAL_SIZE"
EOF
}

create_monitoring_scripts() {
    mkdir -p scripts/monitoring
    
    cat > scripts/monitoring/system-monitor.sh << 'EOF'
#!/bin/bash
# System Monitoring Script

set -euo pipefail

METRICS_FILE="/logs/metrics.json"

# Collect system metrics
collect_metrics() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # System metrics
