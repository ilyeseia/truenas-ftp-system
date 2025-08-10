            fi
        done
    fi
    
    # Test 2: Service connectivity
    log_info "اختبار الاتصال بالخدمات"
    local services=(
        "http://localhost:${TRUENAS_WEB_PORT:-80}:TrueNAS"
        "http://localhost:${DASHBOARD_PORT:-8080}:Dashboard"
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
    if [[ -n "${PROMETHEUS_PORT:-}" ]]; then
        echo "  • Prometheus Metrics: http://localhost:${PROMETHEUS_PORT}"
    fi
    if [[ -n "${GRAFANA_PORT:-}" ]]; then
        echo "  • Grafana Monitoring: http://localhost:${GRAFANA_PORT}"
    fi
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
    if [[ -n "${GRAFANA_PASSWORD:-}" ]]; then
        echo "  • Grafana: admin / ${GRAFANA_PASSWORD}"
    fi
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
            docker-compose -f docker-compose-complete.yml exec ftp-client /scripts/backup-daemon.sh create 2>/dev/null || echo "Backup service not running"
            ;;
        "clean"|"cleanup")
            docker-compose -f docker-compose-complete.yml down -v
            docker system prune -f
            log_success "تم تنظيف النظام"
            ;;
        "restart")
            docker-compose -f docker-compose-complete.yml restart
            log_success "تم إعادة تشغيل الخدمات"
            ;;
        "logs")
            docker-compose -f docker-compose-complete.yml logs -f
            ;;
        "help"|"-h"|"--help")
            cat << 'EOF'
🗄️ TrueNAS + FTP System Installer

الاستخدام:
  ./deploy.sh [COMMAND]

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
  ./deploy.sh install    # تثبيت كامل
  ./deploy.sh test       # اختبار النظام
  ./deploy.sh status     # عرض الحالة

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
                        docker-compose -f docker-compose-complete.yml exec ftp-client /scripts/backup-daemon.sh create 2>/dev/null || echo "خدمة النسخ الاحتياطي غير متاحة"
                        ;;
                    9|"9️⃣")
                        echo -e "${YELLOW}هل أنت متأكد من تنظيف النظام؟ (y/N)${NC}"
                        read -p "الاختيار: " confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            docker-compose -f docker-compose-complete.yml down -v
                            docker system prune -f
                            log_success "تم تنظيف النظام"
                        fi
                        ;;
                    "🔄")
                        docker-compose -f docker-compose-complete.yml restart
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
fi