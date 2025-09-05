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

# Function to apply optimizations (overwrite existing values only)
apply_optimizations() {
    echo -e "\033[1;32mApplying optimizations...\033[0m"

    # Update /etc/sysctl.conf with new configurations
    declare -A sysctl_settings=(
        # Gaming-optimized sysctl settings
        ["vm.swappiness"]="10"
        ["vm.dirty_ratio"]="30"
        ["vm.dirty_background_ratio"]="10"
        ["fs.file-max"]="2097152"
        ["net.core.somaxconn"]="1024"
        ["net.core.netdev_max_backlog"]="4096"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.ipv4.ip_nonlocal_bind"]="1"
        ["net.ipv4.tcp_keepalive_time"]="300"
        ["net.ipv4.tcp_keepalive_intvl"]="30"
        ["net.ipv4.tcp_keepalive_probes"]="5"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.tcp_max_orphans"]="65536"
        ["net.ipv4.tcp_max_syn_backlog"]="2048"
        ["net.ipv4.tcp_max_tw_buckets"]="1048576"
        ["net.ipv4.tcp_reordering"]="3"
        ["net.ipv4.tcp_mem"]="786432 1697152 1945728"
        ["net.ipv4.tcp_rmem"]="4096 262144 16777216"
        ["net.ipv4.tcp_wmem"]="4096 65536 16777216"
        ["net.ipv4.tcp_syn_retries"]="3"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_mtu_probing"]="1"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.default.rp_filter"]="1"
        ["net.ipv4.ip_no_pmtu_disc"]="0"
        ["vm.vfs_cache_pressure"]="50"
        ["net.ipv4.tcp_fastopen"]="0"
        ["net.ipv4.tcp_ecn"]="0"
        ["net.ipv4.tcp_retries2"]="5"
        ["net.ipv6.conf.all.forwarding"]="1"
        ["net.ipv4.conf.all.forwarding"]="1"
        ["net.ipv4.tcp_low_latency"]="0"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.core.default_qdisc"]="fq_codel"
        ["net.netfilter.nf_conntrack_max"]="65536"
        ["net.ipv4.tcp_fin_timeout"]="15"
        ["net.netfilter.nf_conntrack_log_invalid"]="0"
        ["net.ipv4.conf.all.log_martians"]="0"
        ["net.ipv4.conf.default.log_martians"]="0"
    )

    for key in "${!sysctl_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${sysctl_settings[$key]}"
    done

    # Update /etc/security/limits.conf with new limits
    declare -A limits_settings=(
        ["* soft nproc"]="65535"
        ["* hard nproc"]="65535"
        ["* soft nofile"]="1048576"
        ["* hard nofile"]="1048576"
        ["root soft nproc"]="65535"
        ["root hard nproc"]="65535"
        ["root soft nofile"]="1048576"
        ["root hard nofile"]="1048576"
    )

    for key in "${!limits_settings[@]}"; do
        if grep -q "^$key" "$LIMITS_CONF"; then
            sed -i "s|^$key.*|$key ${limits_settings[$key]}|" "$LIMITS_CONF"
        else
            echo "$key ${limits_settings[$key]}" >> "$LIMITS_CONF"
        fi
    done

    reload_sysctl
    echo -e "\033[1;32mOptimization Complete!\033[0m"
}

# Function to disable all optimizations (remove specific entries)
disable_optimizations() {
    echo -e "\033[1;32mDisabling all optimizations...\033[0m"

    # Remove specific optimization settings from /etc/sysctl.conf
    SYSCTL_KEYS=(
        "vm.swappiness"
        "vm.dirty_ratio"
        "vm.dirty_background_ratio"
        "fs.file-max"
        "net.core.somaxconn"
        "net.core.netdev_max_backlog"
        "net.ipv4.ip_local_port_range"
        "net.ipv4.ip_nonlocal_bind"
        "net.ipv4.tcp_fin_timeout"
        "net.ipv4.tcp_keepalive_time"
        "net.ipv4.tcp_syncookies"
        "net.ipv4.tcp_max_orphans"
        "net.ipv4.tcp_max_syn_backlog"
        "net.ipv4.tcp_max_tw_buckets"
        "net.ipv4.tcp_reordering"
        "net.ipv4.tcp_mem"
        "net.ipv4.tcp_rmem"
        "net.ipv4.tcp_wmem"
        "net.ipv4.tcp_syn_retries"
        "net.ipv4.tcp_tw_reuse"
        "net.ipv4.tcp_keepalive_intvl"
        "net.ipv4.tcp_keepalive_probes"
        "net.ipv4.tcp_mtu_probing"
        "net.ipv4.tcp_congestion_control"
        "net.ipv4.tcp_sack"
        "net.ipv4.conf.all.rp_filter"
        "net.ipv4.conf.default.rp_filter"
        "net.ipv4.ip_no_pmtu_disc"
        "vm.vfs_cache_pressure"
        "net.ipv4.tcp_fastopen"
        "net.ipv4.tcp_ecn"
        "net.ipv4.tcp_retries2"
        "net.ipv6.conf.all.forwarding"
        "net.ipv4.conf.all.forwarding"
        "net.ipv4.tcp_low_latency"
        "net.ipv4.tcp_window_scaling"
        "net.core.default_qdisc"
        "net.netfilter.nf_conntrack_max"
        "net.netfilter.nf_conntrack_log_invalid"
        "net.ipv4.conf.all.log_martians"
        "net.ipv4.conf.default.log_martians"
    )

    for key in "${SYSCTL_KEYS[@]}"; do
        sed -i "/^$key/d" "$SYSCTL_CONF"
    done

    # Remove specific limits from /etc/security/limits.conf
    LIMIT_KEYS=(
        "* soft nproc"
        "* hard nproc"
        "* soft nofile"
        "* hard nofile"
        "root soft nproc"
        "root hard nproc"
        "root soft nofile"
        "root hard nofile"
    )

    for key in "${LIMIT_KEYS[@]}"; do
        sed -i "/^$key/d" "$LIMITS_CONF"
    done

    # Reload sysctl
    echo -e "\033[1;32mReloading sysctl settings...\033[0m"
    sysctl -p

    echo -e "\033[1;32mAll optimizations have been disabled!\033[0m"
}

apply_fast_tcp() {
    echo -e "\033[1;32mApplying VERY FAST TCP optimizations...\033[0m"

    # Sysctl settings for very fast TCP (UDP-like behavior)
    declare -A sysctl_settings=(
        ["net.core.rmem_max"]="134217728"
        ["net.core.wmem_max"]="134217728"
        ["net.core.rmem_default"]="16777216"
        ["net.core.wmem_default"]="16777216"
        ["net.core.netdev_max_backlog"]="30000"
        ["net.core.somaxconn"]="32768"
        ["net.ipv4.ip_local_port_range"]="1024 65000"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.core.default_qdisc"]="fq"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_fin_timeout"]="5"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_keepalive_time"]="120"
        ["net.ipv4.tcp_keepalive_intvl"]="20"
        ["net.ipv4.tcp_keepalive_probes"]="3"
        ["net.ipv4.tcp_syn_retries"]="2"
        ["net.ipv4.tcp_retries1"]="1"
        ["net.ipv4.tcp_retries2"]="3"
        ["net.ipv4.tcp_orphan_retries"]="0"
        ["net.ipv4.tcp_mtu_probing"]="1"
        ["net.ipv4.tcp_sack"]="0"
        ["net.ipv4.tcp_dsack"]="0"
        ["net.ipv4.tcp_low_latency"]="1"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.tcp_no_metrics_save"]="1"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.netfilter.nf_conntrack_max"]="524288"
        ["net.netfilter.nf_conntrack_tcp_timeout_time_wait"]="30"
        ["net.netfilter.nf_conntrack_tcp_timeout_established"]="300000"
    )

    # Apply sysctl settings
    for key in "${!sysctl_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${sysctl_settings[$key]}"
    done

    # Limits for fast connections
    declare -A limits_settings=(
        ["* soft nproc"]="65535"
        ["* hard nproc"]="65535"
        ["* soft nofile"]="1048576"
        ["* hard nofile"]="1048576"
        ["root soft nproc"]="65535"
        ["root hard nproc"]="65535"
        ["root soft nofile"]="1048576"
        ["root hard nofile"]="1048576"
    )

    for key in "${!limits_settings[@]}"; do
        if grep -q "^$key" "$LIMITS_CONF"; then
            sed -i "s|^$key.*|$key ${limits_settings[$key]}|" "$LIMITS_CONF"
        else
            echo "$key ${limits_settings[$key]}" >> "$LIMITS_CONF"
        fi
    done

    # Load BBR module if available
    if modprobe tcp_bbr 2>/dev/null; then
        echo "Loaded tcp_bbr module."
    fi

    reload_sysctl
    echo -e "\033[1;32mVERY FAST TCP optimizations applied!\033[0m"
}

disable_fast_tcp() {
    echo -e "\033[1;32mDisabling VERY FAST TCP optimizations...\033[0m"

    # Sysctl keys to remove
    SYSCTL_KEYS=(
        "net.core.rmem_max"
        "net.core.wmem_max"
        "net.core.rmem_default"
        "net.core.wmem_default"
        "net.core.netdev_max_backlog"
        "net.core.somaxconn"
        "net.ipv4.ip_local_port_range"
        "net.ipv4.tcp_congestion_control"
        "net.core.default_qdisc"
        "net.ipv4.tcp_fastopen"
        "net.ipv4.tcp_fin_timeout"
        "net.ipv4.tcp_tw_reuse"
        "net.ipv4.tcp_keepalive_time"
        "net.ipv4.tcp_keepalive_intvl"
        "net.ipv4.tcp_keepalive_probes"
        "net.ipv4.tcp_syn_retries"
        "net.ipv4.tcp_retries1"
        "net.ipv4.tcp_retries2"
        "net.ipv4.tcp_orphan_retries"
        "net.ipv4.tcp_mtu_probing"
        "net.ipv4.tcp_sack"
        "net.ipv4.tcp_dsack"
        "net.ipv4.tcp_low_latency"
        "net.ipv4.tcp_window_scaling"
        "net.ipv4.tcp_no_metrics_save"
        "net.ipv4.tcp_syncookies"
        "net.netfilter.nf_conntrack_max"
        "net.netfilter.nf_conntrack_tcp_timeout_time_wait"
        "net.netfilter.nf_conntrack_tcp_timeout_established"
    )

    for key in "${SYSCTL_KEYS[@]}"; do
        sed -i "/^$key/d" "$SYSCTL_CONF"
    done

    # Limits to remove
    LIMIT_KEYS=(
        "* soft nproc"
        "* hard nproc"
        "* soft nofile"
        "* hard nofile"
        "root soft nproc"
        "root hard nproc"
        "root soft nofile"
        "root hard nofile"
    )

    for key in "${LIMIT_KEYS[@]}"; do
        sed -i "/^$key/d" "$LIMITS_CONF"
    done

    # Reload sysctl
    echo -e "\033[1;32mReloading sysctl settings...\033[0m"
    sysctl -p

    echo -e "\033[1;32mVERY FAST TCP optimizations removed!\033[0m"
}

apply_full_optimizations() {
    echo -e "\033[1;32mApplying optimizations...\033[0m"

    declare -A sysctl_settings=(
        # Memory and swap
        ["vm.swappiness"]="10"
        ["vm.dirty_ratio"]="10"
        ["vm.dirty_background_ratio"]="5"
        ["vm.dirty_expire_centisecs"]="1500"
        ["vm.dirty_writeback_centisecs"]="500"
        ["vm.vfs_cache_pressure"]="50"
        ["vm.min_free_kbytes"]="131072"
        ["vm.page_cluster"]="0"
        ["vm.overcommit_memory"]="1"
        ["vm.overcommit_ratio"]="80"
        ["vm.max_map_count"]="262144"
        ["vm.mmap_min_addr"]="65536"
        ["vm.zone_reclaim_mode"]="0"
        ["vm.stat_interval"]="1"

        # Kernel scheduler
        ["kernel.sched_latitude_ns"]="6000000"
        ["kernel.sched_min_granularity_ns"]="1500000"
        ["kernel.sched_wakeup_granularity_ns"]="2000000"
        ["kernel.sched_migration_cost_ns"]="500000"
        ["kernel.sched_nr_migrate"]="64"
        ["kernel.sched_tunable_scaling"]="0"
        ["kernel.sched_child_runs_first"]="0"
        ["kernel.sched_energy_aware"]="1"
        ["kernel.sched_schedstats"]="0"
        ["kernel.sched_rr_timeslice_ms"]="25"
        ["kernel.sched_rt_period_us"]="1000000"
        ["kernel.sched_rt_runtime_us"]="950000"
        ["kernel.sched_cfs_bandwidth_slice_us"]="5000"
        ["kernel.sched_autogroup_enabled"]="1"

        # File system
        ["fs.file-max"]="2097152"
        ["fs.nr_open"]="2097152"
        ["fs.inotify.max_user_watches"]="524288"
        ["fs.inotify.max_user_instances"]="256"
        ["fs.inotify.max_queued_events"]="32768"
        ["fs.aio-max-nr"]="1048576"
        ["fs.pipe-max-size"]="4194304"

        # Core networking
        ["net.core.rmem_max"]="134217728"
        ["net.core.wmem_max"]="134217728"
        ["net.core.rmem_default"]="16777216"
        ["net.core.wmem_default"]="16777216"
        ["net.core.netdev_max_backlog"]="30000"
        ["net.core.netdev_budget"]="600"
        ["net.core.netdev_budget_usecs"]="8000"
        ["net.core.somaxconn"]="32768"
        ["net.core.dev_weight"]="128"
        ["net.core.dev_weight_rx_bias"]="1"
        ["net.core.dev_weight_tx_bias"]="1"
        ["net.core.bpf_jit_enable"]="1"
        ["net.core.bpf_jit_kallsyms"]="1"
        ["net.core.bpf_jit_harden"]="0"
        ["net.core.flow_limit_cpu_bitmap"]="255"
        ["net.core.flow_limit_table_len"]="8192"
        ["net.core.default_qdisc"]="fq_codel"
        ["net.unix.max_dgram_qlen"]="512"

        # TCP tuning
        ["net.ipv4.tcp_rmem"]="8192 131072 134217728"
        ["net.ipv4.tcp_wmem"]="8192 131072 134217728"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_fastopen_blackhole_timeout_sec"]="0"
        ["net.ipv4.tcp_fin_timeout"]="10"
        ["net.ipv4.tcp_keepalive_time"]="600"
        ["net.ipv4.tcp_keepalive_intvl"]="30"
        ["net.ipv4.tcp_keepalive_probes"]="3"
        ["net.ipv4.tcp_max_syn_backlog"]="8192"
        ["net.ipv4.tcp_max_tw_buckets"]="2000000"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_tw_reuse_delay"]="100"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.ipv4.tcp_timestamps"]="1"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.tcp_dsack"]="1"
        ["net.ipv4.tcp_fack"]="1"
        ["net.ipv4.tcp_ecn"]="2"
        ["net.ipv4.tcp_syn_retries"]="3"
        ["net.ipv4.tcp_synack_retries"]="3"
        ["net.ipv4.tcp_retries1"]="3"
        ["net.ipv4.tcp_retries2"]="8"
        ["net.ipv4.tcp_orphan_retries"]="1"
        ["net.ipv4.tcp_syncookies"]="1"
        ["net.ipv4.tcp_rfc1337"]="1"
        ["net.ipv4.tcp_slow_start_after_idle"]="0"
        ["net.ipv4.tcp_no_metrics_save"]="1"
        ["net.ipv4.tcp_moderate_rcvbuf"]="1"
        ["net.ipv4.tcp_mtu_probing"]="2"
        ["net.ipv4.tcp_base_mss"]="1024"
        ["net.ipv4.tcp_min_snd_mss"]="48"
        ["net.ipv4.tcp_mtu_probe_floor"]="48"
        ["net.ipv4.tcp_probe_threshold"]="8"
        ["net.ipv4.tcp_probe_interval"]="600"
        ["net.ipv4.tcp_adv_win_scale"]="2"
        ["net.ipv4.tcp_app_win"]="31"
        ["net.ipv4.tcp_tso_win_divisor"]="8"
        ["net.ipv4.tcp_limit_output_bytes"]="1048576"
        ["net.ipv4.tcp_challenge_ack_limit"]="1000"
        ["net.ipv4.tcp_autocorking"]="1"
        ["net.ipv4.tcp_min_tso_segs"]="8"
        ["net.ipv4.tcp_tso_rtt_log"]="9"
        ["net.ipv4.tcp_pacing_ss_ratio"]="120"
        ["net.ipv4.tcp_pacing_ca_ratio"]="110"
        ["net.ipv4.tcp_reordering"]="3"
        ["net.ipv4.tcp_max_reordering"]="32"
        ["net.ipv4.tcp_recovery"]="1"
        ["net.ipv4.tcp_early_retrans"]="3"
        ["net.ipv4.tcp_frto"]="2"
        ["net.ipv4.tcp_thin_linear_timeouts"]="1"
        ["net.ipv4.tcp_min_rtt_wlen"]="300"
        ["net.ipv4.tcp_comp_sack_delay_ns"]="500000"
        ["net.ipv4.tcp_comp_sack_slack_ns"]="50000"
        ["net.ipv4.tcp_comp_sack_nr"]="44"
        ["net.ipv4.tcp_notsent_lowat"]="131072"
        ["net.ipv4.tcp_invalid_ratelimit"]="250"
        ["net.ipv4.tcp_reflect_tos"]="1"
        ["net.ipv4.tcp_abort_on_overflow"]="0"
        ["net.ipv4.tcp_fwmark_accept"]="1"
        ["net.ipv4.tcp_l3mdev_accept"]="1"
        ["net.ipv4.tcp_migrate_req"]="1"
        ["net.ipv4.tcp_syn_linear_timeouts"]="4"
        ["net.ipv4.tcp_shrink_window"]="0"
        ["net.ipv4.tcp_workaround_signed_windows"]="0"

        # IPv4 general
        ["net.ipv4.ip_forward"]="1"
        ["net.ipv4.ip_default_ttl"]="64"
        ["net.ipv4.ip_no_pmtu_disc"]="0"
        ["net.ipv4.ip_forward_use_pmtu"]="1"
        ["net.ipv4.fwmark_reflect"]="1"
        ["net.ipv4.fib_multipath_use_neigh"]="1"
        ["net.ipv4.fib_multipath_hash_policy"]="1"
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.default.rp_filter"]="1"
        ["net.ipv4.conf.all.accept_source_route"]="0"
        ["net.ipv4.conf.default.accept_source_route"]="0"
        ["net.ipv4.conf.all.accept_redirects"]="0"
        ["net.ipv4.conf.default.accept_redirects"]="0"
        ["net.ipv4.conf.all.secure_redirects"]="0"
        ["net.ipv4.conf.default.secure_redirects"]="0"
        ["net.ipv4.conf.all.send_redirects"]="0"
        ["net.ipv4.conf.default.send_redirects"]="0"
        ["net.ipv4.conf.all.log_martians"]="0"
        ["net.ipv4.conf.default.log_martians"]="0"
        ["net.ipv4.icmp_echo_ignore_all"]="0"
        ["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
        ["net.ipv4.icmp_ignore_bogus_error_responses"]="1"
        ["net.ipv4.icmp_ratelimit"]="100"
        ["net.ipv4.icmp_ratemask"]="6168"

        # Conntrack settings
        ["net.netfilter.nf_conntrack_max"]="1048576"
        ["net.netfilter.nf_conntrack_tcp_timeout_established"]="432000"
        ["net.netfilter.nf_conntrack_tcp_timeout_time_wait"]="60"
        ["net.netfilter.nf_conntrack_tcp_timeout_close_wait"]="30"
        ["net.netfilter.nf_conntrack_tcp_timeout_fin_wait"]="60"
        ["net.netfilter.nf_conntrack_tcp_timeout_syn_sent"]="60"
        ["net.netfilter.nf_conntrack_tcp_timeout_syn_recv"]="30"
        ["net.netfilter.nf_conntrack_udp_timeout"]="30"
        ["net.netfilter.nf_conntrack_udp_timeout_stream"]="120"
        ["net.netfilter.nf_conntrack_icmp_timeout"]="30"
        ["net.netfilter.nf_conntrack_generic_timeout"]="120"
        ["net.netfilter.nf_conntrack_buckets"]="262144"
        ["net.netfilter.nf_conntrack_checksum"]="0"
        ["net.netfilter.nf_conntrack_tcp_be_liberal"]="1"
        ["net.netfilter.nf_conntrack_tcp_loose"]="1"
    )

    for key in "${!sysctl_settings[@]}"; do
        update_config "$SYSCTL_CONF" "$key" "${sysctl_settings[$key]}"
    done

    reload_sysctl
    echo -e "\033[1;32mAll optimizations have been applied successfully.\033[0m"
}

remove_full_optimizations() {
    echo -e "\033[1;31mRemoving optimizations...\033[0m"

    # List of keys to remove
    local keys=(
        net.core.rmem_max
        net.core.wmem_max
        net.core.rmem_default
        net.core.wmem_default
        net.core.netdev_max_backlog
        net.core.netdev_budget
        net.core.netdev_budget_usecs
        net.core.somaxconn
        net.core.dev_weight
        net.core.dev_weight_rx_bias
        net.core.dev_weight_tx_bias
        net.core.bpf_jit_enable
        net.core.bpf_jit_kallsyms
        net.core.bpf_jit_harden
        net.core.flow_limit_cpu_bitmap
        net.core.flow_limit_table_len
        net.ipv4.tcp_rmem
        net.ipv4.tcp_wmem
        net.ipv4.tcp_congestion_control
        net.ipv4.tcp_fastopen
        net.ipv4.tcp_fastopen_blackhole_timeout_sec
        net.ipv4.tcp_fin_timeout
        net.ipv4.tcp_keepalive_time
        net.ipv4.tcp_keepalive_intvl
        net.ipv4.tcp_keepalive_probes
        net.ipv4.tcp_max_syn_backlog
        net.ipv4.tcp_max_tw_buckets
        net.ipv4.tcp_tw_reuse
        net.ipv4.tcp_tw_reuse_delay
        net.ipv4.tcp_window_scaling
        net.ipv4.tcp_timestamps
        net.ipv4.tcp_sack
        net.ipv4.tcp_dsack
        net.ipv4.tcp_fack
        net.ipv4.tcp_ecn
        net.ipv4.tcp_syn_retries
        net.ipv4.tcp_synack_retries
        net.ipv4.tcp_retries1
        net.ipv4.tcp_retries2
        net.ipv4.tcp_orphan_retries
        net.ipv4.tcp_syncookies
        net.ipv4.tcp_rfc1337
        net.ipv4.tcp_slow_start_after_idle
        net.ipv4.tcp_no_metrics_save
        net.ipv4.tcp_moderate_rcvbuf
        net.ipv4.tcp_mtu_probing
        net.ipv4.tcp_base_mss
        net.ipv4.tcp_min_snd_mss
        net.ipv4.tcp_mtu_probe_floor
        net.ipv4.tcp_probe_threshold
        net.ipv4.tcp_probe_interval
        net.ipv4.tcp_adv_win_scale
        net.ipv4.tcp_app_win
        net.ipv4.tcp_tso_win_divisor
        net.ipv4.tcp_limit_output_bytes
        net.ipv4.tcp_challenge_ack_limit
        net.ipv4.tcp_autocorking
        net.ipv4.tcp_min_tso_segs
        net.ipv4.tcp_tso_rtt_log
        net.ipv4.tcp_pacing_ss_ratio
        net.ipv4.tcp_pacing_ca_ratio
        net.ipv4.tcp_reordering
        net.ipv4.tcp_max_reordering
        net.ipv4.tcp_recovery
        net.ipv4.tcp_early_retrans
        net.ipv4.tcp_frto
        net.ipv4.tcp_thin_linear_timeouts
        net.ipv4.tcp_min_rtt_wlen
        net.ipv4.tcp_comp_sack_delay_ns
        net.ipv4.tcp_comp_sack_slack_ns
        net.ipv4.tcp_comp_sack_nr
        net.ipv4.tcp_notsent_lowat
        net.ipv4.tcp_invalid_ratelimit
        net.ipv4.tcp_reflect_tos
        net.ipv4.tcp_abort_on_overflow
        net.ipv4.tcp_fwmark_accept
        net.ipv4.tcp_l3mdev_accept
        net.ipv4.tcp_migrate_req
        net.ipv4.tcp_syn_linear_timeouts
        net.ipv4.tcp_shrink_window
        net.ipv4.tcp_workaround_signed_windows
        net.ipv4.ip_forward
        net.ipv4.ip_default_ttl
        net.ipv4.ip_no_pmtu_disc
        net.ipv4.ip_forward_use_pmtu
        net.ipv4.fwmark_reflect
        net.ipv4.fib_multipath_use_neigh
        net.ipv4.fib_multipath_hash_policy
        net.ipv4.conf.all.rp_filter
        net.ipv4.conf.default.rp_filter
        net.ipv4.conf.all.accept_source_route
        net.ipv4.conf.default.accept_source_route
        net.ipv4.conf.all.accept_redirects
        net.ipv4.conf.default.accept_redirects
        net.ipv4.conf.all.secure_redirects
        net.ipv4.conf.default.secure_redirects
        net.ipv4.conf.all.send_redirects
        net.ipv4.conf.default.send_redirects
        net.ipv4.conf.all.log_martians
        net.ipv4.conf.default.log_martians
        net.ipv4.icmp_echo_ignore_all
        net.ipv4.icmp_echo_ignore_broadcasts
        net.ipv4.icmp_ignore_bogus_error_responses
        net.ipv4.icmp_ratelimit
        net.ipv4.icmp_ratemask
        net.netfilter.nf_conntrack_max
        net.netfilter.nf_conntrack_tcp_timeout_established
        net.netfilter.nf_conntrack_tcp_timeout_time_wait
        net.netfilter.nf_conntrack_tcp_timeout_close_wait
        net.netfilter.nf_conntrack_tcp_timeout_fin_wait
        net.netfilter.nf_conntrack_tcp_timeout_syn_sent
        net.netfilter.nf_conntrack_tcp_timeout_syn_recv
        net.netfilter.nf_conntrack_udp_timeout
        net.netfilter.nf_conntrack_udp_timeout_stream
        net.netfilter.nf_conntrack_icmp_timeout
        net.netfilter.nf_conntrack_generic_timeout
        net.netfilter.nf_conntrack_buckets
        net.netfilter.nf_conntrack_checksum
        net.netfilter.nf_conntrack_tcp_be_liberal
        net.netfilter.nf_conntrack_tcp_loose
        vm.swappiness
        vm.dirty_ratio
        vm.dirty_background_ratio
        vm.dirty_expire_centisecs
        vm.dirty_writeback_centisecs
        vm.vfs_cache_pressure
        vm.min_free_kbytes
        vm.page_cluster
        vm.overcommit_memory
        vm.overcommit_ratio
        vm.max_map_count
        vm.mmap_min_addr
        vm.zone_reclaim_mode
        vm.stat_interval
        kernel.sched_latency_ns
        kernel.sched_min_granularity_ns
        kernel.sched_wakeup_granularity_ns
        kernel.sched_migration_cost_ns
        kernel.sched_nr_migrate
        kernel.sched_tunable_scaling
        kernel.sched_child_runs_first
        kernel.sched_energy_aware
        kernel.sched_schedstats
        kernel.sched_rr_timeslice_ms
        kernel.sched_rt_period_us
        kernel.sched_rt_runtime_us
        kernel.sched_cfs_bandwidth_slice_us
        kernel.sched_autogroup_enabled
        fs.file-max
        fs.nr_open
        fs.inotify.max_user_watches
        fs.inotify.max_user_instances
        fs.inotify.max_queued_events
        fs.aio-max-nr
        fs.pipe-max-size
        net.core.default_qdisc
        net.unix.max_dgram_qlen
    )

    # Backup original file before modifying
    cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%F_%T)

    for key in "${keys[@]}"; do
        # Delete lines starting with the key, optionally with spaces, ignoring comments
        sed -i "/^\s*${key}\s*=/d" /etc/sysctl.conf
    done

    # Reload sysctl settings
    sysctl -p

    echo -e "\033[1;32mOptimizations removed and sysctl reloaded.\033[0m"
}

# Function to manage TCP congestion control and qdisc
network_tuning_menu() {
    while true; do
        display_header
        echo -e "\033[1;33mTCP Congestion Control & Queue Discipline Manager\033[0m"
        echo
        echo -e "\033[1;32mCurrent: CC: \033[1;34m$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "Not set")\033[0m"
        echo -e "\033[1;32mCurrent: QDISC: \033[1;34m$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "Not set")\033[0m"
        echo
        
        local options=(
            "Set TCP Congestion Control"          "Set Queue Discipline (qdisc)"
            "Apply BBR (Google)"                  "Apply BBR2 (Improved BBR)"
            "Apply CUBIC (Default)"               "Apply Reno (Traditional)"
            "Apply Vegas (Delay-based)"           "Apply Westwood (Loss-based)"
            "Apply Westwood+ (Enhanced)"          "Apply Hybla (Satellite/Wireless)"
            "Apply Highspeed (High-speed)"        "Apply HTCP (Hamilton TCP)"
            "Apply Illinois (Delay+Loss)"         "Apply Yeah (Highspeed)"
            "Apply Veno (Wireless)"               "Apply Scalable (High-speed)"
            "Apply LP (Loss Priority)"            "Apply Compound (Delay+Loss)"
            "Apply CDG (Delay-Gradient)"          "Apply DCTCP (Data Center)"
            "Apply BIC (Binary Increase)"         "Apply NCR (Non-Congestion)"
            "Apply OLI (Open-Loop)"               "List all CC algorithms"
            "List queue disciplines"              "Test network performance"
            "Reset to defaults"
        )
        
        # Display two columns
        for i in $(seq 0 2 $((${#options[@]} - 1))); do
            printf "\033[1;32m%2d.\033[0m %-25s \033[1;34m%2d.\033[0m %-25s\n" \
                   $((i+1)) "${options[i]}" $((i+2)) "${options[i+1]}"
        done
        
        echo -e "\033[1;31m 0.\033[0m Return to main menu"
        echo
        display_footer
        
        read -p "Select an option: " choice
        echo

        case $choice in
            1) set_congestion_control ;;
            2) set_qdisc ;;
            3) apply_cc "bbr" "Google's BBR" "fq" ;;
            4) apply_cc "bbr2" "BBR v2" "fq" ;;
            5) apply_cc "cubic" "CUBIC" "fq_codel" ;;
            6) apply_cc "reno" "Reno" "pfifo_fast" ;;
            7) apply_cc "vegas" "Vegas" "fq" ;;
            8) apply_cc "westwood" "Westwood" "fq_codel" ;;
            9) apply_cc "westwood" "Westwood+" "fq_codel" ;;
            10) apply_cc "hybla" "Hybla" "fq" ;;
            11) apply_cc "highspeed" "Highspeed" "fq" ;;
            12) apply_cc "htcp" "HTCP" "fq_codel" ;;
            13) apply_cc "illinois" "Illinois" "fq" ;;
            14) apply_cc "yeah" "Yeah" "fq" ;;
            15) apply_cc "veno" "Veno" "fq_codel" ;;
            16) apply_cc "scalable" "Scalable" "fq" ;;
            17) apply_cc "lp" "LP" "fq" ;;
            18) apply_cc "compound" "Compound" "fq" ;;
            19) apply_cc "cdg" "CDG" "fq" ;;
            20) apply_cc "dctcp" "DCTCP" "fq" ;;
            21) apply_cc "bic" "BIC" "fq" ;;
            22) apply_cc "ncr" "NCR" "fq" ;;
            23) apply_cc "oli" "OLI" "fq" ;;
            24) list_all_congestion_controls ;;
            25) list_qdiscs ;;
            26) test_network_performance ;;
            27) reset_network_settings ;;
            0) break ;;
            *) echo -e "\033[1;31mInvalid option.\033[0m" ;;
        esac

        echo -e "\n\033[1;34mPress Enter to continue...\033[0m"
        read
    done
}

# Generic function to apply congestion control
apply_cc() {
    local cc_algo="$1"
    local cc_name="$2"
    local qdisc="${3:-fq}"
    
    echo -e "\033[1;32mApplying $cc_name ($cc_algo)...\033[0m"
    
    # Load module if available
    modprobe "tcp_${cc_algo}" 2>/dev/null
    
    # Apply settings
    sysctl -w "net.ipv4.tcp_congestion_control=${cc_algo}" 2>/dev/null || \
    sysctl -w "net.ipv4.tcp_congestion_control=cubic"
    
    sysctl -w "net.core.default_qdisc=${qdisc}"
    
    update_config "$SYSCTL_CONF" "net.ipv4.tcp_congestion_control" "$cc_algo"
    update_config "$SYSCTL_CONF" "net.core.default_qdisc" "$qdisc"
    
    echo -e "\033[1;32m${cc_name} applied successfully!\033[0m"
}

# Function to set TCP congestion control
set_congestion_control() {
    echo -e "\033[1;32mAvailable TCP Congestion Controls:\033[0m"
    list_all_congestion_controls | grep -v "Available" | sed '/^$/d'
    echo
    read -p "Enter congestion control algorithm: " cc_algo
    
    if ls /lib/modules/$(uname -r)/kernel/net/ipv4/ | grep -q "tcp_${cc_algo}.ko"; then
        modprobe "tcp_${cc_algo}" 2>/dev/null
        sysctl -w "net.ipv4.tcp_congestion_control=${cc_algo}"
        update_config "$SYSCTL_CONF" "net.ipv4.tcp_congestion_control" "$cc_algo"
        echo -e "\033[1;32mSet to: ${cc_algo}\033[0m"
    else
        echo -e "\033[1;31mAlgorithm '${cc_algo}' not found.\033[0m"
    fi
}

# Function to set queue discipline
set_qdisc() {
    echo -e "\033[1;32mAvailable Queue Disciplines:\033[0m"
    tc qdisc list | grep -o '^[^ ]*' | sort | uniq | head -10
    echo
    read -p "Enter queue discipline: " qdisc
    
    sysctl -w "net.core.default_qdisc=${qdisc}"
    update_config "$SYSCTL_CONF" "net.core.default_qdisc" "$qdisc"
    echo -e "\033[1;32mQDISC set to: ${qdisc}\033[0m"
}

# Function to list all available congestion controls
list_all_congestion_controls() {
    echo -e "\033[1;32mAvailable TCP CC Algorithms:\033[0m"
    echo -e "\033[1;34mLoaded:\033[0m"
    sysctl -n net.ipv4.tcp_available_congestion_control 2>/dev/null | tr ' ' '\n'
    echo -e "\033[1;34mModules:\033[0m"
    ls /lib/modules/$(uname -r)/kernel/net/ipv4/ | grep tcp_ | sed 's/\.ko$//;s/tcp_//' | head -15
}

# Function to list available queue disciplines
list_qdiscs() {
    echo -e "\033[1;32mAvailable Queue Disciplines:\033[0m"
    tc qdisc list | grep -o '^[^ ]*' | sort | uniq | head -15
}

# Function to test network performance
test_network_performance() {
    echo -e "\033[1;32mTesting network...\033[0m"
    echo -e "CC: $(sysctl -n net.ipv4.tcp_congestion_control)"
    echo -e "QDISC: $(sysctl -n net.core.default_qdisc)"
    echo -e "rmem: $(sysctl -n net.ipv4.tcp_rmem)"
    echo -e "wmem: $(sysctl -n net.ipv4.tcp_wmem)"
    
    if command -v ping &> /dev/null; then
        echo -e "\033[1;34mPing test:\033[0m"
        ping -c 2 8.8.8.8 | tail -1
    fi
}

# Function to reset network settings to defaults
reset_network_settings() {
    echo -e "\033[1;32mResetting to defaults...\033[0m"
    sed -i '/^net.ipv4.tcp_congestion_control/d; /^net.core.default_qdisc/d' "$SYSCTL_CONF"
    sysctl -p
    echo -e "\033[1;32mReset complete.\033[0m"
}

# Function to show contents of sysctl.conf
show_sysctl_conf() {
    echo -e "\033[1;34mContents of sysctl.conf:\033[0m"
    cat $SYSCTL_CONF
}

# Function to show contents of limits.conf
show_limits_conf() {
    echo -e "\033[1;34mContents of limits.conf:\033[0m"
    cat $LIMITS_CONF
}

# Function to edit sysctl.conf
edit_sysctl_conf() {
    echo -e "\033[1;32mOpening sysctl.conf for editing...\033[0m"
    nano $SYSCTL_CONF
    echo -e "\033[1;32mReloading sysctl settings...\033[0m"
    sysctl -p
}

# Function to edit limits.conf
edit_limits_conf() {
    echo -e "\033[1;32mOpening limits.conf for editing...\033[0m"
    nano $LIMITS_CONF
    echo -e "\033[1;32mChanges to limits.conf will take effect after next login.\033[0m"
}

tc() {
    cat <<'EOF' > /root/tc_optimize.sh
#!/bin/bash

tc_optimize() {
    # Detect default interface
    INTERFACE=$(ip route get 8.8.8.8 | awk '/dev/ {print $5; exit}')
    
    # Clear old configurations
    tc qdisc del dev "$INTERFACE" root 2>/dev/null
    tc qdisc del dev "$INTERFACE" ingress 2>/dev/null
    ip link set dev "$INTERFACE" mtu 1500 2>/dev/null
    echo 1000 > "/sys/class/net/$INTERFACE/tx_queue_len" 2>/dev/null

    # Try CAKE
    if tc qdisc add dev "$INTERFACE" root handle 1: cake bandwidth 1000mbit rtt 20ms 2>/dev/null &&
       tc qdisc add dev "$INTERFACE" parent 1: handle 10: netem delay 1ms loss 0.005% duplicate 0.05% reorder 0.5% 2>/dev/null; then
        echo "$(date): CAKE+Netem optimization complete on $INTERFACE"

    # Try FQ_CoDel
    elif tc qdisc add dev "$INTERFACE" root handle 1: fq_codel limit 10240 flows 1024 target 5ms interval 100ms 2>/dev/null &&
         tc qdisc add dev "$INTERFACE" parent 1: handle 10: netem delay 1ms loss 0.005% duplicate 0.05% reorder 0.5% 2>/dev/null; then
        echo "$(date): FQ_CoDel+Netem optimization complete on $INTERFACE"

    # Try HTB
    elif tc qdisc add dev "$INTERFACE" root handle 1: htb default 11 2>/dev/null &&
         tc class add dev "$INTERFACE" parent 1: classid 1:1 htb rate 1000mbit ceil 1000mbit 2>/dev/null &&
         tc class add dev "$INTERFACE" parent 1:1 classid 1:11 htb rate 1000mbit ceil 1000mbit 2>/dev/null &&
         tc qdisc add dev "$INTERFACE" parent 1:11 handle 10: netem delay 1ms loss 0.005% duplicate 0.05% reorder 0.5% 2>/dev/null; then
        echo "$(date): HTB+Netem optimization complete on $INTERFACE"

    # Try PFIFO
    elif tc qdisc add dev "$INTERFACE" root handle 1: pfifo_fast 2>/dev/null &&
         tc qdisc add dev "$INTERFACE" parent 1: handle 10: netem delay 1ms loss 0.005% 2>/dev/null; then
        echo "$(date): Basic PFIFO+Netem optimization complete on $INTERFACE"

    # Fallback Netem only
    else
        tc qdisc add dev "$INTERFACE" root netem delay 1ms loss 0.005% 2>/dev/null
        echo "$(date): Fallback Netem optimization complete on $INTERFACE"
    fi >> /var/log/tc_smart.log 2>&1
}

tc_optimize
EOF

    chmod +x /root/tc_optimize.sh

    # Add to crontab if not present
    local cron_job="@reboot /root/tc_optimize.sh >> /var/log/tc_smart.log 2>&1"
    if crontab -l 2>/dev/null | grep -Fq "/root/tc_optimize.sh"; then
        echo -e "\033[1;33mCron job already exists, skipping...\033[0m"
    else
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo -e "\033[1;32mCron job added successfully!\033[0m"
    fi
}

# Function to display a header
display_header() {
    clear
    echo -e "\033[1;36m==============================================\033[0m"
    echo -e "\033[1;36m            Network Optimizer Tool            \033[0m"
    echo -e "\033[1;36m==============================================\033[0m"
    echo
}

# Function to display a footer
display_footer() {
    echo -e "\033[1;36m==============================================\033[0m"
    echo
}

# Function to display a menu with options
display_menu() {
    local title="$1"
    shift
    local options=("$@")
    
    display_header
    echo -e "\033[1;33m$title\033[0m"
    echo
    
    for i in "${!options[@]}"; do
        if [ $((i % 2)) -eq 0 ]; then
            echo -e "\033[1;32m$((i+1)).\033[0m ${options[$i]}"
        else
            echo -e "\033[1;34m$((i+1)).\033[0m ${options[$i]}"
        fi
    done
    
    echo -e "\033[1;31m0.\033[0m Return to previous menu"
    echo
    display_footer
}

# Submenu for Optimize options
Optimize_Menu() {
    local options=(
        "Apply normal TCP optimizations"
        "Remove normal TCP optimizations"
        "Apply full TCP optimizations"
        "Remove full TCP optimizations"
        "Apply interfaces (TC) Optimize"
        "Apply fast TCP optimizations"
        "Remove fast TCP"
    )
    
    while true; do
        display_menu "Optimize Options" "${options[@]}"
        read -p "Select an option: " opt_choice

        case $opt_choice in
            1) apply_optimizations ;;
            2) disable_optimizations ;;
            3) apply_full_optimizations ;;
            4) remove_full_optimizations ;;
            5) tc ;;
            6) apply_fast_tcp ;;
            7) disable_fast_tcp ;;
            0) break ;;
            *) echo -e "\033[1;31mInvalid option. Please select a valid number.\033[0m" ;;
        esac

        echo -e "\n\033[1;34mPress Enter to continue...\033[0m"
        read
    done
}

# Main menu for optimizer
Optimizer() {
    local options=(
        "Backup (sysctl.conf & limits.conf)"
        "Optimize"
        "Set BBR by LightKnight"
        "Show sysctl.conf"
        "Show limits.conf"
        "Edit sysctl.conf"
        "Edit limits.conf"
        "Apply changes (sysctl -p)"
        "Disable log (rsyslog)"
    )
    
    while true; do
        display_menu "Network Optimizer" "${options[@]}"
        read -p "Select an option: " choice

        case $choice in
            1) backup_configs ;;
            2) Optimize_Menu ;;
            3) network_tuning_menu ;;
            4) show_sysctl_conf ;;
            5) show_limits_conf ;;
            6) edit_sysctl_conf ;;
            7) edit_limits_conf ;;
            8) reload_sysctl ;;
            9)
                sudo systemctl stop rsyslog
                sudo systemctl disable rsyslog
                echo -e "\033[1;32mRsyslog disabled successfully.\033[0m"
                ;;
            0)
                echo -e "\033[1;34mReturning to main menu...\033[0m"
                break 
                ;;
            *) echo -e "\033[1;31mInvalid option. Please select a valid number.\033[0m" ;;
        esac

        echo -e "\n\033[1;34mPress Enter to continue...\033[0m"
        read
    done
}

# Start the optimizer
Optimizer
