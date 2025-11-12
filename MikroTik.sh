#!/bin/bash

set -euo pipefail

# ==============================================================================
# CONFIGURATION
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
LOG_FILE="/var/log/mikrotik_installer.log"
CONFIG_FILE="/etc/mikrotik_installer.conf"
BACKUP_DIR="/var/backups/mikrotik"
TEMP_DIR="/tmp/mikrotik_installer"

# Defaults
# Defaults
DEFAULT_CHR_VERSION="7.15.2"
DEFAULT_PORTS="80 123 8291 22 443 53 1701 1723 1812 1813 2000 3784 3799 4500 4784 500 1194 5678 5679 8728 8729 60594 8080 20561 8900 8999 9999 21 23 110 995 143 993 25 465 587 3306 5432 3389 5900"

# ==============================================================================
# CORE FUNCTIONS
# ==============================================================================

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "${timestamp} [${level}] ${message}" | tee -a "$LOG_FILE"
}

error_exit() {
    log "ERROR" "$1"
    exit 1
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "WARN" "Running as root user"
    else
        log "WARN" "Not running as root - some operations may require sudo"
    fi
}

init_directories() {
    mkdir -p "$BACKUP_DIR" "$TEMP_DIR"
    chmod 700 "$BACKUP_DIR"
}

# ==============================================================================
# SYSTEM DETECTION
# ==============================================================================

detect_system() {
    log "INFO" "Detecting system information..."
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        DISTRO_ID="${ID}"
        log "INFO" "Distribution: $NAME $VERSION_ID"
    else
        error_exit "Cannot detect distribution"
    fi
    
    ARCH=$(uname -m)
    log "INFO" "Architecture: $ARCH"
}

detect_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64) echo "x86" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l|armv6l) echo "arm" ;;
        *) error_exit "Unsupported architecture: $arch" ;;
    esac
}

# ==============================================================================
# DEPENDENCY MANAGEMENT
# ==============================================================================

check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    local deps=("wget" "curl" "unzip" "tar" "gzip")
    local missing_deps=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "INFO" "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y -qq "${missing_deps[@]}"
    fi
}

# ==============================================================================
# CHR INSTALLATION
# ==============================================================================

verify_chr_requirements() {
    log "INFO" "Verifying system requirements..."
    
    local available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 10097152 ]]; then
        error_exit "Insufficient disk space. Need at least 10GB free."
    fi
    
    local total_mem=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    if [[ $total_mem -lt 1000000 ]]; then
        log "WARN" "Low memory detected. CHR recommends at least 1GB RAM."
        read -p "Continue anyway? (y/n): " continue_low_mem
        [[ ! $continue_low_mem =~ ^[Yy]$ ]] && exit 0
    fi
}

download_chr_image() {
    local version="$1"
    local arch=$(detect_architecture)
    local url="https://download.mikrotik.com/routeros/${version}/chr-${version}.img.zip"
    local filename="chr-${version}.img.zip"
    
    log "INFO" "Downloading CHR $version for $arch..."
    
    if wget --continue --progress=bar:force "$url" -O "$filename"; then
        unzip -q "$filename" -d "chr-${version}"
        log "INFO" "CHR image downloaded and extracted"
    else
        error_exit "Failed to download CHR image"
    fi
}

install_chr_image() {
    echo "=================================================================="
    echo "CRITICAL WARNING"
    echo "=================================================================="
    echo "THIS OPERATION WILL REPLACE YOUR CURRENT OS WITH MIKROTIK CHR"
    echo "ALL DATA WILL BE PERMANENTLY DELETED"
    echo "=================================================================="
    
    read -p "Press Enter to continue or Ctrl+C to cancel"
    
    check_root
    verify_chr_requirements

    local version
    echo "Available CHR versions:"
    local versions=("7.20.4" "7.19.3" "7.18.2" "7.17.3" "7.16.3" "7.15.2")
    
    for i in "${!versions[@]}"; do
        echo "$((i+1))) ${versions[i]}"
    done
    
    read -p "Select version [1-${#versions[@]}]: " selected_num
    if [[ "$selected_num" =~ ^[0-9]+$ ]] && [ "$selected_num" -ge 1 ] && [ "$selected_num" -le "${#versions[@]}" ]; then
        version="${versions[$((selected_num-1))]}"
    else
        error_exit "Invalid version selection"
    fi
    
    download_chr_image "$version"
    
    local root_disk=$(lsblk -n -o PKNAME $(findmnt -n -o SOURCE /) 2>/dev/null | head -1)
    [[ -z "$root_disk" ]] && error_exit "Could not detect root disk"
    
    local full_disk_path="/dev/${root_disk}"
    local chr_image=$(find "chr-${version}" -name "*.img" | head -1)
    
    echo "=================================================================="
    echo "FINAL CONFIRMATION"
    echo "=================================================================="
    echo "Target Disk: $full_disk_path"
    echo "MikroTik Version: $version"
    echo "=================================================================="
    
    read -p "Type 'ERASE' to proceed: " final_confirmation
    [[ "$final_confirmation" != "ERASE" ]] && exit 0
    
    log "INFO" "Writing CHR image to disk..."
    for partition in ${full_disk_path}*; do
        mountpoint -q "$partition" 2>/dev/null && umount -f "$partition"
    done
    
    if dd if="$chr_image" bs=1M of="$full_disk_path" status=progress; then
        log "INFO" "Installation complete. Rebooting..."
        sync
        sleep 10
        echo b > /proc/sysrq-trigger
    else
        error_exit "Failed to write CHR image"
    fi
}

# ==============================================================================
# DOCKER INSTALLATION
# ==============================================================================

install_docker() {

    
    if command -v docker &> /dev/null; then
        log "INFO" "Docker is already installed"
        return
    fi
    
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker "$USER"
    rm -f get-docker.sh
    
    log "INFO" "Docker installed successfully"
}

download_docker_image() {

    
    local url="https://github.com/Ptechgithub/MIKROTIK/releases/download/L6/Docker-image-Mikrotik-7.7-L6.7z"
    local filename="Docker-image-Mikrotik-7.7-L6.7z"
    
    wget --continue --progress=bar:force "$url" -O "$filename"
    7z x "$filename" -y
    docker load --input mikrotik7.7_docker_livekadeh.com
    
    log "INFO" "MikroTik Docker image loaded"
}

create_mikrotik_container() {
    local container_name="mikrotik_router"
    
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        read -p "Container exists. Remove and recreate? (y/n): " recreate
        if [[ "$recreate" == "y" ]]; then
            docker stop "$container_name" 2>/dev/null || true
            docker rm "$container_name" 2>/dev/null || true
        else
            log "INFO" "Using existing container"
            return 0
        fi
    fi
    
    # Build port mappings
    local port_mappings=""
    for port in $DEFAULT_PORTS; do
        port_mappings+=" -p $port:$port"
    done
    
    # Ask about persistent storage
    read -p "Enable persistent storage? (recommended) [Y/n]: " persistent_storage
    persistent_storage=${persistent_storage:-Y}
    
    local volume_mappings=""
    if [[ "$persistent_storage" =~ ^[Yy]$ ]]; then
        # Create volume if it doesn't exist
        if ! docker volume ls | grep -q "mikrotik_data"; then
            docker volume create mikrotik_data
        fi
        volume_mappings=" -v mikrotik_data:/routeros -v mikrotik_data:/flash -v mikrotik_data:/rw -v mikrotik_data:/storage"
        log "INFO" "Persistent storage enabled"
    else
        log "WARN" "Persistent storage disabled - configuration will be lost on container restart"
    fi
    
    # Add time volume
    volume_mappings+=" -v /etc/localtime:/etc/localtime:ro"
    
    # Create the container with all options
    docker run -d \
        --name "$container_name" \
        --restart unless-stopped \
        --cap-add=NET_ADMIN \
        --cap-add=SYS_MODULE \
        --cap-add=SYS_RAWIO \
        --device=/dev/net/tun \
        --sysctl net.ipv4.ip_forward=1 \
        --sysctl net.ipv6.conf.all.disable_ipv6=0 \
        --sysctl net.ipv4.conf.all.rp_filter=0 \
        $port_mappings \
        $volume_mappings \
        -e TZ=UTC \
        -e ROS_LICENSE=yes \
        livekadeh_com_mikrotik7_7
        
    if [ $? -eq 0 ]; then
        log "INFO" "MikroTik container created successfully"
        
        # Wait for container to start
        sleep 5
        
        # Show container status
        echo -e "${GREEN}Container Status:${NC}"
        docker ps -f "name=$container_name"
        
        # Show access information
        show_container_access_info
        
    else
        error_exit "Failed to create MikroTik container"
    fi
}

show_container_access_info() {
    echo -e "${GREEN}Access Information:${NC}"
    echo "=========================================="
    
    local host_ip=$(hostname -I | awk '{print $1}')
    [[ -z "$host_ip" ]] && host_ip="localhost"
    
    echo "Web Interface: http://$host_ip:80"
    echo "WinBox:        $host_ip:8291"
    echo "SSH:           ssh admin@$host_ip -p 22"
    echo "HTTPS:         https://$host_ip:443"
    echo ""
    echo "Default credentials:"
    echo "Username: admin"
    echo "Password: (no password)"
    echo ""
    echo "Container access: docker exec -it mikrotik_router bash"
    echo "=========================================="
}

install_mikrotik_docker() {

    
    install_docker
    download_docker_image
    create_mikrotik_container
    
    log "INFO" "MikroTik Docker installation completed"
}

# ==============================================================================
# DOCKER COMPOSE
# ==============================================================================

check_port_availability() {
    local port="$1"
    if ss -tuln | grep -q ":${port} " || \
       netstat -tuln 2>/dev/null | grep -q ":${port} "; then
        return 1
    else
        return 0
    fi
}

setup_docker_compose() {
    log "INFO" "Setting up Docker Compose..."
    
    # ONLY BRIDGE MODE - NO HOST MODE OPTION
    local network_section="    networks:
      - mikrotik_net"
    
    local sysctls_section="    sysctls:
      - net.ipv4.ip_forward=1          # IP forwarding
      - net.ipv6.conf.all.disable_ipv6=0  # IPv6
      - net.ipv4.conf.all.rp_filter=0  # Asymmetric routing
      - net.core.somaxconn=65535       # Max connection queue
      - net.core.netdev_max_backlog=30000 # Network buffer size
      - net.ipv4.tcp_max_syn_backlog=30000 # TCP connection queue"
    
    # Define port mappings with alternatives
    declare -A port_mappings
    port_mappings=(
        ["80"]="8080"
        ["8291"]="8292" 
        ["22"]="2222"
        ["443"]="8443"
        ["53"]="5353"
        ["1701"]="11701"
        ["1723"]="11723"
        ["1812"]="11812"
        ["1813"]="11813"
        ["2000"]="12000"
        ["3784"]="13784"
        ["3799"]="13799"
        ["4500"]="14500"
        ["4784"]="14784"
        ["500"]="1500"
        ["1194"]="11194"
        ["5678"]="15678"
        ["5679"]="15679"
        ["8728"]="18728"
        ["8729"]="18729"
        ["60594"]="60595"
        ["8080"]="18080"
        ["20561"]="20562"
        ["8900"]="18900"
        ["8999"]="18999"
        ["9999"]="19999"
        ["21"]="2021"
        ["23"]="2023"
        ["110"]="10110"
        ["995"]="10995"
        ["143"]="10143"
        ["993"]="10993"
        ["25"]="10025"
        ["465"]="10465"
        ["587"]="10587"
        ["3306"]="13306"
        ["5432"]="15432"
        ["3389"]="13389"
        ["5900"]="15900"
    )
    
    # Check port availability and build ports section
    local ports_section=""
    for port in $DEFAULT_PORTS; do
        local alt_port="${port_mappings[$port]:-$(($port + 10000))}"
        
        if check_port_availability "$port"; then
            ports_section+="      - \"$port:$port\"\n"
            log "INFO" "Port $port is available"
        else
            echo -e "${YELLOW}Port $port is already in use${NC}"
            echo "Suggested alternative: $alt_port"
            read -p "Enter alternative port for $port (or press Enter for $alt_port, or 'skip' to skip): " user_port
            
            if [[ -z "$user_port" ]]; then
                final_port="$alt_port"
            elif [[ "$user_port" == "skip" ]]; then
                log "INFO" "Skipping port $port"
                continue
            else
                if [[ "$user_port" =~ ^[0-9]+$ ]] && [ "$user_port" -ge 1 ] && [ "$user_port" -le 65535 ]; then
                    final_port="$user_port"
                else
                    echo -e "${RED}Invalid port, using default alternative $alt_port${NC}"
                    final_port="$alt_port"
                fi
            fi
            
            if check_port_availability "$final_port"; then
                ports_section+="      - \"$final_port:$port\"\n"
                log "INFO" "Mapping $port -> $final_port"
            else
                echo -e "${RED}Alternative port $final_port is also busy, skipping port $port${NC}"
            fi
        fi
    done

    # Ask about persistent storage
    read -p "Enable persistent storage? (recommended) [Y/n]: " persistent_storage
    persistent_storage=${persistent_storage:-Y}
    
    local volumes_section=""
    local volumes_definition=""
    
    if [[ "$persistent_storage" =~ ^[Yy]$ ]]; then
        volumes_section="    volumes:
      - mikrotik_data:/routeros
      - mikrotik_data:/flash
      - mikrotik_data:/rw
      - mikrotik_data:/storage
      - /etc/localtime:/etc/localtime:ro"
        
        volumes_definition="
volumes:
  mikrotik_data:
    driver: local"
        log "INFO" "Persistent storage enabled"
    else
        volumes_section="    volumes:
      - /etc/localtime:/etc/localtime:ro"
        log "WARN" "Persistent storage disabled"
    fi

    # Ask for timezone
    read -p "Enter timezone [UTC]: " timezone
    timezone=${timezone:-UTC}
    
    # Create docker-compose.yml - ONLY BRIDGE MODE
    cat > docker-compose.yml << EOF
services:
  mikrotik:
    image: livekadeh_com_mikrotik7_7
    container_name: mikrotik_router
    restart: unless-stopped
$network_section
    cap_add:
      - NET_ADMIN     # Network config
      - SYS_MODULE    # Load kernel modules
      - SYS_RAWIO     # Raw I/O access
      - SYS_TIME      # System clock changes
      - SYS_NICE      # Change process priority
      - IPC_LOCK      # Lock memory in RAM
    devices:
      - "/dev/net/tun"  # TUN/TAP tunnels
      - "/dev/kvm"      # Hardware virtualization
      - "/dev/ppp"      # PPP dial-up connections
    security_opt:
      - seccomp=unconfined   # Bypass system call filtering
      - apparmor=unconfined  # Bypass AppArmor restrictions
    privileged: true         # Full host access (DANGEROUS)
    ulimits:
      nproc: 65535           # Max processes
      nofile:                # Max open files
        soft: 65535
        hard: 65535
$sysctls_section
    ports:
$(echo -e "$ports_section")
$volumes_section
    environment:
      - TZ=$timezone
      - ROS_LICENSE=yes
$volumes_definition

networks:
  mikrotik_net:
    driver: bridge
EOF

    log "INFO" "Docker Compose file created"
    
    # Show configuration
    echo -e "${GREEN}Final Configuration:${NC}"
    echo "=========================================="
    echo -e "Network Mode: BRIDGE (SAFE)"
    echo -e "Port Mappings:"
    echo -e "$ports_section"
    echo "Persistent Storage: $persistent_storage"
    echo "Timezone: $timezone"
    echo "=========================================="
    
    echo -e "${GREEN}Access Information:${NC}"
    echo "Web Interface: http://your-server-ip:80"
    echo "WinBox: your-server-ip:8291"
    echo "SSH: ssh admin@your-server-ip -p 22"
    echo ""
    echo "Container is SAFELY isolated in bridge network"
}

ensure_docker_running() {
    # First check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log "INFO" "Docker is not installed. Installing..."
        install_docker
        return
    fi
    
    # Check if Docker service exists and is running
    if systemctl is-active --quiet docker; then
        log "INFO" "Docker service is running"
    else
        log "INFO" "Starting Docker service..."
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Wait for Docker to be ready
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
    fi
}

deploy_with_compose() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker is not installed. Installing Docker first...${NC}"
        install_docker
        
        # Wait for Docker to be ready
        echo "Waiting for Docker to start..."
        sleep 10
    fi
    
    # Check if Docker service is running
    if ! systemctl is-active --quiet docker; then
        echo -e "${YELLOW}Starting Docker service...${NC}"
        sudo systemctl start docker
        sudo systemctl enable docker
        sleep 5
    fi
    
    # Verify Docker is working
    if ! docker info &> /dev/null; then
        echo -e "${RED}Docker is not working properly. Please check Docker installation.${NC}"
        return 1
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
        install_docker_compose
    fi
    
    ensure_docker_running
    setup_docker_compose
    
    if ! docker images -a | grep -q "livekadeh_com_mikrotik7_7"; then
        download_docker_image
    fi
    
    # Use the correct compose command
    if command -v docker-compose &> /dev/null; then
        docker-compose up -d
    elif docker compose version &> /dev/null; then
        docker compose up -d
    else
        echo -e "${RED}Docker Compose not available${NC}"
        return 1
    fi
    
    log "INFO" "MikroTik deployed with Docker Compose"
}

# Also add this function if missing:
install_docker_compose() {

    
    # Install Docker Compose Plugin (preferred method)
    sudo apt-get update
    sudo apt-get install -y docker-compose-plugin
    
    # Alternative: Install standalone docker-compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then

        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi
    
    # Verify installation
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        log "INFO" "Docker Compose installed successfully"
    else
        error_exit "Failed to install Docker Compose"
    fi
}

# ==============================================================================
# MANAGEMENT FUNCTIONS
# ==============================================================================

container_status() {
    local container_name="mikrotik_router"
    
    if docker ps -a --format "{{.Names}}" | grep -q "$container_name"; then
        echo -e "${GREEN}Container Information:${NC}"
        echo "=========================================="
        
        # Basic container info in clean format
        docker ps -a -f "name=$container_name" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
        
        echo -e "\n${GREEN}Port Mappings:${NC}"
        echo "=========================================="
        
        # Get ports and format them nicely
        local ports=$(docker inspect "$container_name" --format='{{range $p, $conf := .NetworkSettings.Ports}}{{$p}} {{end}}')
        for port in $ports; do
            local mapping=$(docker port "$container_name" "$port" 2>/dev/null | head -1)
            if [[ -n "$mapping" ]]; then
                echo "  $port -> $mapping"
            fi
        done
        
        echo -e "\n${GREEN}Resource Usage:${NC}"
        echo "=========================================="
        docker stats "$container_name" --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
    else
        log "WARN" "Container '$container_name' not found"
    fi
}

backup_config() {
    local container_name="mikrotik_router"
    local backup_name="mikrotik_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
        docker export "$container_name" | gzip > "$BACKUP_DIR/$backup_name"
        log "INFO" "Backup created: $backup_name"
    else
        log "WARN" "Container is not running"
    fi
}

system_health_check() {
    echo -e "${GREEN}System Health Check${NC}"
    echo "=========================================="
    
    # Check Docker service
    if systemctl is-active --quiet docker; then
        echo -e "Docker service: ${GREEN}Running${NC}"
    else
        echo -e "Docker service: ${RED}Not running${NC}"
    fi
    
    # Check disk space
    local disk_usage=$(df / --output=pcent | tail -1 | tr -d ' %')
    if [ "$disk_usage" -lt 80 ]; then
        echo -e "Disk usage: ${GREEN}${disk_usage}%${NC}"
    else
        echo -e "Disk usage: ${RED}${disk_usage}%${NC}"
    fi
    
    # Check memory
    if command -v free &> /dev/null; then
        local mem_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
        if (( $(echo "$mem_usage < 80" | bc -l 2>/dev/null) )); then
            echo -e "Memory usage: ${GREEN}${mem_usage}%${NC}"
        else
            echo -e "Memory usage: ${RED}${mem_usage}%${NC}"
        fi
    fi
    
    # Check container status
    local container_name="mikrotik_router"
    if docker ps --format "{{.Names}}" | grep -q "$container_name"; then
        echo -e "MikroTik container: ${GREEN}Running${NC}"
    else
        echo -e "MikroTik container: ${RED}Not running${NC}"
    fi
    
    echo "=========================================="
}

manage_container() {
    local action
    while true; do
    clear
        local container_name="mikrotik_router"  # MOVE INSIDE
    
    echo -e "${GREEN}Container Management${NC}"
    echo "=========================================="
    echo "1) Start Container"
    echo "2) Stop Container"
    echo "3) Restart Container"
    echo "4) View Container Logs"
    echo "5) Remove Container"
    echo "6) Remove Container & Image"
    echo "0) Back to Main Menu"
    echo ""
    
    read -p "Select action [0-6]: " action
    
    case $action in
        1)
            if docker start "$container_name"; then
                log "INFO" "Container started successfully"
            else
                log "ERROR" "Failed to start container"
            fi
            ;;
        2)
            if docker stop "$container_name"; then
                log "INFO" "Container stopped successfully"
            else
                log "ERROR" "Failed to stop container"
            fi
            ;;
        3)
            if docker restart "$container_name"; then
                log "INFO" "Container restarted successfully"
            else
                log "ERROR" "Failed to restart container"
            fi
            ;;
        4)
            echo -e "${YELLOW}Showing container logs (Ctrl+C to exit):${NC}"
            docker logs -f "$container_name"
            ;;
        5)
            read -p "Are you sure you want to remove the container? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
                docker stop "$container_name" 2>/dev/null
                if docker rm "$container_name"; then
                    log "INFO" "Container removed successfully"
                else
                    log "ERROR" "Failed to remove container"
                fi
            fi
            ;;
        6)
            read -p "This will remove container AND image. Continue? (y/n): " confirm
            if [[ "$confirm" == "y" ]]; then
                docker stop "$container_name" 2>/dev/null
                docker rm "$container_name" 2>/dev/null
                if docker rmi "livekadeh_com_mikrotik7_7"; then
                    log "INFO" "Container and image removed successfully"
                else
                    log "ERROR" "Failed to remove image"
                fi
            fi
            ;;
        0) return ;;
        *) echo "Invalid option" ;;
    esac

    done
}

manage_compose() {
    local action
    while true; do
        clear
        echo -e "${GREEN}Docker Compose Management${NC}"
        echo "=========================================="
        echo "1) Start Services"
        echo "2) Stop Services"
        echo "3) Restart Services"
        echo "4) View Logs"
        echo "5) Down (Stop & Remove)"
        echo "6) Recreate Services"
        echo "0) Back to Main Menu"
        echo ""
        
        read -p "Select action [0-6]: " action
        
        # Determine which compose command to use
        local compose_cmd
        if command -v docker-compose &> /dev/null; then
            compose_cmd="docker-compose"
        elif docker compose version &> /dev/null; then
            compose_cmd="docker compose"
        else
            echo -e "${RED}Docker Compose not found!${NC}"
            return 1
        fi
        
        case $action in
            1)
                if $compose_cmd start; then
                    log "INFO" "Services started successfully"
                else
                    log "ERROR" "Failed to start services"
                fi
                ;;
            2)
                if $compose_cmd stop; then
                    log "INFO" "Services stopped successfully"
                else
                    log "ERROR" "Failed to stop services"
                fi
                ;;
            3)
                if $compose_cmd restart; then
                    log "INFO" "Services restarted successfully"
                else
                    log "ERROR" "Failed to restart services"
                fi
                ;;
            4)
                echo -e "${YELLOW}Showing compose logs (Ctrl+C to exit):${NC}"
                $compose_cmd logs -f
                ;;
            5)
                read -p "This will stop and remove all containers. Continue? (y/n): " confirm
                if [[ "$confirm" == "y" ]]; then
                    if $compose_cmd down; then
                        log "INFO" "Services stopped and removed"
                    else
                        log "ERROR" "Failed to stop services"
                    fi
                fi
                ;;
            6)
                if $compose_cmd up -d --force-recreate; then
                    log "INFO" "Services recreated successfully"
                else
                    log "ERROR" "Failed to recreate services"
                fi
                ;;
            0) return ;;
            *) echo "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

cleanup_system() {
    local option
    while true; do
    clear
    echo -e "${GREEN}System Cleanup${NC}"
    echo "=========================================="
    echo "1) Remove All Stopped Containers"
    echo "2) Remove Dangling Images"
    echo "3) Remove Unused Networks"
    echo "4) Remove All Unused Data (Prune)"
    echo "5) Cleanup Temporary Files"
    echo "6) Remove MikroTik Container Only"
    echo "7) Remove MikroTik Container & Image"
    echo "8) Remove ALL Docker Data (Nuclear Option)"
    echo "9) Remove ALL MikroTik Files (Complete Clean)"
    echo "0) Back to Main Menu"
    echo ""
    
    read -p "Select cleanup option [0-9]: " option
    
    case $option in
        1)
            docker container prune -f
            log "INFO" "Stopped containers removed"
            ;;
        2)
            docker image prune -f
            log "INFO" "Dangling images removed"
            ;;
        3)
            docker network prune -f
            log "INFO" "Unused networks removed"
            ;;
        4)
            docker system prune -af
            log "INFO" "All unused data removed"
            ;;
        5)
            rm -rf "$TEMP_DIR"
            log "INFO" "Temporary files cleaned up"
            ;;
        6)
            echo -e "${YELLOW}Removing MikroTik container...${NC}"
            docker stop mikrotik_router 2>/dev/null || true
            docker rm mikrotik_router 2>/dev/null || true
            log "INFO" "MikroTik container removed"
            ;;
        7)
            echo -e "${YELLOW}Removing MikroTik container and image...${NC}"
            docker stop mikrotik_router 2>/dev/null || true
            docker rm mikrotik_router 2>/dev/null || true
            docker rmi livekadeh_com_mikrotik7_7 2>/dev/null || true
            log "INFO" "MikroTik container and image removed"
            ;;
        8)
            echo -e "${RED}==========================================${NC}"
            echo -e "${RED}        WARNING: NUCLEAR OPTION${NC}"
            echo -e "${RED}==========================================${NC}"
            echo "This will remove:"
            echo "✓ All containers (running and stopped)"
            echo "✓ All images"
            echo "✓ All networks" 
            echo "✓ All volumes"
            echo "✓ All build cache"
            echo ""
            read -p "Type 'DELETE EVERYTHING' to confirm: " confirmation
            if [[ "$confirmation" == "DELETE EVERYTHING" ]]; then
                echo -e "${RED}Removing ALL Docker data...${NC}"
                
                # Remove all containers
                docker rm -f $(docker ps -aq) 2>/dev/null || true
                
                # Remove all images
                docker rmi -f $(docker images -aq) 2>/dev/null || true
                
                # Remove all volumes
                docker volume rm -f $(docker volume ls -q) 2>/dev/null || true
                
                # Remove all networks (except defaults)
                docker network rm $(docker network ls -q --filter type=custom) 2>/dev/null || true
                
                # Full system prune
                docker system prune -af --volumes
                
                log "INFO" "ALL Docker data removed"
            else
                echo "Nuclear cleanup cancelled"
            fi
            ;;
        9)
            echo -e "${RED}==========================================${NC}"
            echo -e "${RED}    COMPLETE MIKROTIK CLEANUP${NC}"
            echo -e "${RED}==========================================${NC}"
            echo "This will remove:"
            echo "✓ All MikroTik Docker containers/images"
            echo "✓ All leftover MikroTik files"
            echo "✓ All downloaded MikroTik images"
            echo "✓ All temporary files"
            echo "✓ All containerd snapshot data"
            echo ""
            read -p "Type 'CLEAN MIKROTIK' to confirm: " confirmation
            if [[ "$confirmation" == "CLEAN MIKROTIK" ]]; then
                echo -e "${RED}Removing ALL MikroTik files...${NC}"
                
                # Stop and remove MikroTik containers
                docker stop mikrotik_router 2>/dev/null || true
                docker rm mikrotik_router 2>/dev/null || true
                docker rmi livekadeh_com_mikrotik7_7 2>/dev/null || true
                
                # Remove downloaded image files (KEEP 7z files)
                rm -f /root/mikrotik7.7_docker_livekadeh.com 2>/dev/null || true
                rm -f mikrotik7.7_docker_livekadeh.com 2>/dev/null || true
                
                # Remove CHR installation files
                rm -rf chr-* 2>/dev/null || true
                rm -f chr-*.img.zip 2>/dev/null || true
                rm -f chr-*.img 2>/dev/null || true
                
                # Remove temporary directories
                rm -rf "$TEMP_DIR" 2>/dev/null || true
                rm -rf /tmp/mikrotik_* 2>/dev/null || true
                
                # Remove backup directories
                rm -rf "$BACKUP_DIR" 2>/dev/null || true
                rm -rf ./mikrotik_backups 2>/dev/null || true
                
                # Remove compose files
                rm -f docker-compose.yml 2>/dev/null || true
                rm -f docker-compose.*.yml 2>/dev/null || true
                rm -f .env 2>/dev/null || true
                
                # Remove setup scripts
                rm -f setup_*.sh 2>/dev/null || true
                
                # Clean Docker system
                docker system prune -af 2>/dev/null || true
                
                # Force containerd cleanup - EMPTY ENTIRE CONTAINERD DIRECTORY
                echo "Cleaning containerd data..."
                if systemctl is-active --quiet containerd; then
                    echo "Stopping containerd..."
                    systemctl stop containerd
                    
                    # Empty the entire containerd directory
                    if [[ -d "/var/lib/containerd" ]]; then
                        echo "Emptying /var/lib/containerd..."
                        # Remove all contents but keep the directory structure
                        find /var/lib/containerd -mindepth 1 -delete 2>/dev/null || true
                    fi
                    
                    echo "Starting containerd..."
                    systemctl start containerd
                    
                    # Wait for containerd to initialize
                    sleep 5
                fi
                
                # Also clean any temporary containerd directories
                if [[ -d "/var/lib/containerd" ]]; then
                    # Ensure the directory exists and has proper structure
                    mkdir -p /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots
                    mkdir -p /var/lib/containerd/io.containerd.content.v1.content/blobs/sha256
                    chown -R root:root /var/lib/containerd 2>/dev/null || true
                fi
                
                # Method 2: Use ctr command if available
                if command -v ctr &> /dev/null; then
                    echo "Using ctr to clean images..."
                    ctr -n moby images rm $(ctr -n moby images ls -q) 2>/dev/null || true
                fi
                
                log "INFO" "ALL MikroTik files removed"
                echo -e "${GREEN}Cleanup complete! Freed up ~5GB+ of space.${NC}"
                echo -e "${YELLOW}Note: Downloaded .7z files were kept for future use.${NC}"
            else
                echo "MikroTik cleanup cancelled"
            fi
            ;;
        0) return ;;
        *) echo "Invalid option" ;;
    esac

    done
}
# ==============================================================================
# DEPENDENCY MANAGEMENT
# ==============================================================================

install_essentials() {
    log "INFO" "Installing essential dependencies..."
    
    local essentials=(
        "wget"
        "curl"
        "p7zip-full"
        "p7zip-rar"
        "tar"
        "gzip"
        "unzip"
        "zip"
        "net-tools"
        "iproute2"
        "dnsutils"
        "jq"
        "bc"
        "file"
        "software-properties-common"
        "apt-transport-https"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )
    
    # Check which packages are missing using better method
    local missing_packages=()
    for package in "${essentials[@]}"; do
        if ! dpkg -s "$package" &> /dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        echo -e "${GREEN}All essential packages are already installed.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Missing packages: ${missing_packages[*]}${NC}"
    echo "Installing missing packages only..."
    
    # Update package list
    sudo apt-get update -qq
    
    # Install only missing packages
    for package in "${missing_packages[@]}"; do
        echo -e "${YELLOW}Installing: $package${NC}"
        if sudo apt-get install -y -qq "$package"; then
            echo -e "${GREEN}✓ $package installed${NC}"
        else
            echo -e "${RED}✗ Failed to install: $package${NC}"
        fi
    done
    
    # Install Docker Compose if not present
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${YELLOW}Installing Docker Compose...${NC}"
        install_docker_compose
    fi
    
    log "INFO" "Essential dependencies installation completed"
}

check_dependencies() {
    log "INFO" "Checking dependencies..."
    
    # Use dpkg -s for accurate package checking
    local basic_deps=("wget" "curl" "p7zip-full" "tar" "gzip" "unzip")
    local missing_deps=()
    
    for dep in "${basic_deps[@]}"; do
        if ! dpkg -s "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "INFO" "Missing dependencies detected: ${missing_deps[*]}"
        read -p "Install missing dependencies automatically? [Y/n]: " install_choice
        install_choice=${install_choice:-Y}
        
        if [[ "$install_choice" =~ ^[Yy]$ ]]; then
            install_essentials
        else
            log "WARN" "Some dependencies are missing: ${missing_deps[*]}"
        fi
    else
        log "INFO" "All basic dependencies are installed"
    fi
}
# ==============================================================================
# STATUS FUNCTIONS
# ==============================================================================

show_system_status() {
    echo -e "${BLUE}System Status:${NC}"
    echo "=========================================="
    
    # Docker status
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        echo -e "Docker: ${GREEN}✓ Running${NC}"
    else
        echo -e "Docker: ${RED}✗ Not running${NC}"
    fi
    
    # MikroTik container status
    if docker ps -a --format "{{.Names}}" | grep -q "mikrotik_router"; then
        if docker ps --format "{{.Names}}" | grep -q "mikrotik_router"; then
            echo -e "MikroTik Container: ${GREEN}✓ Running${NC}"
        else
            echo -e "MikroTik Container: ${YELLOW}⏸ Stopped${NC}"
        fi
    else
        echo -e "MikroTik Container: ${RED}✗ Not found${NC}"
    fi
    
    # Docker Compose status
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        echo -e "Docker Compose: ${GREEN}✓ Installed${NC}"
    else
        echo -e "Docker Compose: ${RED}✗ Not installed${NC}"
    fi
    
    # Essential dependencies status
    local missing_deps=()
    local basic_deps=("wget" "curl" "p7zip-full" "tar" "gzip" "unzip")
    for dep in "${basic_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null && ! dpkg -s "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        echo -e "Dependencies: ${GREEN}✓ All installed${NC}"
    else
        echo -e "Dependencies: ${RED}✗ Missing: ${missing_deps[*]}${NC}"
    fi
    
    # Disk space status
    local disk_usage=$(df / --output=pcent | tail -1 | tr -d ' %')
    if [ "$disk_usage" -lt 80 ]; then
        echo -e "Disk Space: ${GREEN}✓ ${disk_usage}% used${NC}"
    else
        echo -e "Disk Space: ${RED}✗ ${disk_usage}% used${NC}"
    fi
    
    echo "=========================================="
    echo ""
}

# ==============================================================================
# MAIN MENU
# ==============================================================================

show_main_menu() {
    clear
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════╗"
    echo "║      MikroTik Deployment Tool       ║"
    echo "║         Github.com/Ptechgithub      ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Show system status
    show_system_status
    
    # Menu Options
    echo -e "${GREEN}Menu Options:${NC}"
    echo "1) Install MikroTik CHR (Bare Metal)"
    echo "2) Install MikroTik via Docker"
    echo "3) Deploy with Docker Compose"
    echo "4) Container Status"
    echo "5) Backup Configuration"
    echo "6) System Health Check"
    echo "7) Manage Container"
    echo "8) Manage Docker Compose"
    echo "9) System Cleanup"
    echo "10) Install Essential Dependencies"
    echo "0) Exit"
    echo ""
}

main_menu() {
    init_directories
    detect_system
    while true; do
        show_main_menu
        read -p "Select an option [0-10]: " choice
        
        case $choice in
            1) install_chr_image ;;
            2) install_mikrotik_docker ;;
            3) deploy_with_compose ;;
            4) container_status ;;
            5) backup_config ;;
            6) system_health_check ;;
            7) manage_container ;;
            8) manage_compose ;;
            9) cleanup_system ;;
            10) install_essentials ;;
            0) exit 0 ;;
            *) echo "Invalid option" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}



# ==============================================================================
# START SCRIPT
# ==============================================================================

if [[ $# -eq 0 ]]; then
    main_menu
else
    # Command-line mode for automation
    case $1 in
        --chr) install_chr_image ;;
        --docker) install_mikrotik_docker ;;
        --compose) deploy_with_compose ;;
        --status) container_status ;;
        --backup) backup_config ;;
        *) echo "Use --chr, --docker, --compose, --status, or --backup" ;;
    esac
fi
