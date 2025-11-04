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

create_tc_optimizer_script() {
    local category="$1"
    
    echo -e "${GREEN}Creating TC optimizer script for $category mode...${NC}"
    
    # Create the script with proper error handling
    cat > "$TC_SCRIPT_PATH" << EOF
#!/bin/bash
# TC Optimizer - $category Mode
# Runs at startup via cron



# Wait for network to be ready
sleep 30

INTERFACE=\$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print \$5; exit}')

if [ -z "\$INTERFACE" ]; then
    exit 1
fi



# Clean existing rules
tc qdisc del dev "\$INTERFACE" root 2>/dev/null
tc qdisc del dev "\$INTERFACE" ingress 2>/dev/null

# Apply $category optimization
EOF

    # Add the specific category configuration
    case "$category" in
        "gaming")
            cat >> "$TC_SCRIPT_PATH" << 'GAMING_EOF'
echo 256 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
ethtool -A "$INTERFACE" rx off tx off 2>/dev/null
if tc qdisc add dev "$INTERFACE" root cake bandwidth 1000mbit besteffort dual-dsthost nat nowash no-ack-filter 2>/dev/null; then
   
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 1000 flows 1024 target 2ms interval 20ms noecn 2>/dev/null; then
   
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
   
fi
GAMING_EOF
            ;;
        "high-loss")
            cat >> "$TC_SCRIPT_PATH" << 'HIGHLOSS_EOF'
echo 4000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null
if tc qdisc add dev "$INTERFACE" root cake bandwidth 850mbit besteffort ack-filter nat nowash 2>/dev/null; then
  
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 30000 flows 4096 ecn ce-threshold 1ms 2>/dev/null; then

else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
   
fi
HIGHLOSS_EOF
            ;;
        "general")
            cat >> "$TC_SCRIPT_PATH" << 'GENERAL_EOF'
echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
if tc qdisc add dev "$INTERFACE" root cake bandwidth 1000mbit besteffort nat nowash 2>/dev/null; then

elif tc qdisc add dev "$INTERFACE" root fq_codel ecn ce-threshold 4ms 2>/dev/null; then
 
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast

fi
GENERAL_EOF
            ;;
    esac

    # Add the footer
    cat >> "$TC_SCRIPT_PATH" << 'EOF'



exit 0
EOF

    # Make the script executable
    chmod +x "$TC_SCRIPT_PATH"
    
    # Verify the script was created
    if [ -f "$TC_SCRIPT_PATH" ] && [ -x "$TC_SCRIPT_PATH" ]; then
        echo -e "${GREEN}✓ TC optimizer script created at: $TC_SCRIPT_PATH${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to create TC optimizer script${NC}"
        return 1
    fi
}

# Check if optimizations are enabled at startup
check_startup_status() {
    echo -e "${YELLOW}Checking startup status...${NC}"
    
    if crontab -l 2>/dev/null | grep -q "$TC_SCRIPT_NAME"; then
        echo -e "${GREEN}✓ TC optimizations are enabled at startup${NC}"
        echo -e "${WHITE}Cron entry:${NC}"
        crontab -l | grep "$TC_SCRIPT_NAME"
        return 0
    else
        echo -e "${YELLOW}⚠ TC optimizations are NOT enabled at startup${NC}"
        return 1
    fi
}

# Enable optimizations at system startup
enable_startup_optimizations() {
    local category="${1:-general}"
    
    echo -e "${YELLOW}Enabling TC optimizations at startup...${NC}"
    
    # Create the TC optimizer script with the selected category
    if ! create_tc_optimizer_script "$category"; then
        echo -e "${RED}Failed to create TC script${NC}"
        return 1
    fi
    
    # Create a temporary crontab
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$TC_SCRIPT_NAME" > "$temp_cron"
    
    # Add the startup optimization entry
    echo "@reboot sleep 30 && $TC_SCRIPT_PATH" >> "$temp_cron"
    
    # Install the new crontab
    if crontab "$temp_cron"; then
        rm -f "$temp_cron"
        echo -e "${GREEN}✓ Startup optimizations enabled for category: $category${NC}"
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
    local category="$1"
    
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
            enable_startup_optimizations "$category"
            ;;
        [Nn]*)
            echo -e "${YELLOW}TC optimizations will run only once (current session)${NC}"
            ;;
        [Ss]*)
            check_startup_status
            echo ""
            echo -n "Press Enter to continue..."
            read -r
            ask_startup_config "$category"
            ;;
        [Dd]*)
            disable_startup_optimizations
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ask_startup_config "$category"
            ;;
    esac
}

# Clean up TC rules
cleanup_tc() {
    local interface="$1"
    echo -e "${YELLOW}Cleaning existing TC rules...${NC}"
    tc qdisc del dev "$interface" root 2>/dev/null
    tc qdisc del dev "$interface" ingress 2>/dev/null
    echo 1000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
}

# Enhanced TC optimization functions
apply_tc_gaming_optimizations() {
    local interface="$1"
    echo -e "${GREEN}Applying GAMING optimizations (Ultra Low Latency)...${NC}"
    
    # Set optimal queue length for low latency
    echo 256 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
    
    # Disable Ethernet flow control for lower latency
    ethtool -A "$interface" rx off tx off 2>/dev/null
    
    if tc qdisc add dev "$interface" root cake bandwidth 1000mbit besteffort dual-dsthost nat nowash no-ack-filter 2>/dev/null; then
        echo -e "${GREEN}Using CAKE (Optimal for gaming)${NC}"
    elif tc qdisc add dev "$interface" root fq_codel limit 1000 flows 1024 target 2ms interval 20ms noecn 2>/dev/null; then
        echo -e "${GREEN}Using FQ_Codel (Excellent for gaming)${NC}"
    elif tc qdisc add dev "$interface" root pfifo_fast 2>/dev/null; then
        echo -e "${YELLOW}Using PFIFO_Fast (Fallback)${NC}"
    else
        echo -e "${RED}Failed to apply any queue discipline${NC}"
        return 1
    fi
    
    # Verify the qdisc was applied
    if tc qdisc show dev "$interface" | grep -q "cake\|fq_codel\|pfifo"; then
        echo -e "${GREEN}✓ Gaming optimizations applied successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to verify queue discipline${NC}"
        return 1
    fi
}

apply_tc_high_loss_optimizations() {
    local interface="$1"
    echo -e "${YELLOW}Applying HIGH PACKET LOSS optimizations...${NC}"
    
    # Larger buffers for loss recovery
    echo 4000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
    
    # Enable ECN if supported
    echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null
    
    if tc qdisc add dev "$interface" root cake bandwidth 850mbit besteffort ack-filter nat nowash 2>/dev/null; then
        echo -e "${GREEN}Using CAKE with advanced loss compensation${NC}"
    elif tc qdisc add dev "$interface" root fq_codel limit 30000 flows 4096 ecn ce-threshold 1ms 2>/dev/null; then
        echo -e "${GREEN}Using FQ_Codel with enhanced loss tolerance${NC}"
    elif tc qdisc add dev "$interface" root pfifo_fast 2>/dev/null; then
        echo -e "${YELLOW}Using PFIFO_Fast with larger buffers${NC}"
    else
        echo -e "${RED}Failed to apply any queue discipline${NC}"
        return 1
    fi
    
    # Verify application
    if tc qdisc show dev "$interface" | grep -q "cake\|fq_codel\|pfifo"; then
        echo -e "${GREEN}✓ High-loss optimizations applied successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to verify queue discipline${NC}"
        return 1
    fi
}

apply_tc_general_optimizations() {
    local interface="$1"
    echo -e "${BLUE}Applying GENERAL PURPOSE optimizations...${NC}"
    
    # Balanced queue length
    echo 1000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
    
    if tc qdisc add dev "$interface" root cake bandwidth 1000mbit besteffort nat nowash 2>/dev/null; then
        echo -e "${GREEN}Using CAKE (Optimal all-around)${NC}"
    elif tc qdisc add dev "$interface" root fq_codel ecn ce-threshold 4ms 2>/dev/null; then
        echo -e "${GREEN}Using FQ_Codel (Excellent balanced)${NC}"
    elif tc qdisc add dev "$interface" root pfifo_fast 2>/dev/null; then
        echo -e "${YELLOW}Using PFIFO_Fast (Compatible)${NC}"
    else
        echo -e "${RED}Failed to apply any queue discipline${NC}"
        return 1
    fi
    
    # Verify application
    if tc qdisc show dev "$interface" | grep -q "cake\|fq_codel\|pfifo"; then
        echo -e "${GREEN}✓ General optimizations applied successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to verify queue discipline${NC}"
        return 1
    fi
}

# Main TC optimization function
tc_optimize_by_category() {
    local category="${1:-general}"
    local auto_mode="${2:-false}"
    
    echo "=============================================="
    echo "        TC OPTIMIZER - $category MODE"
    echo "=============================================="
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}ERROR: Could not detect network interface${NC}"
        return 1
    fi
    
    echo -e "${WHITE}Detected interface: ${GREEN}$INTERFACE${NC}"
    
    cleanup_tc "$INTERFACE"
    
    echo -e "${YELLOW}Applying $category optimizations...${NC}"
    
    case "$category" in
        "gaming")
            apply_tc_gaming_optimizations "$INTERFACE"
            ;;
        "high-loss")
            apply_tc_high_loss_optimizations "$INTERFACE"
            ;;
        "general")
            apply_tc_general_optimizations "$INTERFACE"
            ;;
        *)
            echo -e "${RED}Unknown category: $category${NC}"
            return 1
            ;;
    esac
    
    local result=$?
    
    echo ""
    echo "=============================================="
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}$category OPTIMIZATION COMPLETE${NC}"
        echo -e "${WHITE}Interface: ${GREEN}$INTERFACE${NC}"
        echo -e "${WHITE}Queue Discipline: ${GREEN}$(tc qdisc show dev "$INTERFACE" | head -1 | awk '{print $2}')${NC}"
    else
        echo -e "${RED}$category OPTIMIZATION FAILED${NC}"
    fi
    echo "=============================================="
    
    # Only ask about startup if not in auto mode and optimization was successful
    if [ "$auto_mode" = "false" ] && [ $result -eq 0 ]; then
        ask_startup_config "$category"
    fi
    
    return $result
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
    echo -e "  ${GREEN}5${NC}${WHITE}. TC Gaming Mode${CYAN}"
    echo -e "  ${GREEN}6${NC}${WHITE}. TC High Loss Mode${CYAN}"
    echo -e "  ${GREEN}7${NC}${WHITE}. TC General Mode${CYAN}"
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
    echo
    echo -e "  ${GREEN}0${NC}${WHITE}. Exit${CYAN}"
    echo "================================================================"
    echo -e "${NC}"
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
            5) tc_optimize_by_category "gaming" ;;
            6) tc_optimize_by_category "high-loss" ;;
            7) tc_optimize_by_category "general" ;;
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
            18) remove_all_optimizations ;;
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
