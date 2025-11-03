#!/bin/bash

# Define paths to configuration files
SYSCTL_CONF="/etc/sysctl.conf"
LIMITS_CONF="/etc/security/limits.conf"
BACKUP_DIR="/etc/optimizer_backups"

# Function to create backup directory
create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        echo -e "\033[1;32mCreated backup directory: $BACKUP_DIR\033[0m"
    fi
}

# Function to back up existing configurations
backup_configs() {
    create_backup_dir
    echo -e "\033[1;32mBacking up configuration files...\033[0m"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$SYSCTL_CONF" "${BACKUP_DIR}/sysctl.conf.bak.${timestamp}"
    cp "$LIMITS_CONF" "${BACKUP_DIR}/limits.conf.bak.${timestamp}"
    echo -e "\033[1;32mBackup completed: ${BACKUP_DIR}/sysctl.conf.bak.${timestamp}\033[0m"
    echo -e "\033[1;32mBackup completed: ${BACKUP_DIR}/limits.conf.bak.${timestamp}\033[0m"
}

# Function to reload sysctl configurations
reload_sysctl() {
    echo -e "\033[1;32mReloading sysctl settings...\033[0m"
    sysctl -p
}

# Function to check if a setting exists and update it
update_config() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    if grep -q "^$key" "$file"; then
        # Check if the value is already set correctly
        if grep -q "^$key.*$value" "$file"; then
            echo -e "\033[1;33mSetting $key already configured with value $value\033[0m"
        else
            sed -i "s|^$key.*|$key = $value|" "$file"
            echo -e "\033[1;32mUpdated $key to $value\033[0m"
        fi
    else
        echo "$key = $value" >> "$file"
        echo -e "\033[1;32mAdded $key with value $value\033[0m"
    fi
}

# =============================================================================
# GAMING OPTIMIZATIONS (Low Latency Focus)
# =============================================================================
apply_gaming_optimizations() {
    echo -e "\033[1;36m?? Applying GAMING Optimizations (Low Latency Focus)...\033[0m"

    declare -A gaming_settings=(
        # Memory and swap
        ["vm.swappiness"]="30"
        ["vm.dirty_ratio"]="15"
        ["vm.dirty_background_ratio"]="5"
        ["vm.dirty_expire_centisecs"]="1000"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="50"
        ["vm.min_free_kbytes"]="65536"
        
        # Core networking
        ["net.core.rmem_max"]="33554432"
        ["net.core.wmem_max"]="33554432"
        ["net.core.rmem_default"]="262144"
        ["net.core.wmem_default"]="262144"
        ["net.core.netdev_max_backlog"]="2000"
        ["net.core.netdev_budget"]="600"
        ["net.core.somaxconn"]="65535"
        ["net.core.optmem_max"]="65536"
        
        # TCP tuning for low latency
        ["net.ipv4.tcp_rmem"]="4096 87380 33554432"
        ["net.ipv4.tcp_wmem"]="4096 16384 33554432"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_low_latency"]="1"
        
        # Connection handling
        ["net.ipv4.tcp_max_syn_backlog"]="8192"
        ["net.ipv4.tcp_max_tw_buckets"]="2000000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="10"
        ["net.ipv4.tcp_keepalive_time"]="300"
        ["net.ipv4.tcp_keepalive_intvl"]="30"
        ["net.ipv4.tcp_keepalive_probes"]="3"
        
        # UDP optimization (important for games)
        ["net.ipv4.udp_rmem_min"]="8192"
        ["net.ipv4.udp_wmem_min"]="8192"
        
        # Security (gaming servers need security too)
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv4.conf.default.accept_redirects"]="0"
        ["net.ipv4.conf.all.accept_source_route"]="0"
        ["net.ipv4.conf.default.accept_source_route"]="0"
        
        # File handles
        ["fs.file-max"]="2097152"
    )

    for key in "${!gaming_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${gaming_settings[$key]}"
    done

    # Apply gaming-specific limits
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
    echo -e "\033[1;32m?? GAMING optimizations applied successfully!\033[0m"
    echo -e "\033[1;33m?? Optimized for: Low latency, fast response times, UDP performance\033[0m"
}

# =============================================================================
# STREAMING OPTIMIZATIONS (High Throughput Focus)
# =============================================================================
apply_streaming_optimizations() {
    echo -e "\033[1;36m?? Applying STREAMING Optimizations (High Throughput Focus)...\033[0m"

    declare -A streaming_settings=(
        # Memory and swap
        ["vm.swappiness"]="10"
        ["vm.dirty_ratio"]="20"
        ["vm.dirty_background_ratio"]="10"
        ["vm.dirty_expire_centisecs"]="3000"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="100"
        
        # Core networking (larger buffers for streaming)
        ["net.core.rmem_max"]="67108864"
        ["net.core.wmem_max"]="67108864"
        ["net.core.rmem_default"]="4194304"
        ["net.core.wmem_default"]="4194304"
        ["net.core.netdev_max_backlog"]="5000"
        ["net.core.somaxconn"]="65535"
        
        # TCP tuning for high throughput
        ["net.ipv4.tcp_rmem"]="8192 87380 67108864"
        ["net.ipv4.tcp_wmem"]="8192 65536 67108864"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq_codel"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_notsent_lowat"]="16384"
        
        # Connection handling
        ["net.ipv4.tcp_max_syn_backlog"]="16384"
        ["net.ipv4.tcp_max_tw_buckets"]="4000000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="15"
        ["net.ipv4.tcp_keepalive_time"]="600"
        
        # File handles
        ["fs.file-max"]="4194304"
        ["fs.nr_open"]="4194304"
        
        # Conntrack for many connections
        ["net.netfilter.nf_conntrack_max"]="262144"
        ["net.netfilter.nf_conntrack_tcp_timeout_established"]="86400"
    )

    for key in "${!streaming_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${streaming_settings[$key]}"
    done

    # Apply streaming-specific limits
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
    echo -e "\033[1;32m?? STREAMING optimizations applied successfully!\033[0m"
    echo -e "\033[1;33m?? Optimized for: High bandwidth, stable connections, large file transfers\033[0m"
}

# =============================================================================
# GENERAL PURPOSE OPTIMIZATIONS (Balanced)
# =============================================================================
apply_general_optimizations() {
    echo -e "\033[1;36m?? Applying GENERAL PURPOSE Optimizations (Balanced)...\033[0m"

    declare -A general_settings=(
        # Memory and swap
        ["vm.swappiness"]="60"
        ["vm.dirty_ratio"]="20"
        ["vm.dirty_background_ratio"]="10"
        ["vm.dirty_expire_centisecs"]="3000"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="100"
        
        # Core networking
        ["net.core.rmem_max"]="16777216"
        ["net.core.wmem_max"]="16777216"
        ["net.core.rmem_default"]="262144"
        ["net.core.wmem_default"]="262144"
        ["net.core.netdev_max_backlog"]="3000"
        ["net.core.somaxconn"]="4096"
        
        # TCP tuning (balanced)
        ["net.ipv4.tcp_rmem"]="4096 87380 16777216"
        ["net.ipv4.tcp_wmem"]="4096 16384 16777216"
        ["net.ipv4.tcp_congestion_control"]="cubic"
        ["net.core.default_qdisc"]="fq_codel"
        ["net.ipv4.tcp_fastopen"]="3"
        
        # Connection handling
        ["net.ipv4.tcp_max_syn_backlog"]="1024"
        ["net.ipv4.tcp_max_tw_buckets"]="262144"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="30"
        ["net.ipv4.tcp_keepalive_time"]="7200"
        
        # Security
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.default.rp_filter"]="1"
        
        # File handles
        ["fs.file-max"]="65536"
    )

    for key in "${!general_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${general_settings[$key]}"
    done

    # Apply general-purpose limits
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
    echo -e "\033[1;32m?? GENERAL PURPOSE optimizations applied successfully!\033[0m"
    echo -e "\033[1;33m?? Optimized for: Balanced performance, stability, everyday use\033[0m"
}

# =============================================================================
# COMPETITIVE GAMING OPTIMIZATIONS (Extreme Low Latency)
# =============================================================================
apply_competitive_gaming_optimizations() {
    echo -e "\033[1;36m?? Applying COMPETITIVE GAMING Optimizations (Extreme Low Latency)...\033[0m"

    declare -A comp_settings=(
        # Memory and swap (aggressive)
        ["vm.swappiness"]="1"
        ["vm.dirty_ratio"]="5"
        ["vm.dirty_background_ratio"]="3"
        ["vm.dirty_expire_centisecs"]="500"
        ["vm.dirty_writeback_centisecs"]="100"
        ["vm.vfs_cache_pressure"]="25"
        ["vm.min_free_kbytes"]="131072"
        
        # Core networking (minimal buffers)
        ["net.core.rmem_max"]="16777216"
        ["net.core.wmem_max"]="16777216"
        ["net.core.rmem_default"]="131072"
        ["net.core.wmem_default"]="131072"
        ["net.core.netdev_max_backlog"]="1000"
        ["net.core.netdev_budget"]="300"
        ["net.core.somaxconn"]="65535"
        ["net.core.optmem_max"]="65536"
        
        # TCP tuning (ultra low latency)
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
        
        # Connection handling (fast cleanup)
        ["net.ipv4.tcp_max_syn_backlog"]="4096"
        ["net.ipv4.tcp_max_tw_buckets"]="1800000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_fin_timeout"]="5"
        ["net.ipv4.tcp_keepalive_time"]="1800"
        ["net.ipv4.tcp_keepalive_intvl"]="15"
        ["net.ipv4.tcp_keepalive_probes"]="3"
        
        # UDP optimization
        ["net.ipv4.udp_rmem_min"]="4096"
        ["net.ipv4.udp_wmem_min"]="4096"
        
        # File handles
        ["fs.file-max"]="1048576"
    )

    for key in "${!comp_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${comp_settings[$key]}"
    done

    reload_sysctl
    echo -e "\033[1;32m?? COMPETITIVE GAMING optimizations applied successfully!\033[0m"
    echo -e "\033[1;33m??  WARNING: Very aggressive settings - may affect stability\033[0m"
    echo -e "\033[1;33m?? Optimized for: Extreme low latency, competitive gaming\033[0m"
}


# =============================================================================
# REMOVE ALL OPTIMIZATIONS (Complete Reset)
# =============================================================================
remove_all_optimizations() {
    echo -e "\033[1;31m??? Removing ALL optimizations and restoring defaults...\033[0m"
    
    # Create comprehensive backup before removal
    backup_configs
    
    # Remove ALL custom settings from sysctl.conf
    local sysctl_keys=(
        # Memory settings
        "vm.swappiness" "vm.dirty_ratio" "vm.dirty_background_ratio"
        "vm.dirty_expire_centisecs" "vm.dirty_writeback_centisecs"
        "vm.vfs_cache_pressure" "vm.min_free_kbytes" "vm.max_map_count"
        "vm.overcommit_memory" "vm.overcommit_ratio" "vm.page_cluster"
        "vm.zone_reclaim_mode" "vm.stat_interval" "vm.mmap_min_addr"
        
        # Core networking
        "net.core.rmem_max" "net.core.wmem_max" "net.core.rmem_default"
        "net.core.wmem_default" "net.core.netdev_max_backlog"
        "net.core.netdev_budget" "net.core.somaxconn" "net.core.optmem_max"
        "net.core.dev_weight" "net.core.dev_weight_rx_bias" "net.core.dev_weight_tx_bias"
        "net.core.message_cost" "net.core.message_burst" "net.core.bpf_jit_enable"
        "net.core.default_qdisc" "net.unix.max_dgram_qlen"
        
        # TCP settings
        "net.ipv4.tcp_rmem" "net.ipv4.tcp_wmem" "net.ipv4.tcp_congestion_control"
        "net.ipv4.tcp_fastopen" "net.ipv4.tcp_slow_start_after_idle"
        "net.ipv4.tcp_low_latency" "net.ipv4.tcp_no_metrics_save" "net.ipv4.tcp_timestamps"
        "net.ipv4.tcp_sack" "net.ipv4.tcp_dsack" "net.ipv4.tcp_fack"
        "net.ipv4.tcp_max_syn_backlog" "net.ipv4.tcp_max_tw_buckets" "net.ipv4.tcp_tw_reuse"
        "net.ipv4.tcp_fin_timeout" "net.ipv4.tcp_keepalive_time" "net.ipv4.tcp_keepalive_intvl"
        "net.ipv4.tcp_keepalive_probes" "net.ipv4.tcp_notsent_lowat" "net.ipv4.tcp_syncookies"
        "net.ipv4.tcp_rfc1337" "net.ipv4.tcp_abort_on_overflow" "net.ipv4.tcp_adv_win_scale"
        "net.ipv4.tcp_app_win" "net.ipv4.tcp_base_mss" "net.ipv4.tcp_comp_sack_delay_ns"
        "net.ipv4.tcp_comp_sack_nr" "net.ipv4.tcp_comp_sack_slack_ns" "net.ipv4.tcp_ecn"
        "net.ipv4.tcp_frto" "net.ipv4.tcp_limit_output_bytes" "net.ipv4.tcp_mtu_probe_floor"
        "net.ipv4.tcp_mtu_probing" "net.ipv4.tcp_probe_interval" "net.ipv4.tcp_probe_threshold"
        "net.ipv4.tcp_recovery" "net.ipv4.tcp_reordering" "net.ipv4.tcp_max_reordering"
        "net.ipv4.tcp_retries1" "net.ipv4.tcp_retries2" "net.ipv4.tcp_orphan_retries"
        "net.ipv4.tcp_syn_retries" "net.ipv4.tcp_synack_retries" "net.ipv4.tcp_thin_linear_timeouts"
        "net.ipv4.tcp_tso_win_divisor" "net.ipv4.tcp_min_tso_segs" "net.ipv4.tcp_min_snd_mss"
        "net.ipv4.tcp_min_rtt_wlen" "net.ipv4.tcp_moderate_rcvbuf" "net.ipv4.tcp_autocorking"
        "net.ipv4.tcp_reflect_tos" "net.ipv4.tcp_shrink_window" "net.ipv4.tcp_workaround_signed_windows"
        "net.ipv4.tcp_migrate_req" "net.ipv4.tcp_l3mdev_accept" "net.ipv4.tcp_fwmark_accept"
        "net.ipv4.tcp_syn_linear_timeouts" "net.ipv4.tcp_pacing_ss_ratio" "net.ipv4.tcp_pacing_ca_ratio"
        "net.ipv4.tcp_early_retrans" "net.ipv4.tcp_invalid_ratelimit" "net.ipv4.tcp_challenge_ack_limit"
        "net.ipv4.tcp_tw_reuse_delay" "net.ipv4.tcp_tso_rtt_log"
        
        # UDP settings
        "net.ipv4.udp_rmem_min" "net.ipv4.udp_wmem_min"
        
        # IPv4 general settings
        "net.ipv4.ip_forward" "net.ipv4.ip_default_ttl" "net.ipv4.ip_no_pmtu_disc"
        "net.ipv4.ip_forward_use_pmtu" "net.ipv4.fwmark_reflect" "net.ipv4.fib_multipath_use_neigh"
        "net.ipv4.fib_multipath_hash_policy"
        
        # IPv4 security
        "net.ipv4.conf.all.rp_filter" "net.ipv4.conf.default.rp_filter"
        "net.ipv4.conf.all.accept_source_route" "net.ipv4.conf.default.accept_source_route"
        "net.ipv4.conf.all.accept_redirects" "net.ipv4.conf.default.accept_redirects"
        "net.ipv4.conf.all.secure_redirects" "net.ipv4.conf.default.secure_redirects"
        "net.ipv4.conf.all.send_redirects" "net.ipv4.conf.default.send_redirects"
        "net.ipv4.conf.all.log_martians" "net.ipv4.conf.default.log_martians"
        
        # ICMP settings
        "net.ipv4.icmp_echo_ignore_all" "net.ipv4.icmp_echo_ignore_broadcasts"
        "net.ipv4.icmp_ignore_bogus_error_responses" "net.ipv4.icmp_ratelimit"
        "net.ipv4.icmp_ratemask"
        
        # Conntrack settings
        "net.netfilter.nf_conntrack_max" "net.netfilter.nf_conntrack_tcp_timeout_established"
        "net.netfilter.nf_conntrack_tcp_timeout_time_wait" "net.netfilter.nf_conntrack_tcp_timeout_close_wait"
        "net.netfilter.nf_conntrack_tcp_timeout_fin_wait" "net.netfilter.nf_conntrack_tcp_timeout_syn_sent"
        "net.netfilter.nf_conntrack_tcp_timeout_syn_recv" "net.netfilter.nf_conntrack_udp_timeout"
        "net.netfilter.nf_conntrack_udp_timeout_stream" "net.netfilter.nf_conntrack_icmp_timeout"
        "net.netfilter.nf_conntrack_generic_timeout" "net.netfilter.nf_conntrack_buckets"
        "net.netfilter.nf_conntrack_checksum" "net.netfilter.nf_conntrack_tcp_be_liberal"
        "net.netfilter.nf_conntrack_tcp_loose" "net.netfilter.nf_conntrack_log_invalid"
        
        # File system settings
        "fs.file-max" "fs.nr_open" "fs.inotify.max_user_watches"
        "fs.inotify.max_user_instances" "fs.inotify.max_queued_events"
        "fs.aio-max-nr" "fs.pipe-max-size"
        
        # Kernel scheduler settings
        "kernel.sched_latency_ns" "kernel.sched_min_granularity_ns" "kernel.sched_wakeup_granularity_ns"
        "kernel.sched_migration_cost_ns" "kernel.sched_nr_migrate" "kernel.sched_tunable_scaling"
        "kernel.sched_child_runs_first" "kernel.sched_energy_aware" "kernel.sched_schedstats"
        "kernel.sched_rr_timeslice_ms" "kernel.sched_rt_period_us" "kernel.sched_rt_runtime_us"
        "kernel.sched_cfs_bandwidth_slice_us" "kernel.sched_autogroup_enabled"
    )

    # Remove all custom settings from sysctl.conf
    for key in "${sysctl_keys[@]}"; do
        sed -i "/^\s*${key}\s*=/d" "$SYSCTL_CONF"
    done

    # Remove all custom limits from limits.conf
    local limit_keys=(
        "* soft nproc" "* hard nproc" "* soft nofile" "* hard nofile"
        "root soft nproc" "root hard nproc" "root soft nofile" "root hard nofile"
    )

    for key in "${limit_keys[@]}"; do
        sed -i "/^$key/d" "$LIMITS_CONF"
    done

    # Reload sysctl to apply default settings
    echo -e "\033[1;33m?? Reloading system defaults...\033[0m"
    sysctl -p > /dev/null 2>&1
    sysctl --system > /dev/null 2>&1

    # Reset network interfaces to defaults
    echo -e "\033[1;33m?? Resetting network settings...\033[0m"
    
    # Remove any custom TC configurations
    for interface in $(ls /sys/class/net/ | grep -v lo); do
        tc qdisc del dev "$interface" root 2>/dev/null
        tc qdisc del dev "$interface" ingress 2>/dev/null
    done

    # Reset congestion control to default
    echo "cubic" > /proc/sys/net/ipv4/tcp_congestion_control 2>/dev/null
    
    # Reset queue discipline to default
    echo "fq_codel" > /proc/sys/net/core/default_qdisc 2>/dev/null

    echo -e "\033[1;32m? ALL optimizations removed successfully!\033[0m"
    echo -e "\033[1;33m?? System restored to default settings:\033[0m"
    echo -e "   • Congestion Control: \033[1;34m$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo 'cubic')\033[0m"
    echo -e "   • Queue Discipline:   \033[1;34m$(sysctl -n net.core.default_qdisc 2>/dev/null || echo 'fq_codel')\033[0m"
    echo -e "   • File Limits:        \033[1;34mRestored to system defaults\033[0m"
    echo -e "   • Network Settings:   \033[1;34mRestored to kernel defaults\033[0m"
}

# =============================================================================
# QUICK RESET (Remove only main optimizations)
# =============================================================================
quick_reset_optimizations() {
    echo -e "\033[1;33m? Quick reset of main optimizations...\033[0m"
    
    # Remove only the main optimization settings
    local main_keys=(
        "vm.swappiness" "vm.dirty_ratio" "vm.dirty_background_ratio"
        "net.core.rmem_max" "net.core.wmem_max" "net.core.rmem_default" "net.core.wmem_default"
        "net.core.netdev_max_backlog" "net.core.somaxconn"
        "net.ipv4.tcp_rmem" "net.ipv4.tcp_wmem" "net.ipv4.tcp_congestion_control"
        "net.core.default_qdisc" "net.ipv4.tcp_fastopen" "net.ipv4.tcp_slow_start_after_idle"
        "net.ipv4.tcp_max_syn_backlog" "net.ipv4.tcp_max_tw_buckets" "fs.file-max"
    )

    for key in "${main_keys[@]}"; do
        sed -i "/^\s*${key}\s*=/d" "$SYSCTL_CONF"
    done

    # Remove main limits
    sed -i "/^* soft nofile/d; /^* hard nofile/d; /^root soft nofile/d; /^root hard nofile/d" "$LIMITS_CONF"

    reload_sysctl
    echo -e "\033[1;32m? Quick reset completed!\033[0m"
}

# =============================================================================
# NETWORK TUNING MENU (BBR & QDisc Manager)
# =============================================================================
network_tuning_menu() {
    while true; do
        clear
        echo -e "\033[1;36m==============================================\033[0m"
        echo -e "\033[1;36m           NETWORK TUNING MANAGER            \033[0m"
        echo -e "\033[1;36m==============================================\033[0m"
        echo
        
        # Current settings
        echo -e "\033[1;35mCURRENT SETTINGS:\033[0m"
        echo -e "  Congestion Control: \033[1;34m$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "Not set")\033[0m"
        echo -e "  Queue Discipline:   \033[1;34m$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "Not set")\033[0m"
        echo
        
        # Quick apply presets
        echo -e "\033[1;33m?? QUICK PRESETS:\033[0m"
        echo -e "  1. ?? Gaming Preset (BBR + fq)"
        echo -e "  2. ?? Streaming Preset (BBR + fq_codel)" 
        echo -e "  3. ?? General Preset (CUBIC + fq_codel)"
        echo -e "  4. ?? Competitive Preset (BBR + fq, aggressive)"
        echo
        
        # Manual tuning
        echo -e "\033[1;33mMANUAL TUNING:\033[0m"
        echo -e "  5. Set Custom Congestion Control"
        echo -e "  6. Set Custom Queue Discipline"
        echo -e "  7. List Available Algorithms"
        echo -e "  8. Test Network Performance"
        echo -e "  9. Reset to System Defaults"
        echo
        echo -e "  0. ?? Return to Main Menu"
        echo
        echo -e "\033[1;36m==============================================\033[0m"

        read -p "$(echo -e '\033[1;32mSelect an option [0-9]: \033[0m')" choice

        case $choice in
            1)
                sysctl -w net.ipv4.tcp_congestion_control=bbr
                sysctl -w net.core.default_qdisc=fq
                update_config "$SYSCTL_CONF" "net.ipv4.tcp_congestion_control" "bbr"
                update_config "$SYSCTL_CONF" "net.core.default_qdisc" "fq"
                echo -e "\033[1;32m? Gaming preset applied: BBR + fq\033[0m"
                ;;
            2)
                sysctl -w net.ipv4.tcp_congestion_control=bbr
                sysctl -w net.core.default_qdisc=fq_codel
                update_config "$SYSCTL_CONF" "net.ipv4.tcp_congestion_control" "bbr"
                update_config "$SYSCTL_CONF" "net.core.default_qdisc" "fq_codel"
                echo -e "\033[1;32m? Streaming preset applied: BBR + fq_codel\033[0m"
                ;;
            3)
                sysctl -w net.ipv4.tcp_congestion_control=cubic
                sysctl -w net.core.default_qdisc=fq_codel
                update_config "$SYSCTL_CONF" "net.ipv4.tcp_congestion_control" "cubic"
                update_config "$SYSCTL_CONF" "net.core.default_qdisc" "fq_codel"
                echo -e "\033[1;32m? General preset applied: CUBIC + fq_codel\033[0m"
                ;;
            4)
                sysctl -w net.ipv4.tcp_congestion_control=bbr
                sysctl -w net.core.default_qdisc=fq
                sysctl -w net.ipv4.tcp_low_latency=1
                sysctl -w net.ipv4.tcp_no_metrics_save=1
                update_config "$SYSCTL_CONF" "net.ipv4.tcp_congestion_control" "bbr"
                update_config "$SYSCTL_CONF" "net.core.default_qdisc" "fq"
                update_config "$SYSCTL_CONF" "net.ipv4.tcp_low_latency" "1"
                update_config "$SYSCTL_CONF" "net.ipv4.tcp_no_metrics_save" "1"
                echo -e "\033[1;32m? Competitive preset applied: BBR + fq (aggressive)\033[0m"
                ;;
            5) set_custom_cc ;;
            6) set_custom_qdisc ;;
            7) list_algorithms ;;
            8) test_network_performance ;;
            9) reset_network_tuning ;;
            0) break ;;
            *) echo -e "\033[1;31m? Invalid option\033[0m" ;;
        esac

        echo -e "\n\033[1;34mPress Enter to continue...\033[0m"
        read
    done
}

# =============================================================================
# SUPPORTING FUNCTIONS
# =============================================================================
set_custom_cc() {
    echo -e "\033[1;36mAvailable Congestion Controls:\033[0m"
    sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | tr ' ' '\n'
    echo
    read -p "Enter congestion control algorithm: " cc_algo
    sysctl -w net.ipv4.tcp_congestion_control=$cc_algo
    update_config "$SYSCTL_CONF" "net.ipv4.tcp_congestion_control" "$cc_algo"
    echo -e "\033[1;32m? Congestion control set to: $cc_algo\033[0m"
}

set_custom_qdisc() {
    echo -e "\033[1;36mAvailable Queue Disciplines:\033[0m"
    tc qdisc list | grep -o '^[^ ]*' | sort | uniq
    echo
    read -p "Enter queue discipline: " qdisc
    sysctl -w net.core.default_qdisc=$qdisc
    update_config "$SYSCTL_CONF" "net.core.default_qdisc" "$qdisc"
    echo -e "\033[1;32m? Queue discipline set to: $qdisc\033[0m"
}

list_algorithms() {
    echo -e "\033[1;36m?? Available Congestion Control Algorithms:\033[0m"
    sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | tr ' ' '\n' | while read algo; do
        echo -e "  \033[1;34m$algo\033[0m"
    done
}

test_network_performance() {
    echo -e "\033[1;36m?? Testing Network Performance...\033[0m"
    if command -v ping &> /dev/null; then
        echo -e "\033[1;33mPing Test (Google DNS):\033[0m"
        ping -c 4 8.8.8.8 | tail -2
    fi
}

reset_network_tuning() {
    sed -i '/^net.ipv4.tcp_congestion_control/d; /^net.core.default_qdisc/d; /^net.ipv4.tcp_low_latency/d; /^net.ipv4.tcp_no_metrics_save/d' "$SYSCTL_CONF"
    sysctl -p
    echo -e "\033[1;32m? Network tuning reset to system defaults\033[0m"
}

# =============================================================================
# MAIN MENU
# =============================================================================
main_menu() {
    while true; do
        clear
        echo -e "\033[1;36m==============================================\033[0m"
        echo -e "\033[1;36m           NETWORK OPTIMIZER TOOL            \033[0m"
        echo -e "\033[1;36m==============================================\033[0m"
        echo
        echo -e "\033[1;33mMAIN MENU:\033[0m"
        echo
        echo -e "\033[1;32mCONFIGURATION MANAGEMENT:\033[0m"
        echo -e "  1. Backup Current Configuration"
        echo -e "  2. Show Current sysctl Settings"
        echo -e "  3. Edit sysctl.conf Manually"
        echo -e "  4. Apply Changes (sysctl -p)"
        echo
        echo -e "\033[1;34mOPTIMIZATION PROFILES:\033[0m"
        echo -e "  5. Apply GAMING Optimizations"
        echo -e "  6. Apply STREAMING Optimizations" 
        echo -e "  7. Apply GENERAL PURPOSE Optimizations"
        echo -e "  8. Apply COMPETITIVE GAMING Optimizations"
        echo
        echo -e "\033[1;35mADVANCED TOOLS:\033[0m"
        echo -e "  9. Network Tuning Manager (BBR/QDisc)"
        echo -e "  10. Remove All Optimizations"
        echo -e "  11. Disable System Logging (rsyslog)"
        echo -e "  12. Remove Optimizations (Reset to defaults)"
        echo -e "  0. ?? Exit"
        echo
        echo -e "\033[1;36m==============================================\033[0m"

        read -p "$(echo -e '\033[1;32mSelect an option [0-11]: \033[0m')" choice

        case $choice in
            1) backup_configs ;;
            2) show_sysctl_conf ;;
            3) edit_sysctl_conf ;;
            4) reload_sysctl ;;
            5) apply_gaming_optimizations ;;
            6) apply_streaming_optimizations ;;
            7) apply_general_optimizations ;;
            8) apply_competitive_gaming_optimizations ;;
            9) network_tuning_menu ;;
            10) remove_all_optimizations ;;
            11) 
                systemctl stop rsyslog 2>/dev/null
                systemctl disable rsyslog 2>/dev/null
                echo -e "\033[1;32m? System logging disabled\033[0m"
                ;;
            12) remove_optimizations_menu ;;
            
            0)
                echo -e "\033[1;36mGoodbye!\033[0m"
                exit 0
                ;;
            *) echo -e "\033[1;31m? Invalid option\033[0m" ;;
        esac

        echo -e "\n\033[1;34mPress Enter to continue...\033[0m"
        read
    done
}
# =============================================================================
# REMOVE OPTIMIZATIONS SUBMENU
# =============================================================================
remove_optimizations_menu() {
    while true; do
        clear
        echo -e "\033[1;36m==============================================\033[0m"
        echo -e "\033[1;36m           REMOVE OPTIMIZATIONS              \033[0m"
        echo -e "\033[1;36m==============================================\033[0m"
        echo
        echo -e "\033[1;31m??  WARNING: This will remove optimizations\033[0m"
        echo
        echo -e "\033[1;33m?? REMOVAL OPTIONS:\033[0m"
        echo -e "  1. Remove ALL optimizations (Complete reset)"
        echo -e "  2. Quick reset (Main settings only)"
        echo -e "  3. Remove specific profile"
        echo -e "  4. Show current optimizations"
        echo
        echo -e "  0. Back to Main Menu"
        echo
        echo -e "\033[1;36m==============================================\033[0m"

        read -p "$(echo -e '\033[1;32mSelect removal option [0-4]: \033[0m')" choice

        case $choice in
            1)
                echo -e "\033[1;31mAre you sure you want to remove ALL optimizations? [y/N]: \033[0m"
                read -n 1 confirm
                echo
                if [[ $confirm =~ [yY] ]]; then
                    remove_all_optimizations
                else
                    echo -e "\033[1;33m? Removal cancelled\033[0m"
                fi
                ;;
            2)
                echo -e "\033[1;33mQuick reset main optimizations? [y/N]: \033[0m"
                read -n 1 confirm
                echo
                if [[ $confirm =~ [yY] ]]; then
                    quick_reset_optimizations
                else
                    echo -e "\033[1;33m? Reset cancelled\033[0m"
                fi
                ;;
            3)
                remove_specific_profile
                ;;
            4)
                show_current_optimizations
                ;;
            0)
                break
                ;;
            *)
                echo -e "\033[1;31m? Invalid option\033[0m"
                ;;
        esac

        echo -e "\n\033[1;34mPress Enter to continue...\033[0m"
        read
    done
}

# =============================================================================
# REMOVE SPECIFIC PROFILE
# =============================================================================
remove_specific_profile() {
    echo -e "\033[1;36mSelect profile to remove:\033[0m"
    echo -e "  1. ?? Gaming optimizations"
    echo -e "  2. ?? Streaming optimizations" 
    echo -e "  3. ?? General purpose optimizations"
    echo -e "  4. ?? Competitive gaming optimizations"
    echo -e "  5. ?? Network tuning only"
    echo
    read -p "$(echo -e '\033[1;32mSelect profile [1-5]: \033[0m')" profile_choice

    case $profile_choice in
        1) remove_gaming_optimizations ;;
        2) remove_streaming_optimizations ;;
        3) remove_general_optimizations ;;
        4) remove_competitive_optimizations ;;
        5) reset_network_tuning ;;
        *) echo -e "\033[1;31m? Invalid choice\033[0m" ; return ;;
    esac
}

# =============================================================================
# PROFILE-SPECIFIC REMOVAL FUNCTIONS
# =============================================================================
remove_gaming_optimizations() {
    echo -e "\033[1;33mRemoving gaming optimizations...\033[0m"
    local gaming_keys=(
        "vm.swappiness=30" "vm.dirty_ratio=15" "vm.dirty_background_ratio=5"
        "net.core.rmem_max=33554432" "net.core.wmem_max=33554432"
        "net.ipv4.tcp_rmem=4096 87380 33554432" "net.ipv4.tcp_wmem=4096 16384 33554432"
        "net.ipv4.tcp_low_latency=1" "net.ipv4.udp_rmem_min=8192" "net.ipv4.udp_wmem_min=8192"
    )
    remove_specific_settings "${gaming_keys[@]}"
}

remove_streaming_optimizations() {
    echo -e "\033[1;33mRemoving streaming optimizations...\033[0m"
    local streaming_keys=(
        "vm.swappiness=10" "vm.dirty_ratio=20" "vm.dirty_background_ratio=10"
        "net.core.rmem_max=67108864" "net.core.wmem_max=67108864"
        "net.ipv4.tcp_rmem=8192 87380 67108864" "net.ipv4.tcp_wmem=8192 65536 67108864"
        "net.ipv4.tcp_notsent_lowat=16384" "net.netfilter.nf_conntrack_max=262144"
    )
    remove_specific_settings "${streaming_keys[@]}"
}

remove_general_optimizations() {
    echo -e "\033[1;33mRemoving general optimizations...\033[0m"
    local general_keys=(
        "vm.swappiness=60" "vm.dirty_ratio=20" "vm.dirty_background_ratio=10"
        "net.core.rmem_max=16777216" "net.core.wmem_max=16777216"
        "net.ipv4.tcp_rmem=4096 87380 16777216" "net.ipv4.tcp_wmem=4096 16384 16777216"
    )
    remove_specific_settings "${general_keys[@]}"
}

remove_competitive_optimizations() {
    echo -e "\033[1;33mRemoving competitive gaming optimizations...\033[0m"
    local competitive_keys=(
        "vm.swappiness=1" "vm.dirty_ratio=5" "vm.dirty_background_ratio=3"
        "net.ipv4.tcp_no_metrics_save=1" "net.ipv4.tcp_timestamps=0"
        "net.ipv4.tcp_sack=0" "net.ipv4.tcp_dsack=0" "net.ipv4.tcp_fack=0"
    )
    remove_specific_settings "${competitive_keys[@]}"
}

# =============================================================================
# GENERIC SETTING REMOVAL FUNCTION
# =============================================================================
remove_specific_settings() {
    local settings=("$@")
    for setting in "${settings[@]}"; do
        local key="${setting%=*}"
        sed -i "/^\s*${key}\s*=/d" "$SYSCTL_CONF"
    done
    reload_sysctl
    echo -e "\033[1;32m? Specific optimizations removed!\033[0m"
}

# =============================================================================
# SHOW CURRENT OPTIMIZATIONS
# =============================================================================
show_current_optimizations() {
    echo -e "\033[1;36m?? CURRENT OPTIMIZATIONS:\033[0m"
    echo
    echo -e "\033[1;33mKey Settings:\033[0m"
    echo -e "  Congestion Control: \033[1;34m$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null)\033[0m"
    echo -e "  Queue Discipline:   \033[1;34m$(sysctl -n net.core.default_qdisc 2>/dev/null)\033[0m"
    echo -e "  TCP rmem:           \033[1;34m$(sysctl -n net.ipv4.tcp_rmem 2>/dev/null)\033[0m"
    echo -e "  TCP wmem:           \033[1;34m$(sysctl -n net.ipv4.tcp_wmem 2>/dev/null)\033[0m"
    echo -e "  File max:           \033[1;34m$(sysctl -n fs.file-max 2>/dev/null)\033[0m"
    echo
    echo -e "\033[1;33mCustom settings in sysctl.conf:\033[0m"
    grep -v "^#" "$SYSCTL_CONF" | grep -v "^$" | head -20
}
# =============================================================================
# SUPPORTING FUNCTIONS FOR MAIN MENU
# =============================================================================
show_sysctl_conf() {
    echo -e "\033[1;34m?? Current sysctl.conf:\033[0m"
    if [ -f "$SYSCTL_CONF" ]; then
        cat "$SYSCTL_CONF"
    else
        echo -e "\033[1;31m? sysctl.conf not found\033[0m"
    fi
}

edit_sysctl_conf() {
    if command -v nano &> /dev/null; then
        nano "$SYSCTL_CONF"
    elif command -v vim &> /dev/null; then
        vim "$SYSCTL_CONF"
    elif command -v vi &> /dev/null; then
        vi "$SYSCTL_CONF"
    else
        echo -e "\033[1;31m? No text editor found. Install nano, vim, or vi.\033[0m"
    fi
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "\033[1;31m? Please run as root: sudo $0\033[0m"
    exit 1
fi

# Create backup directory
create_backup_dir

# Start the main menu
main_menu
