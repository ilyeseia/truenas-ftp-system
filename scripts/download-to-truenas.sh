#!/bin/bash

# ========================================
# Enhanced Download Script
# Advanced file download with retry, resume, and monitoring
# ========================================

set -euo pipefail

# Configuration
FTP_HOST="${FTP_HOST:-ftp71.nitroflare.com}"
FTP_USER="${FTP_USER:-}"
FTP_PASS="${FTP_PASS:-}"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/truenas/downloads}"
LOG_FILE="/logs/downloads.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log "INFO: $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log "SUCCESS: $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log "ERROR: $1"
}

# Show progress bar
show_progress() {
    local current=$1
    local total=$2
    local filename="$3"
    local percentage=$((current * 100 / total))
    local filled=$((percentage / 4))
    local empty=$((25 - filled))
    
    printf "\r${BLUE}Downloading: ${filename}${NC} ["
    printf "%*s" $filled | tr ' ' '='
    printf "%*s" $empty | tr ' ' '-'
    printf "] %d%%" $percentage
}

# Download single file with progress and retry
download_file() {
    local remote_file="$1"
    local local_file="${2:-$(basename "$remote_file")}"
    local destination="$DOWNLOAD_DIR/$local_file"
    
    log_info "Starting download: $remote_file"
    
    # Create directory if needed
    mkdir -p "$(dirname "$destination")"
    
    # Use lftp with progress and resume capabilities
    lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << EOF
set ftp:ssl-allow no
set ftp:passive-mode on
set net:timeout 30
set net:max-retries 3
set xfer:clobber off
set cmd:move-background no
get -c "$remote_file" -o "$destination"
quit
EOF
    
    if [[ $? -eq 0 && -f "$destination" ]]; then
        local file_size=$(du -h "$destination" | cut -f1)
        log_success "Download completed: $local_file ($file_size)"
        
        # Move to processing directory for further handling
        mkdir -p "/truenas/processing"
        cp "$destination" "/truenas/processing/"
        
        return 0
    else
        log_error "Download failed: $remote_file"
        return 1
    fi
}

# Batch download from file list
batch_download() {
    local file_list="$1"
    
    if [[ ! -f "$file_list" ]]; then
        log_error "File list not found: $file_list"
        return 1
    fi
    
    log_info "Starting batch download from: $file_list"
    
    local total_files=$(grep -v '^#' "$file_list" | grep -v '^$' | wc -l)
    local current=0
    local successful=0
    local failed=0
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        ((current++))
        
        show_progress $current $total_files "$line"
        echo # New line after progress bar
        
        if download_file "$line"; then
            ((successful++))
        else
            ((failed++))
        fi
        
        # Small delay between downloads
        sleep 2
        
    done < "$file_list"
    
    echo ""
    log_info "Batch download summary:"
    log_info "  Total files: $total_files"
    log_info "  Successful: $successful"
    log_info "  Failed: $failed"
    log_info "  Success rate: $(( successful * 100 / total_files ))%"
}

# Check FTP connection
test_connection() {
    log_info "Testing FTP connection to $FTP_HOST"
    
    if lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" -e "ls; quit" >/dev/null 2>&1; then
        log_success "FTP connection successful"
        return 0
    else
        log_error "FTP connection failed"
        return 1
    fi
}

# List remote files
list_files() {
    local remote_path="${1:-/}"
    
    log_info "Listing files in: $remote_path"
    
    lftp -u "$FTP_USER","$FTP_PASS" "$FTP_HOST" << EOF
cd "$remote_path"
ls -la
quit
EOF
}

# Show download statistics
show_stats() {
    echo "=== Download Statistics ==="
    echo "Recent downloads (last 24h):"
    
    local recent_count=$(find "$DOWNLOAD_DIR" -type f -mtime -1 | wc -l)
    local total_size=$(du -sh "$DOWNLOAD_DIR" 2>/dev/null | cut -f1)
    local total_files=$(find "$DOWNLOAD_DIR" -type f | wc -l)
    
    echo "  Files downloaded today: $recent_count"
    echo "  Total files: $total_files"
    echo "  Total size: $total_size"
    
    echo ""
    echo "Recent activity:"
    tail -10 "$LOG_FILE" 2>/dev/null || echo "No recent activity"
}

# Main menu
show_menu() {
    echo "=== Enhanced FTP Download Tool ==="
    echo "1. Test connection"
    echo "2. Download single file"
    echo "3. Batch download from list"
    echo "4. List remote files"
    echo "5. Show statistics"
    echo "6. Exit"
    echo ""
    read -p "Choose option: " choice
}

# Main execution
main() {
    case "${1:-menu}" in
        "test")
            test_connection
            ;;
        "download")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 download <remote_file> [local_name]"
                exit 1
            fi
            download_file "$2" "${3:-}"
            ;;
        "batch")
            if [[ -z "${2:-}" ]]; then
                echo "Usage: $0 batch <file_list>"
                exit 1
            fi
            batch_download "$2"
            ;;
        "list")
            list_files "${2:-}"
            ;;
        "stats")
            show_stats
            ;;
        "menu")
            while true; do
                show_menu
                case $choice in
                    1) test_connection ;;
                    2) 
                        read -p "Enter remote file path: " remote_file
                        read -p "Enter local name (optional): " local_name
                        download_file "$remote_file" "$local_name"
                        ;;
                    3)
                        read -p "Enter file list path: " file_list
                        batch_download "$file_list"
                        ;;
                    4)
                        read -p "Enter remote path (default /): " remote_path
                        list_files "${remote_path:-/}"
                        ;;
                    5) show_stats ;;
                    6) exit 0 ;;
                    *) echo "Invalid option" ;;
                esac
                echo ""
                read -p "Press Enter to continue..."
            done
            ;;
        *)
            echo "Enhanced FTP Download Tool"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  test                    - Test FTP connection"
            echo "  download <file> [name]  - Download single file"
            echo "  batch <list>           - Batch download from file list"
            echo "  list [path]            - List remote files"
            echo "  stats                  - Show download statistics"
            echo "  menu                   - Interactive menu"
            echo ""
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
