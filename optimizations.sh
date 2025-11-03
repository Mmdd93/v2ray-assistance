#!/bin/bash

# =============================================================================
# CONFIGURATION
# =============================================================================
SYSCTL_CONF="/etc/sysctl.conf"
LIMITS_CONF="/etc/security/limits.conf"
BACKUP_DIR="/etc/optimizer_backups"

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
    cp "$SYSCTL_CONF" "${BACKUP_DIR}/sysctl.conf.bak.${timestamp}"
    cp "$LIMITS_CONF" "${BACKUP_DIR}/limits.conf.bak.${timestamp}"
    echo -e "${GREEN}Backup completed: ${BACKUP_DIR}/sysctl.conf.bak.${timestamp}${NC}"
    echo -e "${GREEN}Backup completed: ${BACKUP_DIR}/limits.conf.bak.${timestamp}${NC}"
}

reload_sysctl() {
    echo -e "${GREEN}Reloading sysctl settings...${NC}"
    sysctl -p
}

update_config() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    if grep -q "^$key" "$file"; then
        if grep -q "^$key.*$value" "$file"; then
            echo -e "${YELLOW}Setting $key already configured with value $value${NC}"
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
    done

    reload_sysctl
    echo -e "${GREEN}GAMING optimizations applied successfully!${NC}"
    echo -e "${YELLOW}Optimized for: Low latency, fast response times, UDP performance${NC}"
}

apply_streaming_optimizations() {
    echo -e "${CYAN}Applying STREAMING Optimizations (High Throughput Focus)...${NC}"

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
        ["fs.nr_open"]="4194304"
        ["net.netfilter.nf_conntrack_max"]="262144"
        ["net.netfilter.nf_conntrack_tcp_timeout_established"]="86400"
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
    done

    reload_sysctl
    echo -e "${GREEN}STREAMING optimizations applied successfully!${NC}"
    echo -e "${YELLOW}Optimized for: High bandwidth, stable connections, large file transfers${NC}"
}

apply_general_optimizations() {
    echo -e "${CYAN}Applying GENERAL PURPOSE Optimizations (Balanced)...${NC}"

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
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.default.rp_filter"]="1"
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
    done

    reload_sysctl
    echo -e "${GREEN}GENERAL PURPOSE optimizations applied successfully!${NC}"
    echo -e "${YELLOW}Optimized for: Balanced performance, stability, everyday use${NC}"
}

apply_competitive_gaming_optimizations() {
    echo -e "${CYAN}Applying COMPETITIVE GAMING Optimizations (Extreme Low Latency)...${NC}"

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
    echo -e "${GREEN}COMPETITIVE GAMING optimizations applied successfully!${NC}"
    echo -e "${YELLOW}WARNING: Very aggressive settings - may affect stability${NC}"
    echo -e "${YELLOW}Optimized for: Extreme low latency, competitive gaming${NC}"
}

# =============================================================================
# TC OPTIMIZATION FUNCTIONS
# =============================================================================

tc_optimize_by_category() {
    local category="${1:-general}"
    
    echo "=============================================="
    echo "        TC OPTIMIZER - $category MODE"
    echo "=============================================="
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}ERROR: Could not detect network interface${NC}"
        return 1
    fi
    
    echo -e "${WHITE}Detected interface: ${GREEN}$INTERFACE${NC}"
    
    detect_link_speed() {
        local speed
        if command -v ethtool >/dev/null 2>&1; then
            speed=$(ethtool "$INTERFACE" 2>/dev/null | grep -oP 'Speed: \K[0-9]+')
            if [ -n "$speed" ]; then
                echo "$speed"
                return
            fi
        fi
        
        if [ -f "/sys/class/net/$INTERFACE/speed" ]; then
            speed=$(cat "/sys/class/net/$INTERFACE/speed" 2>/dev/null)
            if [ "$speed" -gt 0 ] 2>/dev/null; then
                echo "$speed"
                return
            fi
        fi
        
        case "$INTERFACE" in
            eth*|en*) echo "1000" ;;
            wlan*|wlp*) echo "300" ;;
            *) echo "1000" ;;
        esac
    }
    
    LINK_SPEED=$(detect_link_speed)
    BANDWIDTH=$((LINK_SPEED * 85 / 100))
    echo -e "${WHITE}Link speed: ${GREEN}${LINK_SPEED}Mbps${NC}"
    echo -e "${WHITE}Target bandwidth: ${GREEN}${BANDWIDTH}Mbps${NC}"
    
    cleanup_tc() {
        echo -e "${YELLOW}Cleaning existing TC rules...${NC}"
        tc qdisc del dev "$INTERFACE" root 2>/dev/null
        tc qdisc del dev "$INTERFACE" ingress 2>/dev/null
        ip link set dev "$INTERFACE" mtu 1500 2>/dev/null
        echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
    }
    
    cleanup_tc
    
    test_qdisc() {
        local qdisc=$1
        tc qdisc add dev "$INTERFACE" root "$qdisc" 2>/dev/null
        if [ $? -eq 0 ]; then
            tc qdisc del dev "$INTERFACE" root 2>/dev/null
            return 0
        fi
        return 1
    }
    
    echo -e "${YELLOW}Applying $category optimizations...${NC}"
    
    case "$category" in
        "gaming")
            apply_tc_gaming_optimizations
            ;;
        "high-loss")
            apply_tc_high_loss_optimizations
            ;;
        "general")
            apply_tc_general_optimizations
            ;;
        *)
            echo -e "${RED}Unknown category: $category${NC}"
            return 1
            ;;
    esac
    
    echo ""
    echo "=============================================="
    echo -e "${GREEN}$category OPTIMIZATION COMPLETE${NC}"
    echo "=============================================="
    echo -e "${WHITE}Interface: ${GREEN}$INTERFACE${NC}"
    echo -e "${WHITE}Link Speed: ${GREEN}${LINK_SPEED}Mbps${NC}"
    echo -e "${WHITE}Configured Bandwidth: ${GREEN}${BANDWIDTH}Mbps${NC}"
    echo -e "${WHITE}Queue Discipline: ${GREEN}$(tc qdisc show dev "$INTERFACE" | head -1 | awk '{print $2}')${NC}"
    echo -e "${WHITE}TX Queue Length: ${GREEN}$(cat "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null || echo 'default')${NC}"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $category mode: $INTERFACE - ${LINK_SPEED}Mbps - $(tc qdisc show dev "$INTERFACE" | head -1)" >> /var/log/tc_optimizer.log
}

apply_tc_gaming_optimizations() {
    echo -e "${GREEN}Applying GAMING optimizations (Ultra Low Latency)...${NC}"
    
    echo 256 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
    
    if test_qdisc "cake"; then
        echo -e "${GREEN}Using CAKE (Best for gaming)${NC}"
        tc qdisc add dev "$INTERFACE" root cake bandwidth ${BANDWIDTH}mbit besteffort dual-dsthost
        echo -e "${GREEN}CAKE configured with dual-dsthost for gaming traffic${NC}"
        
    elif test_qdisc "fq_codel"; then
        echo -e "${GREEN}Using FQ_Codel (Excellent for gaming)${NC}"
        tc qdisc add dev "$INTERFACE" root fq_codel \
            limit 1000 \
            flows 512 \
            target 3ms \
            interval 50ms \
            quantum 300 \
            noecn
        echo -e "${GREEN}FQ_Codel configured with aggressive low-latency settings${NC}"
        
    elif test_qdisc "fq"; then
        echo -e "${GREEN}Using FQ (Good for gaming with BBR)${NC}"
        tc qdisc add dev "$INTERFACE" root fq \
            flow_limit 500 \
            quantum 300 \
            initial_quantum 10000
        echo -e "${GREEN}FQ configured for gaming${NC}"
        
    else
        echo -e "${YELLOW}Using PFIFO_Fast with gaming optimizations${NC}"
        tc qdisc add dev "$INTERFACE" root pfifo_fast
        echo -e "${GREEN}Basic PFIFO_Fast configured${NC}"
    fi
    
    echo 1 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null
    echo 0 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null
}

apply_tc_high_loss_optimizations() {
    echo -e "${YELLOW}Applying HIGH PACKET LOSS optimizations...${NC}"
    
    echo 4000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
    
    if test_qdisc "cake"; then
        echo -e "${GREEN}Using CAKE with loss compensation${NC}"
        tc qdisc add dev "$INTERFACE" root cake bandwidth ${BANDWIDTH}mbit besteffort ack-filter
        echo -e "${GREEN}CAKE configured with ack-filter for lossy networks${NC}"
        
    elif test_qdisc "fq_codel"; then
        echo -e "${GREEN}Using FQ_Codel with loss tolerance${NC}"
        tc qdisc add dev "$INTERFACE" root fq_codel \
            limit 20000 \
            flows 2048 \
            target 10ms \
            interval 200ms \
            memory_limit 64Mb \
            ecn
        echo -e "${GREEN}FQ_Codel configured for high packet loss environments${NC}"
        
    elif test_qdisc "sfq"; then
        echo -e "${GREEN}Using SFQ with loss recovery${NC}"
        tc qdisc add dev "$INTERFACE" root sfq \
            perturb 120 \
            quantum 1514 \
            depth 127
        echo -e "${GREEN}SFQ configured for packet loss scenarios${NC}"
        
    else
        echo -e "${YELLOW}Using basic configuration with larger buffers${NC}"
        tc qdisc add dev "$INTERFACE" root pfifo_fast
        echo -e "${GREEN}Basic configuration with larger buffers${NC}"
    fi
    
    echo 2 > /proc/sys/net/ipv4/tcp_syn_retries 2>/dev/null
    echo 2 > /proc/sys/net/ipv4/tcp_synack_retries 2>/dev/null
    echo 5 > /proc/sys/net/ipv4/tcp_retries1 2>/dev/null
    echo 15 > /proc/sys/net/ipv4/tcp_retries2 2>/dev/null
}

apply_tc_general_optimizations() {
    echo -e "${BLUE}Applying GENERAL PURPOSE optimizations...${NC}"
    
    echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
    
    if test_qdisc "cake"; then
        echo -e "${GREEN}Using CAKE (Best all-around)${NC}"
        tc qdisc add dev "$INTERFACE" root cake bandwidth ${BANDWIDTH}mbit besteffort
        echo -e "${GREEN}CAKE configured for general purpose use${NC}"
        
    elif test_qdisc "fq_codel"; then
        echo -e "${GREEN}Using FQ_Codel (Excellent balanced)${NC}"
        tc qdisc add dev "$INTERFACE" root fq_codel \
            limit 10240 \
            flows 1024 \
            target 5ms \
            interval 100ms \
            memory_limit 32Mb
        echo -e "${GREEN}FQ_Codel configured for general use${NC}"
        
    elif test_qdisc "fq"; then
        echo -e "${GREEN}Using FQ (Good performance)${NC}"
        tc qdisc add dev "$INTERFACE" root fq
        echo -e "${GREEN}FQ configured${NC}"
        
    else
        echo -e "${YELLOW}Using PFIFO_Fast (Compatible)${NC}"
        tc qdisc add dev "$INTERFACE" root pfifo_fast
        echo -e "${GREEN}PFIFO_Fast configured${NC}"
    fi
}

apply_netem_testing() {
    local condition="$1"
    
    echo -e "${PURPLE}Applying NetEM for testing: $condition${NC}"
    
    apply_tc_general_optimizations
    
    local handle=$(tc qdisc show dev "$INTERFACE" | head -1 | awk '{print $3}')
    
    case "$condition" in
        "gaming-latency")
            tc qdisc add dev "$INTERFACE" parent $handle netem delay 10ms 2ms distribution normal
            echo -e "${GREEN}Added gaming-like latency: 10ms +-2ms${NC}"
            ;;
        "high-loss")
            tc qdisc add dev "$INTERFACE" parent $handle netem loss 5% 25%
            echo -e "${GREEN}Added high packet loss: 5%${NC}"
            ;;
        "wireless")
            tc qdisc add dev "$INTERFACE" parent $handle netem delay 20ms 10ms loss 2% 10% duplicate 1%
            echo -e "${GREEN}Added wireless-like conditions${NC}"
            ;;
        "satellite")
            tc qdisc add dev "$INTERFACE" parent $handle netem delay 600ms 100ms loss 1%
            echo -e "${GREEN}Added satellite-like latency${NC}"
            ;;
        "internet-typical")
            tc qdisc add dev "$INTERFACE" parent $handle netem delay 30ms 5ms loss 0.5% 10%
            echo -e "${GREEN}Added internet typical conditions${NC}"
            ;;
    esac
}

tc_remove_optimizations() {
    echo -e "${RED}Removing ALL TC optimizations...${NC}"
    
    for INTERFACE in $(ls /sys/class/net/ | grep -v lo); do
        echo -e "${YELLOW}Cleaning $INTERFACE...${NC}"
        tc qdisc del dev "$INTERFACE" root 2>/dev/null
        tc qdisc del dev "$INTERFACE" ingress 2>/dev/null
        ip link set dev "$INTERFACE" mtu 1500 2>/dev/null
        echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
    done
    
    echo 0 > /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null
    echo 1 > /proc/sys/net/ipv4/tcp_slow_start_after_idle 2>/dev/null
    
    echo -e "${GREEN}All TC optimizations removed${NC}"
}

# =============================================================================
# REMOVAL FUNCTIONS
# =============================================================================

remove_all_optimizations() {
    echo -e "${RED}Removing ALL optimizations and restoring defaults...${NC}"
    
    backup_configs
    
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
        "net.netfilter.nf_conntrack_max" "net.netfilter.nf_conntrack_tcp_timeout_established"
    )

    for key in "${sysctl_keys[@]}"; do
        sed -i "/^\s*${key}\s*=/d" "$SYSCTL_CONF"
    done

    local limit_keys=(
        "* soft nproc" "* hard nproc" "* soft nofile" "* hard nofile"
        "root soft nproc" "root hard nproc" "root soft nofile" "root hard nofile"
    )

    for key in "${limit_keys[@]}"; do
        sed -i "/^$key/d" "$LIMITS_CONF"
    done

    echo -e "${YELLOW}Reloading system defaults...${NC}"
    sysctl -p > /dev/null 2>&1
    sysctl --system > /dev/null 2>&1

    echo -e "${YELLOW}Resetting network settings...${NC}"
    
    for interface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev "$interface" root 2>/dev/null
        tc qdisc del dev "$interface" ingress 2>/dev/null
    done

    echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    echo "fq_codel" > /proc/sys/net/core/default_qdisc 2>/dev/null

    echo -e "${GREEN}ALL optimizations removed successfully!${NC}"
    echo -e "${YELLOW}System restored to default settings:${NC}"
    echo -e "   Congestion Control: ${BLUE}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'cubic')${NC}"
    echo -e "   Queue Discipline:   ${BLUE}$(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'fq_codel')${NC}"
    echo -e "   File Limits:        ${BLUE}Restored to system defaults${NC}"
    echo -e "   Network Settings:   ${BLUE}Restored to kernel defaults${NC}"
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
    
    # Network settings
    echo -e "${YELLOW}NETWORK SETTINGS:${NC}"
    echo -e "  Congestion Control: ${GREEN}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'default')${NC}"
    echo -e "  Queue Discipline:   ${GREEN}$(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'default')${NC}"
    echo -e "  TCP Low Latency:    ${GREEN}$(sysctl -n net.ipv4.tcp_low_latency 2>/dev/null || echo '0')${NC}"
    echo -e "  TCP Fast Open:      ${GREEN}$(sysctl -n net.ipv4.tcp_fastopen 2>/dev/null || echo '0')${NC}"
    
    # Memory settings
    echo -e "\n${YELLOW}MEMORY SETTINGS:${NC}"
    echo -e "  Swappiness:         ${GREEN}$(sysctl -n vm.swappiness 2>/dev/null || echo '60')${NC}"
    echo -e "  Dirty Ratio:        ${GREEN}$(sysctl -n vm.dirty_ratio 2>/dev/null || echo '20')${NC}"
    echo -e "  Dirty Background:   ${GREEN}$(sysctl -n vm.dirty_background_ratio 2>/dev/null || echo '10')${NC}"
    
    # File limits
    echo -e "\n${YELLOW}FILE LIMITS:${NC}"
    echo -e "  File Max:           ${GREEN}$(sysctl -n fs.file-max 2>/dev/null || echo 'default')${NC}"
    echo -e "  Current Open Files: ${GREEN}$(cat /proc/sys/fs/file-nr | awk '{print $1}')${NC}"
    
    # TC status
    echo -e "\n${YELLOW}TRAFFIC CONTROL:${NC}"
    for IFACE in $(ls /sys/class/net/ | grep -v lo); do
        QDISC=$(tc qdisc show dev "$IFACE" 2>/dev/null | head -1 || echo "None")
        echo -e "  ${WHITE}$IFACE: ${BLUE}$QDISC${NC}"
    done
    
    # Service status
    echo -e "\n${YELLOW}SERVICE STATUS:${NC}"
    if systemctl is-active --quiet rsyslog; then
        echo -e "  System Logging:     ${GREEN}ENABLED${NC}"
    else
        echo -e "  System Logging:     ${RED}DISABLED${NC}"
    fi
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
                
                # Validate key format
                if [[ ! "$key" =~ ^[a-zA-Z0-9_.]+$ ]]; then
                    echo -e "${RED}Invalid key format${NC}"
                    continue
                fi
                
                # Try to apply live
                if sysctl -w "$key=$value" 2>/dev/null; then
                    echo -e "${GREEN}Live setting applied: $key = $value${NC}"
                    
                    # Also update config file
                    if grep -q "^$key" "$SYSCTL_CONF" 2>/dev/null; then
                        sed -i "s|^$key.*|$key = $value|" "$SYSCTL_CONF"
                    else
                        echo "$key = $value" >> "$SYSCTL_CONF"
                    fi
                    echo -e "${GREEN}Config file updated${NC}"
                else
                    echo -e "${RED}Failed to apply setting${NC}"
                fi
                ;;
            *)
                # Try to show current value
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
    
    # Reload sysctl
    if sysctl -p; then
        echo -e "${GREEN}Sysctl settings applied${NC}"
    else
        echo -e "${RED}Error applying sysctl settings${NC}"
        return 1
    fi
    
    # Apply TC settings if interface detected
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -n "$INTERFACE" ]; then
        echo -e "${GREEN}Network interface detected: $INTERFACE${NC}"
        # You can add TC re-application here if needed
    fi
    
    echo -e "${GREEN}All settings applied successfully${NC}"
}

disable_system_logging() {
    echo -e "${YELLOW}Disabling system logging...${NC}"
    
    if systemctl stop rsyslog 2>/dev/null && systemctl disable rsyslog 2>/dev/null; then
        echo -e "${GREEN}System logging disabled${NC}"
        
        # Also disable journald if requested
        echo -e "${YELLOW}Disable systemd journal as well? [y/N]: ${NC}"
        read -r choice
        if [[ "$choice" =~ [yY] ]]; then
            if systemctl stop systemd-journald 2>/dev/null && systemctl disable systemd-journald 2>/dev/null; then
                echo -e "${GREEN}Systemd journal disabled${NC}"
            else
                echo -e "${RED}Failed to disable systemd journal${NC}"
            fi
        fi
    else
        echo -e "${RED}Failed to disable system logging${NC}"
    fi
}

enable_system_logging() {
    echo -e "${YELLOW}Enabling system logging...${NC}"
    
    if systemctl enable rsyslog 2>/dev/null && systemctl start rsyslog 2>/dev/null; then
        echo -e "${GREEN}System logging enabled${NC}"
        
        # Also enable journald
        if systemctl enable systemd-journald 2>/dev/null && systemctl start systemd-journald 2>/dev/null; then
            echo -e "${GREEN}Systemd journal enabled${NC}"
        fi
    else
        echo -e "${RED}Failed to enable system logging${NC}"
    fi
}

toggle_logging() {
    if systemctl is-active --quiet rsyslog; then
        disable_system_logging
    else
        enable_system_logging
    fi
}

show_log_status() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                   LOGGING STATUS                              "
    echo "================================================================"
    echo -e "${NC}"
    
    echo -e "${YELLOW}SERVICE STATUS:${NC}"
    if systemctl is-active --quiet rsyslog; then
        echo -e "  rsyslog:          ${GREEN}ACTIVE${NC}"
    else
        echo -e "  rsyslog:          ${RED}INACTIVE${NC}"
    fi
    
    if systemctl is-active --quiet systemd-journald; then
        echo -e "  systemd-journal:  ${GREEN}ACTIVE${NC}"
    else
        echo -e "  systemd-journal:  ${RED}INACTIVE${NC}"
    fi
    
    echo -e "\n${YELLOW}LOG FILES:${NC}"
    local log_files=(
        "/var/log/syslog"
        "/var/log/messages"
        "/var/log/kern.log"
        "/var/log/tc_optimizer.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            size=$(du -h "$log_file" 2>/dev/null | cut -f1)
            lines=$(wc -l < "$log_file" 2>/dev/null)
            echo -e "  ${WHITE}$log_file: ${GREEN}$size, $lines lines${NC}"
        else
            echo -e "  ${WHITE}$log_file: ${RED}Not found${NC}"
        fi
    done
    
    # Show recent TC optimizer activity
    if [ -f "/var/log/tc_optimizer.log" ]; then
        echo -e "\n${YELLOW}RECENT TC OPTIMIZER ACTIVITY:${NC}"
        tail -5 "/var/log/tc_optimizer.log" | while read line; do
            echo -e "  ${WHITE}$line${NC}"
        done
    fi
}

clear_logs() {
    echo -e "${YELLOW}Clearing log files...${NC}"
    
    local log_files=(
        "/var/log/syslog"
        "/var/log/messages"
        "/var/log/kern.log"
        "/var/log/tc_optimizer.log"
    )
    
    for log_file in "${log_files[@]}"; do
        if [ -f "$log_file" ]; then
            if truncate -s 0 "$log_file" 2>/dev/null; then
                echo -e "${GREEN}Cleared: $log_file${NC}"
            else
                echo -e "${RED}Failed to clear: $log_file${NC}"
            fi
        fi
    done
    
    # Also clear journal if active
    if command -v journalctl >/dev/null 2>&1; then
        if journalctl --vacuum-size=1M 2>/dev/null; then
            echo -e "${GREEN}Cleared systemd journal${NC}"
        fi
    fi
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
    
    # Basic ping test
    if command -v ping >/dev/null 2>&1; then
        echo -e "\n${YELLOW}PING TEST (Google DNS):${NC}"
        ping -c 4 -W 2 8.8.8.8 2>/dev/null | grep -E "packets|rtt|loss" || echo -e "${RED}Ping test failed${NC}"
    fi
    
    # Speed test if available
    if command -v speedtest-cli >/dev/null 2>&1; then
        echo -e "\n${YELLOW}SPEED TEST:${NC}"
        speedtest-cli --simple 2>/dev/null || echo -e "${RED}Speed test not available${NC}"
    elif command -v iperf3 >/dev/null 2>&1; then
        echo -e "\n${YELLOW}IPERF3 (requires server):${NC}"
        echo -e "${WHITE}Run: iperf3 -c <server> -t 10${NC}"
    fi
    
    # Interface statistics
    echo -e "\n${YELLOW}INTERFACE STATISTICS:${NC}"
    if [ -f "/sys/class/net/$INTERFACE/statistics/rx_bytes" ]; then
        rx_bytes=$(cat "/sys/class/net/$INTERFACE/statistics/rx_bytes")
        tx_bytes=$(cat "/sys/class/net/$INTERFACE/statistics/tx_bytes")
        echo -e "  RX: ${GREEN}$(numfmt --to=iec $rx_bytes)${NC}, TX: ${GREEN}$(numfmt --to=iec $tx_bytes)${NC}"
    fi
    
    # Connection count
    if command -v ss >/dev/null 2>&1; then
        echo -e "\n${YELLOW}CONNECTION COUNT:${NC}"
        total_conn=$(ss -tun | wc -l)
        echo -e "  Total connections: ${GREEN}$((total_conn - 1))${NC}"
    fi
}

show_sysctl_file() {
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                   SYSCTL.CONF CONTENTS                        "
    echo "================================================================"
    echo -e "${NC}"
    
    if [ -f "$SYSCTL_CONF" ]; then
        # Show only non-empty, non-comment lines
        grep -v '^#' "$SYSCTL_CONF" | grep -v '^$' | while read line; do
            echo -e "  ${WHITE}$line${NC}"
        done
        
        total_lines=$(grep -v '^#' "$SYSCTL_CONF" | grep -v '^$' | wc -l)
        echo -e "\n${YELLOW}Total active settings: ${GREEN}$total_lines${NC}"
    else
        echo -e "${RED}sysctl.conf not found${NC}"
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
    echo -e "${WHITE}Select optimization category:${CYAN}                       "
    echo "                                                                "
    echo -e "${GREEN}SYSCTL OPTIMIZATIONS:${CYAN}                              "
    echo -e "  ${GREEN}1${NC}${WHITE}. Gaming (Low Latency)${CYAN}                           "
    echo -e "  ${GREEN}2${NC}${WHITE}. Streaming (High Throughput)${CYAN}                    "
    echo -e "  ${GREEN}3${NC}${WHITE}. General Purpose (Balanced)${CYAN}                     "
    echo -e "  ${GREEN}4${NC}${WHITE}. Competitive Gaming (Extreme)${CYAN}                   "
    echo "                                                                "
    echo -e "${BLUE}TC OPTIMIZATIONS:${CYAN}                                 "
    echo -e "  ${GREEN}5${NC}${WHITE}. TC Gaming Mode${CYAN}                                "
    echo -e "  ${GREEN}6${NC}${WHITE}. TC High Loss Mode${CYAN}                             "
    echo -e "  ${GREEN}7${NC}${WHITE}. TC General Mode${CYAN}                               "
    echo -e "  ${GREEN}8${NC}${WHITE}. NetEM Testing${CYAN}                                 "
    echo "                                                                "
    echo -e "${YELLOW}TOOLS & MANAGEMENT:${CYAN}                             "
    echo -e "  ${GREEN}9${NC}${WHITE}. Show Current Status${CYAN}                           "
    echo -e "  ${GREEN}10${NC}${WHITE}. Backup Configurations${CYAN}                        "
    echo -e "  ${GREEN}11${NC}${WHITE}. Remove All Optimizations${CYAN}                     "
    echo "                                                                "
    echo -e "${PURPLE}SYSTEM CONTROL:${CYAN}                                "
    echo -e "  ${GREEN}12${NC}${WHITE}. System Control Panel${CYAN}                         "
    echo "                                                                "
    echo -e "  ${GREEN}0${NC}${WHITE}. Exit${CYAN}                                         "
    echo "                                                                "
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

show_status() {
    clear
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                   CURRENT SYSTEM STATUS                       "
    echo "================================================================"
    echo -e "${NC}"
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -z "$INTERFACE" ]; then
        echo -e "${RED}ERROR: Could not detect network interface${NC}"
    else
        echo -e "${WHITE}Interface: ${GREEN}$INTERFACE${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Network Settings:${NC}"
    echo -e "  Congestion Control: ${BLUE}$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'Not set')${NC}"
    echo -e "  Queue Discipline:   ${BLUE}$(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'Not set')${NC}"
    echo -e "  TCP Low Latency:    ${BLUE}$(cat /proc/sys/net/ipv4/tcp_low_latency 2>/dev/null || echo 'default')${NC}"
    
    echo ""
    echo -e "${YELLOW}TC Configuration:${NC}"
    for IFACE in $(ls /sys/class/net/ | grep -v lo); do
        QDISC=$(tc qdisc show dev "$IFACE" 2>/dev/null | head -1 || echo "None")
        echo -e "  ${WHITE}$IFACE: ${BLUE}$QDISC${NC}"
    done
    
    echo ""
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read
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
        read
    done
}

main_menu() {
    while true; do
        show_main_menu
        echo -e "${YELLOW}Select option [0-11]: ${NC}"
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
            9) show_status ;;
            10) backup_configs ;;
            11) remove_all_optimizations ;;
            12) handle_control_menu ;;
            0)
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option! Please select 0-11${NC}"
                ;;
        esac
        
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read
    done
}
# =============================================================================
# CONTROL MENU
# =============================================================================

show_control_menu() {
    clear
    echo -e "${CYAN}"
    echo "================================================================"
    echo "                   SYSTEM CONTROL PANEL                        "
    echo "================================================================"
    echo -e "${WHITE}Select control action:${CYAN}                             "
    echo "                                                                "
    echo -e "${GREEN}VIEW & MONITOR:${CYAN}                                  "
    echo -e "  ${GREEN}1${NC}${WHITE}. Show Current Settings${CYAN}                           "
    echo -e "  ${GREEN}2${NC}${WHITE}. Show Sysctl.conf File${CYAN}                           "
    echo -e "  ${GREEN}3${NC}${WHITE}. Show Logging Status${CYAN}                             "
    echo -e "  ${GREEN}4${NC}${WHITE}. Test Network Performance${CYAN}                        "
    echo "                                                                "
    echo -e "${BLUE}EDIT & CONFIGURE:${CYAN}                                "
    echo -e "  ${GREEN}5${NC}${WHITE}. Live Sysctl Editor${CYAN}                              "
    echo -e "  ${GREEN}6${NC}${WHITE}. Edit Sysctl.conf (Text Editor)${CYAN}                  "
    echo -e "  ${GREEN}7${NC}${WHITE}. Apply Settings Immediately${CYAN}                      "
    echo "                                                                "
    echo -e "${YELLOW}LOGGING CONTROL:${CYAN}                                "
    echo -e "  ${GREEN}8${NC}${WHITE}. Toggle System Logging${CYAN}                           "
    echo -e "  ${GREEN}9${NC}${WHITE}. Clear Log Files${CYAN}                                 "
    echo "                                                                "
    echo -e "${PURPLE}MAINTENANCE:${CYAN}                                    "
    echo -e "  ${GREEN}10${NC}${WHITE}. Backup Configurations${CYAN}                          "
    echo -e "  ${GREEN}11${NC}${WHITE}. Remove All Optimizations${CYAN}                       "
    echo "                                                                "
    echo -e "  ${GREEN}0${NC}${WHITE}. Back to Main Menu${CYAN}                             "
    echo "                                                                "
    echo "================================================================"
    echo -e "${NC}"
}

handle_control_menu() {
    while true; do
        show_control_menu
        echo -e "${YELLOW}Select option [0-11]: ${NC}"
        read -r choice
        
        case $choice in
            1) show_current_settings ;;
            2) show_sysctl_file ;;
            3) show_log_status ;;
            4) test_network_performance ;;
            5) edit_sysctl_live ;;
            6) edit_sysctl_conf ;;
            7) apply_settings_immediately ;;
            8) toggle_logging ;;
            9) clear_logs ;;
            10) backup_configs ;;
            11) remove_all_optimizations ;;
            0)
                break
                ;;
            *)
                echo -e "${RED}Invalid option! Please select 0-11${NC}"
                ;;
        esac
        
        echo -e "\n${CYAN}Press Enter to continue...${NC}"
        read
    done
}

# =============================================================================
# EDIT SYSCTL.CONF FUNCTION
# =============================================================================

edit_sysctl_conf() {
    echo -e "${YELLOW}Opening sysctl.conf for editing...${NC}"
    
    # Show file info first
    if [ -f "$SYSCTL_CONF" ]; then
        file_size=$(du -h "$SYSCTL_CONF" | cut -f1)
        line_count=$(wc -l < "$SYSCTL_CONF")
        echo -e "${WHITE}File: $SYSCTL_CONF ($file_size, $line_count lines)${NC}"
    fi
    
    # Select editor
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
    
    # Edit file
    if $editor "$SYSCTL_CONF"; then
        echo -e "${GREEN}File edited successfully${NC}"
        
        # Ask to apply changes
        echo -e "${YELLOW}Apply changes now? [y/N]: ${NC}"
        read -r apply_choice
        if [[ "$apply_choice" =~ [yY] ]]; then
            apply_settings_immediately
        else
            echo -e "${YELLOW}Remember to apply changes later with option 7${NC}"
        fi
    else
        echo -e "${RED}Error editing file${NC}"
    fi
}
# =============================================================================
# INITIALIZATION
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo $0${NC}"
    exit 1
fi

create_backup_dir
main_menu
