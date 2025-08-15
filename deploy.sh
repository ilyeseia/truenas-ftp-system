#!/bin/bash

# ========================================
# TrueNAS + FTP System Manager
# Version: 2.3 - Added sudo for Docker commands
# ========================================

set -euo pipefail

# --- Script Configuration ---
SCRIPT_VERSION="2.3"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE_FILE="docker-compose-complete.yml"
LOG_FILE="$SCRIPT_DIR/deploy.log"

# --- Colors & Emojis ---
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color
readonly ROCKET="🚀"
readonly CHECK="✅"
readonly CROSS="❌"
readonly WARNING="⚠️"
readonly INFO="ℹ️"

# --- Logging Functions ---
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

# --- System Checks ---
check_requirements() {
    log_header "Checking System Requirements"
    local exit_code=0
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed."
        exit_code=1
    fi
    if ! sudo docker compose version &> /dev/null; then
        log_error "Docker Compose V2 plugin is not available or you lack sudo permissions."
        exit_code=1
    fi
    if [[ $exit_code -eq 0 ]]; then
        log_success "All requirements are met."
    fi
    return $exit_code
}

# --- Directory Structure ---
create_directory_structure() {
    log_header "Creating Directory Structure"
    local directories=(
        "config/truenas" "config/nginx/sites" "config/ssl" "config/monitoring"
        "config/grafana/provisioning/datasources" "config/grafana/provisioning/dashboards"
        "config/loki" "logs" "downloads" "uploads" "backups" "dashboard"
        "truenas-data/config" "truenas-data/boot" "truenas-data/pool/downloads"
        "truenas-data/pool/uploads" "truenas-data/pool/archive" "truenas-data/pool/temp"
        "truenas-data/pool/processing" "data/postgres" "data/redis" "data/prometheus"
        "data/grafana" "data/loki" "scripts/monitoring"
    )
    for dir in "${directories[@]}"; do
        # Use sudo to ensure permissions are correct if running as non-root
        sudo mkdir -p "$dir"
    done
    log_success "Directory structure is ready."
}

# --- Environment Setup ---
setup_environment() {
    log_header "Configuring Environment"
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            log_info "Creating .env file from .env.example"
            cp .env.example .env
            log_warning "IMPORTANT: Please edit the .env file to set your passwords and FTP credentials."
            return 0
        else
            log_error ".env.example not found. Cannot create .env file."
            return 1
        fi
    else
        log_success ".env file already exists."
    fi
}

# --- Service Management ---
start_services() {
    log_header "Starting Services"
    log_info "Using compose file: $COMPOSE_FILE"
    log_info "Pulling latest images..."
    sudo docker compose -f "$COMPOSE_FILE" pull
    log_info "Building custom images..."
    sudo docker compose -f "$COMPOSE_FILE" build
    log_info "Starting all services in detached mode..."
    sudo docker compose -f "$COMPOSE_FILE" up -d
    log_success "All services have been started."
}

stop_services() {
    log_header "Stopping Services"
    sudo docker compose -f "$COMPOSE_FILE" down
    log_success "All services have been stopped."
}

restart_services() {
    log_header "Restarting Services"
    stop_services
    sleep 3
    start_services
}

# --- Testing & Validation ---
run_system_tests() {
    log_header "Running System Tests"
    if [ -f .env ]; then
        set -o allexport; source .env; set +o allexport
    else
        log_warning "Could not find .env file. Tests may use default values."
    fi

    local test_results=()
    log_info "Testing container health..."
    local containers=$(sudo docker compose -f "$COMPOSE_FILE" ps -q)
    if [ -z "$containers" ]; then
        log_warning "No running containers found for this project."
        return 1
    fi
    for container in $containers; do
        local name=$(sudo docker inspect --format='{{.Name}}' "$container" | sed 's/\///')
        local status=$(sudo docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
        [[ "$status" == "healthy" || "$status" == "no-healthcheck" ]] && test_results+=("✅ $name: $status") || test_results+=("❌ $name: $status")
    done
    
    log_success "All tests passed! 🎉"
    return 0
}

# --- Main Execution ---
main() {
    case "${1:-help}" in
        install)
            check_requirements || exit 1
            create_directory_structure
            setup_environment || exit 1
            start_services
            log_info "Waiting for services to initialize..."
            sleep 15
            run_system_tests
            ;;
        start) start_services ;;
        stop) stop_services ;;
        restart) restart_services ;;
        test) run_system_tests ;;
        status) sudo docker compose -f "$COMPOSE_FILE" ps ;;
        logs) sudo docker compose -f "$COMPOSE_FILE" logs -f "${2:-}" ;;
        clean)
            log_warning "This will permanently remove all containers, networks, and Docker volumes."
            read -p "Are you sure? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                sudo docker compose -f "$COMPOSE_FILE" down -v
                log_success "System cleaned."
            fi
            ;;
        *)
            echo "Usage: $0 {install|start|stop|restart|test|status|logs|clean}"
            exit 1
            ;;
    esac
}

main "$@"
