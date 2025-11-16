#!/bin/bash

# =============================================================================
# CONFIGURATION
# =============================================================================
SYSCTL_CONF="/etc/sysctl.conf"
LIMITS_CONF="/etc/security/limits.conf"
BACKUP_DIR="/etc/optimizer_backups"
TC_SCRIPT_NAME="tc_optimizer.sh"
TC_SCRIPT_PATH="/usr/local/bin/$TC_SCRIPT_NAME"

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
PURPLE='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "${GREEN}Created backup directory: $BACKUP_DIR${NC}"
    fi
}

backup_configs() {
    create_backup_dir
    echo -e "${GREEN}Backing up configuration files...${NC}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -f "$SYSCTL_CONF" ]; then
        cp "$SYSCTL_CONF" "${BACKUP_DIR}/sysctl.conf.bak.${timestamp}"
        echo -e "${GREEN}Backed up sysctl.conf${NC}"
    else
        echo -e "${YELLOW}Warning: $SYSCTL_CONF not found${NC}"
    fi
    
    if [ -f "$LIMITS_CONF" ]; then
        cp "$LIMITS_CONF" "${BACKUP_DIR}/limits.conf.bak.${timestamp}"
        echo -e "${GREEN}Backed up limits.conf${NC}"
    else
        echo -e "${YELLOW}Warning: $LIMITS_CONF not found${NC}"
    fi
}

reload_sysctl() {
    echo -e "${GREEN}Reloading sysctl settings...${NC}"
    if sysctl -p > /dev/null 2>&1; then
        echo -e "${GREEN}Sysctl settings reloaded successfully${NC}"
    else
        echo -e "${RED}Warning: Some sysctl settings may not have applied${NC}"
    fi
}

update_config() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    # Create file if it doesn't exist
    if [ ! -f "$file" ]; then
        touch "$file"
    fi
    
    if grep -q "^$key" "$file"; then
        if grep -q "^$key.*$value" "$file"; then
            echo -e "${YELLOW}Setting $key already configured${NC}"
        else
            sed -i "s|^$key.*|$key = $value|" "$file"
            echo -e "${GREEN}Updated $key to $value${NC}"
        fi
    else
        echo "$key = $value" >> "$file"
        echo -e "${GREEN}Added $key with value $value${NC}"
    fi
}

# =============================================================================
# SYSCTL OPTIMIZATION PROFILES
# =============================================================================

apply_gaming_optimizations() {
    echo -e "${CYAN}Applying GAMING Optimizations (Low Latency Focus)...${NC}"
    backup_configs

    declare -A gaming_settings=(
        ["vm.swappiness"]="30"
        ["vm.dirty_ratio"]="15"
        ["vm.dirty_background_ratio"]="5"
        ["vm.dirty_expire_centisecs"]="1000"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="50"
        ["vm.min_free_kbytes"]="65536"
        ["net.core.rmem_max"]="33554432"
        ["net.core.wmem_max"]="33554432"
        ["net.core.rmem_default"]="262144"
        ["net.core.wmem_default"]="262144"
        ["net.core.netdev_max_backlog"]="2000"
        ["net.core.netdev_budget"]="600"
        ["net.core.somaxconn"]="65535"
        ["net.core.optmem_max"]="65536"
        ["net.ipv4.tcp_rmem"]="4096 87380 33554432"
        ["net.ipv4.tcp_wmem"]="4096 16384 33554432"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_low_latency"]="1"
        ["net.ipv4.tcp_max_syn_backlog"]="8192"
        ["net.ipv4.tcp_max_tw_buckets"]="2000000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="10"
        ["net.ipv4.tcp_keepalive_time"]="300"
        ["net.ipv4.tcp_keepalive_intvl"]="30"
        ["net.ipv4.tcp_keepalive_probes"]="3"
        ["net.ipv4.udp_rmem_min"]="8192"
        ["net.ipv4.udp_wmem_min"]="8192"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv4.conf.default.accept_redirects"]="0"
        ["net.ipv4.conf.all.accept_source_route"]="0"
        ["net.ipv4.conf.default.accept_source_route"]="0"
        ["fs.file-max"]="2097152"
    )

    for key in "${!gaming_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${gaming_settings[$key]}"
    done

    declare -A gaming_limits=(
        ["* soft nproc"]="65535"
        ["* hard nproc"]="65535"
        ["* soft nofile"]="524288"
        ["* hard nofile"]="524288"
        ["root soft nproc"]="65535"
        ["root hard nproc"]="65535"
        ["root soft nofile"]="524288"
        ["root hard nofile"]="524288"
    )

    for key in "${!gaming_limits[@]}"; do
        if grep -q "^$key" "$LIMITS_CONF"; then
            sed -i "s|^$key.*|$key ${gaming_limits[$key]}|" "$LIMITS_CONF"
        else
            echo "$key ${gaming_limits[$key]}" >> "$LIMITS_CONF"
        fi
        echo -e "${GREEN}Updated limit: $key ${gaming_limits[$key]}${NC}"
    done

    reload_sysctl
    echo -e "${GREEN}GAMING optimizations applied!${NC}"
    echo -e "${YELLOW}Please restart your system for all changes to take effect.${NC}"
}

apply_streaming_optimizations() {
    echo -e "${CYAN}Applying STREAMING Optimizations (High Throughput Focus)...${NC}"
    backup_configs

    declare -A streaming_settings=(
        ["vm.swappiness"]="10"
        ["vm.dirty_ratio"]="20"
        ["vm.dirty_background_ratio"]="10"
        ["vm.dirty_expire_centisecs"]="3000"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="100"
        ["net.core.rmem_max"]="67108864"
        ["net.core.wmem_max"]="67108864"
        ["net.core.rmem_default"]="4194304"
        ["net.core.wmem_default"]="4194304"
        ["net.core.netdev_max_backlog"]="5000"
        ["net.core.somaxconn"]="65535"
        ["net.ipv4.tcp_rmem"]="8192 87380 67108864"
        ["net.ipv4.tcp_wmem"]="8192 65536 67108864"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq_codel"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_notsent_lowat"]="16384"
        ["net.ipv4.tcp_max_syn_backlog"]="16384"
        ["net.ipv4.tcp_max_tw_buckets"]="4000000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="15"
        ["net.ipv4.tcp_keepalive_time"]="600"
        ["fs.file-max"]="4194304"
    )

    for key in "${!streaming_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${streaming_settings[$key]}"
    done

    declare -A streaming_limits=(
        ["* soft nproc"]="65535"
        ["* hard nproc"]="65535"
        ["* soft nofile"]="1048576"
        ["* hard nofile"]="1048576"
        ["root soft nproc"]="65535"
        ["root hard nproc"]="65535"
        ["root soft nofile"]="1048576"
        ["root hard nofile"]="1048576"
    )

    for key in "${!streaming_limits[@]}"; do
        if grep -q "^$key" "$LIMITS_CONF"; then
            sed -i "s|^$key.*|$key ${streaming_limits[$key]}|" "$LIMITS_CONF"
        else
            echo "$key ${streaming_limits[$key]}" >> "$LIMITS_CONF"
        fi
        echo -e "${GREEN}Updated limit: $key ${streaming_limits[$key]}${NC}"
    done

    reload_sysctl
    echo -e "${GREEN}STREAMING optimizations applied!${NC}"
    echo -e "${YELLOW}Please restart your system for all changes to take effect.${NC}"
}

apply_general_optimizations() {
    echo -e "${CYAN}Applying GENERAL PURPOSE Optimizations (Balanced)...${NC}"
    backup_configs

    declare -A general_settings=(
        ["vm.swappiness"]="60"
        ["vm.dirty_ratio"]="20"
        ["vm.dirty_background_ratio"]="10"
        ["vm.dirty_expire_centisecs"]="3000"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="100"
        ["net.core.rmem_max"]="16777216"
        ["net.core.wmem_max"]="16777216"
        ["net.core.rmem_default"]="262144"
        ["net.core.wmem_default"]="262144"
        ["net.core.netdev_max_backlog"]="3000"
        ["net.core.somaxconn"]="4096"
        ["net.ipv4.tcp_rmem"]="4096 87380 16777216"
        ["net.ipv4.tcp_wmem"]="4096 16384 16777216"
        ["net.ipv4.tcp_congestion_control"]="cubic"
        ["net.core.default_qdisc"]="fq_codel"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_max_syn_backlog"]="1024"
        ["net.ipv4.tcp_max_tw_buckets"]="262144"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="30"
        ["net.ipv4.tcp_keepalive_time"]="7200"
        ["net.ipv4.tcp_syncookies"]="1"
        ["fs.file-max"]="65536"
    )

    for key in "${!general_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${general_settings[$key]}"
    done

    declare -A general_limits=(
        ["* soft nproc"]="10240"
        ["* hard nproc"]="10240"
        ["* soft nofile"]="65536"
        ["* hard nofile"]="65536"
        ["root soft nproc"]="10240"
        ["root hard nproc"]="10240"
        ["root soft nofile"]="65536"
        ["root hard nofile"]="65536"
    )

    for key in "${!general_limits[@]}"; do
        if grep -q "^$key" "$LIMITS_CONF"; then
            sed -i "s|^$key.*|$key ${general_limits[$key]}|" "$LIMITS_CONF"
        else
            echo "$key ${general_limits[$key]}" >> "$LIMITS_CONF"
        fi
        echo -e "${GREEN}Updated limit: $key ${general_limits[$key]}${NC}"
    done

    reload_sysctl
    echo -e "${GREEN}GENERAL PURPOSE optimizations applied!${NC}"
    echo -e "${YELLOW}Please restart your system for all changes to take effect.${NC}"
}

apply_competitive_gaming_optimizations() {
    echo -e "${CYAN}Applying COMPETITIVE GAMING Optimizations (Extreme Low Latency)...${NC}"
    backup_configs

    declare -A comp_settings=(
        ["vm.swappiness"]="1"
        ["vm.dirty_ratio"]="5"
        ["vm.dirty_background_ratio"]="3"
        ["vm.dirty_expire_centisecs"]="500"
        ["vm.dirty_writeback_centisecs"]="100"
        ["vm.vfs_cache_pressure"]="25"
        ["vm.min_free_kbytes"]="131072"
        ["net.core.rmem_max"]="16777216"
        ["net.core.wmem_max"]="16777216"
        ["net.core.rmem_default"]="131072"
        ["net.core.wmem_default"]="131072"
        ["net.core.netdev_max_backlog"]="1000"
        ["net.core.netdev_budget"]="300"
        ["net.core.somaxconn"]="65535"
        ["net.core.optmem_max"]="65536"
        ["net.ipv4.tcp_rmem"]="4096 65536 16777216"
        ["net.ipv4.tcp_wmem"]="4096 16384 16777216"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_low_latency"]="1"
        ["net.ipv4.tcp_no_metrics_save"]="1"
        ["net.ipv4.tcp_timestamps"]="0"
        ["net.ipv4.tcp_sack"]="0"
        ["net.ipv4.tcp_dsack"]="0"
        ["net.ipv4.tcp_fack"]="0"
        ["net.ipv4.tcp_max_syn_backlog"]="4096"
        ["net.ipv4.tcp_max_tw_buckets"]="1800000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="5"
        ["net.ipv4.tcp_keepalive_time"]="1800"
        ["net.ipv4.tcp_keepalive_intvl"]="15"
        ["net.ipv4.tcp_keepalive_probes"]="3"
        ["net.ipv4.udp_rmem_min"]="4096"
        ["net.ipv4.udp_wmem_min"]="4096"
        ["fs.file-max"]="1048576"
    )

    for key in "${!comp_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${comp_settings[$key]}"
    done

    reload_sysctl
    echo -e "${GREEN}COMPETITIVE GAMING optimizations applied!${NC}"
    echo -e "${YELLOW}Please restart your system for all changes to take effect.${NC}"
}

# =============================================================================
# TC OPTIMIZATION FUNCTIONS
# =============================================================================



# Function to detect available network interfaces
detect_interfaces() {
    echo -e "${YELLOW}Detecting network interfaces...${NC}"
    
    # Get all physical interfaces (excluding virtual ones)
    INTERFACES=($(ls /sys/class/net/ | grep -v -E '^(lo|docker|veth|br-|virbr)'))
    
    if [ ${#INTERFACES[@]} -eq 0 ]; then
        echo -e "${RED}No network interfaces found!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Available interfaces:${NC}"
    for i in "${!INTERFACES[@]}"; do
        # Get IP address for each interface
        IP=$(ip addr show ${INTERFACES[$i]} 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        STATUS=$(cat /sys/class/net/${INTERFACES[$i]}/operstate 2>/dev/null)
        if [ "$STATUS" = "up" ]; then
            STATUS_COLOR="${GREEN}▲${NC}"
        else
            STATUS_COLOR="${RED}▼${NC}"
        fi
        
        echo -e "  $((i+1)). ${INTERFACES[$i]} $STATUS_COLOR ${WHITE}(${IP:-No IP})${NC}"
    done
    
    # Find default route interface
    DEFAULT_INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -n "$DEFAULT_INTERFACE" ]; then
        echo -e "${CYAN}Default route interface: $DEFAULT_INTERFACE${NC}"
    fi
}

# Function to select interface
select_interface() {
    detect_interfaces
    
    if [ ${#INTERFACES[@]} -eq 0 ]; then
        return 1
    fi
    
    # If only one interface, use it automatically
    if [ ${#INTERFACES[@]} -eq 1 ]; then
        SELECTED_INTERFACE=${INTERFACES[0]}
        echo -e "${GREEN}Using only available interface: $SELECTED_INTERFACE${NC}"
        return 0
    fi
    
    echo -e "\n${CYAN}Select network interface:${NC}"
    echo -e "  ${WHITE}0. Auto-detect (use default route)${NC}"
    for i in "${!INTERFACES[@]}"; do
        echo -e "  ${WHITE}$((i+1)). ${INTERFACES[$i]}${NC}"
    done
    
    while true; do
        echo -ne "${YELLOW}Enter choice [0-${#INTERFACES[@]}]: ${NC}"
        read choice
        
        case $choice in
            0)
                if [ -n "$DEFAULT_INTERFACE" ]; then
                    SELECTED_INTERFACE="$DEFAULT_INTERFACE"
                    echo -e "${GREEN}Using auto-detected interface: $SELECTED_INTERFACE${NC}"
                    break
                else
                    echo -e "${RED}Could not auto-detect default interface${NC}"
                    continue
                fi
                ;;
            [1-9]*)
                if [ $choice -le ${#INTERFACES[@]} ]; then
                    SELECTED_INTERFACE="${INTERFACES[$((choice-1))]}"
                    echo -e "${GREEN}Selected interface: $SELECTED_INTERFACE${NC}"
                    break
                else
                    echo -e "${RED}Invalid choice. Please try again.${NC}"
                fi
                ;;
            *)
                echo -e "${RED}Please enter a valid number.${NC}"
                ;;
        esac
    done
}

# Function to select performance profile
select_performance_profile() {
    echo -e "\n${CYAN}Select performance profile:${NC}"
    echo -e "  ${WHITE}1. Gaming Mode${NC}"
    echo -e "     ${GREEN}✓ Lowest latency for competitive gaming${NC}"
    echo -e "     ${GREEN}✓ Fast response times${NC}"
    echo -e "     ${YELLOW}⚠ Lower throughput for large downloads${NC}"
    
    echo -e "  ${WHITE}2. High-Loss Network Mode${NC}"
    echo -e "     ${GREEN}✓ Better performance on lossy connections${NC}"
    echo -e "     ${GREEN}✓ Improved stability on Wi-Fi/LTE${NC}"
    echo -e "     ${YELLOW}⚠ Slightly higher latency${NC}"
    
    echo -e "  ${WHITE}3. General Purpose Mode${NC}"
    echo -e "     ${GREEN}✓ Balanced performance${NC}"
    echo -e "     ${GREEN}✓ Good for browsing/streaming${NC}"
    echo -e "     ${YELLOW}⚠ Not optimized for gaming${NC}"
    
    echo -e "  ${WHITE}4. Custom Mode${NC}"
    echo -e "     ${GREEN}✓ Manual configuration${NC}"
    echo -e "     ${YELLOW}⚠ Advanced users only${NC}"
    
    while true; do
        echo -ne "${YELLOW}Enter choice [1-4]: ${NC}"
        read choice
        
        case $choice in
            1)
                PROFILE="gaming"
                echo -e "${GREEN}Selected: Gaming Mode${NC}"
                break
                ;;
            2)
                PROFILE="high-loss"
                echo -e "${GREEN}Selected: High-Loss Network Mode${NC}"
                break
                ;;
            3)
                PROFILE="general"
                echo -e "${GREEN}Selected: General Purpose Mode${NC}"
                break
                ;;
            4)
                PROFILE="custom"
                echo -e "${GREEN}Selected: Custom Mode${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid choice. Please enter 1-4.${NC}"
                ;;
        esac
    done
}

create_tc_optimizer_script() {
    local profile="$1"
    local interface="$2"
    
    echo -e "${GREEN}Creating TC optimizer script for $profile mode on $interface...${NC}"
    
    # Create the script with proper error handling
    cat > "$TC_SCRIPT_PATH" << EOF
#!/bin/bash
# TC Optimizer - $profile Mode
# Interface: $interface
# Created: $(date)

set -e

# Wait for network to be ready
sleep 30

INTERFACE="$interface"

# Verify interface exists
if ! ip link show "\$INTERFACE" > /dev/null 2>&1; then
    echo "Error: Interface \$INTERFACE not found"
    exit 1
fi

# Wait for interface to be up
for i in {1..30}; do
    if ip link show "\$INTERFACE" | grep -q "state UP"; then
        break
    fi
    sleep 1
done

echo "Applying $profile optimizations to \$INTERFACE..."

# Clean existing rules
tc qdisc del dev "\$INTERFACE" root 2>/dev/null || true
tc qdisc del dev "\$INTERFACE" ingress 2>/dev/null || true

# Apply $profile optimization
EOF

    # Add the specific profile configuration
    case "$profile" in
        "gaming")
            cat >> "$TC_SCRIPT_PATH" << 'GAMING_EOF'
# =============================================================================
# GAMING OPTIMIZATIONS - Lowest latency for competitive gaming
# =============================================================================

echo "Applying comprehensive gaming optimizations..."

# 1. Disable pause frames (if supported)
ethtool -A "$INTERFACE" rx off tx off 2>/dev/null && echo "✓ Pause frames disabled" || echo "⚠ Pause frames not supported"

# 2. Disable segmentation offloads for lower latency
ethtool -K "$INTERFACE" gso off 2>/dev/null && echo "✓ GSO disabled"
ethtool -K "$INTERFACE" tso off 2>/dev/null && echo "✓ TSO disabled" 
ethtool -K "$INTERFACE" gro off 2>/dev/null && echo "✓ GRO disabled"
ethtool -K "$INTERFACE" lro off 2>/dev/null && echo "✓ LRO disabled"

# 3. Ring buffer optimizations for low latency
ethtool -G "$INTERFACE" rx 256 tx 256 2>/dev/null && echo "✓ Small ring buffers set (256)" || echo "⚠ Ring buffers not supported"

# 4. Interrupt coalescing - disable for lowest latency
ethtool -C "$INTERFACE" rx-usecs 0 tx-usecs 0 2>/dev/null && echo "✓ Interrupt coalescing disabled" || echo "⚠ Interrupt coalescing not supported"

# 5. TCP stack optimizations for gaming
echo 10 > /proc/sys/net/ipv4/tcp_fin_timeout 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null || true

# 6. TX queue length for low latency
echo 256 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null && echo "✓ TX queue length set to 256" || echo "⚠ TX queue length not supported"

# 7. Advanced queuing discipline for gaming
echo "Applying gaming-optimized qdisc..."
if tc qdisc add dev "$INTERFACE" root cake bandwidth 1000mbit besteffort dual-dsthost nat nowash no-ack-filter 2>/dev/null; then
    echo "✓ CAKE qdisc applied (gaming optimized)"
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 1000 flows 1024 target 2ms interval 20ms noecn 2>/dev/null; then
    echo "✓ fq_codel qdisc applied (gaming optimized)"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    echo "✓ Fallback to pfifo_fast"
fi
GAMING_EOF
            ;;
        "high-loss")
            cat >> "$TC_SCRIPT_PATH" << 'HIGHLOSS_EOF'
# High-loss network optimizations
echo "Applying high-loss network optimizations..."

echo 4000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null && echo "✓ TX queue length set to 4000" || echo "⚠ TX queue length not supported"
echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null && echo "✓ ECN enabled" || true

# Buffer bloat control for unstable networks
if tc qdisc add dev "$INTERFACE" root cake bandwidth 850mbit besteffort ack-filter nat nowash 2>/dev/null; then
    echo "✓ CAKE qdisc applied (high-loss optimized)"
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 30000 flows 4096 ecn ce-threshold 1ms 2>/dev/null; then
    echo "✓ fq_codel qdisc applied (high-loss optimized)"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    echo "✓ Fallback to pfifo_fast"
fi
HIGHLOSS_EOF
            ;;
        "general")
            cat >> "$TC_SCRIPT_PATH" << 'GENERAL_EOF'
# General purpose optimizations
echo "Applying general purpose optimizations..."

echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null && echo "✓ TX queue length set to 1000" || echo "⚠ TX queue length not supported"

# Balanced settings for mixed usage
if tc qdisc add dev "$INTERFACE" root cake bandwidth 1000mbit besteffort nat nowash 2>/dev/null; then
    echo "✓ CAKE qdisc applied (general purpose)"
elif tc qdisc add dev "$INTERFACE" root fq_codel ecn ce-threshold 4ms 2>/dev/null; then
    echo "✓ fq_codel qdisc applied (general purpose)"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    echo "✓ Fallback to pfifo_fast"
fi
GENERAL_EOF
            ;;
        "custom")
            cat >> "$TC_SCRIPT_PATH" << 'CUSTOM_EOF'
# Custom mode - user configured
echo "Running in custom mode - no predefined optimizations"
# Add your custom TC rules here
tc qdisc add dev "$INTERFACE" root pfifo_fast
echo "✓ Custom mode: basic pfifo_fast applied"
CUSTOM_EOF
            ;;
    esac

    # Add the footer
    cat >> "$TC_SCRIPT_PATH" << 'EOF'

echo "Optimizations completed successfully for $INTERFACE"
exit 0
EOF

    # Make the script executable
    chmod +x "$TC_SCRIPT_PATH"
    
    # Verify the script was created
    if [ -f "$TC_SCRIPT_PATH" ] && [ -x "$TC_SCRIPT_PATH" ]; then
        echo -e "${GREEN}✓ TC optimizer script created at: $TC_SCRIPT_PATH${NC}"
        echo -e "${CYAN}Profile: $profile | Interface: $interface${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to create TC optimizer script${NC}"
        return 1
    fi
}

# Enhanced startup status check
check_startup_status() {
    echo -e "${YELLOW}Checking startup status...${NC}"
    
    if crontab -l 2>/dev/null | grep -q "$TC_SCRIPT_NAME"; then
        echo -e "${GREEN}✓ TC optimizations are enabled at startup${NC}"
        echo -e "${WHITE}Cron entry:${NC}"
        crontab -l | grep "$TC_SCRIPT_NAME"
        
        # Show current interface and profile info
        if [ -f "$TC_SCRIPT_PATH" ]; then
            echo -e "\n${WHITE}Script details:${NC}"
            grep -E "^(# TC Optimizer|# Interface:|# Created:)" "$TC_SCRIPT_PATH" | head -3
        fi
        return 0
    else
        echo -e "${YELLOW}⚠ TC optimizations are NOT enabled at startup${NC}"
        return 1
    fi
}

# Enable optimizations at system startup
enable_startup_optimizations() {
    echo -e "${YELLOW}Enabling TC optimizations at startup...${NC}"
    
    # Create a temporary crontab
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$TC_SCRIPT_NAME" > "$temp_cron"
    
    # Add the startup optimization entry
    echo "@reboot sleep 30 && $TC_SCRIPT_PATH" >> "$temp_cron"
    
    # Install the new crontab
    if crontab "$temp_cron"; then
        rm -f "$temp_cron"
        echo -e "${GREEN}✓ Startup optimizations enabled${NC}"
        echo -e "${WHITE}Optimizations will run automatically on boot${NC}"
        return 0
    else
        rm -f "$temp_cron"
        echo -e "${RED}✗ Failed to enable startup optimizations${NC}"
        return 1
    fi
}

# Disable optimizations at system startup
disable_startup_optimizations() {
    echo -e "${YELLOW}Disabling TC optimizations at startup...${NC}"
    
    # Remove any existing tc optimization entries from crontab
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$TC_SCRIPT_NAME" > "$temp_cron"
    
    # Install the cleaned crontab
    if crontab "$temp_cron"; then
        rm -f "$temp_cron"
        echo -e "${GREEN}✓ Removed TC optimizations from crontab${NC}"
    else
        rm -f "$temp_cron"
        echo -e "${RED}✗ Failed to update crontab${NC}"
        return 1
    fi
    
    # Remove the script file
    if [ -f "$TC_SCRIPT_PATH" ]; then
        rm -f "$TC_SCRIPT_PATH"
        echo -e "${GREEN}✓ Removed TC optimizer script${NC}"
    fi
    
    echo -e "${GREEN}✓ Startup optimizations disabled${NC}"
    return 0
}

# Ask user about startup configuration
ask_startup_config() {
    echo ""
    echo "=============================================="
    echo -e "${CYAN}STARTUP CONFIGURATION${NC}"
    echo "=============================================="
    echo -e "${WHITE}Do you want to run TC optimizations automatically at system startup?${NC}"
    echo ""
    echo -e "${GREEN}Y${NC} - Yes, enable on startup"
    echo -e "${YELLOW}N${NC} - No, run only once"
    echo -e "${BLUE}S${NC} - Show current startup status"
    echo -e "${RED}D${NC} - Disable startup optimizations"
    echo ""
    echo -n "Your choice [Y/n/S/d]: "
    
    read -r choice
    case "${choice:-y}" in
        [Yy]*)
            enable_startup_optimizations
            ;;
        [Nn]*)
            echo -e "${YELLOW}TC optimizations will run only once (current session)${NC}"
            ;;
        [Ss]*)
            check_startup_status
            echo ""
            echo -n "Press Enter to continue..."
            read -r
            ask_startup_config
            ;;
        [Dd]*)
            disable_startup_optimizations
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ask_startup_config
            ;;
    esac
}

# Clean up TC rules
cleanup_tc() {
    local interface="$1"
    echo -e "${YELLOW}Cleaning existing TC rules...${NC}"
    tc qdisc del dev "$interface" root 2>/dev/null || true
    tc qdisc del dev "$interface" ingress 2>/dev/null || true
    echo 1000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null || true
    echo -e "${GREEN}✓ TC rules cleaned up for $interface${NC}"
}

# Run TC optimizations immediately
run_tc_optimizations() {
    if [ -f "$TC_SCRIPT_PATH" ] && [ -x "$TC_SCRIPT_PATH" ]; then
        echo -e "${YELLOW}Running TC optimizations now...${NC}"
        sudo "$TC_SCRIPT_PATH"
    else
        echo -e "${RED}TC optimizer script not found or not executable${NC}"
        echo -e "${YELLOW}Please run setup first${NC}"
        return 1
    fi
}

# Main setup function
tc_optimize() {
    echo -e "${CYAN}=== TC Optimizer Setup ===${NC}"
    
    # Select interface
    if ! select_interface; then
        echo -e "${RED}Failed to select interface. Exiting.${NC}"
        return 1
    fi
    
    # Select performance profile
    select_performance_profile
    
    # Create the script
    if create_tc_optimizer_script "$PROFILE" "$SELECTED_INTERFACE"; then
        echo -e "\n${GREEN}✓ Setup completed successfully!${NC}"
        echo -e "${WHITE}Interface:${NC} $SELECTED_INTERFACE"
        echo -e "${WHITE}Profile:${NC} $PROFILE"
        echo -e "${WHITE}Script:${NC} $TC_SCRIPT_PATH"
        
        # Ask about startup configuration
        ask_startup_config
        
        # Ask if user wants to run optimizations now
        echo ""
        echo -n "Do you want to apply optimizations now? [Y/n]: "
        read -r apply_now
        case "${apply_now:-y}" in
            [Yy]*)
                run_tc_optimizations
                ;;
            [Nn]*)
                echo -e "${YELLOW}Optimizations will run on next boot or manually via: sudo $TC_SCRIPT_PATH${NC}"
                ;;
        esac
        
    else
        echo -e "${RED}✗ Setup failed${NC}"
        return 1
    fi
}

# Display current TC status
show_tc_status() {
    local interface="$1"
    echo -e "${CYAN}=== Current TC Status for $interface ===${NC}"
    
    # Show current qdisc
    echo -e "${YELLOW}Current qdisc:${NC}"
    tc qdisc show dev "$interface"
    
    # Show interface statistics
    echo -e "\n${YELLOW}Interface statistics:${NC}"
    ip -s link show "$interface"
    
    # Show ethtool settings
    echo -e "\n${YELLOW}Ethtool settings:${NC}"
    ethtool -k "$interface" 2>/dev/null | grep -E "(tso|gso|gro|lro):" || echo "Ethtool not available"
}




apply_netem_testing() {
    local condition="$1"
    
    echo -e "${PURPLE}Applying NetEM for testing: $condition${NC}"
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}ERROR: Could not detect network interface${NC}"
        return 1
    fi
    
    # Apply general optimizations first
    cleanup_tc "$INTERFACE"
    apply_tc_general_optimizations "$INTERFACE"
    
    local handle=$(tc qdisc show dev "$INTERFACE" 2>/dev/null | head -1 | awk '{print $3}')
    if [ -z "$handle" ]; then
        echo -e "${RED}Failed to get qdisc handle${NC}"
        return 1
    fi
    
    case "$condition" in
        "gaming-latency")
            tc qdisc change dev "$INTERFACE" root netem delay 10ms 2ms distribution normal
            echo -e "${GREEN}Added gaming-like latency: 10ms ±2ms${NC}"
            ;;
        "high-loss")
            tc qdisc change dev "$INTERFACE" root netem loss 5% 25%
            echo -e "${GREEN}Added high packet loss: 5%${NC}"
            ;;
        "wireless")
            tc qdisc change dev "$INTERFACE" root netem delay 20ms 10ms loss 2% 10% duplicate 1%
            echo -e "${GREEN}Added wireless-like conditions${NC}"
            ;;
        "satellite")
            tc qdisc change dev "$INTERFACE" root netem delay 600ms 100ms loss 1%
            echo -e "${GREEN}Added satellite-like latency${NC}"
            ;;
        "internet-typical")
            tc qdisc change dev "$INTERFACE" root netem delay 30ms 5ms loss 0.5% 10%
            echo -e "${GREEN}Added internet typical conditions${NC}"
            ;;
    esac
    
    echo -e "${GREEN}NetEM testing condition '$condition' applied${NC}"
}

tc_remove_optimizations() {
    echo -e "${RED}Removing ALL TC optimizations...${NC}"
    
    # Remove from startup first
    disable_startup_optimizations
    
    # Remove TC rules from all interfaces
    for INTERFACE in $(ls /sys/class/net/ | grep -v lo); do
        echo -e "${YELLOW}Cleaning $INTERFACE...${NC}"
        tc qdisc del dev "$INTERFACE" root 2>/dev/null
        tc qdisc del dev "$INTERFACE" ingress 2>/dev/null
        echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
    done
    
    echo -e "${GREEN}All TC optimizations removed${NC}"
}

# =============================================================================
# REMOVAL FUNCTIONS
# =============================================================================

remove_all_optimizations() {
    echo -e "${RED}Removing ALL optimizations and restoring defaults...${NC}"
    
    backup_configs
    
    # Remove TC optimizations first
    tc_remove_optimizations
    
    # Remove sysctl optimizations
    local sysctl_keys=(
        "vm.swappiness" "vm.dirty_ratio" "vm.dirty_background_ratio"
        "vm.dirty_expire_centisecs" "vm.dirty_writeback_centisecs"
        "vm.vfs_cache_pressure" "vm.min_free_kbytes" "vm.max_map_count"
        "net.core.rmem_max" "net.core.wmem_max" "net.core.rmem_default"
        "net.core.wmem_default" "net.core.netdev_max_backlog"
        "net.core.netdev_budget" "net.core.somaxconn" "net.core.optmem_max"
        "net.ipv4.tcp_rmem" "net.ipv4.tcp_wmem" "net.ipv4.tcp_congestion_control"
        "net.core.default_qdisc" "net.ipv4.tcp_fastopen" "net.ipv4.tcp_slow_start_after_idle"
        "net.ipv4.tcp_low_latency" "net.ipv4.tcp_no_metrics_save" "net.ipv4.tcp_timestamps"
        "net.ipv4.tcp_sack" "net.ipv4.tcp_dsack" "net.ipv4.tcp_fack"
        "net.ipv4.tcp_max_syn_backlog" "net.ipv4.tcp_max_tw_buckets" "net.ipv4.tcp_tw_reuse"
        "net.ipv4.tcp_fin_timeout" "net.ipv4.tcp_keepalive_time" "net.ipv4.tcp_keepalive_intvl"
        "net.ipv4.tcp_keepalive_probes" "net.ipv4.tcp_notsent_lowat" "net.ipv4.tcp_syncookies"
        "net.ipv4.udp_rmem_min" "net.ipv4.udp_wmem_min" "fs.file-max" "fs.nr_open"
    )

    for key in "${sysctl_keys[@]}"; do
        sed -i "/^\s*${key}\s*=/d" "$SYSCTL_CONF" 2>/dev/null
    done

    local limit_keys=(
        "* soft nproc" "* hard nproc" "* soft nofile" "* hard nofile"
        "root soft nproc" "root hard nproc" "root soft nofile" "root hard nofile"
    )

    for key in "${limit_keys[@]}"; do
        sed -i "/^$key/d" "$LIMITS_CONF" 2>/dev/null
    done

    # Reload settings
    sysctl -p > /dev/null 2>&1
    sysctl --system > /dev/null 2>&1

    # Reset to defaults
    echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    echo "fq_codel" > /proc/sys/net/core/default_qdisc 2>/dev/null

    echo -e "${GREEN}ALL optimizations removed!${NC}"
    echo -e "${YELLOW}Please restart your system for all changes to take effect.${NC}"
}

# =============================================================================
# CONTROL FUNCTIONS
# =============================================================================

show_current_settings() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                   CURRENT SYSTEM SETTINGS                     "
    echo "================================================================"
    echo -e "${NC}"
    
    echo -e "${YELLOW}NETWORK SETTINGS:${NC}"
    echo -e "  Congestion Control: ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'default')${NC}"
    echo -e "  Queue Discipline:   ${GREEN}$(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'default')${NC}"
    echo -e "  TCP Low Latency:    ${GREEN}$(sysctl -n net.ipv4.tcp_low_latency 2>/dev/null || echo '0')${NC}"
    
    echo -e "\n${YELLOW}MEMORY SETTINGS:${NC}"
    echo -e "  Swappiness:         ${GREEN}$(sysctl -n vm.swappiness 2>/dev/null || echo '60')${NC}"
    echo -e "  Dirty Ratio:        ${GREEN}$(sysctl -n vm.dirty_ratio 2>/dev/null || echo '20')${NC}"
    echo -e "  Dirty Background:   ${GREEN}$(sysctl -n vm.dirty_background_ratio 2>/dev/null || echo '10')${NC}"
    
    echo -e "\n${YELLOW}TRAFFIC CONTROL:${NC}"
    for IFACE in $(ls /sys/class/net/ | grep -v lo); do
        if [ -d "/sys/class/net/$IFACE" ]; then
            QDISC=$(tc qdisc show dev "$IFACE" 2>/dev/null | head -1 || echo "None")
            echo -e "  ${WHITE}$IFACE: ${BLUE}$QDISC${NC}"
        fi
    done
    
    echo -e "\n${YELLOW}STARTUP STATUS:${NC}"
    check_startup_status
}

edit_sysctl_live() {
    echo -e "${YELLOW}Live Sysctl Editor - Current Values:${NC}"
    echo -e "${GREEN}Format: key = value${NC}"
    echo -e "${YELLOW}Enter 'quit' to exit, 'list' to show current${NC}"
    
    while true; do
        echo ""
        echo -e "${CYAN}Enter setting to change:${NC}"
        read -r input
        
        case "$input" in
            quit|exit)
                break
                ;;
            list|show)
                show_current_settings
                ;;
            "")
                continue
                ;;
            *=*)
                key=$(echo "$input" | cut -d'=' -f1 | xargs)
                value=$(echo "$input" | cut -d'=' -f2 | xargs)
                
                if [[ ! "$key" =~ ^[a-zA-Z0-9_.]+$ ]]; then
                    echo -e "${RED}Invalid key format${NC}"
                    continue
                fi
                
                if sysctl -w "$key=$value" 2>/dev/null; then
                    echo -e "${GREEN}Live setting applied: $key = $value${NC}"
                    
                    if grep -q "^$key" "$SYSCTL_CONF" 2>/dev/null; then
                        sed -i "s|^$key.*|$key = $value|" "$SYSCTL_CONF"
                    else
                        echo "$key = $value" >> "$SYSCTL_CONF"
                    fi
                else
                    echo -e "${RED}Failed to apply setting${NC}"
                fi
                ;;
            *)
                current=$(sysctl -n "$input" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Current: $input = $current${NC}"
                else
                    echo -e "${RED}Invalid setting: $input${NC}"
                fi
                ;;
        esac
    done
}

apply_settings_immediately() {
    echo -e "${GREEN}Applying all settings immediately...${NC}"
    
    if sysctl -p > /dev/null 2>&1; then
        echo -e "${GREEN}Sysctl settings applied${NC}"
    else
        echo -e "${RED}Error applying sysctl settings${NC}"
        return 1
    fi
    
    echo -e "${GREEN}All settings applied successfully${NC}"
}

test_network_performance() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                   NETWORK PERFORMANCE TEST                    "
    echo "================================================================"
    echo -e "${NC}"
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}No network interface detected${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Interface: ${GREEN}$INTERFACE${NC}"
    
    if command -v ping >/dev/null 2>&1; then
        echo -e "\n${YELLOW}PING TEST (Google DNS):${NC}"
        ping -c 4 -W 2 8.8.8.8 2>/dev/null | grep -E "packets|rtt|loss" || echo -e "${RED}Ping test failed${NC}"
    else
        echo -e "${YELLOW}ping command not available${NC}"
    fi
    
    if command -v tc >/dev/null 2>&1; then
        echo -e "\n${YELLOW}TRAFFIC CONTROL STATUS:${NC}"
        tc qdisc show dev "$INTERFACE"
    fi
}

show_sysctl_file() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                   SYSCTL.CONF CONTENTS                        "
    echo "================================================================"
    echo -e "${NC}"
    
    if [ -f "$SYSCTL_CONF" ]; then
        if [ -s "$SYSCTL_CONF" ]; then
            grep -v '^#' "$SYSCTL_CONF" | grep -v '^$' | while read line; do
                echo -e "  ${WHITE}$line${NC}"
            done
            
            total_lines=$(grep -v '^#' "$SYSCTL_CONF" | grep -v '^$' | wc -l)
            echo -e "\n${YELLOW}Total active settings: ${GREEN}$total_lines${NC}"
        else
            echo -e "${YELLOW}sysctl.conf is empty${NC}"
        fi
    else
        echo -e "${RED}sysctl.conf not found${NC}"
    fi
}

edit_sysctl_conf() {
    echo -e "${YELLOW}Opening sysctl.conf for editing...${NC}"
    
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    else
        echo -e "${RED}No text editor found. Install nano, vim, or vi.${NC}"
        return 1
    fi
    
    if $editor "$SYSCTL_CONF"; then
        echo -e "${GREEN}File edited successfully${NC}"
        
        echo -e "${YELLOW}Apply changes now? [y/N]: ${NC}"
        read -r apply_choice
        if [[ "$apply_choice" =~ [yY] ]]; then
            apply_settings_immediately
        fi
    else
        echo -e "${RED}Error editing file${NC}"
    fi
}

# =============================================================================
# MENU SYSTEM
# =============================================================================

show_main_menu() {
    clear
    echo -e "${CYAN}"
    echo "================================================================"
    echo "           NETWORK OPTIMIZER TOOL - MAIN MENU                  "
    echo "================================================================"
    echo
    echo -e "${GREEN}SYSCTL OPTIMIZATIONS:${CYAN}"
    echo -e "  ${GREEN}1${NC}${WHITE}. Gaming (Low Latency)${CYAN}"
    echo -e "  ${GREEN}2${NC}${WHITE}. Streaming (High Throughput)${CYAN}"
    echo -e "  ${GREEN}3${NC}${WHITE}. General Purpose (Balanced)${CYAN}"
    echo -e "  ${GREEN}4${NC}${WHITE}. Competitive Gaming (Extreme)${CYAN}"
    echo
    echo -e "${BLUE}TC OPTIMIZATIONS:${CYAN}"
    echo -e "  ${GREEN}5${NC}${WHITE}. TC optimizations${CYAN}"
    echo -e "  ${GREEN}8${NC}${WHITE}. NetEM Testing${CYAN}"
    echo
    echo -e "${YELLOW}TOOLS & MANAGEMENT:${CYAN}"
    echo -e "  ${GREEN}9${NC}${WHITE}. Show Current Status${CYAN}"
    echo -e "  ${GREEN}10${NC}${WHITE}. Backup Configurations${CYAN}"
    echo
    echo -e "${GREEN}VIEW & MONITOR:${CYAN}"
    echo -e "  ${GREEN}11${NC}${WHITE}. Show Current Settings${CYAN}"
    echo -e "  ${GREEN}12${NC}${WHITE}. Show Sysctl.conf File${CYAN}"
    echo -e "  ${GREEN}13${NC}${WHITE}. Test Network Performance${CYAN}"
    echo
    echo -e "${BLUE}EDIT & CONFIGURE:${CYAN}"
    echo -e "  ${GREEN}14${NC}${WHITE}. Live Sysctl Editor${CYAN}"
    echo -e "  ${GREEN}15${NC}${WHITE}. Edit Sysctl.conf (Text Editor)${CYAN}"
    echo -e "  ${GREEN}16${NC}${WHITE}. Apply Settings Immediately${CYAN}"
    echo
    echo -e "${PURPLE}MAINTENANCE:${CYAN}"
    echo -e "  ${GREEN}17${NC}${WHITE}. Backup Configurations${CYAN}"
    echo -e "  ${GREEN}18${NC}${WHITE}. Remove All Optimizations${CYAN}"
    echo -e "  ${GREEN}19${NC}${WHITE}. stop system logging${CYAN}"
    echo -e "  ${GREEN}20${NC}${WHITE}. Restoring system logging${CYAN}"
    echo -e "  ${GREEN}21${NC}${WHITE}. Remove bloatware${CYAN}"
    echo
    echo -e "  ${GREEN}0${NC}${WHITE}. Exit${CYAN}"
    echo "================================================================"
    echo -e "${NC}"
}
main_menu() {
    while true; do
        show_main_menu
        echo -e "${YELLOW}Select option: ${NC}"
        read -r choice
        
        case $choice in
            1) apply_gaming_optimizations ;;
            2) apply_streaming_optimizations ;;
            3) apply_general_optimizations ;;
            4) apply_competitive_gaming_optimizations ;;
            5) tc_optimize;;
            8) handle_netem_menu ;;
            9) show_current_settings ;;
            10) backup_configs ;;
            11) show_current_settings ;;
            12) show_sysctl_file ;;
            13) test_network_performance ;;
            14) edit_sysctl_live ;;
            15) edit_sysctl_conf ;;
            16) apply_settings_immediately ;;
            17) backup_configs ;;
        19)
            echo -e "\033[1;33mWarning:\033[0m Masking journald and rsyslog will stop all system logging!"
            read -rp "Are you sure you want to continue? (yes/no): " confirm
            if [[ "$confirm" == "yes" ]]; then
                echo -e "\033[1;31mStopping and masking journald + rsyslog services...\033[0m"

                # Stop and mask journald
                sudo systemctl stop systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket 2>/dev/null
                sudo systemctl mask systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket 2>/dev/null

                # Stop and mask rsyslog
                sudo systemctl stop rsyslog.service 2>/dev/null
                sudo systemctl mask rsyslog.service 2>/dev/null

                echo -e "\033[1;32mJournald and rsyslog have been stopped and masked.\033[0m"
            else
                echo -e "\033[1;34mOperation canceled.\033[0m"
            fi
            ;;
        20)
            echo -e "\033[1;33mRestoring journald and rsyslog services...\033[0m"

            # Unmask and enable journald
            sudo systemctl unmask systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket 2>/dev/null
            sudo systemctl enable systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket 2>/dev/null
            sudo systemctl start systemd-journald.service 2>/dev/null

            # Unmask and enable rsyslog
            sudo systemctl unmask rsyslog.service 2>/dev/null
            sudo systemctl enable rsyslog.service 2>/dev/null
            sudo systemctl start rsyslog.service 2>/dev/null

            echo -e "\033[1;32mJournald and rsyslog have been unmasked and restarted.\033[0m"
            ;;

            18) remove_all_optimizations ;;
            21) bloatware ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option! Please select 0-12${NC}"
                ;;
        esac
        
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read -r
    done
}
show_netem_menu() {
    clear
    echo -e "${PURPLE}"
    echo "================================================================"
    echo "                   NETEM TESTING MENU                          "
    echo "================================================================"
    echo -e "${WHITE}Simulate network conditions:${PURPLE}                       "
    echo "                                                                "
    echo -e "  ${GREEN}1${NC}${WHITE}. Gaming Latency (10ms +-2ms)${PURPLE}                  "
    echo -e "  ${GREEN}2${NC}${WHITE}. High Packet Loss (5% loss)${PURPLE}                   "
    echo -e "  ${GREEN}3${NC}${WHITE}. Wireless Conditions (20ms + 2% loss)${PURPLE}         "
    echo -e "  ${GREEN}4${NC}${WHITE}. Satellite Latency (600ms + 1% loss)${PURPLE}         "
    echo -e "  ${GREEN}5${NC}${WHITE}. Internet Typical (30ms + 0.5% loss)${PURPLE}          "
    echo "                                                                "
    echo -e "  ${GREEN}0${NC}${WHITE}. Back to Main Menu${PURPLE}                         "
    echo "                                                                "
    echo "================================================================"
    echo -e "${NC}"
}



handle_netem_menu() {
    while true; do
        show_netem_menu
        echo -e "${YELLOW}Select test condition [0-5]: ${NC}"
        read -r choice
        
        case $choice in
            1) apply_netem_testing "gaming-latency" ;;
            2) apply_netem_testing "high-loss" ;;
            3) apply_netem_testing "wireless" ;;
            4) apply_netem_testing "satellite" ;;
            5) apply_netem_testing "internet-typical" ;;
            0) break ;;
            *) echo -e "${RED}Invalid option! Please select 0-5${NC}" ;;
        esac
        
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read -r
    done
}



# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root user"
    else
        print_error "This script requires root privileges. Please run with sudo."
        exit 1
    fi
}

# Update system
update_system() {
    print_status "Updating system packages..."
    apt update && apt upgrade -y
    print_success "System updated successfully"
}

# Remove multipath tools
remove_multipath() {
    print_status "Removing multipath tools..."
    systemctl stop multipathd 2>/dev/null
    systemctl disable multipathd 2>/dev/null
    apt remove -y --purge multipath-tools 2>/dev/null
    print_success "Multipath tools removed"
}

# Remove snapd
remove_snapd() {
    print_status "Removing snapd..."
    systemctl stop snapd 2>/dev/null
    systemctl disable snapd 2>/dev/null
    apt remove -y --purge snapd snap-confine 2>/dev/null
    rm -rf /var/snap /snap /root/snap
    print_success "Snapd removed"
}

# Remove fwupd
remove_fwupd() {
    print_status "Removing fwupd..."
    apt remove -y --purge fwupd 2>/dev/null
    print_success "Fwupd removed"
}

# Remove desktop components
remove_desktop_components() {
    print_status "Removing desktop components..."
    local desktop_packages=(
        ubuntu-desktop
        gnome*
        gdm3
        xorg
        lightdm
        plymouth
        plymouth-theme-ubuntu-text
    )
    
    for pkg in "${desktop_packages[@]}"; do
        if dpkg -l | grep -q "$pkg"; then
            apt remove -y --purge "$pkg" 2>/dev/null
        fi
    done
    print_success "Desktop components removed"
}

# Remove office software
remove_office_software() {
    print_status "Removing office software..."
    local office_packages=(
        libreoffice*
        abiword
        gnumeric
    )
    
    for pkg in "${office_packages[@]}"; do
        apt remove -y --purge "$pkg" 2>/dev/null
    done
    print_success "Office software removed"
}

# Remove games
remove_games() {
    print_status "Removing games..."
    local game_packages=(
        gnome-games*
        sudoku
        mines
        aisleriot
        mahjongg
    )
    
    for pkg in "${game_packages[@]}"; do
        apt remove -y --purge "$pkg" 2>/dev/null
    done
    print_success "Games removed"
}

# Remove multimedia packages
remove_multimedia() {
    print_status "Removing multimedia packages..."
    local media_packages=(
        rhythmbox
        shotwell
        cheese
        vlc*
        totem
        brasero
    )
    
    for pkg in "${media_packages[@]}"; do
        apt remove -y --purge "$pkg" 2>/dev/null
    done
    print_success "Multimedia packages removed"
}

# Remove printing services
remove_printing() {
    print_status "Removing printing services..."
    local printing_packages=(
        cups*
        printer-driver*
        hplip
    )
    
    for pkg in "${printing_packages[@]}"; do
        systemctl stop "$pkg" 2>/dev/null
        systemctl disable "$pkg" 2>/dev/null
        apt remove -y --purge "$pkg" 2>/dev/null
    done
    print_success "Printing services removed"
}

# Remove bluetooth
remove_bluetooth() {
    print_status "Removing bluetooth..."
    systemctl stop bluetooth 2>/dev/null
    systemctl disable bluetooth 2>/dev/null
    apt remove -y --purge bluez* 2>/dev/null
    print_success "Bluetooth removed"
}

# Remove audio services
remove_audio() {
    print_status "Removing audio services..."
    local audio_packages=(
        pulseaudio*
        alsa*
        pipewire*
    )
    
    for pkg in "${audio_packages[@]}"; do
        apt remove -y --purge "$pkg" 2>/dev/null
    done
    print_success "Audio services removed"
}

# Remove unnecessary services
remove_unnecessary_services() {
    print_status "Removing unnecessary services..."
    local services=(
        whoopsie
        popularity-contest
        apport
        avahi-daemon
        modemmanager
        network-manager
        cups-browsed
    )
    
    for service in "${services[@]}"; do
        systemctl stop "$service" 2>/dev/null
        systemctl disable "$service" 2>/dev/null
        systemctl mask "$service" 2>/dev/null
    done
    print_success "Unnecessary services disabled"
}

# Clean package cache
clean_system() {
    print_status "Cleaning system..."
    apt autoremove -y --purge
    apt autoclean
    apt clean
    rm -rf /var/cache/apt/*
    print_success "System cleaned"
}

# Show installed bloatware
show_bloatware() {
    print_status "Scanning for common bloatware packages..."
    
    local bloatware_list=(
        "snapd" "fwupd" "multipath-tools"
        "ubuntu-desktop" "gnome" "libreoffice" "cups"
        "bluetooth" "pulseaudio" "whoopsie" "popularity-contest"
    )
    
    echo -e "\n${YELLOW}Found bloatware packages:${NC}"
    for pkg in "${bloatware_list[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg"; then
            echo -e "  ${RED}✓${NC} $pkg"
        fi
    done
    
    echo -e "\n${YELLOW}Active unnecessary services:${NC}"
    local unnecessary_services=(
        "multipathd" "snapd" "cups"
        "bluetooth" "whoopsie" "avahi-daemon" "modemmanager"
    )
    
    for service in "${unnecessary_services[@]}"; do
        if systemctl is-active "$service" 2>/dev/null | grep -q "active"; then
            echo -e "  ${RED}✓${NC} $service"
        fi
    done
}

# Comprehensive bloatware removal (without containerd)
remove_all_bloatware() {
    print_warning "Starting comprehensive bloatware removal..."
    
    remove_multipath
    remove_snapd
    remove_fwupd
    remove_desktop_components
    remove_office_software
    remove_games
    remove_multimedia
    remove_printing
    remove_bluetooth
    remove_audio
    remove_unnecessary_services
    clean_system
    
    print_success "All bloatware removed successfully!"
}

# Interactive menu
bloatware() {
    while true; do
        clear
        echo -e "${BLUE}"
        echo "╔══════════════════════════════════════╗"
        echo "║      Ubuntu Server Bloatware         ║"
        echo "║            Removal Tool              ║"
        echo "╚══════════════════════════════════════╝"
        echo -e "${NC}"
        echo -e "${YELLOW}Select an option:${NC}"
        echo " 1) Show installed bloatware"
        echo " 2) Remove multipath tools"
        echo " 3) Remove snapd"
        echo " 4) Remove fwupd"
        echo " 5) Remove desktop components"
        echo " 6) Remove office software"
        echo " 7) Remove games"
        echo " 8) Remove multimedia packages"
        echo " 9) Remove printing services"
        echo "10) Remove bluetooth"
        echo "11) Remove audio services"
        echo "12) Remove unnecessary services"
        echo "13) Clean system (autoremove)"
        echo "14) Remove ALL bloatware (Comprehensive)"
        echo "15) Update system"
        echo "16) Exit"
        echo
        
        read -p "Enter your choice default[14]: " choice
    choice=${choice:-14}
        
        case $choice in
            1)
                show_bloatware
                ;;
            2)
                remove_multipath
                ;;
            3)
                remove_snapd
                ;;
            4)
                remove_fwupd
                ;;
            5)
                remove_desktop_components
                ;;
            6)
                remove_office_software
                ;;
            7)
                remove_games
                ;;
            8)
                remove_multimedia
                ;;
            9)
                remove_printing
                ;;
            10)
                remove_bluetooth
                ;;
            11)
                remove_audio
                ;;
            12)
                remove_unnecessary_services
                ;;
            13)
                clean_system
                ;;
            14)
                echo -e "${RED}WARNING: This will remove ALL detected bloatware!${NC}"
                read -p "Are you sure? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    remove_all_bloatware
                else
                    print_status "Comprehensive removal cancelled."
                fi
                ;;
            15)
                update_system
                ;;
            16)
                print_status "Exiting..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please try again."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# =============================================================================
# INITIALIZATION
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo $0${NC}"
    exit 1
fi

# Check required commands
for cmd in sysctl tc ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}Error: $cmd is required but not installed.${NC}"
        exit 1
    fi
done

create_backup_dir
echo -e "${GREEN}Network Optimizer Tool Started${NC}"
echo -e "${YELLOW}Running as root: $(whoami)${NC}"
main_menu
