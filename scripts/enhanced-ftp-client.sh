#!/bin/bash

# ========================================
# Enhanced FTP Client Script
# Advanced download management with retry logic, 
# parallel transfers, and intelligent error handling
# ========================================

set -euo pipefail

# ========================================
# CONFIGURATION
# ========================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/ftp-client.conf"
LOG_FILE="${LOG_DIR:-/logs}/ftp-client.log"
ERROR_LOG="${LOG_DIR:-/logs}/ftp-errors.log"
STATS_FILE="${LOG_DIR:-/logs}/ftp-stats.json"

# Default values
FTP_HOST="${FTP_HOST:-ftp71.nitroflare.com}"
FTP_USER="${FTP_USER:-}"
FTP_PASS="${FTP_PASS:-}"
FTP_PORT="${FTP_PORT:-21}"
FTP_PASSIVE="${FTP_PASSIVE:-true}"
FTP_SSL="${FTP_SSL:-false}"
FTP_TIMEOUT="${FTP_TIMEOUT:-30}"
FTP_RETRY_COUNT="${FTP_RETRY_COUNT:-3}"
MAX_CONCURRENT_DOWNLOADS="${MAX_CONCURRENT_DOWNLOADS:-3}"
DOWNLOAD_SPEED_LIMIT="${DOWNLOAD_SPEED_LIMIT:-0}"
CHUNK_SIZE="${CHUNK_SIZE:-8192}"
PARALLEL_TRANSFERS="${PARALLEL_TRANSFERS:-2}"

# Directories
DOWNLOAD_DIR="${DOWNLOAD_DIR:-/truenas/downloads}"
TEMP_DIR="${TEMP_DIR:-/truenas/temp}"
PROCESSING_DIR="${PROCESSING_DIR:-/truenas/processing}"
ARCHIVE_DIR="${ARCHIVE_DIR:-/truenas/archive}"

# ========================================
# LOGGING & UTILITIES
# ========================================
log() {
    local
