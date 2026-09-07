#!/bin/bash

# =====================================================================
# CHANGELOG (fixes applied on top of the original script)
#  1. FIX: Local-destination DNAT (127.0.0.1) no longer relies on dead
#     FORWARD/MASQUERADE rules. Traffic to 127.0.0.1 never traverses
#     FORWARD, it goes through INPUT after DNAT — so an INPUT ACCEPT
#     rule is added instead. Affects: Local Forwarding (opt 3) and any
#     127.0.0.1 target inside Load Balancing (opt 2).
#  2. FIX: check_port_conflict() was building a broken single-element
#     array from a space-joined string, so multi-port/range conflict
#     checks silently mis-evaluated. Now properly word-splits.
#  3. FIX: Rule comments containing spaces caused word-splitting bugs
#     when the comment flag was expanded unquoted into iptables
#     commands (could break the command or truncate the comment).
#     Comments are now sanitized to a single safe token.
#  4. FIX: dnf/yum package name for iproute2 is actually "iproute" on
#     RHEL/CentOS/Fedora — install no longer fails on those distros.
#  5. FIX: enable_ip_forwarding() now appends the sysctl keys if they
#     are completely missing from /etc/sysctl.conf, not just when a
#     commented-out or existing line is present.
#  6. ADD: Port and IP validation before rules are built, so bad input
#     is caught with a clear error instead of a cryptic iptables error.
#  7. ADD: ACCEPT rules for INPUT/FORWARD are inserted at the top of
#     the chain (-I ... 1) instead of appended (-A), so they aren't
#     shadowed by a pre-existing blanket DROP/REJECT rule further up.
#  8. ADD: Idempotency checks (-C before -A/-I) on the core rules so
#     re-running the same configuration doesn't stack duplicate rules.
# =====================================================================

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
MAGENTA='\033[0;35m'

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] This script must be run as root (sudo).${NC}"
  exit 1
fi

# --- Dependency Check & Installation ---
install_dependencies() {
    echo -e "${CYAN}--- Checking Dependencies ---${NC}"
    local packages_needed=("iptables" "gawk")
    local pkg_manager=""

    if command -v apt-get &> /dev/null; then
        pkg_manager="apt-get"
        packages_needed+=("iptables-persistent" "iproute2")
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
        packages_needed+=("iptables-services" "iproute")
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
        packages_needed+=("iptables-services" "iproute")
    else
        echo -e "${RED}[ERROR] Unsupported package manager.${NC}"
        return 1
    fi

    local install_required=false
    for pkg in "${packages_needed[@]}"; do
        if ! dpkg -s "$pkg" &> /dev/null && ! rpm -q "$pkg" &> /dev/null; then
            install_required=true
        fi
    done

    if [ "$install_required" = true ]; then
        echo -e "${YELLOW}[*] Installing missing dependencies...${NC}"
        export DEBIAN_FRONTEND=noninteractive
        $pkg_manager update -y -q > /dev/null 2>&1
        $pkg_manager install -y -q "${packages_needed[@]}" > /dev/null 2>&1
        echo -e "${GREEN}[+] Dependencies installed successfully.${NC}"
    else
        echo -e "${GREEN}[+] All required packages are already installed.${NC}"
    fi
}

# --- Ensure IP Forwarding is Enabled ---
enable_ip_forwarding() {
    local current_status=$(cat /proc/sys/net/ipv4/ip_forward)
    if [ "$current_status" -ne 1 ]; then
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        if grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null; then
            sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
        elif grep -q "^#net.ipv4.ip_forward" /etc/sysctl.conf 2>/dev/null; then
            sed -i 's/^#net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
        else
            echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
        fi
        echo -e "${GREEN}[+] IPv4 Forwarding enabled in Kernel.${NC}"
    fi

    sysctl -w net.ipv4.conf.all.route_localnet=1 > /dev/null 2>&1
    if grep -q "^net.ipv4.conf.all.route_localnet" /etc/sysctl.conf 2>/dev/null; then
        sed -i 's/^net.ipv4.conf.all.route_localnet.*/net.ipv4.conf.all.route_localnet=1/' /etc/sysctl.conf
    elif grep -q "^#net.ipv4.conf.all.route_localnet" /etc/sysctl.conf 2>/dev/null; then
        sed -i 's/^#net.ipv4.conf.all.route_localnet.*/net.ipv4.conf.all.route_localnet=1/' /etc/sysctl.conf
    else
        echo "net.ipv4.conf.all.route_localnet=1" >> /etc/sysctl.conf
    fi
}

# --- Menu Function ---
show_menu() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN}      ADVANCED IPTABLES PORT FORWARDING MANAGER     ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e " 1) Add Remote Forwarding (DNAT - Server to Server)"
    echo -e " 2) Add Advanced Load Balancing (Local/Remote/Mixed Ports)"
    echo -e " 3) Add Local Forwarding (DNAT - to 127.0.0.1)"
    echo -e " 4) Add Local Redirection (REDIRECT - Best for Localhost)"
    echo -e " 5) Manage Traffic Logging (Enable / Disable / View Logs)"
    echo -e " 6) View Active Forwarding & Redirection Rules"
    echo -e " 7) Delete a Specific Rule"
    echo -e " 8) Flush All NAT, FORWARD & REDIRECT Rules"
    echo -e " 9) Save Rules (Make Persistent After Reboot)"
    echo -e " 10) Backup Current Rules to File"
    echo -e " 11) Restore Rules from File"
    echo -e " 0) Exit"
    echo -e "${CYAN}====================================================${NC}"
}

# --- Smart Port Parser ---
normalize_ports() {
    local raw="$1"
    local clean=$(echo "$raw" | tr ',' ' ')
    clean=$(echo "$clean" | sed -E 's/ *- */:/g')
    clean=$(echo "$clean" | sed -E 's/ *: */:/g')
    clean=$(echo "$clean" | tr -s ' ' | sed 's/^ //;s/ $//')
    echo "${clean// /,}"
}

# --- Port List Validator (catches bad input before it hits iptables) ---
validate_port_list() {
    local p start_p end_p
    for p in "$@"; do
        if [[ ! "$p" =~ ^[0-9]+(:[0-9]+)?$ ]]; then
            echo -e "${RED}[ERROR] Invalid port value: '$p'${NC}"
            return 1
        fi
        start_p="${p%%:*}"
        end_p="${p##*:}"
        if (( start_p < 1 || start_p > 65535 || end_p < 1 || end_p > 65535 )); then
            echo -e "${RED}[ERROR] Port out of range (1-65535): '$p'${NC}"
            return 1
        fi
        if (( start_p > end_p )); then
            echo -e "${RED}[ERROR] Invalid range (start > end): '$p'${NC}"
            return 1
        fi
    done
    return 0
}

# --- IPv4 Validator ---
validate_ip() {
    local ip="$1" octet
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    IFS='.' read -r -a octets <<< "$ip"
    for octet in "${octets[@]}"; do
        (( octet >= 0 && octet <= 255 )) || return 1
    done
    return 0
}

# --- Check Port Conflict ---
check_port_conflict() {
    local ports_str="$1"
    local check_proto=$2
    local all_conflicts=""
    local check_ports_array=()
    IFS=' ' read -r -a check_ports_array <<< "$ports_str"
    for p in "${check_ports_array[@]}"; do
        [ -z "$p" ] && continue
        local sp="${p%:*}"; local ep="${p#*:}"
        local conflicts=$(ss -tulnp | awk -v sp="$sp" -v ep="$ep" -v proto="$check_proto" '
            NR>1 {
                n=split($5,a,":"); port=a[n];
                if (port >= sp && port <= ep) {
                    if (proto == "all" || $1 == proto) {
                        match($0, /users:\(\("([^"]+)"/);
                        proc = (RSTART>0) ? substr($0, RSTART+9, RLENGTH-10) : "Unknown Process";
                        print "- Port " port " (" $1 ") is used by [" proc "]"
                    }
                }
            }')
        if [ -n "$conflicts" ]; then all_conflicts="${all_conflicts}${conflicts}\n"; fi
    done
    if [ -n "$all_conflicts" ]; then
        echo -e "\n${RED}[WARNING] CONFLICT DETECTED!${NC}"
        echo -e "${YELLOW}The following incoming port(s) are already in use on this server:${NC}"
        echo -e "${RED}$(echo -e "$all_conflicts" | sed '/^$/d')${NC}"
        read -p "Are you absolutely sure you want to proceed? (y/N) [0 to cancel]: " proceed
        if [[ "$proceed" == "0" || ! "$proceed" =~ ^[Yy]$ ]]; then echo -e "${GREEN}[*] Cancelled.${NC}"; return 1; fi
    fi
    return 0
}

# --- Show Listening Ports ---
show_listening_ports() {
    echo ""
    read -p "Do you want to see the list of active listening ports? (y/N) [0 to cancel]: " show_ports
    if [[ "$show_ports" == "0" ]]; then echo -e "${YELLOW}[*] Operation cancelled.${NC}"; return 1; fi
    if [[ "$show_ports" =~ ^[Yy]$ ]]; then
        echo -e "\n${CYAN}--- Currently Listening Ports (Active Services) ---${NC}"
        echo -e "${YELLOW}Proto | Local Address   | Port   | Process Name${NC}"
        echo "--------------------------------------------------------"
        ss -tulnp | awk 'NR>1 {
            n=split($5,a,":"); port=a[n]; addr=substr($5,1,length($5)-length(port)-1);
            match($0,/users:\(\("([^"]+)"/); proc=(RSTART>0)?substr($0,RSTART+9,RLENGTH-10):"Unknown";
            key=$1"|"addr"|"port; if(!seen[key]++) printf "%-5s | %-15s | %-6s | %s\n", $1, addr, port, proc;
        }' | sort -t '|' -k 3 -n
        echo "--------------------------------------------------------"
    fi
    return 0
}

# --- Core Save Logic ---
do_save_persistent() {
    if command -v netfilter-persistent &> /dev/null; then
        netfilter-persistent save > /dev/null && echo -e "${GREEN}[+] Rules saved via netfilter-persistent.${NC}"
    elif command -v iptables-save &> /dev/null; then
        if [ -d "/etc/sysconfig" ]; then
            iptables-save > /etc/sysconfig/iptables && echo -e "${GREEN}[+] Rules saved to /etc/sysconfig/iptables.${NC}"
        else
            mkdir -p /etc/iptables
            iptables-save > /etc/iptables/rules.v4 && echo -e "${GREEN}[+] Rules saved to /etc/iptables/rules.v4.${NC}"
        fi
    else 
        echo -e "${RED}[ERROR] Could not find a method to save rules persistently.${NC}"
    fi
}

ask_save_and_continue() {
    echo ""
    read -p "Do you want to save these changes persistently (survive reboot)? (y/N) [0 to skip]: " do_save
    if [[ "$do_save" == "0" ]]; then
        echo -e "${YELLOW}[*] Save skipped.${NC}"
    elif [[ "$do_save" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}[*] Saving rules...${NC}"
        do_save_persistent
    fi
    read -p "Press Enter to return to menu..."
}

# --- Comment Sanitizer (prevents word-splitting bugs downstream) ---
sanitize_comment() {
    local input="$1"
    input=$(echo "$input" | tr -d '"'\''')
    input=$(echo "$input" | tr -s '[:space:]' '_')
    input=$(echo "$input" | sed 's/[^A-Za-z0-9_-]/_/g')
    echo "$input"
}

# --- Naming Helper ---
get_rule_comment() {
    local rule_name
    read -p "Enter a name/comment for this rule [Default: iptables-script]: " rule_name
    if [[ "$rule_name" == "0" ]]; then echo "0"; return; fi
    if [[ -z "$rule_name" ]]; then
        echo "-m comment --comment iptables-script"
    else
        rule_name=$(sanitize_comment "$rule_name")
        [[ -z "$rule_name" ]] && rule_name="iptables-script"
        echo "-m comment --comment $rule_name"
    fi
}

# --- 1. Add Remote Rule (DNAT) ---
add_remote_rule() {
    echo -e "\n${CYAN}--- Configure Remote Forwarding (DNAT) ---${NC}"
    echo -e "${YELLOW}(Tip: Enter '0' at any prompt to cancel and go back to menu)${NC}"
    
    read -p "Enter Protocol (tcp / udp / all) [Default: all]: " proto; proto=${proto:-all}
    if [[ "$proto" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [[ "$proto" != "tcp" && "$proto" != "udp" && "$proto" != "all" ]]; then echo -e "${RED}[ERROR] Invalid protocol.${NC}"; sleep 2; return; fi
    
    read -p "Incoming Interface (e.g., eth0) [Leave blank for ANY]: " in_iface
    if [[ "$in_iface" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    iface_flag=""; [ -n "$in_iface" ] && iface_flag="-i $in_iface"
    
    read -p "Incoming Port(s) or Range (e.g., 80 443, 1000-2000, 3000:4000): " src_port_raw
    if [[ "$src_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    IFS=',' read -r -a src_ports <<< "$(normalize_ports "$src_port_raw")"
    if ! validate_port_list "${src_ports[@]}"; then sleep 2; return; fi
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    read -p "Destination Target IP (e.g., 192.168.1.50): " dest_ip
    if [[ "$dest_ip" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if ! validate_ip "$dest_ip"; then echo -e "${RED}[ERROR] Invalid IP address: '$dest_ip'${NC}"; sleep 2; return; fi
    
    read -p "Destination Port(s) [Leave blank to use the same as Incoming] (e.g., 8080): " dest_port_raw
    if [[ "$dest_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -z "$dest_port_raw" ]; then dest_ports=("${src_ports[@]}"); else IFS=',' read -r -a dest_ports <<< "$(normalize_ports "$dest_port_raw")"; fi
    if ! validate_port_list "${dest_ports[@]}"; then sleep 2; return; fi

    local comment_flag=$(get_rule_comment)
    if [[ "$comment_flag" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi

    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"; dp="${dest_ports[$i]:-${dest_ports[0]}}"; dp_target=$(echo "$dp" | tr ':' '-')
        for p in "${protocols[@]}"; do
            iptables -t nat -C PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j DNAT --to-destination $dest_ip:$dp_target 2>/dev/null || \
                iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j DNAT --to-destination $dest_ip:$dp_target
            if [[ "$dest_ip" == "127.0.0.1" ]]; then
                iptables -C INPUT -p $p --dport $dp $comment_flag -j ACCEPT 2>/dev/null || \
                    iptables -I INPUT 1 -p $p --dport $dp $comment_flag -j ACCEPT
            else
                iptables -t nat -C POSTROUTING -d $dest_ip -p $p --dport $dp $comment_flag -j MASQUERADE 2>/dev/null || \
                    iptables -t nat -A POSTROUTING -d $dest_ip -p $p --dport $dp $comment_flag -j MASQUERADE
                iptables -C FORWARD -p $p -d $dest_ip --dport $dp $comment_flag -j ACCEPT 2>/dev/null || \
                    iptables -I FORWARD 1 -p $p -d $dest_ip --dport $dp $comment_flag -j ACCEPT
            fi
        done
        echo -e "${GREEN}[+] Rule Added: $sp -> $dest_ip:$dp${NC}"
    done
    ask_save_and_continue
}

# --- 2. Add Advanced Load Balancing (DNAT) ---
add_load_balancing() {
    echo -e "\n${CYAN}--- Configure Advanced Load Balancing (Round-Robin) ---${NC}"
    echo -e "${YELLOW}(Tip: Enter '0' at any prompt to cancel and go back to menu)${NC}"
    
    read -p "Enter Protocol (tcp / udp / all) [Default: all]: " proto; proto=${proto:-all}
    if [[ "$proto" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [[ "$proto" != "tcp" && "$proto" != "udp" && "$proto" != "all" ]]; then echo -e "${RED}[ERROR] Invalid protocol.${NC}"; sleep 2; return; fi
    
    read -p "Incoming Interface (e.g., eth0) [Leave blank for ANY]: " in_iface
    if [[ "$in_iface" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    iface_flag=""; [ -n "$in_iface" ] && iface_flag="-i $in_iface"

    read -p "Incoming Port(s) or Range (e.g., 80 443, 1000-2000): " src_port_raw
    if [[ "$src_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    IFS=',' read -r -a src_ports <<< "$(normalize_ports "$src_port_raw")"
    if ! validate_port_list "${src_ports[@]}"; then sleep 2; return; fi
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    echo -e "\n${YELLOW}Enter destination targets. You can mix Localhost (127.0.0.1) and Remote IPs."
    echo -e "Format: IP or IP:PORT. Separate multiple targets with commas."
    echo -e "Examples:"
    echo -e "  - Balance between local ports: 127.0.0.1:8081, 127.0.0.1:8082"
    echo -e "  - Mix local and remote: 127.0.0.1:8080, 192.168.1.10:80, 10.0.0.5${NC}"
    read -p "Targets: " targets_raw
    
    if [[ "$targets_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    IFS=',' read -r -a targets <<< "$(echo "$targets_raw" | tr -d ' ')"
    
    local num_targets=${#targets[@]}
    if [ "$num_targets" -lt 2 ]; then echo -e "${RED}[ERROR] You must provide at least 2 targets for Load Balancing.${NC}"; sleep 2; return; fi

    # Validate every target's IP (and port, if given) before touching iptables
    for target in "${targets[@]}"; do
        local t_ip="$target" t_port=""
        if [[ "$target" == *":"* ]]; then t_ip="${target%:*}"; t_port="${target#*:}"; fi
        if ! validate_ip "$t_ip"; then echo -e "${RED}[ERROR] Invalid target IP: '$t_ip'${NC}"; sleep 2; return; fi
        if [[ -n "$t_port" ]] && ! validate_port_list "$t_port"; then sleep 2; return; fi
    done

    local comment_flag=$(get_rule_comment)
    if [[ "$comment_flag" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi

    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"
        
        for p in "${protocols[@]}"; do
            for (( j=0; j<$num_targets; j++ )); do
                target="${targets[$j]}"
                local dip dp dp_target
                
                if [[ "$target" == *":"* ]]; then
                    dip="${target%:*}"
                    dp="${target#*:}"
                else
                    dip="$target"
                    dp="$sp"
                fi
                
                dp_target=$(echo "$dp" | tr ':' '-')

                if [ $j -eq $((num_targets - 1)) ]; then
                    iptables -t nat -C PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j DNAT --to-destination $dip:$dp_target 2>/dev/null || \
                        iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j DNAT --to-destination $dip:$dp_target
                else
                    every=$((num_targets - j))
                    iptables -t nat -C PREROUTING $iface_flag -p $p --dport $sp -m statistic --mode nth --every $every --packet 0 $comment_flag -j DNAT --to-destination $dip:$dp_target 2>/dev/null || \
                        iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp -m statistic --mode nth --every $every --packet 0 $comment_flag -j DNAT --to-destination $dip:$dp_target
                fi

                # FIX: destinations of 127.0.0.1 never traverse FORWARD - they hit
                # INPUT after DNAT. The old script added dead MASQUERADE/FORWARD
                # rules here that never matched local targets.
                if [[ "$dip" == "127.0.0.1" ]]; then
                    iptables -C INPUT -p $p --dport $dp $comment_flag -j ACCEPT 2>/dev/null || \
                        iptables -I INPUT 1 -p $p --dport $dp $comment_flag -j ACCEPT
                else
                    iptables -t nat -C POSTROUTING -d $dip -p $p --dport $dp $comment_flag -j MASQUERADE 2>/dev/null || \
                        iptables -t nat -A POSTROUTING -d $dip -p $p --dport $dp $comment_flag -j MASQUERADE
                    iptables -C FORWARD -p $p -d $dip --dport $dp $comment_flag -j ACCEPT 2>/dev/null || \
                        iptables -I FORWARD 1 -p $p -d $dip --dport $dp $comment_flag -j ACCEPT
                fi
            done
        done
        echo -e "${GREEN}[+] Load Balancing Added: Port $sp distributed among [ ${targets[*]} ]${NC}"
    done
    ask_save_and_continue
}

# --- 3. Add Local DNAT ---
add_local_dnat() {
    echo -e "\n${CYAN}--- Configure Local Forwarding (DNAT to 127.0.0.1) ---${NC}"
    echo -e "${YELLOW}(Tip: Enter '0' at any prompt to cancel and go back to menu)${NC}"
    
    read -p "Enter Protocol (tcp / udp / all) [Default: all]: " proto; proto=${proto:-all}
    if [[ "$proto" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [[ "$proto" != "tcp" && "$proto" != "udp" && "$proto" != "all" ]]; then echo -e "${RED}[ERROR] Invalid protocol.${NC}"; sleep 2; return; fi
    
    read -p "Incoming Interface (e.g., eth0) [Leave blank for ANY]: " in_iface
    if [[ "$in_iface" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    iface_flag=""; [ -n "$in_iface" ] && iface_flag="-i $in_iface"

    read -p "Incoming Port(s) or Range (e.g., 80 443, 1000-2000, 3000:4000): " src_port_raw
    if [[ "$src_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    IFS=',' read -r -a src_ports <<< "$(normalize_ports "$src_port_raw")"
    if ! validate_port_list "${src_ports[@]}"; then sleep 2; return; fi
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    if ! show_listening_ports; then return; fi
    
    read -p "Local Dest Port(s) [Leave blank to use the same as Incoming] (e.g., 8080): " dest_port_raw
    if [[ "$dest_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -z "$dest_port_raw" ]; then dest_ports=("${src_ports[@]}"); else IFS=',' read -r -a dest_ports <<< "$(normalize_ports "$dest_port_raw")"; fi
    if ! validate_port_list "${dest_ports[@]}"; then sleep 2; return; fi
    
    local comment_flag=$(get_rule_comment)
    if [[ "$comment_flag" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    
    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"; dp="${dest_ports[$i]:-${dest_ports[0]}}"; dp_target=$(echo "$dp" | tr ':' '-')
        for p in "${protocols[@]}"; do
            iptables -t nat -C PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j DNAT --to-destination 127.0.0.1:$dp_target 2>/dev/null || \
                iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j DNAT --to-destination 127.0.0.1:$dp_target
            # FIX: was adding dead POSTROUTING MASQUERADE + FORWARD ACCEPT rules
            # (traffic to 127.0.0.1 never hits FORWARD). Now correctly opens INPUT.
            iptables -C INPUT -p $p --dport $dp $comment_flag -j ACCEPT 2>/dev/null || \
                iptables -I INPUT 1 -p $p --dport $dp $comment_flag -j ACCEPT
        done
        echo -e "${GREEN}[+] Rule Added: $sp -> 127.0.0.1:$dp${NC}"
    done
    ask_save_and_continue
}

# --- 4. Add Local REDIRECT ---
add_local_redirect() {
    echo -e "\n${CYAN}--- Configure Local Port Redirection (REDIRECT target) ---${NC}"
    echo -e "${YELLOW}(Tip: Enter '0' at any prompt to cancel and go back to menu)${NC}"
    
    read -p "Enter Protocol (tcp / udp / all) [Default: all]: " proto; proto=${proto:-all}
    if [[ "$proto" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [[ "$proto" != "tcp" && "$proto" != "udp" && "$proto" != "all" ]]; then echo -e "${RED}[ERROR] Invalid protocol.${NC}"; sleep 2; return; fi
    
    read -p "Incoming Interface (e.g., eth0) [Leave blank for ANY]: " in_iface
    if [[ "$in_iface" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    iface_flag=""; [ -n "$in_iface" ] && iface_flag="-i $in_iface"

    read -p "Incoming Port(s) or Range (e.g., 80 443, 1000-2000, 3000:4000): " src_port_raw
    if [[ "$src_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    IFS=',' read -r -a src_ports <<< "$(normalize_ports "$src_port_raw")"
    if ! validate_port_list "${src_ports[@]}"; then sleep 2; return; fi
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    if ! show_listening_ports; then return; fi
    
    read -p "Local Dest Port(s) [Leave blank to use the same as Incoming] (e.g., 8080): " dest_port_raw
    if [[ "$dest_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -z "$dest_port_raw" ]; then dest_ports=("${src_ports[@]}"); else IFS=',' read -r -a dest_ports <<< "$(normalize_ports "$dest_port_raw")"; fi
    if ! validate_port_list "${dest_ports[@]}"; then sleep 2; return; fi
    
    local comment_flag=$(get_rule_comment)
    if [[ "$comment_flag" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    
    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"; dp="${dest_ports[$i]:-${dest_ports[0]}}"; dp_target=$(echo "$dp" | tr ':' '-')
        for p in "${protocols[@]}"; do
            iptables -t nat -C PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j REDIRECT --to-ports $dp_target 2>/dev/null || \
                iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp $comment_flag -j REDIRECT --to-ports $dp_target
            iptables -C INPUT -p $p --dport $dp $comment_flag -j ACCEPT 2>/dev/null || \
                iptables -I INPUT 1 -p $p --dport $dp $comment_flag -j ACCEPT
        done
        echo -e "${GREEN}[+] Local Redirect Added: $sp -> Local $dp_target${NC}"
    done
    ask_save_and_continue
}

# --- 5. Traffic Logging Management ---
manage_logging() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${YELLOW}            TRAFFIC LOGGING MANAGEMENT              ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo " 1) Enable Logging for a Specific Port"
    echo " 2) Disable Logging (Remove all log rules)"
    echo " 3) View Live Traffic Logs"
    echo " 0) Go Back"
    read -p "Choose an option: " log_choice

    case $log_choice in
        1)
            echo -e "${YELLOW}(Tip: Enter '0' at any prompt to cancel and go back)${NC}"
            read -p "Enter Protocol to log (tcp / udp / all) [Default: all]: " proto; proto=${proto:-all}
            if [[ "$proto" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
            read -p "Enter Incoming Port to log (e.g., 8080): " log_port
            if [[ "$log_port" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
            if ! validate_port_list "$log_port"; then sleep 2; return; fi
            
            protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")
            for p in "${protocols[@]}"; do
                iptables -t nat -I PREROUTING 1 -p $p --dport $log_port -j LOG --log-prefix " [IPT-FWD-LOG] " --log-level 4
            done
            echo -e "${GREEN}[+] Logging Enabled for Port $log_port. Logs are saved to Kernel (dmesg).${NC}"
            ask_save_and_continue
            ;;
        2)
            echo -e "${YELLOW}[*] Removing all logging rules...${NC}"
            local rules_removed=0
            while read -r rule; do
                if [[ $rule == -A*LOG*IPT-FWD-LOG* ]]; then
                    local del_rule="${rule/-A/-D}"
                    iptables -t nat $del_rule
                    rules_removed=1
                fi
            done < <(iptables -t nat -S)
            if [ $rules_removed -eq 1 ]; then
                echo -e "${GREEN}[+] All Logging rules disabled.${NC}"
                ask_save_and_continue
            else
                echo -e "${YELLOW}[!] No active logging rules found.${NC}"
                read -p "Press Enter to return to menu..."
            fi
            ;;
        3)
            echo -e "${CYAN}[*] Viewing Live Logs... (Press CTRL+C to stop)${NC}"
            if command -v journalctl &> /dev/null; then
                journalctl -k -f | grep "IPT-FWD-LOG"
            else
                dmesg -wT | grep "IPT-FWD-LOG"
            fi
            ;;
        0) return ;;
        *) echo -e "${RED}[ERROR] Invalid option.${NC}"; sleep 1 ;;
    esac
}

# --- 6. View Rules (Smart Parsing for Load Balance & Local/Remote) ---
view_rules() {
    echo -e "\n${CYAN}=======================================================================================================${NC}"
    echo -e "${GREEN}                                        ACTIVE IPTABLES RULES                                          ${NC}"
    echo -e "${CYAN}=======================================================================================================${NC}"
    
    echo -e "${YELLOW}$(printf "%-22s | %-6s | %-15s | %-22s | %s" "ACTION / TYPE" "PROTO" "SOURCE PORT" "DESTINATION" "NAME/COMMENT")${NC}"
    echo "-------------------------------------------------------------------------------------------------------"

    local rules_found=0
    local prev_src_port=""
    local prev_proto=""
    local prev_is_lb=0

    while read -r rule; do
        if [[ $rule == -A\ PREROUTING* ]]; then
            rules_found=1
            local proto="ALL"
            [[ $rule =~ -p\ ([a-z]+) ]] && proto="${BASH_REMATCH[1]}"
            
            local src_port="ANY"
            if [[ $rule =~ --dport\ ([0-9:]+) ]]; then src_port="${BASH_REMATCH[1]}"
            elif [[ $rule =~ multiport\ --dports\ ([0-9:,]+) ]]; then src_port="${BASH_REMATCH[1]}"
            fi
            
            local action="UNKNOWN"
            local color="${NC}"
            local dest="-"
            local comment="-"
            [[ $rule =~ --comment\ ([^\ ]+) ]] && comment="${BASH_REMATCH[1]}"
            [[ $rule =~ --comment\ \"([^\"]+)\" ]] && comment="${BASH_REMATCH[1]}"
            
            if [[ $rule =~ -j\ LOG ]]; then
                action="LOGGING (Monitor)"
                color="${CYAN}"
                dest="Kernel Syslog"
            elif [[ $rule =~ -j\ REDIRECT ]]; then
                action="REDIRECT (Local)"
                color="${GREEN}"
                [[ $rule =~ --to-ports\ ([0-9-]+) ]] && dest="127.0.0.1:${BASH_REMATCH[1]}"
            elif [[ $rule =~ -j\ DNAT ]]; then
                [[ $rule =~ --to-destination\ ([0-9\.:-]+) ]] && dest="${BASH_REMATCH[1]}"
                
                local loc_type="Remote"
                [[ "$dest" == 127.0.0.* ]] && loc_type="Local"

                if [[ $rule =~ statistic\ --mode\ nth ]]; then
                    action="LOAD BALANCE ($loc_type)"
                    color="${YELLOW}"
                    prev_src_port="$src_port"
                    prev_proto="$proto"
                    prev_is_lb=1
                else
                    # Check if this rule is the fallback of a previous load balancer group
                    if [[ "$prev_is_lb" -eq 1 && "$src_port" == "$prev_src_port" && "$proto" == "$prev_proto" ]]; then
                        action="LOAD BALANCE ($loc_type)"
                        color="${YELLOW}"
                    else
                        action="DNAT ($loc_type)"
                        color="${GREEN}"
                    fi
                    prev_is_lb=0
                fi
            fi
            
            local formatted_action=$(printf "%-22s" "$action")
            echo -e "${color}${formatted_action}${NC} | $(printf "%-6s" "${proto^^}") | $(printf "%-15s" "$src_port") | $(printf "%-22s" "$dest") | ${MAGENTA}$comment${NC}"
        fi
    done < <(iptables -t nat -S)

    if [ $rules_found -eq 0 ]; then echo -e "${YELLOW}No active PREROUTING rules found.${NC}"; fi
    echo -e "${CYAN}=======================================================================================================${NC}"
    read -p "Press Enter to return to menu..."
}

# --- 7. Delete Rule (Multi-Delete) ---
delete_rule() {
    echo -e "\n${CYAN}========================================================================================================${NC}"
    echo -e "${GREEN}                                      ACTIVE IPTABLES RULES                                             ${NC}"
    echo -e "${CYAN}========================================================================================================${NC}"
    echo -e "${YELLOW}$(printf "%-3s | %-15s | %-11s | %-5s | %-20s | %s" "ID" "TABLE:CHAIN" "ACTION" "PROTO" "NAME/COMMENT" "DETAILS")${NC}"
    echo "--------------------------------------------------------------------------------------------------------"

    declare -a cmd_list=()
    local counter=1

    print_rule() {
        local table=$1
        local rule=$2
        
        local chain="-"; [[ $rule =~ -A\ ([A-Z]+) ]] && chain="${BASH_REMATCH[1]}"
        local target="-"; [[ $rule =~ -j\ ([A-Z]+) ]] && target="${BASH_REMATCH[1]}"
        local proto="ALL"; [[ $rule =~ -p\ ([a-z0-9]+) ]] && proto="${BASH_REMATCH[1]}"
        
        local details=""
        [[ $rule =~ -s\ ([0-9\.\/]+) ]] && details+="SRC:${BASH_REMATCH[1]} "
        [[ $rule =~ -d\ ([0-9\.\/]+) ]] && details+="DST:${BASH_REMATCH[1]} "
        [[ $rule =~ --dport\ ([0-9:\-]+) ]] && details+="DPT:${BASH_REMATCH[1]} "
        [[ $rule =~ --dports\ ([0-9:\-]+) ]] && details+="DPT:${BASH_REMATCH[1]} "
        [[ $rule =~ --to-destination\ ([0-9\.:\-]+) ]] && details+="-> ${BASH_REMATCH[1]} "
        [[ $rule =~ --to-ports\ ([0-9\-]+) ]] && details+="-> PORT:${BASH_REMATCH[1]} "
        [[ $rule =~ -i\ ([a-zA-Z0-9\+\-]+) ]] && details+="IN:${BASH_REMATCH[1]} "
        [[ $rule =~ -o\ ([a-zA-Z0-9\+\-]+) ]] && details+="OUT:${BASH_REMATCH[1]} "
        
        local comment="-"
        [[ $rule =~ --comment\ ([^\ ]+) ]] && comment="${BASH_REMATCH[1]}"
        [[ $rule =~ --comment\ \"([^\"]+)\" ]] && comment="${BASH_REMATCH[1]}"
        
        local tbl_short="NAT"; [ "$table" == "filter" ] && tbl_short="FLT"
        
        local color=$NC
        [[ "$target" == "ACCEPT" || "$target" == "DNAT" ]] && color=$GREEN
        [[ "$target" == "DROP" || "$target" == "REJECT" ]] && color=$RED
        [[ "$target" == "MASQUERADE" || "$target" == "REDIRECT" ]] && color=$CYAN
        [[ "$target" == "LOG" ]] && color=$YELLOW

        printf "%-3s | %-15s | ${color}%-11s${NC} | %-5s | ${MAGENTA}%-20s${NC} | %s\n" "$counter" "${tbl_short}:${chain}" "$target" "${proto^^}" "${comment:0:20}" "$details"
    }
    
    while read -r rule; do
        if [[ $rule == -A* ]]; then
            cmd_list+=("iptables -t nat ${rule/-A/-D}")
            print_rule "nat" "$rule"
            ((counter++))
        fi
    done < <(iptables -t nat -S)
    
    while read -r rule; do
        if [[ $rule == -A* ]]; then
            cmd_list+=("iptables -t filter ${rule/-A/-D}")
            print_rule "filter" "$rule"
            ((counter++))
        fi
    done < <(iptables -t filter -S)
    
    if [ ${#cmd_list[@]} -eq 0 ]; then
        echo -e "${YELLOW}[!] No rules found. Iptables is empty.${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi
    
    echo -e "${CYAN}========================================================================================================${NC}"
    read -p "Enter rule number(s) to delete (e.g., 1, 3, 5-10 or 0 to cancel): " raw_choices
    
    if [[ "$raw_choices" == "0" ]]; then 
        echo -e "${YELLOW}[*] Cancelled.${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi

    raw_choices=$(echo "$raw_choices" | tr ',' ' ')
    local expanded_choices=""
    for item in $raw_choices; do
        if [[ $item =~ ^([0-9]+)-([0-9]+)$ ]]; then
            local start=${BASH_REMATCH[1]}
            local end=${BASH_REMATCH[2]}
            if [ "$start" -gt "$end" ]; then local temp=$start; start=$end; end=$temp; fi
            expanded_choices+="$(seq -s ' ' $start $end) "
        elif [[ $item =~ ^[0-9]+$ ]]; then
            expanded_choices+="$item "
        fi
    done

    local unique_choices=$(echo "$expanded_choices" | tr ' ' '\n' | sort -n -u)
    local deleted_count=0

    echo ""
    for num in $unique_choices; do
        if [[ "$num" -ge 1 && "$num" -le ${#cmd_list[@]} ]]; then
            local cmd="${cmd_list[$((num-1))]}"
            eval "$cmd"
            if [ $? -eq 0 ]; then 
                echo -e "${GREEN}[+] Rule $num deleted successfully!${NC}"
                ((deleted_count++))
            else 
                echo -e "${RED}[ERROR] Failed to delete rule $num.${NC}"
            fi
        else
            echo -e "${RED}[ERROR] Rule $num does not exist, skipping.${NC}"
        fi
    done

    if [ "$deleted_count" -gt 0 ]; then
        ask_save_and_continue
    else
        read -p "Press Enter to return to menu..."
    fi
}

# --- 8. Flush Rules ---
flush_rules() {
    echo -e "\n${RED}[WARNING] This will completely reset iptables to an empty state.${NC}"
    read -p "Are you absolutely sure? (y/N) [0 to cancel]: " confirm
    if [[ "$confirm" == "0" ]]; then
        echo -e "${YELLOW}[*] Operation cancelled.${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[*] Resetting all iptables rules...${NC}"
        iptables -P INPUT ACCEPT; iptables -P FORWARD ACCEPT; iptables -P OUTPUT ACCEPT
        iptables -t nat -P PREROUTING ACCEPT; iptables -t nat -P INPUT ACCEPT; iptables -t nat -P OUTPUT ACCEPT; iptables -t nat -P POSTROUTING ACCEPT
        iptables -F; iptables -t nat -F; iptables -t mangle -F; iptables -t raw -F
        iptables -X; iptables -t nat -X; iptables -t mangle -X; iptables -t raw -X
        echo -e "${GREEN}[+] Iptables has been completely flushed and reset.${NC}"
        ask_save_and_continue
    else
        echo -e "${YELLOW}[!] Operation cancelled.${NC}"
        read -p "Press Enter to return to menu..."
    fi
}

# --- 9. Save Persistent (Menu Option) ---
save_persistent_menu() {
    echo -e "\n${CYAN}--- Saving Rules ---${NC}"
    do_save_persistent
    read -p "Press Enter to return to menu..."
}

# --- 10 & 11. Backup / Restore ---
backup_rules() {
    echo -e "\n${CYAN}--- Backup Rules ---${NC}"
    read -p "Enter backup path (default: /root/iptables_backup.txt) [0 to cancel]: " filepath
    if [[ "$filepath" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    filepath=${filepath:-/root/iptables_backup.txt}
    iptables-save > "$filepath" && echo -e "${GREEN}[+] Backed up to $filepath${NC}"
    read -p "Press Enter to return to menu..."
}

restore_rules() {
    echo -e "\n${CYAN}--- Restore Rules ---${NC}"
    read -p "Enter backup file path to restore [0 to cancel]: " filepath
    if [[ "$filepath" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -f "$filepath" ]; then iptables-restore < "$filepath" && echo -e "${GREEN}[+] Restored from $filepath${NC}"
    else echo -e "${RED}[ERROR] File not found!${NC}"; fi
    read -p "Press Enter to return to menu..."
}

# --- Main Execution ---
install_dependencies
enable_ip_forwarding
sleep 1

while true; do
    show_menu
    read -p "Enter your choice [0-11]: " choice
    case $choice in
        1) add_remote_rule ;;
        2) add_load_balancing ;;
        3) add_local_dnat ;;
        4) add_local_redirect ;;
        5) manage_logging ;;
        6) view_rules ;;
        7) delete_rule ;;
        8) flush_rules ;;
        9) save_persistent_menu ;;
        10) backup_rules ;;
        11) restore_rules ;;
        0) echo -e "${GREEN}Exiting...${NC}"; exit 0 ;;
        *) echo -e "${RED}[ERROR] Invalid option!${NC}"; sleep 1 ;;
    esac
done
