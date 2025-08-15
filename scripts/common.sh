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
