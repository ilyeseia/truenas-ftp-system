#!/bin/bash

# ========================================
# System Setup Environment Script
# Prepare the environment for TrueNAS + FTP System
# ========================================

set -euo pipefail

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

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_warning "Running as root. This is not recommended for Docker operations."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Install Docker if not present
install_docker() {
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        
        # Detect OS
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            OS=$ID
        else
            log_error "Cannot detect OS"
            return 1
        fi
        
        case $OS in
            ubuntu|debian)
                sudo apt-get update
                sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
                curl -fsSL https://download.docker.com/linux/$OS/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
                sudo apt-get update
                sudo apt-get install -y docker-ce docker-ce-cli containerd.io
                ;;
            centos|rhel|fedora)
                sudo yum install -y yum-utils
                sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                sudo yum install -y docker-ce docker-ce-cli containerd.io
                ;;
            *)
                log_error "Unsupported OS: $OS"
                return 1
                ;;
        esac
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        log_success "Docker installed successfully"
        log_warning "Please log out and log back in for group changes to take effect"
    else
        log_success "Docker is already installed"
    fi
}

# Install Docker Compose if not present
install_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        log_info "Installing Docker Compose..."
        
        # Get latest version
        local version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d'"' -f4)
        
        # Download and install
        sudo curl -L "https://github.com/docker/compose/releases/download/${version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Create symlink if needed
        if [[ ! -f /usr/bin/docker-compose ]]; then
            sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
        
        log_success "Docker Compose installed successfully"
    else
        log_success "Docker Compose is already installed"
    fi
}

# Install additional tools
install_tools() {
    log_info "Installing additional tools..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y curl wget jq htop tree lftp rsync
    elif command -v yum &> /dev/null; then
        sudo yum install -y curl wget jq htop tree lftp rsync
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y curl wget jq htop tree lftp rsync
    else
        log_warning "Cannot detect package manager. Please install tools manually."
        return 1
    fi
    
    log_success "Additional tools installed"
}

# Configure system limits
configure_limits() {
    log_info "Configuring system limits..."
    
    # Docker daemon configuration
    sudo mkdir -p /etc/docker
    cat > /tmp/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
EOF
    sudo mv /tmp/daemon.json /etc/docker/daemon.json
    
    # System limits
    cat > /tmp/docker-limits.conf << 'EOF'
* soft nofile 64000
* hard nofile 64000
* soft nproc 64000
* hard nproc 64000
EOF
    sudo mv /tmp/docker-limits.conf /etc/security/limits.d/docker-limits.conf
    
    # Sysctl settings
    cat > /tmp/docker-sysctl.conf << 'EOF'
# Docker optimizations
vm.max_map_count=262144
fs.file-max=2097152
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
EOF
    sudo mv /tmp/docker-sysctl.conf /etc/sysctl.d/docker-sysctl.conf
    sudo sysctl --system
    
    log_success "System limits configured"
}

# Setup firewall rules
setup_firewall() {
    log_info "Setting up firewall rules..."
    
    if command -v ufw &> /dev/null; then
        # UFW (Ubuntu/Debian)
        sudo ufw allow 22/tcp comment "SSH"
        sudo ufw allow 80/tcp comment "HTTP"
        sudo ufw allow 443/tcp comment "HTTPS"
        sudo ufw allow 8080/tcp comment "Dashboard"
        sudo ufw allow 3000/tcp comment "Grafana"
        sudo ufw allow 9090/tcp comment "Prometheus"
        sudo ufw --force enable
        log_success "UFW firewall configured"
    elif command -v firewall-cmd &> /dev/null; then
        # FirewallD (CentOS/RHEL/Fedora)
        sudo firewall-cmd --permanent --add-port=22/tcp
        sudo firewall-cmd --permanent --add-port=80/tcp
        sudo firewall-cmd --permanent --add-port=443/tcp
        sudo firewall-cmd --permanent --add-port=8080/tcp
        sudo firewall-cmd --permanent --add-port=3000/tcp
        sudo firewall-cmd --permanent --add-port=9090/tcp
        sudo firewall-cmd --reload
        log_success "FirewallD configured"
    else
        log_warning "No supported firewall found. Please configure manually."
    fi
}

# Create system user for TrueNAS
create_system_user() {
    local username="truenas-ftp"
    
    if ! id "$username" &>/dev/null; then
        log_info "Creating system user: $username"
        sudo useradd -r -s /bin/bash -d /opt/truenas-ftp -m "$username"
        sudo usermod -aG docker "$username"
        log_success "System user created: $username"
    else
        log_success "System user already exists: $username"
    fi
}

# Optimize system for containers
optimize_system() {
    log_info "Optimizing system for containers..."
    
    # Disable swap if enabled (recommended for containers)
    if [[ $(swapon --show | wc -l) -gt 0 ]]; then
        log_warning "Swap is enabled. Consider disabling it for better container performance."
        read -p "Disable swap now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo swapoff -a
            sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
            log_success "Swap disabled"
        fi
    fi
    
    # Set timezone
    log_info "Current timezone: $(timedatectl show --property=Timezone --value)"
    read -p "Set timezone to Europe/Paris? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo timedatectl set-timezone Europe/Paris
        log_success "Timezone set to Europe/Paris"
    fi
    
    # Enable automatic updates (optional)
    read -p "Enable automatic security updates? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v apt-get &> /dev/null; then
            sudo apt-get install -y unattended-upgrades
            sudo dpkg-reconfigure -plow unattended-upgrades
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y dnf-automatic
            sudo systemctl enable --now dnf-automatic.timer
        fi
        log_success "Automatic updates enabled"
    fi
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    # Check memory
    local memory_gb=$(free -g | awk 'NR==2{print $2}')
    if [[ $memory_gb -lt 4 ]]; then
        log_warning "Low memory: ${memory_gb}GB (recommended: 4GB+)"
    else
        log_success "Memory: ${memory_gb}GB"
    fi
    
    # Check disk space
    local disk_gb=$(df / | awk 'NR==2{print int($4/1024/1024)}')
    if [[ $disk_gb -lt 20 ]]; then
        log_warning "Low disk space: ${disk_gb}GB available (recommended: 20GB+)"
    else
        log_success "Disk space: ${disk_gb}GB available"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt 2 ]]; then
        log_warning "Low CPU cores: $cpu_cores (recommended: 2+)"
    else
        log_success "CPU cores: $cpu_cores"
    fi
}

# Main setup function
setup_environment() {
    echo "=== TrueNAS + FTP System Environment Setup ==="
    echo ""
    
    check_root
    check_requirements
    
    log_info "This script will install and configure:"
    echo "  • Docker and Docker Compose"
    echo "  • System optimization for containers"
    echo "  • Required tools and dependencies"
    echo "  • Firewall configuration"
    echo "  • System limits and security"
    echo ""
    
    read -p "Continue with setup? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Setup cancelled"
        exit 0
    fi
    
    echo ""
    install_docker
    install_docker_compose
    install_tools
    configure_limits
    setup_firewall
    create_system_user
    optimize_system
    
    echo ""
    log_success "Environment setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Log out and log back in (for Docker group changes)"
    echo "2. Run: ./deploy.sh install"
    echo "3. Configure your FTP credentials in .env file"
    echo ""
    echo "Note: If you disabled swap, you may need to reboot for changes to take full effect."
}

# Show current system info
show_system_info() {
    echo "=== System Information ==="
    echo ""
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -s)"
    echo "Kernel: $(uname -r)"
    echo "Memory: $(free -h | awk 'NR==2{print $2}') total"
    echo "Disk: $(df -h / | awk 'NR==2{print $4}') available"
    echo "CPU: $(nproc) cores"
    echo ""
    echo "Docker: $(docker --version 2>/dev/null || echo 'Not installed')"
    echo "Docker Compose: $(docker-compose --version 2>/dev/null || echo 'Not installed')"
    echo ""
}

# Cleanup function
cleanup_environment() {
    log_warning "This will remove Docker and related configurations"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    log_info "Cleaning up environment..."
    
    # Stop and remove containers
    docker stop $(docker ps -aq) 2>/dev/null || true
    docker rm $(docker ps -aq) 2>/dev/null || true
    
    # Remove Docker
    if command -v apt-get &> /dev/null; then
        sudo apt-get remove -y docker-ce docker-ce-cli containerd.io
        sudo apt-get autoremove -y
    elif command -v yum &> /dev/null; then
        sudo yum remove -y docker-ce docker-ce-cli containerd.io
    fi
    
    # Remove Docker Compose
    sudo rm -f /usr/local/bin/docker-compose /usr/bin/docker-compose
    
    # Remove configurations
    sudo rm -f /etc/docker/daemon.json
    sudo rm -f /etc/security/limits.d/docker-limits.conf
    sudo rm -f /etc/sysctl.d/docker-sysctl.conf
    
    log_success "Environment cleanup completed"
}

# Main execution
main() {
    case "${1:-setup}" in
        "setup"|"install")
            setup_environment
            ;;
        "info"|"status")
            show_system_info
            ;;
        "cleanup"|"remove")
            cleanup_environment
            ;;
        "docker")
            install_docker
            install_docker_compose
            ;;
        "tools")
            install_tools
            ;;
        "limits")
            configure_limits
            ;;
        "firewall")
            setup_firewall
            ;;
        "help"|"-h"|"--help")
            cat << 'EOF'
TrueNAS + FTP System Environment Setup

Usage: ./setup-environment.sh [command]

Commands:
  setup, install  - Full environment setup
  info, status    - Show system information
  docker          - Install Docker and Docker Compose only
  tools           - Install additional tools only
  limits          - Configure system limits only
  firewall        - Setup firewall rules only
  cleanup, remove - Remove Docker and configurations
  help            - Show this help

EOF
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
