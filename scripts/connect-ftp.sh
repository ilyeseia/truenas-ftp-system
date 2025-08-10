#!/bin/bash

# ========================================
# Connect FTP Script - Enhanced Version
# Test and establish FTP connections with diagnostics
# ========================================

set -euo pipefail

# Configuration
FTP_HOST="${FTP_HOST:-ftp71.nitroflare.com}"
FTP_USER="${FTP_USER:-}"
FTP_PASS="${FTP_PASS:-}"
FTP_PORT="${FTP_PORT:-21}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Check if credentials are set
check_credentials() {
    if [[ -z "$FTP_USER" || -z "$FTP_PASS" ]]; then
        log_error "FTP credentials not set. Please configure FTP_USER and FTP_PASS in .env file"
        return 1
    fi
    return 0
}

# Test network connectivity
test_network() {
    log_info "Testing network connectivity to $FTP_HOST"
    
    if ping -c 1 -W 3 "$FTP_HOST" >/dev/null 2>&1; then
        log_success "Network connectivity: OK"
        return 0
    else
        log_error "Cannot reach $FTP_HOST - check network connection"
        return 1
    fi
}

# Test FTP port
test_ftp_port() {
    log_info "Testing FTP port $FTP_PORT on $FTP_HOST"
    
    if timeout 10 bash -c "</dev/tcp/$FTP_HOST/$FTP_PORT" 2>/dev/null; then
        log_success "FTP port $FTP_PORT: Open"
        return 0
    else
        log_error "FTP port $FTP_PORT: Closed or filtered"
        return 1
    fi
}

# Test FTP authentication
test_ftp_auth() {
    log_info "Testing FTP authentication"
    
    local auth_result=$(lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << 'EOF'
set ftp:ssl-allow no
set ftp:passive-mode on
set net:timeout 10
pwd
quit
EOF
)
    
    if [[ $? -eq 0 ]]; then
        log_success "FTP authentication: OK"
        echo "Current directory: $(echo "$auth_result" | grep -v "^$" | tail -1)"
        return 0
    else
        log_error "FTP authentication failed - check username and password"
        return 1
    fi
}

# Test FTP operations
test_ftp_operations() {
    log_info "Testing FTP operations (list, navigate)"
    
    lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << 'EOF'
set ftp:ssl-allow no
set ftp:passive-mode on
set net:timeout 10
echo "=== Directory listing ==="
ls -la
echo ""
echo "=== Directory navigation test ==="
pwd
echo "=== Connection info ==="
set
quit
EOF
    
    if [[ $? -eq 0 ]]; then
        log_success "FTP operations: OK"
        return 0
    else
        log_error "FTP operations failed"
        return 1
    fi
}

# Interactive FTP session
interactive_ftp() {
    log_info "Starting interactive FTP session"
    log_info "Type 'help' for FTP commands, 'quit' to exit"
    
    lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << 'EOF'
set ftp:ssl-allow no
set ftp:passive-mode on
set net:timeout 30
set cmd:interactive yes
EOF
}

# Show FTP server info
show_server_info() {
    log_info "Gathering FTP server information"
    
    echo "=== FTP Server Information ==="
    echo "Host: $FTP_HOST"
    echo "Port: $FTP_PORT"
    echo "User: $FTP_USER"
    echo ""
    
    # Get server banner and features
    lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << 'EOF'
set ftp:ssl-allow no
set ftp:passive-mode on
set net:timeout 10
debug 1
open
quote SYST
quote FEAT
quit
EOF
}

# Full connection test
full_test() {
    echo "=== FTP Connection Diagnostic ==="
    echo "Server: $FTP_HOST:$FTP_PORT"
    echo "User: $FTP_USER"
    echo ""
    
    local tests=0
    local passed=0
    
    # Test 1: Credentials
    ((tests++))
    if check_credentials; then
        ((passed++))
    fi
    
    # Test 2: Network
    ((tests++))
    if test_network; then
        ((passed++))
    fi
    
    # Test 3: FTP Port
    ((tests++))
    if test_ftp_port; then
        ((passed++))
    fi
    
    # Test 4: Authentication
    ((tests++))
    if test_ftp_auth; then
        ((passed++))
    fi
    
    # Test 5: Operations
    ((tests++))
    if test_ftp_operations; then
        ((passed++))
    fi
    
    echo ""
    echo "=== Test Summary ==="
    echo "Tests passed: $passed/$tests"
    
    if [[ $passed -eq $tests ]]; then
        log_success "All tests passed! FTP connection is working properly"
        return 0
    else
        log_error "Some tests failed. Check the errors above"
        return 1
    fi
}

# Quick connection test
quick_test() {
    log_info "Quick FTP connection test"
    
    if ! check_credentials; then
        return 1
    fi
    
    if timeout 10 lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "ls; quit" >/dev/null 2>&1; then
        log_success "FTP connection: OK"
        return 0
    else
        log_error "FTP connection: Failed"
        return 1
    fi
}

# Show usage
show_usage() {
    echo "FTP Connection Tool"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  test        - Full connection diagnostic"
    echo "  quick       - Quick connection test"
    echo "  info        - Show server information"
    echo "  interactive - Start interactive FTP session"
    echo "  network     - Test network connectivity only"
    echo "  port        - Test FTP port only"
    echo "  auth        - Test authentication only"
    echo ""
    echo "Environment variables:"
    echo "  FTP_HOST - FTP server hostname"
    echo "  FTP_USER - FTP username"
    echo "  FTP_PASS - FTP password"
    echo "  FTP_PORT - FTP port (default: 21)"
    echo ""
}

# Main execution
main() {
    case "${1:-test}" in
        "test"|"full")
            full_test
            ;;
        "quick")
            quick_test
            ;;
        "info")
            show_server_info
            ;;
        "interactive"|"shell")
            interactive_ftp
            ;;
        "network")
            test_network
            ;;
        "port")
            test_ftp_port
            ;;
        "auth")
            test_ftp_auth
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo "Unknown command: $1"
            show_usage
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
