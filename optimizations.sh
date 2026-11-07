#!/bin/bash

# =============================================================================
# CONFIGURATION
# =============================================================================
SYSCTL_CONF="/etc/sysctl.conf"
LIMITS_CONF="/etc/security/limits.conf"
SYSTEMD_LIMITS_DIR="/etc/systemd/system.conf.d"
SYSTEMD_LIMITS_CONF="$SYSTEMD_LIMITS_DIR/99-optimizer-limits.conf"
BACKUP_DIR="/root/optimizer_backups"
TC_SCRIPT_NAME="tc_optimizer.sh"
TC_SCRIPT_PATH="/root/$TC_SCRIPT_NAME"

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
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    
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

enable_kernel_modules() {
    modprobe tcp_bbr 2>/dev/null || true
    modprobe sch_fq 2>/dev/null || true
    modprobe sch_fq_codel 2>/dev/null || true
    modprobe sch_cake 2>/dev/null || true
}

reload_sysctl() {
    enable_kernel_modules
    echo -e "${GREEN}Reloading sysctl settings...${NC}"
    
    # تضمین خوانده شدن فایل در اوبونتو 26 و سیستم‌های جدید systemd
    mkdir -p /etc/sysctl.d
    if [ "$SYSCTL_CONF" = "/etc/sysctl.conf" ] && [ ! -e "/etc/sysctl.d/99-sysctl.conf" ]; then
        ln -sf /etc/sysctl.conf /etc/sysctl.d/99-sysctl.conf
    fi

    if sysctl --system > /dev/null 2>&1; then
        echo -e "${GREEN}Sysctl settings reloaded successfully (Ubuntu 26 compatible)${NC}"
    else
        sysctl -p "$SYSCTL_CONF" > /dev/null 2>&1 || true
        echo -e "${YELLOW}Note: Some kernel parameters were skipped${NC}"
    fi
}

# Safely handles keys with dots
update_config() {
    local file="$1"
    local key="$2"
    local value="$3"
    local escaped_key="${key//./\\.}"
    
    if [ ! -f "$file" ]; then
        touch "$file"
    fi
    
    if grep -q "^[[:space:]]*${escaped_key}[[:space:]]*=" "$file"; then
        local current_value
        current_value=$(grep "^[[:space:]]*${escaped_key}[[:space:]]*=" "$file" | head -1 | sed 's/.*=[[:space:]]*//')
        if [[ "$current_value" == "$value" ]]; then
            echo -e "${YELLOW}Setting $key already configured ($value)${NC}"
        else
            sed -i "s|^[[:space:]]*${escaped_key}[[:space:]]*=.*|$key = $value|" "$file"
            echo -e "${GREEN}Updated $key to $value${NC}"
        fi
    else
        echo "$key = $value" >> "$file"
        echo -e "${GREEN}Added $key = $value${NC}"
    fi
}

# Safely updates both /etc/security/limits.conf AND systemd service limits
apply_system_limits() {
    local nofile_val="$1"
    local nproc_val="$2"

    if [ ! -f "$LIMITS_CONF" ]; then
        touch "$LIMITS_CONF"
    fi

    # Remove old optimizer entries first to prevent duplicates and regex asterisk bugs
    sed -i '/^[[:space:]]*\*[[:space:]]\+\(soft\|hard\)[[:space:]]\+\(nofile\|nproc\)/d' "$LIMITS_CONF" 2>/dev/null
    sed -i '/^[[:space:]]*root[[:space:]]\+\(soft\|hard\)[[:space:]]\+\(nofile\|nproc\)/d' "$LIMITS_CONF" 2>/dev/null

    cat >> "$LIMITS_CONF" << EOF
* soft nproc $nproc_val
* hard nproc $nproc_val
* soft nofile $nofile_val
* hard nofile $nofile_val
root soft nproc $nproc_val
root hard nproc $nproc_val
root soft nofile $nofile_val
root hard nofile $nofile_val
EOF
    echo -e "${GREEN}Updated /etc/security/limits.conf (nofile=$nofile_val, nproc=$nproc_val)${NC}"

    # Apply to systemd so services like HAProxy/Xray also get unlimited/high FDs
    mkdir -p "$SYSTEMD_LIMITS_DIR"
    cat > "$SYSTEMD_LIMITS_CONF" << EOF
[Manager]
DefaultLimitNOFILE=$nofile_val
DefaultLimitNPROC=$nproc_val
EOF
    systemctl daemon-reexec 2>/dev/null || true
    echo -e "${GREEN}Updated systemd service limits (DefaultLimitNOFILE=$nofile_val)${NC}"
}

# Cleans previous optimizer keys so switching profiles never leaves conflicting flags
cleanup_previous_sysctl_keys() {
    echo -e "${YELLOW}Cleaning up previous profile settings to prevent conflicts...${NC}"
    local sysctl_keys=(
        "vm.swappiness" "vm.dirty_ratio" "vm.dirty_background_ratio"
        "vm.dirty_expire_centisecs" "vm.dirty_writeback_centisecs"
        "vm.vfs_cache_pressure" "vm.min_free_kbytes" "vm.max_map_count" "vm.overcommit_memory"
        "net.core.rmem_max" "net.core.wmem_max" "net.core.rmem_default"
        "net.core.wmem_default" "net.core.netdev_max_backlog"
        "net.core.netdev_budget" "net.core.netdev_budget_usecs" "net.core.somaxconn" "net.core.optmem_max"
        "net.ipv4.tcp_mem" "net.ipv4.tcp_rmem" "net.ipv4.tcp_wmem" "net.ipv4.tcp_congestion_control"
        "net.core.default_qdisc" "net.ipv4.tcp_fastopen" "net.ipv4.tcp_slow_start_after_idle"
        "net.ipv4.tcp_low_latency" "net.ipv4.tcp_no_metrics_save" "net.ipv4.tcp_timestamps"
        "net.ipv4.tcp_window_scaling" "net.ipv4.tcp_sack" "net.ipv4.tcp_dsack" "net.ipv4.tcp_fack"
        "net.ipv4.tcp_mtu_probing" "net.ipv4.ip_local_port_range"
        "net.ipv4.tcp_max_syn_backlog" "net.ipv4.tcp_max_tw_buckets" "net.ipv4.tcp_tw_reuse"
        "net.ipv4.tcp_fin_timeout" "net.ipv4.tcp_keepalive_time" "net.ipv4.tcp_keepalive_intvl"
        "net.ipv4.tcp_keepalive_probes" "net.ipv4.tcp_notsent_lowat" "net.ipv4.tcp_syncookies"
        "net.ipv4.udp_rmem_min" "net.ipv4.udp_wmem_min" "fs.file-max" "fs.nr_open"
        "net.ipv4.tcp_user_timeout"
    )

    if [ -f "$SYSCTL_CONF" ]; then
        for key in "${sysctl_keys[@]}"; do
            local escaped_key="${key//./\\.}"
            sed -i "/^[[:space:]]*${escaped_key}[[:space:]]*=/d" "$SYSCTL_CONF" 2>/dev/null
        done
    fi
}

# =============================================================================
# SYSCTL OPTIMIZATION PROFILES
# =============================================================================

apply_gaming_optimizations() {
    echo -e "${CYAN}Applying GAMING Optimizations (Low Latency Focus)...${NC}"
    backup_configs
    cleanup_previous_sysctl_keys

    declare -A gaming_settings=(
        ["vm.swappiness"]="20"
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
        ["net.core.netdev_max_backlog"]="16384"
        ["net.core.netdev_budget"]="600"
        ["net.core.somaxconn"]="65535"
        ["net.core.optmem_max"]="65536"
        ["net.ipv4.tcp_rmem"]="4096 87380 33554432"
        ["net.ipv4.tcp_wmem"]="4096 16384 33554432"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.tcp_timestamps"]="1"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.tcp_dsack"]="1"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.ipv4.tcp_max_syn_backlog"]="16384"
        ["net.ipv4.tcp_max_tw_buckets"]="2000000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="10"
        ["net.ipv4.tcp_keepalive_time"]="180"
        ["net.ipv4.tcp_keepalive_intvl"]="15"
        ["net.ipv4.tcp_keepalive_probes"]="3"
        ["net.ipv4.tcp_user_timeout"]="15000"
        ["net.ipv4.tcp_notsent_lowat"]="16384"
        ["net.ipv4.udp_rmem_min"]="8192"
        ["net.ipv4.udp_wmem_min"]="8192"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv4.conf.default.accept_redirects"]="0"
        ["net.ipv4.conf.all.accept_source_route"]="0"
        ["net.ipv4.conf.default.accept_source_route"]="0"
        ["fs.file-max"]="2097152"
        ["fs.nr_open"]="2097152"
    )

    for key in "${!gaming_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${gaming_settings[$key]}"
    done

    apply_system_limits "524288" "65535"
    reload_sysctl
    echo -e "${GREEN}GAMING optimizations applied!${NC}"
}

apply_streaming_optimizations() {
    echo -e "${CYAN}Applying STREAMING & HIGH DATA TRANSFER Optimizations...${NC}"
    backup_configs
    cleanup_previous_sysctl_keys

    declare -A streaming_settings=(
        ["vm.swappiness"]="10"
        ["vm.dirty_ratio"]="20"
        ["vm.dirty_background_ratio"]="5"
        ["vm.dirty_expire_centisecs"]="1500"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="50"
        ["vm.min_free_kbytes"]="131072"
        ["vm.overcommit_memory"]="1"
        ["net.core.rmem_max"]="134217728"
        ["net.core.wmem_max"]="134217728"
        ["net.core.rmem_default"]="262144"
        ["net.core.wmem_default"]="262144"
        ["net.core.optmem_max"]="2097152"
        ["net.ipv4.tcp_rmem"]="4096 131072 134217728"
        ["net.ipv4.tcp_wmem"]="4096 131072 134217728"
        ["net.core.netdev_max_backlog"]="250000"
        ["net.core.netdev_budget"]="600"
        ["net.core.netdev_budget_usecs"]="8000"
        ["net.core.somaxconn"]="262144"
        ["net.ipv4.tcp_max_syn_backlog"]="262144"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.tcp_timestamps"]="1"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.tcp_dsack"]="1"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_mtu_probing"]="1"
        ["net.ipv4.tcp_notsent_lowat"]="131072"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.ipv4.tcp_max_tw_buckets"]="2000000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="10"
        ["net.ipv4.tcp_keepalive_time"]="300"
        ["net.ipv4.tcp_keepalive_intvl"]="30"
        ["net.ipv4.tcp_keepalive_probes"]="5"
        ["net.ipv4.tcp_user_timeout"]="60000"
        ["fs.file-max"]="4194304"
        ["fs.nr_open"]="4194304"
    )

    for key in "${!streaming_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${streaming_settings[$key]}"
    done

    apply_system_limits "2097152" "262144"
    reload_sysctl
    echo -e "${GREEN}STREAMING & HIGH THROUGHPUT optimizations applied!${NC}"
}

apply_general_optimizations() {
    echo -e "${CYAN}Applying GENERAL PURPOSE Optimizations (Balanced)...${NC}"
    backup_configs
    cleanup_previous_sysctl_keys

    declare -A general_settings=(
        ["vm.swappiness"]="30"
        ["vm.dirty_ratio"]="20"
        ["vm.dirty_background_ratio"]="10"
        ["vm.dirty_expire_centisecs"]="3000"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="100"
        ["net.core.rmem_max"]="33554432"
        ["net.core.wmem_max"]="33554432"
        ["net.core.rmem_default"]="262144"
        ["net.core.wmem_default"]="262144"
        ["net.core.netdev_max_backlog"]="16384"
        ["net.core.somaxconn"]="65535"
        ["net.ipv4.tcp_rmem"]="4096 87380 33554432"
        ["net.ipv4.tcp_wmem"]="4096 16384 33554432"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq_codel"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.tcp_timestamps"]="1"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.tcp_dsack"]="1"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.ipv4.tcp_max_syn_backlog"]="16384"
        ["net.ipv4.tcp_max_tw_buckets"]="524288"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="15"
        ["net.ipv4.tcp_keepalive_time"]="600"
        ["net.ipv4.tcp_user_timeout"]="30000"
        ["net.ipv4.tcp_syncookies"]="1"
        ["fs.file-max"]="1048576"
        ["fs.nr_open"]="1048576"
    )

    for key in "${!general_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${general_settings[$key]}"
    done

    apply_system_limits "524288" "65535"
    reload_sysctl
    echo -e "${GREEN}GENERAL PURPOSE optimizations applied!${NC}"
}

apply_competitive_gaming_optimizations() {
    echo -e "${CYAN}Applying COMPETITIVE GAMING Optimizations (Extreme Low Latency)...${NC}"
    backup_configs
    cleanup_previous_sysctl_keys

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
        ["net.core.netdev_max_backlog"]="4096"
        ["net.core.netdev_budget"]="300"
        ["net.core.somaxconn"]="65535"
        ["net.core.optmem_max"]="65536"
        ["net.ipv4.tcp_rmem"]="4096 65536 16777216"
        ["net.ipv4.tcp_wmem"]="4096 16384 16777216"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_no_metrics_save"]="1"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.tcp_timestamps"]="1"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.tcp_dsack"]="1"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.ipv4.tcp_max_syn_backlog"]="8192"
        ["net.ipv4.tcp_max_tw_buckets"]="1800000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="5"
        ["net.ipv4.tcp_keepalive_time"]="120"
        ["net.ipv4.tcp_keepalive_intvl"]="10"
        ["net.ipv4.tcp_keepalive_probes"]="2"
        ["net.ipv4.tcp_user_timeout"]="10000"
        ["net.ipv4.tcp_notsent_lowat"]="16384"
        ["net.ipv4.udp_rmem_min"]="4096"
        ["net.ipv4.udp_wmem_min"]="4096"
        ["fs.file-max"]="1048576"
        ["fs.nr_open"]="1048576"
    )

    for key in "${!comp_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${comp_settings[$key]}"
    done

    apply_system_limits "1048576" "65535"
    reload_sysctl
    echo -e "${GREEN}COMPETITIVE GAMING optimizations applied!${NC}"
}

# =============================================================================
# TC OPTIMIZATION FUNCTIONS
# =============================================================================

detect_interfaces() {
    echo -e "${YELLOW}Detecting network interfaces...${NC}"
    INTERFACES=($(ls /sys/class/net/ | grep -v -E '^(lo|docker|veth|br-|virbr)'))
    
    if [ ${#INTERFACES[@]} -eq 0 ]; then
        echo -e "${RED}No network interfaces found!${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Available interfaces:${NC}"
    for i in "${!INTERFACES[@]}"; do
        IP=$(ip addr show "${INTERFACES[$i]}" 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
        STATUS=$(cat "/sys/class/net/${INTERFACES[$i]}/operstate" 2>/dev/null)
        if [ "$STATUS" = "up" ]; then
            STATUS_COLOR="${GREEN}UP${NC}"
        else
            STATUS_COLOR="${RED}DOWN${NC}"
        fi
        echo -e "  $((i+1)). ${INTERFACES[$i]} [$STATUS_COLOR] ${WHITE}(${IP:-No IP})${NC}"
    done
    
    DEFAULT_INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -n "$DEFAULT_INTERFACE" ]; then
        echo -e "${CYAN}Default route interface: $DEFAULT_INTERFACE${NC}"
    fi
}

select_interface() {
    detect_interfaces || return 1
    
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
        read -r choice
        case $choice in
            0)
                if [ -n "$DEFAULT_INTERFACE" ]; then
                    SELECTED_INTERFACE="$DEFAULT_INTERFACE"
                    echo -e "${GREEN}Using auto-detected interface: $SELECTED_INTERFACE${NC}"
                    break
                else
                    echo -e "${RED}Could not auto-detect default interface${NC}"
                fi
                ;;
            [1-9]*)
                if [ "$choice" -le "${#INTERFACES[@]}" ] 2>/dev/null; then
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

select_performance_profile() {
    echo -e "\n${CYAN}Select TC performance profile:${NC}"
    echo -e "  ${WHITE}1. Gaming Mode (Low Latency)${NC}"
    echo -e "  ${WHITE}2. Streaming & Proxy Mode (High Throughput / No Bandwidth Cap)${NC}"
    echo -e "  ${WHITE}3. High-Loss Network Mode (Anti-Bufferbloat)${NC}"
    echo -e "  ${WHITE}4. General Purpose Mode (Balanced)${NC}"
    echo -e "  ${WHITE}5. Custom Mode (Basic pfifo_fast)${NC}"
    
    while true; do
        echo -ne "${YELLOW}Enter choice [1-5]: ${NC}"
        read -r choice
        case $choice in
            1) PROFILE="gaming"; break ;;
            2) PROFILE="streaming"; break ;;
            3) PROFILE="high-loss"; break ;;
            4) PROFILE="general"; break ;;
            5) PROFILE="custom"; break ;;
            *) echo -e "${RED}Invalid choice. Please enter 1-5.${NC}" ;;
        esac
    done
    echo -e "${GREEN}Selected TC Profile: $PROFILE${NC}"
}

create_tc_optimizer_script() {
    local profile="$1"
    local interface="$2"
    
    echo -e "${GREEN}Creating TC optimizer script for $profile mode on $interface...${NC}"
    
    cat > "$TC_SCRIPT_PATH" << EOF
#!/bin/bash
# TC Optimizer - $profile Mode
# Interface: $interface
# Created: $(date)

INTERFACE="$interface"

# Verify interface exists
if ! ip link show "\$INTERFACE" > /dev/null 2>&1; then
    echo "Error: Interface \$INTERFACE not found"
    exit 1
fi

# Wait up to 15s for interface to be up
for i in {1..15}; do
    if ip link show "\$INTERFACE" | grep -q "state UP"; then
        break
    fi
    sleep 1
done

echo "Applying $profile optimizations to \$INTERFACE..."

# Clean existing rules
tc qdisc del dev "\$INTERFACE" root 2>/dev/null || true
tc qdisc del dev "\$INTERFACE" ingress 2>/dev/null || true
EOF

    case "$profile" in
        "gaming")
            cat >> "$TC_SCRIPT_PATH" << 'GAMING_EOF'
ethtool -A "$INTERFACE" rx off tx off 2>/dev/null || true
ethtool -K "$INTERFACE" gso off tso off gro off lro off 2>/dev/null || true
echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null || true

if tc qdisc add dev "$INTERFACE" root cake unlimited besteffort dual-dsthost nat nowash no-ack-filter 2>/dev/null; then
    echo "CAKE qdisc applied (gaming optimized)"
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 1000 flows 1024 target 2ms interval 20ms noecn 2>/dev/null; then
    echo "fq_codel qdisc applied (gaming optimized)"
else
    tc qdisc add dev "$INTERFACE" root fq 2>/dev/null || tc qdisc add dev "$INTERFACE" root pfifo_fast
    echo "Fallback qdisc applied"
fi
GAMING_EOF
            ;;
        "streaming")
            cat >> "$TC_SCRIPT_PATH" << 'STREAMING_EOF'
# Enable hardware offloads for maximum throughput and low CPU usage
ethtool -K "$INTERFACE" gso on tso on gro on 2>/dev/null || true
echo 10000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null || true

if tc qdisc add dev "$INTERFACE" root fq maxrate 100gbit 2>/dev/null || tc qdisc add dev "$INTERFACE" root fq 2>/dev/null; then
    echo "FQ qdisc applied (ideal for BBR & High Throughput)"
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 30000 flows 4096 2>/dev/null; then
    echo "fq_codel qdisc applied (high throughput)"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    echo "Fallback to pfifo_fast"
fi
STREAMING_EOF
            ;;
        "high-loss")
            cat >> "$TC_SCRIPT_PATH" << 'HIGHLOSS_EOF'
ethtool -K "$INTERFACE" gso on tso on gro on 2>/dev/null || true
echo 5000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null || true
echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null || true

if tc qdisc add dev "$INTERFACE" root cake unlimited besteffort ack-filter nat nowash 2>/dev/null; then
    echo "CAKE qdisc applied (high-loss optimized)"
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 30000 flows 4096 ecn ce-threshold 1ms 2>/dev/null; then
    echo "fq_codel qdisc applied (high-loss optimized)"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    echo "Fallback to pfifo_fast"
fi
HIGHLOSS_EOF
            ;;
        "general")
            cat >> "$TC_SCRIPT_PATH" << 'GENERAL_EOF'
ethtool -K "$INTERFACE" gso on tso on gro on 2>/dev/null || true
echo 2000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null || true

if tc qdisc add dev "$INTERFACE" root cake unlimited besteffort nat nowash 2>/dev/null; then
    echo "CAKE qdisc applied (general purpose)"
elif tc qdisc add dev "$INTERFACE" root fq_codel ecn ce-threshold 4ms 2>/dev/null; then
    echo "fq_codel qdisc applied (general purpose)"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    echo "Fallback to pfifo_fast"
fi
GENERAL_EOF
            ;;
        "custom")
            cat >> "$TC_SCRIPT_PATH" << 'CUSTOM_EOF'
ethtool -K "$INTERFACE" gso on tso on gro on 2>/dev/null || true
tc qdisc add dev "$INTERFACE" root pfifo_fast
echo "Custom mode: basic pfifo_fast applied"
CUSTOM_EOF
            ;;
    esac

    cat >> "$TC_SCRIPT_PATH" << 'EOF'

echo "Optimizations completed successfully for $INTERFACE"
exit 0
EOF

    chmod +x "$TC_SCRIPT_PATH"
    if [ -f "$TC_SCRIPT_PATH" ] && [ -x "$TC_SCRIPT_PATH" ]; then
        echo -e "${GREEN}TC optimizer script created at: $TC_SCRIPT_PATH${NC}"
        return 0
    else
        echo -e "${RED}Failed to create TC optimizer script${NC}"
        return 1
    fi
}

check_startup_status() {
    echo -e "${YELLOW}Checking startup status...${NC}"
    if crontab -l 2>/dev/null | grep -q "$TC_SCRIPT_NAME"; then
        echo -e "${GREEN}TC optimizations are enabled at startup${NC}"
        crontab -l | grep "$TC_SCRIPT_NAME"
        if [ -f "$TC_SCRIPT_PATH" ]; then
            echo -e "\n${WHITE}Script details:${NC}"
            grep -E "^(# TC Optimizer|# Interface:|# Created:)" "$TC_SCRIPT_PATH" | head -3
        fi
        return 0
    else
        echo -e "${YELLOW}TC optimizations are NOT enabled at startup${NC}"
        return 1
    fi
}

enable_startup_optimizations() {
    echo -e "${YELLOW}Enabling TC optimizations at startup...${NC}"
    local temp_cron
    temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$TC_SCRIPT_NAME" > "$temp_cron" || true
    echo "@reboot sleep 15 && $TC_SCRIPT_PATH" >> "$temp_cron"
    
    if crontab "$temp_cron"; then
        rm -f "$temp_cron"
        echo -e "${GREEN}Startup optimizations enabled${NC}"
        return 0
    else
        rm -f "$temp_cron"
        echo -e "${RED}Failed to enable startup optimizations${NC}"
        return 1
    fi
}

disable_startup_optimizations() {
    echo -e "${YELLOW}Disabling TC optimizations at startup...${NC}"
    local temp_cron
    temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$TC_SCRIPT_NAME" > "$temp_cron" || true
    
    if crontab "$temp_cron"; then
        rm -f "$temp_cron"
        echo -e "${GREEN}Removed TC optimizations from crontab${NC}"
    else
        rm -f "$temp_cron"
        echo -e "${RED}Failed to update crontab${NC}"
        return 1
    fi
    
    if [ -f "$TC_SCRIPT_PATH" ]; then
        rm -f "$TC_SCRIPT_PATH"
        echo -e "${GREEN}Removed TC optimizer script${NC}"
    fi
    return 0
}

ask_startup_config() {
    while true; do
        echo ""
        echo "=============================================="
        echo -e "${CYAN}STARTUP CONFIGURATION${NC}"
        echo "=============================================="
        echo -e "${WHITE}Do you want to run TC optimizations automatically at system startup?${NC}"
        echo -e "${GREEN}Y${NC} - Yes, enable on startup"
        echo -e "${YELLOW}N${NC} - No, run only once"
        echo -e "${BLUE}S${NC} - Show current startup status"
        echo -e "${RED}D${NC} - Disable startup optimizations"
        echo ""
        echo -n "Your choice [Y/n/S/d]: "
        
        read -r choice
        case "${choice:-y}" in
            [Yy]*) enable_startup_optimizations; break ;;
            [Nn]*) echo -e "${YELLOW}TC optimizations will run only once${NC}"; break ;;
            [Ss]*) check_startup_status ;;
            [Dd]*) disable_startup_optimizations; break ;;
            *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
        esac
    done
}

cleanup_tc() {
    local interface="$1"
    echo -e "${YELLOW}Cleaning existing TC rules on $interface...${NC}"
    tc qdisc del dev "$interface" root 2>/dev/null || true
    tc qdisc del dev "$interface" ingress 2>/dev/null || true
    ethtool -K "$interface" gso on tso on gro on 2>/dev/null || true
    echo 1000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null || true
    echo -e "${GREEN}TC rules cleaned up for $interface${NC}"
}

run_tc_optimizations() {
    if [ -f "$TC_SCRIPT_PATH" ] && [ -x "$TC_SCRIPT_PATH" ]; then
        echo -e "${YELLOW}Running TC optimizations now...${NC}"
        "$TC_SCRIPT_PATH"
    else
        echo -e "${RED}TC optimizer script not found or not executable${NC}"
        return 1
    fi
}

tc_optimize() {
    echo -e "${CYAN}=== TC Optimizer Setup ===${NC}"
    if ! select_interface; then
        echo -e "${RED}Failed to select interface. Exiting.${NC}"
        return 1
    fi
    
    select_performance_profile
    
    if create_tc_optimizer_script "$PROFILE" "$SELECTED_INTERFACE"; then
        ask_startup_config
        echo ""
        echo -n "Do you want to apply optimizations now? [Y/n]: "
        read -r apply_now
        case "${apply_now:-y}" in
            [Yy]*) run_tc_optimizations ;;
            *) echo -e "${YELLOW}You can run manually via: sudo $TC_SCRIPT_PATH${NC}" ;;
        esac
    else
        echo -e "${RED}Setup failed${NC}"
        return 1
    fi
}

apply_netem_testing() {
    local condition="$1"
    echo -e "${PURPLE}Applying NetEM for testing: $condition${NC}"
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}ERROR: Could not detect network interface${NC}"
        return 1
    fi
    
    cleanup_tc "$INTERFACE"
    
    case "$condition" in
        "gaming-latency")
            tc qdisc replace dev "$INTERFACE" root netem delay 10ms 2ms distribution normal
            echo -e "${GREEN}Added gaming-like latency: 10ms +-2ms${NC}"
            ;;
        "high-loss")
            tc qdisc replace dev "$INTERFACE" root netem loss 5% 25%
            echo -e "${GREEN}Added high packet loss: 5%${NC}"
            ;;
        "wireless")
            tc qdisc replace dev "$INTERFACE" root netem delay 20ms 10ms loss 2% 10% duplicate 1%
            echo -e "${GREEN}Added wireless-like conditions${NC}"
            ;;
        "satellite")
            tc qdisc replace dev "$INTERFACE" root netem delay 600ms 100ms loss 1%
            echo -e "${GREEN}Added satellite-like latency${NC}"
            ;;
        "internet-typical")
            tc qdisc replace dev "$INTERFACE" root netem delay 30ms 5ms loss 0.5% 10%
            echo -e "${GREEN}Added internet typical conditions${NC}"
            ;;
        "clear")
            echo -e "${GREEN}Cleared NetEM testing rules on $INTERFACE${NC}"
            ;;
    esac
}

tc_remove_optimizations() {
    echo -e "${RED}Removing ALL TC optimizations...${NC}"
    disable_startup_optimizations
    for INTERFACE in $(ls /sys/class/net/ | grep -v lo); do
        echo -e "${YELLOW}Cleaning $INTERFACE...${NC}"
        cleanup_tc "$INTERFACE"
    done
    echo -e "${GREEN}All TC optimizations removed and hardware offloads restored${NC}"
}

# =============================================================================
# REMOVAL FUNCTIONS
# =============================================================================

remove_all_optimizations() {
    echo -e "${RED}Removing ALL optimizations and restoring defaults...${NC}"
    backup_configs
    tc_remove_optimizations
    cleanup_previous_sysctl_keys

    sed -i '/^[[:space:]]*\*[[:space:]]\+\(soft\|hard\)[[:space:]]\+\(nofile\|nproc\)/d' "$LIMITS_CONF" 2>/dev/null
    sed -i '/^[[:space:]]*root[[:space:]]\+\(soft\|hard\)[[:space:]]\+\(nofile\|nproc\)/d' "$LIMITS_CONF" 2>/dev/null
    rm -f "$SYSTEMD_LIMITS_CONF" 2>/dev/null
    systemctl daemon-reexec 2>/dev/null || true

    sysctl -p > /dev/null 2>&1
    sysctl --system > /dev/null 2>&1

    echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null || true
    echo "fq_codel" > /proc/sys/net/core/default_qdisc 2>/dev/null || true

    echo -e "${GREEN}ALL optimizations removed!${NC}"
}

# =============================================================================
# CONTROL & MONITOR FUNCTIONS
# =============================================================================

show_current_settings() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                    CURRENT SYSTEM SETTINGS                     "
    echo "================================================================"
    echo -e "${NC}"
    
    echo -e "${YELLOW}NETWORK SETTINGS:${NC}"
    echo -e "  Congestion Control: ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'default')${NC}"
    echo -e "  Queue Discipline:   ${GREEN}$(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'default')${NC}"
    echo -e "  Somaxconn:          ${GREEN}$(sysctl -n net.core.somaxconn 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  Netdev Backlog:     ${GREEN}$(sysctl -n net.core.netdev_max_backlog 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  Local Port Range:   ${GREEN}$(sysctl -n net.ipv4.ip_local_port_range 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  TCP User Timeout:   ${GREEN}$(sysctl -n net.ipv4.tcp_user_timeout 2>/dev/null || echo 'N/A')${NC}"
    echo -e "  Max Open Files:     ${GREEN}$(sysctl -n fs.file-max 2>/dev/null || echo 'N/A')${NC}"
    
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
    echo -e "${YELLOW}Live Sysctl Editor (Format: key = value | Type 'quit' to exit, 'list' to view)${NC}"
    while true; do
        echo -ne "\n${CYAN}Enter setting: ${NC}"
        read -r input
        case "$input" in
            quit|exit) break ;;
            list|show) show_current_settings ;;
            "") continue ;;
            *=*)
                key=$(echo "$input" | cut -d'=' -f1 | xargs)
                value=$(echo "$input" | cut -d'=' -f2 | xargs)
                if [[ ! "$key" =~ ^[a-zA-Z0-9_.]+$ ]]; then
                    echo -e "${RED}Invalid key format${NC}"
                    continue
                fi
                if sysctl -w "$key=$value" 2>/dev/null; then
                    update_config "$SYSCTL_CONF" "$key" "$value"
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
    reload_sysctl
}

test_network_performance() {
    echo -e "${CYAN}=== NETWORK PERFORMANCE TEST ===${NC}"
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}No network interface detected${NC}"
        return 1
    fi
    echo -e "${YELLOW}Interface: ${GREEN}$INTERFACE${NC}"
    if command -v ping >/dev/null 2>&1; then
        echo -e "\n${YELLOW}PING TEST (8.8.8.8):${NC}"
        ping -c 4 -W 2 8.8.8.8 2>/dev/null | grep -E "packets|rtt|loss" || echo -e "${RED}Ping test failed${NC}"
    fi
    if command -v tc >/dev/null 2>&1; then
        echo -e "\n${YELLOW}TRAFFIC CONTROL STATUS:${NC}"
        tc -s qdisc show dev "$INTERFACE"
    fi
}

show_sysctl_file() {
    echo -e "${CYAN}=== SYSCTL.CONF CONTENTS ===${NC}"
    if [ -f "$SYSCTL_CONF" ] && [ -s "$SYSCTL_CONF" ]; then
        grep -v '^[[:space:]]*#' "$SYSCTL_CONF" | grep -v '^[[:space:]]*$'
        total_lines=$(grep -v '^[[:space:]]*#' "$SYSCTL_CONF" | grep -v '^[[:space:]]*$' | wc -l)
        echo -e "\n${YELLOW}Total active settings: ${GREEN}$total_lines${NC}"
    else
        echo -e "${YELLOW}sysctl.conf is empty or not found${NC}"
    fi
}

edit_sysctl_conf() {
    local editor=""
    for ed in nano vim vi; do
        if command -v "$ed" >/dev/null 2>&1; then
            editor="$ed"
            break
        fi
    done
    if [ -z "$editor" ]; then
        echo -e "${RED}No text editor found.${NC}"
        return 1
    fi
    if "$editor" "$SYSCTL_CONF"; then
        echo -ne "${YELLOW}Apply changes now? [y/N]: ${NC}"
        read -r apply_choice
        [[ "$apply_choice" =~ ^[yY]$ ]] && reload_sysctl
    fi
}

# =============================================================================
# BLOATWARE REMOVAL FUNCTIONS
# =============================================================================

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

update_system() {
    print_status "Updating system packages..."
    apt update && apt upgrade -y
    print_success "System updated successfully"
}

remove_multipath() {
    print_status "Removing multipath tools..."
    systemctl stop multipathd 2>/dev/null || true
    systemctl disable multipathd 2>/dev/null || true
    apt remove -y --purge multipath-tools 2>/dev/null || true
    print_success "Multipath tools removed"
}

remove_snapd() {
    print_status "Removing snapd..."
    systemctl stop snapd 2>/dev/null || true
    systemctl disable snapd 2>/dev/null || true
    apt remove -y --purge snapd snap-confine 2>/dev/null || true
    rm -rf /var/snap /snap /root/snap
    print_success "Snapd removed"
}

remove_fwupd() {
    print_status "Removing fwupd..."
    apt remove -y --purge fwupd 2>/dev/null || true
    print_success "Fwupd removed"
}

remove_desktop_components() {
    print_status "Removing desktop components..."
    apt remove -y --purge ubuntu-desktop "gnome-*" gdm3 xorg lightdm plymouth 2>/dev/null || true
    print_success "Desktop components removed"
}

remove_office_software() {
    print_status "Removing office software..."
    apt remove -y --purge "libreoffice*" abiword gnumeric 2>/dev/null || true
    print_success "Office software removed"
}

remove_games() {
    print_status "Removing games..."
    apt remove -y --purge "gnome-games*" sudoku mines aisleriot mahjongg 2>/dev/null || true
    print_success "Games removed"
}

remove_multimedia() {
    print_status "Removing multimedia packages..."
    apt remove -y --purge rhythmbox shotwell cheese "vlc*" totem brasero 2>/dev/null || true
    print_success "Multimedia packages removed"
}

remove_printing() {
    print_status "Removing printing services..."
    systemctl stop cups cups-browsed 2>/dev/null || true
    systemctl disable cups cups-browsed 2>/dev/null || true
    apt remove -y --purge "cups*" "printer-driver*" hplip 2>/dev/null || true
    print_success "Printing services removed"
}

remove_bluetooth() {
    print_status "Removing bluetooth..."
    systemctl stop bluetooth 2>/dev/null || true
    systemctl disable bluetooth 2>/dev/null || true
    apt remove -y --purge "bluez*" 2>/dev/null || true
    print_success "Bluetooth removed"
}

remove_audio() {
    print_status "Removing audio services..."
    apt remove -y --purge "pulseaudio*" "alsa*" "pipewire*" 2>/dev/null || true
    print_success "Audio services removed"
}

remove_unnecessary_services() {
    print_status "Removing unnecessary services (preserving NetworkManager)..."
    local services=(whoopsie popularity-contest apport avahi-daemon modemmanager cups-browsed)
    for service in "${services[@]}"; do
        systemctl stop "$service" 2>/dev/null || true
        systemctl disable "$service" 2>/dev/null || true
        systemctl mask "$service" 2>/dev/null || true
    done
    print_success "Unnecessary services disabled"
}

clean_system() {
    print_status "Cleaning system..."
    apt autoremove -y --purge
    apt autoclean
    apt clean
    rm -rf /var/cache/apt/*
    print_success "System cleaned"
}

show_bloatware() {
    print_status "Scanning for common bloatware packages..."
    local bloatware_list=("snapd" "fwupd" "multipath-tools" "ubuntu-desktop" "libreoffice" "cups" "bluetooth" "pulseaudio" "whoopsie" "popularity-contest")
    echo -e "\n${YELLOW}Found bloatware packages:${NC}"
    for pkg in "${bloatware_list[@]}"; do
        if dpkg -l | grep -q "^ii[[:space:]]\+$pkg"; then
            echo -e "  ${RED}*${NC} $pkg"
        fi
    done
}

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

bloatware() {
    while true; do
        clear
        echo -e "${BLUE}=== Ubuntu Server Bloatware Removal Tool ===${NC}"
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
        echo " 0) Back to Main Menu"
        echo ""
        read -rp "Enter your choice [0-15, default 14]: " choice
        choice=${choice:-14}
        
        case $choice in
            1) show_bloatware ;;
            2) remove_multipath ;;
            3) remove_snapd ;;
            4) remove_fwupd ;;
            5) remove_desktop_components ;;
            6) remove_office_software ;;
            7) remove_games ;;
            8) remove_multimedia ;;
            9) remove_printing ;;
            10) remove_bluetooth ;;
            11) remove_audio ;;
            12) remove_unnecessary_services ;;
            13) clean_system ;;
            14)
                echo -e "${RED}WARNING: This will remove ALL detected bloatware!${NC}"
                read -rp "Are you sure? (y/N): " confirm_bloat
                if [[ "$confirm_bloat" =~ ^[Yy]$ ]]; then
                    remove_all_bloatware
                else
                    print_status "Cancelled."
                fi
                ;;
            15) update_system ;;
            0) break ;;
            *) print_error "Invalid option." ;;
        esac
        echo ""
        read -rp "Press Enter to continue..."
    done
}

# =============================================================================
# MENU SYSTEM
# =============================================================================

show_netem_menu() {
    clear
    echo -e "${PURPLE}"
    echo "================================================================"
    echo "                     NETEM TESTING MENU                         "
    echo "================================================================"
    echo -e "  ${GREEN}1${NC}${WHITE}. Gaming Latency (10ms +-2ms)${NC}"
    echo -e "  ${GREEN}2${NC}${WHITE}. High Packet Loss (5% loss)${NC}"
    echo -e "  ${GREEN}3${NC}${WHITE}. Wireless Conditions (20ms + 2% loss)${NC}"
    echo -e "  ${GREEN}4${NC}${WHITE}. Satellite Latency (600ms + 1% loss)${NC}"
    echo -e "  ${GREEN}5${NC}${WHITE}. Internet Typical (30ms + 0.5% loss)${NC}"
    echo -e "  ${GREEN}6${NC}${WHITE}. Clear NetEM Rules${NC}"
    echo -e "  ${GREEN}0${NC}${WHITE}. Back to Main Menu${NC}"
    echo "================================================================"
}

handle_netem_menu() {
    while true; do
        show_netem_menu
        echo -ne "${YELLOW}Select test condition [0-6]: ${NC}"
        read -r choice
        case $choice in
            1) apply_netem_testing "gaming-latency" ;;
            2) apply_netem_testing "high-loss" ;;
            3) apply_netem_testing "wireless" ;;
            4) apply_netem_testing "satellite" ;;
            5) apply_netem_testing "internet-typical" ;;
            6) apply_netem_testing "clear" ;;
            0) break ;;
            *) echo -e "${RED}Invalid option! Please select 0-6${NC}" ;;
        esac
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read -r
    done
}

show_main_menu() {
    clear
    echo -e "${CYAN}"
    echo "================================================================"
    echo "             NETWORK OPTIMIZER TOOL - MAIN MENU                 "
    echo "================================================================"
    echo -e "${GREEN}SYSCTL OPTIMIZATIONS:${CYAN}"
    echo -e "  ${GREEN}1${NC}${WHITE}. Gaming (Low Latency)${NC}"
    echo -e "  ${GREEN}2${NC}${WHITE}. Streaming & Proxy (High Throughput / Heavy Connections)${NC}"
    echo -e "  ${GREEN}3${NC}${WHITE}. General Purpose (Balanced)${NC}"
    echo -e "  ${GREEN}4${NC}${WHITE}. Competitive Gaming (Extreme Low Latency)${NC}"
    echo ""
    echo -e "${BLUE}TC OPTIMIZATIONS:${CYAN}"
    echo -e "  ${GREEN}5${NC}${WHITE}. Configure TC Optimizations${NC}"
    echo -e "  ${GREEN}6${NC}${WHITE}. Remove TC Optimizations${NC}"
    echo -e "  ${GREEN}8${NC}${WHITE}. NetEM Network Testing${NC}"
    echo ""
    echo -e "${GREEN}VIEW & MONITOR:${CYAN}"
    echo -e "  ${GREEN}11${NC}${WHITE}. Show Current Settings${NC}"
    echo -e "  ${GREEN}12${NC}${WHITE}. Show Sysctl.conf File${NC}"
    echo -e "  ${GREEN}13${NC}${WHITE}. Test Network Performance${NC}"
    echo ""
    echo -e "${BLUE}EDIT & CONFIGURE:${CYAN}"
    echo -e "  ${GREEN}14${NC}${WHITE}. Live Sysctl Editor${NC}"
    echo -e "  ${GREEN}15${NC}${WHITE}. Edit Sysctl.conf (Text Editor)${NC}"
    echo -e "  ${GREEN}16${NC}${WHITE}. Apply Settings Immediately${NC}"
    echo ""
    echo -e "${PURPLE}MAINTENANCE:${CYAN}"
    echo -e "  ${GREEN}17${NC}${WHITE}. Backup Configurations${NC}"
    echo -e "  ${GREEN}18${NC}${WHITE}. Remove All Optimizations${NC}"
    echo -e "  ${GREEN}19${NC}${WHITE}. Stop System Logging (journald + rsyslog)${NC}"
    echo -e "  ${GREEN}20${NC}${WHITE}. Restore System Logging${NC}"
    echo -e "  ${GREEN}21${NC}${WHITE}. Remove Ubuntu Bloatware${NC}"
    echo ""
    echo -e "  ${GREEN}0${NC}${WHITE}. Exit${CYAN}"
    echo "================================================================"
    echo -e "${NC}"
}

main_menu() {
    while true; do
        show_main_menu
        echo -ne "${YELLOW}Select option: ${NC}"
        read -r choice
        
        case $choice in
            1) apply_gaming_optimizations ;;
            2) apply_streaming_optimizations ;;
            3) apply_general_optimizations ;;
            4) apply_competitive_gaming_optimizations ;;
            5) tc_optimize ;;
            6) tc_remove_optimizations ;;
            8) handle_netem_menu ;;
            9|11) show_current_settings ;;
            10|17) backup_configs ;;
            12) show_sysctl_file ;;
            13) test_network_performance ;;
            14) edit_sysctl_live ;;
            15) edit_sysctl_conf ;;
            16) apply_settings_immediately ;;
            18) remove_all_optimizations ;;
            19)
                echo -e "${YELLOW}Warning:${NC} Masking journald and rsyslog will stop all system logging!"
                read -rp "Are you sure you want to continue? (yes/no): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    systemctl stop systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket rsyslog.service 2>/dev/null || true
                    systemctl mask systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket rsyslog.service 2>/dev/null || true
                    echo -e "${GREEN}Journald and rsyslog have been stopped and masked.${NC}"
                else
                    echo -e "${BLUE}Operation canceled.${NC}"
                fi
                ;;
            20)
                echo -e "${YELLOW}Restoring journald and rsyslog services...${NC}"
                systemctl unmask systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket rsyslog.service 2>/dev/null || true
                systemctl enable systemd-journald.service systemd-journald.socket systemd-journald-dev-log.socket rsyslog.service 2>/dev/null || true
                systemctl start systemd-journald.service rsyslog.service 2>/dev/null || true
                echo -e "${GREEN}Journald and rsyslog have been unmasked and restarted.${NC}"
                ;;
            21) bloatware ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option! Please select a valid number from the menu.${NC}"
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

for cmd in sysctl tc ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}Error: $cmd is required but not installed.${NC}"
        exit 1
    fi
done

create_backup_dir
main_menu
