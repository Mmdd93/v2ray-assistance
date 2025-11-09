#!/bin/bash

# Script: Advanced MikroTik Deployment Manager
# Author: Peyman - Github.com/Ptechgithub
# Version: 3.1.0
# Description: Enterprise-grade MikroTik deployment with multiple installation methods

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging variables
LOG_FILE="/var/log/mikrotik_installer.log"
DEBUG_MODE=false
VERBOSE_MODE=false

# Configuration variables
CONFIG_FILE="/etc/mikrotik_installer.conf"
BACKUP_DIR="/var/backups/mikrotik"
TEMP_DIR="/tmp/mikrotik_installer"

# Default settings
DEFAULT_CHR_VERSION="7.15.2"
DEFAULT_DOCKER_IMAGE="livekadeh_com_mikrotik7_7"
DEFAULT_PORTS="80 8291 22 443 53 1723 4500 500 1194 5678 5679 8728 8729"
RESERVED_PORTS="80 8291"

# Load configuration if exists
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        log "INFO" "Configuration loaded from $CONFIG_FILE"
    fi
}

# Initialize directories
init_directories() {
    mkdir -p "$BACKUP_DIR" "$TEMP_DIR"
    chmod 700 "$BACKUP_DIR"
}

# Advanced logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
    
    case "$level" in
        "ERROR")
            echo -e "${RED}${timestamp} [${level}] ${message}${NC}" >&2
            ;;
        "WARN")
            echo -e "${YELLOW}${timestamp} [${level}] ${message}${NC}"
            ;;
        "INFO")
            echo -e "${GREEN}${timestamp} [${level}] ${message}${NC}"
            ;;
        "DEBUG")
            if [[ "$DEBUG_MODE" == true ]]; then
                echo -e "${BLUE}${timestamp} [${level}] ${message}${NC}"
            fi
            ;;
    esac
}

# Error handling function
error_exit() {
    log "ERROR" "$1"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "Running as root user"
    else
        log "WARN" "Not running as root - some operations may require sudo"
    fi
}

# Detect system information
detect_system() {
    log "INFO" "Detecting system information..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="${ID}"
        DISTRO_VERSION="${VERSION_ID}"
        DISTRO_NAME="${NAME}"
        
        log "INFO" "Distribution: $DISTRO_NAME $DISTRO_VERSION"
        
        case "$DISTRO_ID" in
            "ubuntu"|"debian")
                PM="apt-get"
                PM_UPDATE="$PM update -qq"
                PM_INSTALL="$PM install -y -qq"
                ;;
            "centos"|"rhel")
                PM="yum"
                PM_UPDATE="$PM update -q -y"
                PM_INSTALL="$PM install -y -q"
                ;;
            "fedora")
                PM="dnf"
                PM_UPDATE="$PM update -q -y"
                PM_INSTALL="$PM install -y -q"
                ;;
            "arch")
                PM="pacman"
                PM_UPDATE="$PM -Syu --noconfirm"
                PM_INSTALL="$PM -S --noconfirm"
                ;;
            *)
                error_exit "Unsupported distribution: $DISTRO_ID"
                ;;
        esac
    else
        error_exit "Cannot detect distribution"
    fi
    
    # Detect architecture
    ARCH=$(uname -m)
    log "INFO" "Architecture: $ARCH"
    
    # Detect available memory and disk space
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_GB=$((MEMORY_KB / 1024 / 1024))
    DISK_SPACE=$(df / | awk 'NR==2 {print $4}')
    
    log "INFO" "Memory: ${MEMORY_GB}GB, Disk space: ${DISK_SPACE}KB"
}

# Dependency management
check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    local basic_deps=("wget" "curl" "p7zip-full" "coreutils" "unzip" "tar" "gzip")
    local advanced_deps=("jq" "bc" "net-tools" "iproute2" "dnsutils")
    local missing_deps=()
    
    # Check for missing dependencies
    for dep in "${basic_deps[@]}" "${advanced_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
            log "WARN" "Dependency missing: $dep"
        else
            log "DEBUG" "Dependency found: $dep"
        fi
    done
    
    # Only install if there are missing dependencies
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "INFO" "Installing missing dependencies: ${missing_deps[*]}"
        sudo $PM_UPDATE
        
        for dep in "${missing_deps[@]}"; do
            log "INFO" "Installing $dep..."
            if ! sudo $PM_INSTALL "$dep"; then
                log "WARN" "Failed to install $dep, trying alternative package names..."
                install_dependency_fallback "$dep"
            fi
        done
        
        log "INFO" "Dependency installation completed"
    else
        log "INFO" "All dependencies are already installed"
    fi
}

install_dependency_fallback() {
    local dep="$1"
    case "$dep" in
        "p7zip-full")
            sudo $PM_INSTALL "p7zip" || sudo $PM_INSTALL "7zip" || log "WARN" "Could not install 7zip"
            ;;
        "net-tools")
            sudo $PM_INSTALL "net-tools" || log "WARN" "Could not install net-tools"
            ;;
        "dnsutils")
            sudo $PM_INSTALL "bind-utils" || sudo $PM_INSTALL "dnsutils" || log "WARN" "Could not install dnsutils"
            ;;
        *)
            log "WARN" "No fallback for $dep"
            ;;
    esac
}

# Network validation functions
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

validate_port() {
    local port="$1"
    if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}

check_port_availability() {
    local port="$1"
    if netstat -tuln 2>/dev/null | grep ":${port} " > /dev/null; then
        return 1
    else
        return 0
    fi
}

# Download with retry and resume support
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if wget --continue --progress=bar:force --timeout=30 --tries=3 "$url" -O "$output"; then
            log "INFO" "Download completed: $output"
            return 0
        else
            retry_count=$((retry_count + 1))
            log "WARN" "Download failed, retry $retry_count/$max_retries..."
            sleep 5
        fi
    done
    
    error_exit "Failed to download $url after $max_retries attempts"
}

# Backup existing configuration
backup_system() {
    local backup_name="mikrotik_backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    log "INFO" "Creating system backup..."
    mkdir -p "$backup_path"
    
    # Backup network configuration
    if command -v nmcli &> /dev/null; then
        nmcli connection show > "$backup_path/network_connections.txt" 2>/dev/null || true
    fi
    
    # Backup firewall rules
    if command -v iptables &> /dev/null; then
        iptables-save > "$backup_path/iptables_rules.txt" 2>/dev/null || true
    fi
    
    # Backup Docker containers
    if command -v docker &> /dev/null; then
        docker ps -a > "$backup_path/docker_containers.txt" 2>/dev/null || true
    fi
    
    log "INFO" "Backup created: $backup_path"
}

# CHR Installation functions
get_available_chr_versions() {
    log "INFO" "Fetching available CHR versions..."
    
    # This would typically call an API, for now we'll use a static list
    echo "7.15.2 7.14.1 7.13.5 7.12.4 7.11.2"
}

download_chr_image() {
    local version="${1:-$DEFAULT_CHR_VERSION}"
    local filename="chr-${version}.img.zip"
    local url="https://download.mikrotik.com/routeros/${version}/$filename"
    
    log "INFO" "Downloading CHR version $version..."
    download_with_retry "$url" "$filename"
    
    # Verify download
    if [[ ! -f "$filename" ]]; then
        error_exit "Downloaded file not found: $filename"
    fi
    
    # Extract image
    log "INFO" "Extracting CHR image..."
    if ! unzip -q "$filename" -d chr.img; then
        error_exit "Failed to extract CHR image"
    fi
}

validate_disk_space() {
    local required_space=1000000  # 1GB in KB
    local available_space=$(df / | awk 'NR==2 {print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        error_exit "Insufficient disk space. Required: 1GB, Available: ${available_space}KB"
    fi
}

install_chr_image() {
    log "INFO" "Starting CHR installation..."
    
    check_root
    backup_system
    validate_disk_space
    
    local version
    echo "Available CHR versions:"
    local versions=($(get_available_chr_versions))
    select version in "${versions[@]}"; do
        if [[ -n "$version" ]]; then
            break
        fi
    done
    
    download_chr_image "$version"
    
    # Detect root partition
    local root_partition
    root_partition=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
    
    if [[ -z "$root_partition" ]]; then
        error_exit "Could not detect root partition"
    fi
    
    log "WARN" "This will overwrite $root_partition with CHR image!"
    read -p "Are you sure you want to continue? (yes/no): " confirmation
    
    if [[ "$confirmation" != "yes" ]]; then
        log "INFO" "Installation cancelled by user"
        exit 0
    fi
    
    # Prepare system for disk operations
    log "INFO" "Preparing system for installation..."
    echo 1 > /proc/sys/kernel/sysrq
    sync
    
    # Write CHR image to disk
    log "INFO" "Writing CHR image to disk (this may take several minutes)..."
    local chr_image="chr.img/chr-${version}.img"
    
    if ! dd if="$chr_image" bs=1M of="$root_partition" status=progress; then
        error_exit "Failed to write CHR image to disk"
    fi
    
    # Final sync and reboot
    log "INFO" "Finalizing installation..."
    sync
    echo "Installation complete. System will reboot in 10 seconds..."
    sleep 10
    
    # Trigger reboot
    echo b > /proc/sysrq-trigger
}

# Docker management functions
# Enhanced Docker installation detection
install_docker() {
    log "INFO" "Checking Docker installation..."
    
    # First, check if Docker is already installed but just not running
    if command -v docker &> /dev/null; then
        log "INFO" "Docker command is available, but service may not be running"
        
        # Try to start the existing Docker installation
        if ensure_docker_running; then
            log "INFO" "Docker is now running"
            return 0
        else
            log "WARN" "Existing Docker installation found but couldn't start it"
        fi
    fi
    
    # If we get here, Docker needs to be installed
    log "INFO" "Installing Docker..."
    
    # Set DNS for reliable download
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
    
    # Detect which installation method to use based on distribution
    case "$DISTRO_ID" in
        "ubuntu"|"debian")
            install_docker_apt
            ;;
        "centos"|"rhel"|"fedora")
            install_docker_yum
            ;;
        *)
            install_docker_script
            ;;
    esac
    
    # Verify installation
    if command -v docker &> /dev/null && ensure_docker_running; then
        log "INFO" "Docker installed and running successfully"
    else
        error_exit "Docker installation failed"
    fi
}

# Docker installation via apt (Ubuntu/Debian)
install_docker_apt() {
    log "INFO" "Installing Docker using apt..."
    
    # Update package index
    sudo apt-get update
    
    # Install prerequisites
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package index again
    sudo apt-get update
    
    # Install Docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    log "INFO" "Please log out and log back in for group changes to take effect, or run: newgrp docker"
}

# Docker installation via yum/dnf (CentOS/RHEL/Fedora)
install_docker_yum() {
    log "INFO" "Installing Docker using yum/dnf..."
    
    # Install prerequisites
    sudo $PM install -y yum-utils
    
    # Add Docker repository
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    
    # Install Docker
    sudo $PM install -y docker-ce docker-ce-cli containerd.io
    
    # Start and enable Docker service
    sudo systemctl start docker
    sudo systemctl enable docker
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
}

# Docker installation via official script (fallback)
install_docker_script() {
    log "INFO" "Installing Docker using official script..."
    
    # Download and run Docker installation script
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    # Cleanup
    rm -f get-docker.sh
}

setup_docker_networking() {
    local network_name="mikrotik_net"
    
    # Create custom network if it doesn't exist
    if ! docker network ls | grep -q "$network_name"; then
        log "INFO" "Creating Docker network: $network_name"
        docker network create --subnet=172.20.0.0/16 "$network_name"
    fi
}

get_available_docker_images() {
    log "INFO" "Checking available Docker images..."
    
    # In a real scenario, you might query a registry API
    # For now, we'll use predefined options
    echo "livekadeh_com_mikrotik7_7 mikrotik/routeros:latest custom_mikrotik_image"
}

download_docker_image() {
    local image_source="$1"
    
    case "$image_source" in
        "github")
            local url="https://github.com/Ptechgithub/MIKROTIK/releases/download/L6/Docker-image-Mikrotik-7.7-L6.7z"
            local filename="Docker-image-Mikrotik-7.7-L6.7z"
            
            download_with_retry "$url" "$filename"
            7z e "$filename" -y
            docker load --input mikrotik7.7_docker_livekadeh.com
            ;;
        "dockerhub")
            docker pull mikrotik/routeros:latest
            ;;
        "custom")
            read -p "Enter custom image name: " custom_image
            docker pull "$custom_image"
            ;;
    esac
}

setup_port_mappings() {
    local port_mappings=""
    
    echo "Default ports to be mapped: $DEFAULT_PORTS"
    read -p "Do you want to customize port mappings? (y/n): " customize_ports
    
    if [[ "$customize_ports" == "y" ]]; then
        echo "Enter additional ports (space-separated, or 'none' for no additional ports):"
        read -a additional_ports
        
        if [[ "${additional_ports[0]}" != "none" ]]; then
            for port in "${additional_ports[@]}"; do
                if validate_port "$port"; then
                    if [[ " $RESERVED_PORTS " != *" $port "* ]]; then
                        if check_port_availability "$port"; then
                            port_mappings+=" -p $port:$port"
                            log "INFO" "Port $port will be mapped"
                        else
                            log "WARN" "Port $port is already in use, skipping"
                        fi
                    else
                        log "WARN" "Port $port is reserved for default services, skipping"
                    fi
                else
                    log "WARN" "Invalid port: $port"
                fi
            done
        fi
    fi
    
    # Add default ports
    for port in $DEFAULT_PORTS; do
        port_mappings+=" -p $port:$port"
    done
    
    echo "$port_mappings"
}

setup_volume_mappings() {
    local volume_mappings=""
    read -p "Do you want to setup persistent storage? (y/n): " persistent_storage
    
    if [[ "$persistent_storage" == "y" ]]; then
        local volume_path="/var/lib/mikrotik_data"
        sudo mkdir -p "$volume_path"
        sudo chmod 755 "$volume_path"
        volume_mappings=" -v $volume_path:/routeros/storage"
        log "INFO" "Persistent storage enabled at $volume_path"
    fi
    
    echo "$volume_mappings"
}

create_mikrotik_container() {
    local container_name="livekadeh_com_mikrotik7_7"
    local image_name="livekadeh_com_mikrotik7_7"
    
    # Check if container already exists
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        log "WARN" "Container $container_name already exists"
        read -p "Do you want to remove and recreate it? (y/n): " recreate
        if [[ "$recreate" == "y" ]]; then
            docker stop "$container_name" || true
            docker rm "$container_name" || true
        else
            log "INFO" "Using existing container"
            return 0
        fi
    fi
    
    # Get configuration options
    local port_mappings=$(setup_port_mappings)
    local volume_mappings=$(setup_volume_mappings)
    
    # Create container with advanced options
    log "INFO" "Creating MikroTik container..."
    local docker_cmd="docker run --restart unless-stopped \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_MODULE \
        --device=/dev/net/tun \
        --sysctl net.ipv4.ip_forward=1 \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --name $container_name \
        $port_mappings \
        $volume_mappings \
        -d $image_name"
    
    log "DEBUG" "Docker command: $docker_cmd"
    
    if eval "$docker_cmd"; then
        log "INFO" "MikroTik container created successfully"
        
        # Wait for container to start
        sleep 10
        
        # Show container status
        docker ps -f "name=$container_name"
        
        # Offer to attach to container
        read -p "Do you want to attach to the container console? (y/n): " attach_console
        if [[ "$attach_console" == "y" ]]; then
            log "INFO" "Attaching to container console (press Ctrl+P then Ctrl+Q to detach)"
            docker attach "$container_name"
        fi
    else
        error_exit "Failed to create MikroTik container"
    fi
}

install_mikrotik_docker() {
    log "INFO" "Starting MikroTik Docker installation..."
    
    install_docker
    setup_docker_networking
    
    echo "Select Docker image source:"
    select image_source in "github" "dockerhub" "custom"; do
        case $image_source in
            "github"|"dockerhub"|"custom")
                download_docker_image "$image_source"
                break
                ;;
            *)
                echo "Invalid selection"
                ;;
        esac
    done
    
    create_mikrotik_container
}

# Container management functions
mikrotik_container_status() {
    local container_name="livekadeh_com_mikrotik7_7"
    
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        log "INFO" "MikroTik container status:"
        docker ps -a -f "name=$container_name" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        # Show resource usage
        log "INFO" "Resource usage:"
        docker stats "$container_name" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
        return 0
    else
        log "WARN" "MikroTik container not found"
        return 1
    fi
}

stop_mikrotik_container() {
    local container_name="livekadeh_com_mikrotik7_7"
    
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        log "INFO" "Stopping MikroTik container..."
        docker stop "$container_name"
        log "INFO" "Container stopped"
    else
        log "WARN" "Container not found"
    fi
}

start_mikrotik_container() {
    local container_name="livekadeh_com_mikrotik7_7"
    
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        log "INFO" "Starting MikroTik container..."
        docker start "$container_name"
        log "INFO" "Container started"
        
        # Wait for services to come up
        sleep 5
        mikrotik_container_status
    else
        log "WARN" "Container not found"
    fi
}

restart_mikrotik_container() {
    local container_name="livekadeh_com_mikrotik7_7"
    
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        log "INFO" "Restarting MikroTik container..."
        docker restart "$container_name"
        log "INFO" "Container restarted"
        
        sleep 5
        mikrotik_container_status
    else
        log "WARN" "Container not found"
    fi
}

backup_mikrotik_config() {
    local container_name="livekadeh_com_mikrotik7_7"
    local backup_name="mikrotik_config_$(date +%Y%m%d_%H%M%S).backup"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
        log "INFO" "Backing up MikroTik configuration..."
        
        # Export configuration (this would need MikroTik CLI access)
        # For now, we'll backup the container itself
        docker export "$container_name" | gzip > "${backup_path}.tar.gz"
        
        log "INFO" "Configuration backed up to: ${backup_path}.tar.gz"
    else
        log "WARN" "Container is not running, cannot backup configuration"
    fi
}

uninstall_mikrotik() {
    log "INFO" "Starting MikroTik uninstallation..."
    
    local container_name="livekadeh_com_mikrotik7_7"
    
    # Backup before removal
    read -p "Do you want to backup configuration before uninstall? (y/n): " backup_before_uninstall
    if [[ "$backup_before_uninstall" == "y" ]]; then
        backup_mikrotik_config
    fi
    
    # Stop and remove container
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        log "INFO" "Removing MikroTik container..."
        docker stop "$container_name" || true
        docker rm "$container_name" || true
        log "INFO" "Container removed"
    else
        log "WARN" "Container not found"
    fi
    
    # Remove image
    read -p "Do you want to remove the Docker image as well? (y/n): " remove_image
    if [[ "$remove_image" == "y" ]]; then
        if docker images -a | grep -q "livekadeh_com_mikrotik7_7"; then
            docker rmi "livekadeh_com_mikrotik7_7"
            log "INFO" "Docker image removed"
        else
            log "WARN" "Docker image not found"
        fi
    fi
    
    # Cleanup volumes
    read -p "Do you want to remove persistent data? (y/n): " remove_data
    if [[ "$remove_data" == "y" ]]; then
        local volume_path="/var/lib/mikrotik_data"
        if [[ -d "$volume_path" ]]; then
            sudo rm -rf "$volume_path"
            log "INFO" "Persistent data removed"
        fi
    fi
    
    log "INFO" "Uninstallation completed"
}

# System health check
system_health_check() {
    log "INFO" "Performing system health check..."
    
    # Check Docker service
    if systemctl is-active --quiet docker; then
        log "INFO" "Docker service: ${GREEN}Running${NC}"
    else
        log "WARN" "Docker service: ${RED}Not running${NC}"
    fi
    
    # Check disk space
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$disk_usage" -lt 80 ]; then
        log "INFO" "Disk usage: ${GREEN}${disk_usage}%${NC}"
    else
        log "WARN" "Disk usage: ${RED}${disk_usage}%${NC}"
    fi
    
    # Check memory
    local mem_usage=$(free | awk 'NR==2{printf "%.2f", $3*100/$2}')
    if (( $(echo "$mem_usage < 80" | bc -l) )); then
        log "INFO" "Memory usage: ${GREEN}${mem_usage}%${NC}"
    else
        log "WARN" "Memory usage: ${RED}${mem_usage}%${NC}"
    fi
    
    # Check network
    if ping -c 1 -W 3 8.8.8.8 &> /dev/null; then
        log "INFO" "Network connectivity: ${GREEN}OK${NC}"
    else
        log "WARN" "Network connectivity: ${RED}Failed${NC}"
    fi
}

# Docker Compose functions
setup_docker_compose() {
    log "INFO" "Setting up Docker Compose..."
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
        install_docker_compose
    fi
    
    # Create necessary directories
    mkdir -p {monitoring/dashboards,monitoring/datasources,scripts,backups}
    
    # Generate configuration files
    generate_docker_compose_files
    
    # Ensure .env file exists
    if [[ ! -f ".env" ]]; then
        create_env_file
    fi
    
    generate_monitoring_config
}

install_docker_compose() {
    log "INFO" "Installing Docker Compose..."
    
    # Install Docker Compose v2 (preferred)
    if command -v docker &> /dev/null; then
        log "INFO" "Installing Docker Compose Plugin..."
        sudo $PM_INSTALL docker-compose-plugin
    else
        # Fallback to standalone docker-compose
        log "INFO" "Installing standalone Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    # Verify installation
    if command -v docker-compose &> /dev/null || command -v docker compose &> /dev/null; then
        log "INFO" "Docker Compose installed successfully"
    else
        error_exit "Failed to install Docker Compose"
    fi
}

# Function to check and resolve port conflicts
check_port_conflicts() {
    local ports=("22" "80" "443" "53" "1723" "4500" "500" "1194" "8291" "5678" "5679" "8728" "8729")
    local conflicting_ports=()
    
    log "INFO" "Checking for port conflicts..."
    
    for port in "${ports[@]}"; do
        if netstat -tuln 2>/dev/null | grep -q ":${port} "; then
            conflicting_ports+=("$port")
            log "WARN" "Port $port is already in use"
        fi
    done
    
    if [[ ${#conflicting_ports[@]} -gt 0 ]]; then
        echo "The following ports are already in use: ${conflicting_ports[*]}"
        echo "This will cause conflicts with MikroTik container."
        
        read -p "Do you want to automatically resolve port conflicts? (y/n): " resolve_choice
        if [[ "$resolve_choice" == "y" ]]; then
            resolve_port_conflicts "${conflicting_ports[@]}"
        else
            log "WARN" "Port conflicts not resolved. Container may fail to start."
        fi
    else
        log "INFO" "No port conflicts detected"
    fi
}

# Function to resolve port conflicts
resolve_port_conflicts() {
    local conflicting_ports=("$@")
    
    log "INFO" "Resolving port conflicts by updating .env file..."
    
    # Update .env file with alternative ports
    for port in "${conflicting_ports[@]}"; do
        case $port in
            22)
                update_env_port "SSH_PORT" "2222"
                ;;
            53)
                update_env_port "DNS_PORT" "5353"
                ;;
            80)
                update_env_port "WEB_PORT" "8080"
                ;;
            443)
                update_env_port "HTTPS_PORT" "8443"
                ;;
            8291)
                update_env_port "WINBOX_PORT" "8292"
                ;;
            1723)
                update_env_port "PPTP_PORT" "11723"
                ;;
            4500)
                update_env_port "IPSEC_PORT" "14500"
                ;;
            500)
                update_env_port "IKE_PORT" "1500"
                ;;
            1194)
                update_env_port "OVPN_PORT" "11194"
                ;;
            5678)
                update_env_port "API_PORT" "15678"
                ;;
            5679)
                update_env_port "API_SSL_PORT" "15679"
                ;;
            8728)
                update_env_port "API_RAW_PORT" "18728"
                ;;
            8729)
                update_env_port "API_SSL_RAW_PORT" "18729"
                ;;
        esac
    done
    
    # Regenerate docker-compose.yml with new ports
    generate_docker_compose_files
    
    log "INFO" "Port conflicts resolved. Check .env file for new port mappings."
}

# Generate Docker Compose files
# Generate Docker Compose files
generate_docker_compose_files() {
    log "INFO" "Generating Docker Compose configuration..."
    
    # Main docker-compose.yml
    cat > docker-compose.yml << 'EOF'
services:
  mikrotik:
    image: ${MIKROTIK_IMAGE:-livekadeh_com_mikrotik7_7}
    container_name: ${CONTAINER_NAME:-mikrotik_router}
    restart: ${RESTART_POLICY:-unless-stopped}
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
    devices:
      - "/dev/net/tun"
    sysctls:
      - net.ipv4.ip_forward=1
      - net.ipv6.conf.all.disable_ipv6=0
    ports:
      - "${WEB_PORT:-80}:80"
      - "${WINBOX_PORT:-8291}:8291"
      - "${SSH_PORT:-22}:22"
      - "${HTTPS_PORT:-443}:443"
      - "${DNS_PORT:-53}:53"
      - "${PPTP_PORT:-1723}:1723"
      - "${IPSEC_PORT:-4500}:4500"
      - "${IKE_PORT:-500}:500"
      - "${OVPN_PORT:-1194}:1194"
      - "${L2TP_PORT:-1701}:1701"
      - "${API_PORT:-5678}:5678"
      - "${API_SSL_PORT:-5679}:5679"
      - "${API_RAW_PORT:-8728}:8728"
      - "${API_SSL_RAW_PORT:-8729}:8729"
    volumes:
      # PERSISTENT STORAGE - This prevents factory reset
      - mikrotik_data:/routeros
      - mikrotik_data:/flash
      - mikrotik_data:/rw
      - mikrotik_data:/storage
      # System time
      - /etc/localtime:/etc/localtime:ro
    networks:
      - mikrotik_net
    environment:
      - TZ=${TIMEZONE:-UTC}

networks:
  mikrotik_net:
    driver: bridge

volumes:
  mikrotik_data:
    driver: local
EOF

    log "INFO" "Docker Compose file generated successfully"
}

# Function to create .env file
create_env_file() {
    cat > .env << 'EOF'
# MikroTik Docker Compose Configuration
MIKROTIK_IMAGE=livekadeh_com_mikrotik7_7
CONTAINER_NAME=mikrotik_router
RESTART_POLICY=unless-stopped
TIMEZONE=UTC

# Port Configuration - Change these if you have port conflicts
WEB_PORT=80
WINBOX_PORT=8291
SSH_PORT=22
HTTPS_PORT=443
DNS_PORT=53
PPTP_PORT=1723
IPSEC_PORT=4500
IKE_PORT=500
OVPN_PORT=1194
L2TP_PORT=1701
API_PORT=5678
API_SSL_PORT=5679
API_RAW_PORT=8728
API_SSL_RAW_PORT=8729
EOF

    log "INFO" ".env file created with default values"
}

# Function to update .env port variables
update_env_port() {
    local var_name="$1"
    local port_value="$2"
    
    if [[ -f ".env" ]]; then
        if grep -q "^${var_name}=" ".env"; then
            sed -i "s/^${var_name}=.*/${var_name}=${port_value}/" ".env"
        else
            echo "${var_name}=${port_value}" >> ".env"
        fi
    else
        echo "${var_name}=${port_value}" > ".env"
    fi
}

# Function to let user customize ports
customize_ports() {
    echo "Port Configuration:"
    echo "Current port mappings from .env file:"
    
    # Load current values from .env
    if [[ -f ".env" ]]; then
        source .env 2>/dev/null || true
    fi
    
    echo "  Web Interface: ${WEB_PORT:-80}"
    echo "  WinBox: ${WINBOX_PORT:-8291}" 
    echo "  SSH: ${SSH_PORT:-22}"
    echo "  HTTPS: ${HTTPS_PORT:-443}"
    echo "  DNS: ${DNS_PORT:-53}"
    echo "  PPTP: ${PPTP_PORT:-1723}"
    echo "  IPSec: ${IPSEC_PORT:-4500}"
    echo "  IKE: ${IKE_PORT:-500}"
    echo "  OpenVPN: ${OVPN_PORT:-1194}"
    echo "  L2TP: ${L2TP_PORT:-1701}"
    echo "  API: ${API_PORT:-5678}"
    echo "  API SSL: ${API_SSL_PORT:-5679}"
    echo "  API Raw: ${API_RAW_PORT:-8728}"
    echo "  API SSL Raw: ${API_SSL_RAW_PORT:-8729}"
    echo ""
    
    read -p "Do you want to customize these ports? (y/n): " customize_ports
    
    if [[ "$customize_ports" == "y" ]]; then
        echo "Enter custom ports (press Enter to keep current value):"
        
        read -p "Web Interface port [${WEB_PORT:-80}]: " web_port
        read -p "WinBox port [${WINBOX_PORT:-8291}]: " winbox_port
        read -p "SSH port [${SSH_PORT:-22}]: " ssh_port
        read -p "HTTPS port [${HTTPS_PORT:-443}]: " https_port
        read -p "DNS port [${DNS_PORT:-53}]: " dns_port
        read -p "PPTP port [${PPTP_PORT:-1723}]: " pptp_port
        read -p "IPSec port [${IPSEC_PORT:-4500}]: " ipsec_port
        read -p "IKE port [${IKE_PORT:-500}]: " ike_port
        read -p "OpenVPN port [${OVPN_PORT:-1194}]: " ovpn_port
        read -p "L2TP port [${L2TP_PORT:-1701}]: " l2tp_port
        read -p "API port [${API_PORT:-5678}]: " api_port
        read -p "API SSL port [${API_SSL_PORT:-5679}]: " api_ssl_port
        read -p "API Raw port [${API_RAW_PORT:-8728}]: " api_raw_port
        read -p "API SSL Raw port [${API_SSL_RAW_PORT:-8729}]: " api_ssl_raw_port
        
        # Update .env file with custom ports
        [[ -n "$web_port" ]] && update_env_port "WEB_PORT" "$web_port"
        [[ -n "$winbox_port" ]] && update_env_port "WINBOX_PORT" "$winbox_port"
        [[ -n "$ssh_port" ]] && update_env_port "SSH_PORT" "$ssh_port"
        [[ -n "$https_port" ]] && update_env_port "HTTPS_PORT" "$https_port"
        [[ -n "$dns_port" ]] && update_env_port "DNS_PORT" "$dns_port"
        [[ -n "$pptp_port" ]] && update_env_port "PPTP_PORT" "$pptp_port"
        [[ -n "$ipsec_port" ]] && update_env_port "IPSEC_PORT" "$ipsec_port"
        [[ -n "$ike_port" ]] && update_env_port "IKE_PORT" "$ike_port"
        [[ -n "$ovpn_port" ]] && update_env_port "OVPN_PORT" "$ovpn_port"
        [[ -n "$l2tp_port" ]] && update_env_port "L2TP_PORT" "$l2tp_port"
        [[ -n "$api_port" ]] && update_env_port "API_PORT" "$api_port"
        [[ -n "$api_ssl_port" ]] && update_env_port "API_SSL_PORT" "$api_ssl_port"
        [[ -n "$api_raw_port" ]] && update_env_port "API_RAW_PORT" "$api_raw_port"
        [[ -n "$api_ssl_raw_port" ]] && update_env_port "API_SSL_RAW_PORT" "$api_ssl_raw_port"
        
        # Regenerate docker-compose.yml with new ports
        generate_docker_compose_files
        
        log "INFO" "Port configuration updated"
    fi
}

# Function to setup MikroTik image
setup_mikrotik_image() {
    echo "Select MikroTik image source:"
    echo "1) Use custom image (livekadeh_com_mikrotik7_7)"
    echo "2) Use official MikroTik RouterOS image"
    read -p "Enter your choice [1-2]: " image_choice
    
    # Ensure .env file exists
    if [[ ! -f ".env" ]]; then
        log "INFO" "Creating .env file..."
        create_env_file
    fi
    
    case $image_choice in
        1)
            log "INFO" "Using custom MikroTik image"
            # Update .env file to use custom image
            update_env_port "MIKROTIK_IMAGE" "livekadeh_com_mikrotik7_7"
            
            # Check if image exists locally, if not download it
            if ! docker images -a | grep -q "livekadeh_com_mikrotik7_7"; then
                log "INFO" "Custom image not found locally. Downloading from GitHub..."
                download_mikrotik_image_from_github
            fi
            ;;
        2)
            log "INFO" "Using official MikroTik RouterOS image"
            # Update .env file to use official image
            update_env_port "MIKROTIK_IMAGE" "mikrotik/routeros:latest"
            ;;
        *)
            log "WARN" "Invalid choice, using custom image"
            update_env_port "MIKROTIK_IMAGE" "livekadeh_com_mikrotik7_7"
            ;;
    esac
}

# Function to download MikroTik image from GitHub
download_mikrotik_image_from_github() {
    log "INFO" "Downloading MikroTik Docker image from GitHub..."
    
    local url="https://github.com/Ptechgithub/MIKROTIK/releases/download/L6/Docker-image-Mikrotik-7.7-L6.7z"
    local filename="Docker-image-Mikrotik-7.7-L6.7z"
    
    # Download the image archive
    if download_with_retry "$url" "$filename"; then
        # Extract the image
        if command -v 7z &> /dev/null || command -v 7za &> /dev/null; then
            log "INFO" "Extracting Docker image..."
            7z x "$filename" -y || 7za x "$filename" -y
        else
            log "ERROR" "7z is not installed. Please install p7zip-full package."
            exit 1
        fi
        
        # Load the Docker image
        if [[ -f "mikrotik7.7_docker_livekadeh.com" ]]; then
            log "INFO" "Loading Docker image..."
            docker load --input mikrotik7.7_docker_livekadeh.com
            log "INFO" "MikroTik Docker image loaded successfully"
            
            # Ask user if they want to delete temporary files
            read -p "Do you want to delete the temporary files? (y/n): " delete_files
            if [[ $delete_files =~ ^[Yy]$ ]]; then
                rm -f "$filename" "mikrotik7.7_docker_livekadeh.com"
                log "INFO" "Temporary files deleted successfully"
            else
                log "INFO" "Temporary files kept: $filename and mikrotik7.7_docker_livekadeh.com"
            fi
        else
            error_exit "Docker image file not found after extraction"
        fi
    else
        error_exit "Failed to download MikroTik Docker image"
    fi
}

generate_monitoring_config() {
    log "INFO" "Generating monitoring configuration..."
    
    # Prometheus configuration
    cat > monitoring/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'mikrotik'
    static_configs:
      - targets: ['mikrotik:8728']
    metrics_path: '/metrics'
    params:
      address: ['mikrotik:8728']
      user: ['admin']
      password: ['']
EOF

    # Grafana datasource
    cat > monitoring/datasources/prometheus.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

    log "INFO" "Monitoring configuration generated"
}

# Function to show access information after deployment
show_access_info() {
    echo ""
    echo -e "${GREEN}MikroTik Deployment Successful!${NC}"
    echo "=========================================="
    echo "Access your MikroTik router using:"
    echo ""
    
    # Load current values from .env
    if [[ -f ".env" ]]; then
        source .env 2>/dev/null || true
    fi
    
    local host_ip=$(hostname -I | awk '{print $1}')
    if [[ -z "$host_ip" ]]; then
        host_ip="localhost"
    fi
    
    echo "Web Interface: http://${host_ip}:${WEB_PORT:-80}"
    echo "WinBox:        ${host_ip}:${WINBOX_PORT:-8291}"
    echo "SSH:           ssh admin@${host_ip} -p ${SSH_PORT:-22}"
    echo "HTTPS:         https://${host_ip}:${HTTPS_PORT:-443}"
    echo ""
    echo "Default credentials:"
    echo "Username: admin"
    echo "Password: (no password - CHR mode)"
    echo ""
    echo "Note: Some ports may have been changed to avoid conflicts"
    echo "Check .env file for actual port mappings"
}

# Docker Compose management functions
manage_compose_services() {
    local action="$1"
    local compose_file="${2:-docker-compose.yml}"
    
    # Use docker-compose v2 if available, otherwise use v1
    local compose_cmd="docker-compose"
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    fi
    
    case "$action" in
        "start")
            $compose_cmd -f "$compose_file" start
            ;;
        "stop")
            $compose_cmd -f "$compose_file" stop
            ;;
        "restart")
            $compose_cmd -f "$compose_file" restart
            ;;
        "down")
            $compose_cmd -f "$compose_file" down
            ;;
        "logs")
            $compose_cmd -f "$compose_file" logs -f
            ;;
        "ps")
            $compose_cmd -f "$compose_file" ps
            ;;
        "stats")
            $compose_cmd -f "$compose_file" stats
            ;;
        "up")
            $compose_cmd -f "$compose_file" up -d
            ;;
        *)
            error_exit "Unknown action: $action"
            ;;
    esac
}

# Check and start Docker service
ensure_docker_running() {
    # First check if Docker is installed by checking the command
    if ! command -v docker &> /dev/null; then
        log "INFO" "Docker is not installed. Installing Docker first..."
        install_docker
        return
    fi
    
    # Check if Docker service exists using multiple methods
    local docker_service_found=false
    
    # Method 1: Check systemd service
    if systemctl list-unit-files | grep -q docker.service; then
        docker_service_found=true
        log "INFO" "Docker systemd service found"
    fi
    
    # Method 2: Check if Docker socket exists
    if [[ -S "/var/run/docker.sock" ]]; then
        docker_service_found=true
        log "INFO" "Docker socket found"
    fi
    
    # Method 3: Check if Docker process is running
    if pgrep -f "dockerd" > /dev/null; then
        docker_service_found=true
        log "INFO" "Docker daemon process is running"
    fi
    
    if [[ "$docker_service_found" == false ]]; then
        log "WARN" "Docker service not found via standard methods. Checking Docker directly..."
        
        # Try to communicate with Docker directly
        if docker info &> /dev/null; then
            log "INFO" "Docker is running (direct communication successful)"
            return 0
        else
            log "INFO" "Starting Docker manually..."
            start_docker_manual
            return
        fi
    fi
    
    # Now check if Docker is running and accessible
    if docker info &> /dev/null; then
        log "INFO" "Docker is running and accessible"
        return 0
    fi
    
    # If we have systemd service but it's not running, start it
    if systemctl list-unit-files | grep -q docker.service; then
        if ! systemctl is-active --quiet docker; then
            log "INFO" "Starting Docker systemd service..."
            if sudo systemctl start docker; then
                sudo systemctl enable docker
                
                # Wait for Docker to be ready
                wait_for_docker
                return $?
            else
                log "ERROR" "Failed to start Docker systemd service"
                start_docker_manual
                return
            fi
        fi
    else
        # No systemd service found, try manual start
        start_docker_manual
        return
    fi
}

# Wait for Docker to be ready
wait_for_docker() {
    local max_retries=10
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if docker info &> /dev/null; then
            log "INFO" "Docker is now running and accessible"
            return 0
        else
            retry_count=$((retry_count + 1))
            log "WARN" "Waiting for Docker to be ready... ($retry_count/$max_retries)"
            sleep 3
        fi
    done
    
    log "ERROR" "Docker failed to become ready after $max_retries attempts"
    return 1
}

# Start Docker manually (for non-systemd installations)
start_docker_manual() {
    log "INFO" "Attempting to start Docker manually..."
    
    # Method 1: Try dockerd directly
    if command -v dockerd &> /dev/null; then
        log "INFO" "Starting dockerd directly..."
        sudo nohup dockerd &> /tmp/dockerd.log &
        sleep 5
        
        if wait_for_docker; then
            log "INFO" "Docker started successfully via dockerd"
            return 0
        fi
    fi
    
    # Method 2: Try service command (for older systems)
    if command -v service &> /dev/null; then
        log "INFO" "Starting Docker via service command..."
        sudo service docker start
        sleep 5
        
        if wait_for_docker; then
            log "INFO" "Docker started successfully via service command"
            return 0
        fi
    fi
    
    # Method 3: Try init.d (for very old systems)
    if [[ -f "/etc/init.d/docker" ]]; then
        log "INFO" "Starting Docker via init.d..."
        sudo /etc/init.d/docker start
        sleep 5
        
        if wait_for_docker; then
            log "INFO" "Docker started successfully via init.d"
            return 0
        fi
    fi
    
    # Method 4: Last resort - check if Docker is already running but needs sudo
    log "INFO" "Checking if Docker needs sudo privileges..."
    if sudo docker info &> /dev/null; then
        log "INFO" "Docker is running but requires sudo"
        return 0
    fi
    
    log "ERROR" "Could not start Docker using any method"
    log "INFO" "Please start Docker manually and try again:"
    log "INFO" "  sudo systemctl start docker"
    log "INFO" "  OR"
    log "INFO" "  sudo dockerd &"
    error_exit "Docker service could not be started"
}

# Check Docker installation status
check_docker_status() {
    log "INFO" "Checking Docker status..."
    
    if command -v docker &> /dev/null; then
        echo "✓ Docker command is available"
        
        if docker info &> /dev/null; then
            echo "✓ Docker daemon is running and accessible"
            echo "✓ Docker version: $(docker --version | cut -d' ' -f3 | tr -d ',')"
            return 0
        else
            echo "✗ Docker command exists but daemon is not accessible"
            return 1
        fi
    else
        echo "✗ Docker command not found"
        return 1
    fi
}

# Deploy with Docker Compose
deploy_with_compose() {
    local compose_file="${1:-docker-compose.yml}"
    
    log "INFO" "Deploying with Docker Compose: $compose_file"
    
    # Ensure Docker is running
    ensure_docker_running
    
    if [[ ! -f "$compose_file" ]]; then
        error_exit "Docker Compose file not found: $compose_file"
    fi
    
    # Check for port conflicts and customize if needed
    check_port_conflicts
    customize_ports
    
    # Check if the MikroTik image exists locally
    if ! docker images -a | grep -q "livekadeh_com_mikrotik7_7"; then
        log "INFO" "MikroTik Docker image not found locally. Downloading from GitHub..."
        download_mikrotik_image_from_github
    fi
    
    # Validate compose file
    if command -v docker-compose &> /dev/null; then
        if ! docker-compose -f "$compose_file" config > /dev/null; then
            error_exit "Invalid Docker Compose file"
        fi
    fi
    
    # Deploy services
    log "INFO" "Starting services..."
    manage_compose_services "up" "$compose_file"
    
    # Show status
    manage_compose_services "ps" "$compose_file"
    
    log "INFO" "Deployment completed successfully"
    
    # Show access information
    show_access_info
}

# Main menu
show_main_menu() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║               Advanced MikroTik Deployment Manager          ║"
    echo "║                      Version 3.1.0                          ║"
    echo "║                 Author: Github.com/Ptechgithub              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # System Information
    if command -v lsb_release &> /dev/null; then
        OS=$(lsb_release -d | cut -f2)
    elif [ -f /etc/os-release ]; then
        OS=$(source /etc/os-release && echo $PRETTY_NAME)
    else
        OS="Unknown"
    fi
    
    ARCH=$(uname -m)
    if [ -f /proc/meminfo ]; then
        MEMORY_GB=$(grep MemTotal /proc/meminfo | awk '{printf "%.1f", $2/1024/1024}')
    else
        MEMORY_GB="Unknown"
    fi
    
    echo -e "${YELLOW}System Information:${NC}"
    echo -e "  OS: $OS"
    echo -e "  Arch: $ARCH"
    echo -e "  Memory: ${MEMORY_GB}GB"
    echo ""
    
    echo -e "${GREEN}Main Installation Options:${NC}"
    echo "  1) Install MikroTik CHR (Bare Metal)"
    echo "  2) Install MikroTik via Docker"
    echo "  3) Deploy with Docker Compose"
    echo ""
    
    echo -e "${BLUE}Docker Compose Management:${NC}"
    echo "  4) Start Compose Services"
    echo "  5) Stop Compose Services"
    echo "  6) Restart Compose Services"
    echo "  7) Compose Services Status"
    echo "  8) View Compose Logs"
    echo "  9) Backup Configuration"
    echo "  10) Restore Configuration"
    echo ""
    
    echo -e "${PURPLE}System & Monitoring:${NC}"
    echo "  11) System Health Check"
    echo "  12) Docker Status Check"
    echo "  13) View Installation Log"
    echo "  14) Cleanup Temporary Files"
    echo "  15) Customize Ports"
    echo ""
    
    echo -e "${RED}Utility Options:${NC}"
    echo "  0) Exit"
    echo ""
    
    echo -e "${YELLOW}Quick Commands:${NC}"
    echo "  - Use command-line options for automation"
    echo "  - Run with --help for all options"
    echo ""
}

# Menu interaction handler
handle_menu_choice() {
    local choice="$1"
    
    case $choice in
        1)
            log "INFO" "Starting CHR installation..."
            install_chr_image
            ;;
        2)
            log "INFO" "Starting Docker installation..."
            install_mikrotik_docker
            ;;
        3)
            log "INFO" "Setting up Docker Compose deployment..."
            ensure_docker_running
            setup_docker_compose
            
            # Let user choose image source
            setup_mikrotik_image
            
            read -p "Do you want to include monitoring stack? (y/n): " monitoring_choice
            if [[ "$monitoring_choice" == "y" ]]; then
                generate_monitoring_config
                deploy_with_compose "docker-compose.monitoring.yml"
            else
                deploy_with_compose "docker-compose.yml"
            fi
            ;;
        4)
            manage_compose_services "start" "docker-compose.yml"
            ;;
        5)
            manage_compose_services "stop" "docker-compose.yml"
            ;;
        6)
            manage_compose_services "restart" "docker-compose.yml"
            ;;
        7)
            manage_compose_services "ps" "docker-compose.yml"
            ;;
        8)
            manage_compose_services "logs" "docker-compose.yml"
            ;;
        9)
            backup_mikrotik_config
            ;;
        10)
            read -p "Enter backup file to restore from: " backup_file
            if [[ -n "$backup_file" ]]; then
                log "INFO" "Restore function would be implemented here"
            else
                log "ERROR" "No backup file specified"
            fi
            ;;
        11)
            system_health_check
            ;;
        12)
            check_docker_status
            ;;
        13)
            if command -v less &> /dev/null; then
                less "$LOG_FILE"
            else
                cat "$LOG_FILE"
            fi
            ;;
        14)
            rm -rf "$TEMP_DIR"
            log "INFO" "Temporary files cleaned up"
            ;;
        15)
            customize_ports
            ;;
        0)
            log "INFO" "Exiting Advanced MikroTik Deployment Manager"
            exit 0
            ;;
        *)
            log "ERROR" "Invalid option: $choice"
            ;;
    esac
}

# Main menu loop
main_menu() {
    while true; do
        show_main_menu
        read -p "$(echo -e ${YELLOW}"Select an option [0-15]: "${NC})" choice
        
        handle_menu_choice "$choice"
        
        if [[ "$choice" != "0" ]]; then
            echo ""
            read -p "$(echo -e ${YELLOW}"Press Enter to continue..."${NC})" wait
        fi
    done
}

# Initialize and start the menu
init_directories
detect_system
load_config
check_dependencies

log "INFO" "Advanced MikroTik Deployment Manager started"

# Start the main menu
main_menu
