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
# CORE FUNCTIONS
# =============================================================================

create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
    fi
}

backup_configs() {
    create_backup_dir
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    if [ -f "$SYSCTL_CONF" ]; then
        cp "$SYSCTL_CONF" "${BACKUP_DIR}/sysctl.conf.bak.${timestamp}"
    fi
    
    if [ -f "$LIMITS_CONF" ]; then
        cp "$LIMITS_CONF" "${BACKUP_DIR}/limits.conf.bak.${timestamp}"
    fi
}

reload_sysctl() {
    sysctl -p > /dev/null 2>&1
}

update_config() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    if [ ! -f "$file" ]; then
        touch "$file"
    fi
    
    if grep -q "^$key" "$file"; then
        if ! grep -q "^$key.*$value" "$file"; then
            sed -i "s|^$key.*|$key = $value|" "$file"
        fi
    else
        echo "$key = $value" >> "$file"
    fi
}

# =============================================================================
# SYSCTL OPTIMIZATION PROFILES
# =============================================================================

apply_gaming_optimizations() {
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
    done

    reload_sysctl
}

apply_streaming_optimizations() {
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
    done

    reload_sysctl
}

apply_general_optimizations() {
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
    done

    reload_sysctl
}

apply_competitive_gaming_optimizations() {
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
}

# =============================================================================
# TC OPTIMIZATION FUNCTIONS
# =============================================================================

create_tc_optimizer_script() {
    local category="$1"
    
    cat > "$TC_SCRIPT_PATH" << EOF
#!/bin/bash
# TC Optimizer - $category Mode
# Runs at startup via cron

LOG_FILE="/var/log/tc_optimizer.log"

log() {
    echo "\$(date): \$1" >> "\$LOG_FILE"
}

sleep 30

INTERFACE=\$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print \$5; exit}')

if [ -z "\$INTERFACE" ]; then
    log "ERROR: No network interface found"
    exit 1
fi

log "Starting TC $category optimization on \$INTERFACE"

tc qdisc del dev "\$INTERFACE" root 2>/dev/null
tc qdisc del dev "\$INTERFACE" ingress 2>/dev/null

EOF

    case "$category" in
        "gaming")
            cat >> "$TC_SCRIPT_PATH" << 'GAMING_EOF'
echo 256 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
ethtool -A "$INTERFACE" rx off tx off 2>/dev/null
if tc qdisc add dev "$INTERFACE" root cake bandwidth 1000mbit besteffort dual-dsthost nat nowash no-ack-filter 2>/dev/null; then
    log "Applied CAKE for gaming"
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 1000 flows 1024 target 2ms interval 20ms noecn 2>/dev/null; then
    log "Applied FQ_Codel for gaming"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    log "Applied PFIFO_FAST for gaming"
fi
GAMING_EOF
            ;;
        "high-loss")
            cat >> "$TC_SCRIPT_PATH" << 'HIGHLOSS_EOF'
echo 4000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null
if tc qdisc add dev "$INTERFACE" root cake bandwidth 850mbit besteffort ack-filter nat nowash 2>/dev/null; then
    log "Applied CAKE for high-loss"
elif tc qdisc add dev "$INTERFACE" root fq_codel limit 30000 flows 4096 ecn ce-threshold 1ms 2>/dev/null; then
    log "Applied FQ_Codel for high-loss"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    log "Applied PFIFO_FAST for high-loss"
fi
HIGHLOSS_EOF
            ;;
        "general")
            cat >> "$TC_SCRIPT_PATH" << 'GENERAL_EOF'
echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
if tc qdisc add dev "$INTERFACE" root cake bandwidth 1000mbit besteffort nat nowash 2>/dev/null; then
    log "Applied CAKE for general"
elif tc qdisc add dev "$INTERFACE" root fq_codel ecn ce-threshold 4ms 2>/dev/null; then
    log "Applied FQ_Codel for general"
else
    tc qdisc add dev "$INTERFACE" root pfifo_fast
    log "Applied PFIFO_FAST for general"
fi
GENERAL_EOF
            ;;
    esac

    cat >> "$TC_SCRIPT_PATH" << 'EOF'

if tc qdisc show dev "$INTERFACE" | grep -q "cake\|fq_codel\|pfifo"; then
    log "TC $category optimization completed successfully"
else
    log "ERROR: Failed to verify queue discipline"
    exit 1
fi

exit 0
EOF

    chmod +x "$TC_SCRIPT_PATH"
}

check_startup_status() {
    if crontab -l 2>/dev/null | grep -q "$TC_SCRIPT_NAME"; then
        return 0
    else
        return 1
    fi
}

enable_startup_optimizations() {
    local category="${1:-general}"
    
    if ! create_tc_optimizer_script "$category"; then
        return 1
    fi
    
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$TC_SCRIPT_NAME" > "$temp_cron"
    
    echo "@reboot sleep 30 && $TC_SCRIPT_PATH" >> "$temp_cron"
    
    if crontab "$temp_cron"; then
        rm -f "$temp_cron"
        return 0
    else
        rm -f "$temp_cron"
        return 1
    fi
}

disable_startup_optimizations() {
    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null | grep -v "$TC_SCRIPT_NAME" > "$temp_cron"
    
    if crontab "$temp_cron"; then
        rm -f "$temp_cron"
    else
        rm -f "$temp_cron"
        return 1
    fi
    
    if [ -f "$TC_SCRIPT_PATH" ]; then
        rm -f "$TC_SCRIPT_PATH"
    fi
    
    return 0
}

ask_startup_config() {
    local category="$1"
    
    echo ""
    echo "=============================================="
    echo "STARTUP CONFIGURATION"
    echo "=============================================="
    echo "Do you want to run TC optimizations automatically at system startup?"
    echo ""
    echo "Y - Yes, enable on startup"
    echo "N - No, run only once"
    echo "S - Show current startup status"
    echo "D - Disable startup optimizations"
    echo ""
    echo -n "Your choice [Y/n/S/d]: "
    
    read -r choice
    case "${choice:-y}" in
        [Yy]*) enable_startup_optimizations "$category" ;;
        [Nn]*) ;;
        [Ss]*) 
            check_startup_status
            echo ""
            echo -n "Press Enter to continue..."
            read -r
            ask_startup_config "$category"
            ;;
        [Dd]*) disable_startup_optimizations ;;
        *) ask_startup_config "$category" ;;
    esac
}

cleanup_tc() {
    local interface="$1"
    tc qdisc del dev "$interface" root 2>/dev/null
    tc qdisc del dev "$interface" ingress 2>/dev/null
    echo 1000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
}

apply_tc_gaming_optimizations() {
    local interface="$1"
    
    echo 256 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
    ethtool -A "$interface" rx off tx off 2>/dev/null
    
    if tc qdisc add dev "$interface" root cake bandwidth 1000mbit besteffort dual-dsthost nat nowash no-ack-filter 2>/dev/null; then
        return 0
    elif tc qdisc add dev "$interface" root fq_codel limit 1000 flows 1024 target 2ms interval 20ms noecn 2>/dev/null; then
        return 0
    elif tc qdisc add dev "$interface" root pfifo_fast 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

apply_tc_high_loss_optimizations() {
    local interface="$1"
    
    echo 4000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
    echo 1 > /proc/sys/net/ipv4/tcp_ecn 2>/dev/null
    
    if tc qdisc add dev "$interface" root cake bandwidth 850mbit besteffort ack-filter nat nowash 2>/dev/null; then
        return 0
    elif tc qdisc add dev "$interface" root fq_codel limit 30000 flows 4096 ecn ce-threshold 1ms 2>/dev/null; then
        return 0
    elif tc qdisc add dev "$interface" root pfifo_fast 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

apply_tc_general_optimizations() {
    local interface="$1"
    
    echo 1000 > "/sys/class/net/$interface/tx_queue_len" 2>/dev/null
    
    if tc qdisc add dev "$interface" root cake bandwidth 1000mbit besteffort nat nowash 2>/dev/null; then
        return 0
    elif tc qdisc add dev "$interface" root fq_codel ecn ce-threshold 4ms 2>/dev/null; then
        return 0
    elif tc qdisc add dev "$interface" root pfifo_fast 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

tc_optimize_by_category() {
    local category="${1:-general}"
    local auto_mode="${2:-false}"
    
    echo "=============================================="
    echo "        TC OPTIMIZER - $category MODE"
    echo "=============================================="
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    
    if [ -z "$INTERFACE" ]; then
        return 1
    fi
    
    cleanup_tc "$INTERFACE"
    
    case "$category" in
        "gaming") apply_tc_gaming_optimizations "$INTERFACE" ;;
        "high-loss") apply_tc_high_loss_optimizations "$INTERFACE" ;;
        "general") apply_tc_general_optimizations "$INTERFACE" ;;
        *) return 1 ;;
    esac
    
    local result=$?
    
    echo ""
    echo "=============================================="
    if [ $result -eq 0 ]; then
        echo "$category OPTIMIZATION COMPLETE"
        echo "Interface: $INTERFACE"
        echo "Queue Discipline: $(tc qdisc show dev "$INTERFACE" | head -1 | awk '{print $2}')"
    else
        echo "$category OPTIMIZATION FAILED"
    fi
    echo "=============================================="
    
    if [ "$auto_mode" = "false" ] && [ $result -eq 0 ]; then
        ask_startup_config "$category"
    fi
    
    return $result
}

apply_netem_testing() {
    local condition="$1"
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -z "$INTERFACE" ]; then
        return 1
    fi
    
    cleanup_tc "$INTERFACE"
    apply_tc_general_optimizations "$INTERFACE"
    
    local handle=$(tc qdisc show dev "$INTERFACE" 2>/dev/null | head -1 | awk '{print $3}')
    if [ -z "$handle" ]; then
        return 1
    fi
    
    case "$condition" in
        "gaming-latency") tc qdisc change dev "$INTERFACE" root netem delay 10ms 2ms distribution normal ;;
        "high-loss") tc qdisc change dev "$INTERFACE" root netem loss 5% 25% ;;
        "wireless") tc qdisc change dev "$INTERFACE" root netem delay 20ms 10ms loss 2% 10% duplicate 1% ;;
        "satellite") tc qdisc change dev "$INTERFACE" root netem delay 600ms 100ms loss 1% ;;
        "internet-typical") tc qdisc change dev "$INTERFACE" root netem delay 30ms 5ms loss 0.5% 10% ;;
    esac
}

tc_remove_optimizations() {
    disable_startup_optimizations
    
    for INTERFACE in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev "$INTERFACE" root 2>/dev/null
        tc qdisc del dev "$INTERFACE" ingress 2>/dev/null
        echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null
    done
}

# =============================================================================
# REMOVAL FUNCTIONS
# =============================================================================

remove_all_optimizations() {
    backup_configs
    
    tc_remove_optimizations
    
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

    sysctl -p > /dev/null 2>&1
    sysctl --system > /dev/null 2>&1

    echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    echo "fq_codel" > /proc/sys/net/core/default_qdisc 2>/dev/null
}

# =============================================================================
# CONTROL FUNCTIONS
# =============================================================================

show_current_settings() {
    echo "================================================================"
    echo "                   CURRENT SYSTEM SETTINGS                     "
    echo "================================================================"
    
    echo "NETWORK SETTINGS:"
    echo "  Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'default')"
    echo "  Queue Discipline:   $(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'default')"
    echo "  TCP Low Latency:    $(sysctl -n net.ipv4.tcp_low_latency 2>/dev/null || echo '0')"
    
    echo "MEMORY SETTINGS:"
    echo "  Swappiness:         $(sysctl -n vm.swappiness 2>/dev/null || echo '60')"
    echo "  Dirty Ratio:        $(sysctl -n vm.dirty_ratio 2>/dev/null || echo '20')"
    echo "  Dirty Background:   $(sysctl -n vm.dirty_background_ratio 2>/dev/null || echo '10')"
    
    echo "TRAFFIC CONTROL:"
    for IFACE in $(ls /sys/class/net/ | grep -v lo); do
        if [ -d "/sys/class/net/$IFACE" ]; then
            QDISC=$(tc qdisc show dev "$IFACE" 2>/dev/null | head -1 || echo "None")
            echo "  $IFACE: $QDISC"
        fi
    done
    
    echo "STARTUP STATUS:"
    check_startup_status
}

edit_sysctl_live() {
    echo "Live Sysctl Editor - Current Values:"
    echo "Format: key = value"
    echo "Enter 'quit' to exit, 'list' to show current"
    
    while true; do
        echo ""
        echo "Enter setting to change:"
        read -r input
        
        case "$input" in
            quit|exit) break ;;
            list|show) show_current_settings ;;
            "") continue ;;
            *=*)
                key=$(echo "$input" | cut -d'=' -f1 | xargs)
                value=$(echo "$input" | cut -d'=' -f2 | xargs)
                
                if [[ ! "$key" =~ ^[a-zA-Z0-9_.]+$ ]]; then
                    continue
                fi
                
                if sysctl -w "$key=$value" 2>/dev/null; then
                    if grep -q "^$key" "$SYSCTL_CONF" 2>/dev/null; then
                        sed -i "s|^$key.*|$key = $value|" "$SYSCTL_CONF"
                    else
                        echo "$key = $value" >> "$SYSCTL_CONF"
                    fi
                fi
                ;;
            *)
                current=$(sysctl -n "$input" 2>/dev/null)
                if [ $? -eq 0 ]; then
                    echo "Current: $input = $current"
                fi
                ;;
        esac
    done
}

apply_settings_immediately() {
    sysctl -p > /dev/null 2>&1
}

test_network_performance() {
    echo "================================================================"
    echo "                   NETWORK PERFORMANCE TEST                    "
    echo "================================================================"
    
    INTERFACE=$(ip route get 8.8.8.8 2>/dev/null | awk '/dev/ {print $5; exit}')
    if [ -z "$INTERFACE" ]; then
        return 1
    fi
    
    echo "Interface: $INTERFACE"
    
    if command -v ping >/dev/null 2>&1; then
        echo "PING TEST (Google DNS):"
        ping -c 4 -W 2 8.8.8.8 2>/dev/null | grep -E "packets|rtt|loss" || echo "Ping test failed"
    fi
    
    if command -v tc >/dev/null 2>&1; then
        echo "TRAFFIC CONTROL STATUS:"
        tc qdisc show dev "$INTERFACE"
    fi
}

show_sysctl_file() {
    echo "================================================================"
    echo "                   SYSCTL.CONF CONTENTS                        "
    echo "================================================================"
    
    if [ -f "$SYSCTL_CONF" ]; then
        if [ -s "$SYSCTL_CONF" ]; then
            grep -v '^#' "$SYSCTL_CONF" | grep -v '^$' | while read line; do
                echo "  $line"
            done
            
            total_lines=$(grep -v '^#' "$SYSCTL_CONF" | grep -v '^$' | wc -l)
            echo "Total active settings: $total_lines"
        else
            echo "sysctl.conf is empty"
        fi
    else
        echo "sysctl.conf not found"
    fi
}

edit_sysctl_conf() {
    if command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vim >/dev/null 2>&1; then
        editor="vim"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    else
        return 1
    fi
    
    if $editor "$SYSCTL_CONF"; then
        echo "Apply changes now? [y/N]: "
        read -r apply_choice
        if [[ "$apply_choice" =~ [yY] ]]; then
            apply_settings_immediately
        fi
    fi
}

# =============================================================================
# MENU SYSTEM
# =============================================================================

show_main_menu() {
    clear
    echo "================================================================"
    echo "           NETWORK OPTIMIZER TOOL - MAIN MENU                  "
    echo "================================================================"
    echo
    echo "SYSCTL OPTIMIZATIONS:"
    echo "  1. Gaming (Low Latency)"
    echo "  2. Streaming (High Throughput)"
    echo "  3. General Purpose (Balanced)"
    echo "  4. Competitive Gaming (Extreme)"
    echo
    echo "TC OPTIMIZATIONS:"
    echo "  5. TC Gaming Mode"
    echo "  6. TC High Loss Mode"
    echo "  7. TC General Mode"
    echo "  8. NetEM Testing"
    echo
    echo "TOOLS & MANAGEMENT:"
    echo "  9. Show Current Status"
    echo "  10. Backup Configurations"
    echo
    echo "VIEW & MONITOR:"
    echo "  11. Show Current Settings"
    echo "  12. Show Sysctl.conf File"
    echo "  13. Test Network Performance"
    echo
    echo "EDIT & CONFIGURE:"
    echo "  14. Live Sysctl Editor"
    echo "  15. Edit Sysctl.conf (Text Editor)"
    echo "  16. Apply Settings Immediately"
    echo
    echo "MAINTENANCE:"
    echo "  17. Backup Configurations"
    echo "  18. Remove All Optimizations"
    echo
    echo "  0. Exit"
    echo "================================================================"
}

show_netem_menu() {
    clear
    echo "================================================================"
    echo "                   NETEM TESTING MENU                          "
    echo "================================================================"
    echo "Simulate network conditions:"
    echo
    echo "  1. Gaming Latency (10ms +-2ms)"
    echo "  2. High Packet Loss (5% loss)"
    echo "  3. Wireless Conditions (20ms + 2% loss)"
    echo "  4. Satellite Latency (600ms + 1% loss)"
    echo "  5. Internet Typical (30ms + 0.5% loss)"
    echo
    echo "  0. Back to Main Menu"
    echo "================================================================"
}

handle_netem_menu() {
    while true; do
        show_netem_menu
        echo "Select test condition [0-5]: "
        read -r choice
        
        case $choice in
            1) apply_netem_testing "gaming-latency" ;;
            2) apply_netem_testing "high-loss" ;;
            3) apply_netem_testing "wireless" ;;
            4) apply_netem_testing "satellite" ;;
            5) apply_netem_testing "internet-typical" ;;
            0) break ;;
            *) ;;
        esac
        
        echo "Press Enter to continue..."
        read -r
    done
}

main_menu() {
    while true; do
        show_main_menu
        echo "Select option: "
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
            0) exit 0 ;;
            *) ;;
        esac
        
        echo "Press Enter to continue..."
        read -r
    done
}

# =============================================================================
# INITIALIZATION
# =============================================================================

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo $0"
    exit 1
fi

for cmd in sysctl tc ip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        exit 1
    fi
done

create_backup_dir
main_menu
