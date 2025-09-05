# Define paths to configuration files
SYSCTL_CONF="/etc/sysctl.conf"
LIMITS_CONF="/etc/security/limits.conf"

# Function to back up existing configurations
backup_configs() {
    echo -e "\033[1;32mBacking up configuration files...\033[0m"
    cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak"
    cp "$LIMITS_CONF" "${LIMITS_CONF}.bak"
    echo -e "\033[1;32mBackup completed.\033[0m"
}

# Function to reload sysctl configurations
reload_sysctl() {
    echo -e "\033[1;32mReloading sysctl settings...\033[0m"
    sysctl -p
}

# Function to apply optimizations (overwrite existing values only)
apply_optimizations() {
    echo -e "\033[1;32mApplying optimizations...\033[0m"

    # Update /etc/sysctl.conf with new configurations (overwrite existing values or add if missing)
    declare -A sysctl_settings=(
        # Gaming-optimized sysctl settings
["vm.swappiness"]="10"                      # Allow some use of swap to prevent memory pressure issues in long sessions.
["vm.dirty_ratio"]="30"                     # Lower write-back threshold to reduce potential stutters caused by high I/O.
["vm.dirty_background_ratio"]="10"          # Trigger background writeback sooner to avoid large I/O spikes.
["fs.file-max"]="2097152"                   # No change; sufficient for most gaming setups.
["net.core.somaxconn"]="1024"               # Lower backlog for gaming workloads to avoid delays.
["net.core.netdev_max_backlog"]="4096"      # Reduced to minimize bufferbloat in high-packet-rate scenarios.
["net.ipv4.ip_local_port_range"]="1024 65535"  # Keep full port range for outbound connections.
["net.ipv4.ip_nonlocal_bind"]="1"           # Useful for some advanced gaming setups (e.g., hosting).
["net.ipv4.tcp_keepalive_time"]="300"        # Shorter keepalive time to detect stale connections faster.
["net.ipv4.tcp_keepalive_intvl"]="30"       # Reduced interval to ensure faster keepalive probes.
["net.ipv4.tcp_keepalive_probes"]="5"       # Fewer probes to kill stale connections more quickly.
["net.ipv4.tcp_syncookies"]="1"             # Enable SYN cookies to protect against SYN flood attacks.
["net.ipv4.tcp_max_orphans"]="65536"        # Lower to prevent excessive resource use from orphaned connections.
["net.ipv4.tcp_max_syn_backlog"]="2048"     # Lower backlog size for a gaming environment.
["net.ipv4.tcp_max_tw_buckets"]="1048576"   # Prevent excessive time-wait buckets.
["net.ipv4.tcp_reordering"]="3"             # Default value; sufficient for gaming.
["net.ipv4.tcp_mem"]="786432 1697152 1945728" # No change; tuned for most workloads.
["net.ipv4.tcp_rmem"]="4096 262144 16777216"  # Larger initial buffer for fast response but avoids excessive buffering.
["net.ipv4.tcp_wmem"]="4096 65536 16777216"  # Balanced buffer sizes for outbound traffic.
["net.ipv4.tcp_syn_retries"]="3"            # Lower retry count for faster recovery from lost packets.
["net.ipv4.tcp_tw_reuse"]="1"               # Enable reuse of time-wait sockets to reduce delays.
["net.ipv4.tcp_mtu_probing"]="1"            # Enable MTU probing to optimize packet sizes.
["net.ipv4.tcp_congestion_control"]="bbr"   # Use BBR for low-latency, high-throughput gaming.
["net.ipv4.tcp_sack"]="1"                   # Enable Selective Acknowledgments for better packet loss recovery.
["net.ipv4.conf.all.rp_filter"]="1"         # Enable Reverse Path Filtering for security.
["net.ipv4.conf.default.rp_filter"]="1"     # Same as above for new interfaces.
["net.ipv4.ip_no_pmtu_disc"]="0"            # Enable Path MTU Discovery for optimal packet sizes.
["vm.vfs_cache_pressure"]="50"              # Increase inode cache retention for smoother gameplay.
["net.ipv4.tcp_fastopen"]="0"               # Enable fast open for lower connection setup latency.
["net.ipv4.tcp_ecn"]="0"                    # Disable ECN for better compatibility with older routers.
["net.ipv4.tcp_retries2"]="5"               # Lower retries for faster recovery of failed connections.
["net.ipv6.conf.all.forwarding"]="1"        # enable forwarding unless IPv6 routing is needed.
["net.ipv4.conf.all.forwarding"]="1"        # enable IPv4 forwarding for most gaming setups.
["net.ipv4.tcp_low_latency"]="0"            # Prioritize low latency over throughput.
["net.ipv4.tcp_window_scaling"]="1"         # Enable TCP window scaling for better performance.
["net.core.default_qdisc"]="fq_codel"       # Use FQ-CoDel to reduce bufferbloat.
["net.netfilter.nf_conntrack_max"]="65536"  # No change; sufficient for gaming.
["net.ipv4.tcp_fin_timeout"]="15"           # Short timeout for closing stale connections.
["net.netfilter.nf_conntrack_log_invalid"]="0" # Disable logging invalid packets for cleaner logs.
["net.ipv4.conf.all.log_martians"]="0"      # Disable logging martian packets for performance.
["net.ipv4.conf.default.log_martians"]="0"  # Same as above for new interfaces.
	
    )

    for key in "${!sysctl_settings[@]}"; do
        if grep -q "^$key" "$SYSCTL_CONF"; then
            sed -i "s|^$key.*|$key = ${sysctl_settings[$key]}|" "$SYSCTL_CONF"
        else
            echo "$key = ${sysctl_settings[$key]}" >> "$SYSCTL_CONF"
        fi
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
        if grep -q "^$key" "$SYSCTL_CONF"; then
            sed -i "s|^$key.*|$key = ${sysctl_settings[$key]}|" "$SYSCTL_CONF"
        else
            echo "$key = ${sysctl_settings[$key]}" >> "$SYSCTL_CONF"
        fi
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
        ["kernel.sched_latency_ns"]="6000000"
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
        grep -q "^${key} = " /etc/sysctl.conf && \
            sudo sed -i "s|^${key} = .*|${key} = ${sysctl_settings[$key]}|" /etc/sysctl.conf || \
            echo "${key} = ${sysctl_settings[$key]}" | sudo tee -a /etc/sysctl.conf >/dev/null
    done

    sudo sysctl -p
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

# Function to install BBR via LightKnight
bbr_script() {
    echo -e "\033[1;32mUpdating system and installing necessary packages...\033[0m"
    sudo apt update && sudo apt install -y python3 python3-pip
    echo -e "\033[1;32mFetching and running the Python script...\033[0m"
    python3 <(curl -Ls https://raw.githubusercontent.com/kalilovers/LightKnightBBR/main/bbr.py --ipv4)

    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mPython script executed successfully.\033[0m"
    else
        echo -e "\033[1;31mFailed to execute the Python script.\033[0m"
    fi
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
     echo -e "\033[1;32mreload\033[0m"# Apply the updated sysctl settings
    sysctl -p
}

# Function to edit limits.conf
edit_limits_conf() {
    echo -e "\033[1;32mOpening limits.conf for editing...\033[0m"
    nano $LIMITS_CONF
     echo -e "\033[1;32mreload\033[0m"# Apply the updated sysctl settings
    sysctl -p

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

# Submenu for Optimize options
Optimize_Menu() {
    while true; do
        clear
        echo -e "\033[1;32m=======================\033[0m"
        echo -e "\033[1;32m Optimize Options \033[0m"
        echo -e "\033[1;32m=======================\033[0m"
        echo -e "\033[1;32m1.\033[0m Apply light optimizations"
        echo -e "\033[1;32m2.\033[0m Disable light optimizations"
        echo -e "\033[1;32m3.\033[0m Apply full optimizations"
        echo -e "\033[1;32m4.\033[0m Remove full optimizations"
        echo -e "\033[1;32m5.\033[0m tc Optimize"
        echo -e "\033[1;32m6.\033[0m Optimize fast TCP"
        echo -e "\033[1;32m7.\033[0m Disable fast TCP"
        echo -e "\033[1;32m0.\033[0m Return to Optimizer menu"
        echo -e "\nSelect an option: "
        read opt_choice

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

        echo -e "\n\033[1;34mPress Enter to return to the Optimize submenu...\033[0m"
        read
    done
}

# Main menu for optimizer
Optimizer() {
    while true; do
        clear
        echo -e "\033[1;32m=======================\033[0m"
        echo -e "\033[1;32m Network Optimizer \033[0m"
        echo -e "\033[1;32m=======================\033[0m"
        echo -e "\033[1;32m1.\033[0m Backup (sysctl.conf & limits.conf)"
        echo -e "\033[1;32m2.\033[0m Optimize "
        echo -e "\033[1;32m3.\033[0m Set BBR by LightKnight"
        echo -e "\033[1;32m4.\033[0m Show sysctl.conf"
        echo -e "\033[1;32m5.\033[0m Show limits.conf"
        echo -e "\033[1;32m6.\033[0m Edit sysctl.conf"
        echo -e "\033[1;32m7.\033[0m Edit limits.conf"
        echo -e "\033[1;32m8.\033[0m Apply changes (sysctl -p)"
        echo -e "\033[1;32m9.\033[0m Disable log (rsyslog)"
        echo -e "\033[1;32m0.\033[0m Main menu"
        echo -e "\nSelect an option: "
        read choice

        case $choice in
            1) backup_configs ;;
            2) Optimize_Menu ;;
            3) bbr_script ;;
            4) show_sysctl_conf ;;
            5) show_limits_conf ;;
            6) edit_sysctl_conf ;;
            7) edit_limits_conf ;;
            8) sysctl -p ;;
            9)
                sudo systemctl stop rsyslog
                sudo systemctl disable rsyslog
                ;;
            0)
                echo -e "\033[1;34mReturning to main menu...\033[0m"
                break ;;
            *) echo -e "\033[1;31mInvalid option. Please select a valid number.\033[0m" ;;
        esac

        echo -e "\n\033[1;34mPress Enter to return to the Optimizer menu...\033[0m"
        read
    done
}


Optimizer
