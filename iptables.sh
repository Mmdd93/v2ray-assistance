#!/bin/bash

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# --- Root Check ---
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] This script must be run as root (sudo).${NC}"
  exit 1
fi

# --- Dependency Check & Installation ---
install_dependencies() {
    echo -e "${CYAN}--- Checking Dependencies ---${NC}"
    local packages_needed=("iptables" "iproute2" "gawk")
    local pkg_manager=""

    if command -v apt-get &> /dev/null; then
        pkg_manager="apt-get"
        packages_needed+=("iptables-persistent")
    elif command -v dnf &> /dev/null; then
        pkg_manager="dnf"
        packages_needed+=("iptables-services")
    elif command -v yum &> /dev/null; then
        pkg_manager="yum"
        packages_needed+=("iptables-services")
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
    if [ "$current_status" -eq 0 ]; then
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1
        sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
        sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
        echo -e "${GREEN}[+] IPv4 Forwarding enabled in Kernel.${NC}"
    fi
    sysctl -w net.ipv4.conf.all.route_localnet=1 > /dev/null 2>&1
    sed -i 's/#net.ipv4.conf.all.route_localnet=1/net.ipv4.conf.all.route_localnet=1/g' /etc/sysctl.conf
}

# --- Menu Function ---
show_menu() {
    clear
    echo -e "${CYAN}====================================================${NC}"
    echo -e "${GREEN}      ADVANCED IPTABLES PORT FORWARDING MANAGER     ${NC}"
    echo -e "${CYAN}====================================================${NC}"
    echo -e " 1) Add Remote Forwarding (DNAT - Server to Server)"
    echo -e " 2) Add Remote Load Balancing (DNAT to Multiple IPs)"
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

# --- Check Port Conflict ---
check_port_conflict() {
    local check_ports_array=("$1")
    local check_proto=$2
    local all_conflicts=""
    for p in "${check_ports_array[@]}"; do
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
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    read -p "Destination Target IP (e.g., 192.168.1.50): " dest_ip
    if [[ "$dest_ip" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    
    read -p "Destination Port(s) [Leave blank to use the same as Incoming] (e.g., 8080): " dest_port_raw
    if [[ "$dest_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -z "$dest_port_raw" ]; then dest_ports=("${src_ports[@]}"); else IFS=',' read -r -a dest_ports <<< "$(normalize_ports "$dest_port_raw")"; fi

    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"; dp="${dest_ports[$i]:-${dest_ports[0]}}"; dp_target=$(echo "$dp" | tr ':' '-')
        for p in "${protocols[@]}"; do
            iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp -j DNAT --to-destination $dest_ip:$dp_target
            iptables -t nat -A POSTROUTING -d $dest_ip -p $p --dport $dp -j MASQUERADE
            iptables -A FORWARD -p $p -d $dest_ip --dport $dp -j ACCEPT
        done
        echo -e "${GREEN}[+] Rule Added: $sp -> $dest_ip:$dp${NC}"
    done
    ask_save_and_continue
}

# --- 2. Add Remote Load Balancing (DNAT) ---
add_load_balancing() {
    echo -e "\n${CYAN}--- Configure Load Balancing (Round-Robin) ---${NC}"
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
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    echo -e "${YELLOW}Enter multiple destination IPs separated by commas.${NC}"
    read -p "Destination IPs (e.g., 192.168.1.10, 192.168.1.11, 10.0.0.5): " dest_ips_raw
    if [[ "$dest_ips_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    IFS=',' read -r -a dest_ips <<< "$(echo "$dest_ips_raw" | tr -d ' ')"
    
    local num_ips=${#dest_ips[@]}
    if [ "$num_ips" -lt 2 ]; then echo -e "${RED}[ERROR] You must provide at least 2 IP addresses for Load Balancing.${NC}"; sleep 2; return; fi

    read -p "Destination Port(s) [Leave blank to use the same as Incoming] (e.g., 8080): " dest_port_raw
    if [[ "$dest_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -z "$dest_port_raw" ]; then dest_ports=("${src_ports[@]}"); else IFS=',' read -r -a dest_ports <<< "$(normalize_ports "$dest_port_raw")"; fi

    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"; dp="${dest_ports[$i]:-${dest_ports[0]}}"; dp_target=$(echo "$dp" | tr ':' '-')
        for p in "${protocols[@]}"; do
            for (( j=0; j<$num_ips; j++ )); do
                dip="${dest_ips[$j]}"
                if [ $j -eq $((num_ips - 1)) ]; then
                    iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp -j DNAT --to-destination $dip:$dp_target
                else
                    every=$((num_ips - j))
                    iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp -m statistic --mode nth --every $every --packet 0 -j DNAT --to-destination $dip:$dp_target
                fi
                iptables -t nat -A POSTROUTING -d $dip -p $p --dport $dp -j MASQUERADE
                iptables -A FORWARD -p $p -d $dip --dport $dp -j ACCEPT
            done
        done
        echo -e "${GREEN}[+] Load Balancing Added: Port $sp distributed among ${dest_ips[*]} (Port $dp)${NC}"
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
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    if ! show_listening_ports; then return; fi
    
    read -p "Local Dest Port(s) [Leave blank to use the same as Incoming] (e.g., 8080): " dest_port_raw
    if [[ "$dest_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -z "$dest_port_raw" ]; then dest_ports=("${src_ports[@]}"); else IFS=',' read -r -a dest_ports <<< "$(normalize_ports "$dest_port_raw")"; fi
    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"; dp="${dest_ports[$i]:-${dest_ports[0]}}"; dp_target=$(echo "$dp" | tr ':' '-')
        for p in "${protocols[@]}"; do
            iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp -j DNAT --to-destination 127.0.0.1:$dp_target
            iptables -t nat -A POSTROUTING -d 127.0.0.1 -p $p --dport $dp -j MASQUERADE
            iptables -A FORWARD -p $p -d 127.0.0.1 --dport $dp -j ACCEPT
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
    if ! check_port_conflict "${src_ports[*]}" "$proto"; then return; fi
    
    if ! show_listening_ports; then return; fi
    
    read -p "Local Dest Port(s) [Leave blank to use the same as Incoming] (e.g., 8080): " dest_port_raw
    if [[ "$dest_port_raw" == "0" ]]; then echo -e "${YELLOW}[*] Cancelled.${NC}"; return; fi
    if [ -z "$dest_port_raw" ]; then dest_ports=("${src_ports[@]}"); else IFS=',' read -r -a dest_ports <<< "$(normalize_ports "$dest_port_raw")"; fi
    protocols=("$proto"); [ "$proto" == "all" ] && protocols=("tcp" "udp")

    for i in "${!src_ports[@]}"; do
        sp="${src_ports[$i]}"; dp="${dest_ports[$i]:-${dest_ports[0]}}"; dp_target=$(echo "$dp" | tr ':' '-')
        for p in "${protocols[@]}"; do
            iptables -t nat -A PREROUTING $iface_flag -p $p --dport $sp -j REDIRECT --to-ports $dp_target
            iptables -A INPUT -p $p --dport $dp -j ACCEPT
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

# --- 6. View Rules ---
view_rules() {
    echo -e "\n${CYAN}========================================================================================${NC}"
    echo -e "${GREEN}                              ACTIVE IPTABLES RULES                                     ${NC}"
    echo -e "${CYAN}========================================================================================${NC}"
    
    echo -e "${YELLOW}$(printf "%-20s | %-8s | %-15s | %-25s" "ACTION / TYPE" "PROTO" "SOURCE PORT" "DESTINATION / INFO")${NC}"
    echo "----------------------------------------------------------------------------------------"

    local rules_found=0
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
            local dest="-"
            
            if [[ $rule =~ -j\ LOG ]]; then
                action=$(printf "%-20s" "LOGGING (Monitor)")
                action="${CYAN}${action}${NC}"
                dest="Kernel Syslog"
            elif [[ $rule =~ -j\ REDIRECT ]]; then
                action=$(printf "%-20s" "REDIRECT (Local)")
                action="${GREEN}${action}${NC}"
                [[ $rule =~ --to-ports\ ([0-9-]+) ]] && dest="localhost:${BASH_REMATCH[1]}"
            elif [[ $rule =~ -j\ DNAT ]]; then
                if [[ $rule =~ statistic\ --mode\ nth ]]; then
                    action=$(printf "%-20s" "LOAD BALANCE (DNAT)")
                    action="${YELLOW}${action}${NC}"
                else
                    action=$(printf "%-20s" "DNAT (Remote/Local)")
                    action="${GREEN}${action}${NC}"
                fi
                [[ $rule =~ --to-destination\ ([0-9\.:-]+) ]] && dest="${BASH_REMATCH[1]}"
            fi
            
            echo -e "$action | $(printf "%-8s" "${proto^^}") | $(printf "%-15s" "$src_port") | $(printf "%-25s" "$dest")"
        fi
    done < <(iptables -t nat -S)

    if [ $rules_found -eq 0 ]; then echo -e "${YELLOW}No active PREROUTING rules found.${NC}"; fi
    echo -e "${CYAN}========================================================================================${NC}"
    read -p "Press Enter to return to menu..."
}

# --- 7. Delete Rule (Unified View) ---
delete_rule() {
    echo -e "\n${CYAN}--- All Active Rules (NAT & FILTER) ---${NC}"
    declare -a cmd_list=()
    local counter=1
    
    while read -r rule; do
        if [[ $rule == -A* ]]; then
            local del_rule="${rule/-A/-D}"
            cmd_list+=("iptables -t nat $del_rule")
            echo -e "${YELLOW}$counter)${NC} [NAT] $rule"
            ((counter++))
        fi
    done < <(iptables -t nat -S)
    
    while read -r rule; do
        if [[ $rule == -A* ]]; then
            local del_rule="${rule/-A/-D}"
            cmd_list+=("iptables -t filter $del_rule")
            echo -e "${YELLOW}$counter)${NC} [FILTER] $rule"
            ((counter++))
        fi
    done < <(iptables -t filter -S)
    
    if [ ${#cmd_list[@]} -eq 0 ]; then
        echo -e "${YELLOW}[!] No rules found. Iptables is empty.${NC}"
        read -p "Press Enter to return to menu..."
        return
    fi
    
    echo ""
    read -p "Enter rule number to delete (or 0 to cancel): " rule_choice
    if [[ "$rule_choice" -eq 0 ]]; then 
        echo -e "${YELLOW}[*] Cancelled.${NC}"
        read -p "Press Enter to return to menu..."
    elif [[ "$rule_choice" -ge 1 && "$rule_choice" -le ${#cmd_list[@]} ]]; then
        local cmd="${cmd_list[$((rule_choice-1))]}"
        eval "$cmd"
        if [ $? -eq 0 ]; then 
            echo -e "${GREEN}[+] Rule deleted successfully!${NC}"
            ask_save_and_continue
        else 
            echo -e "${RED}[ERROR] Failed to delete rule.${NC}"
            read -p "Press Enter to return to menu..."
        fi
    else 
        echo -e "${RED}[ERROR] Invalid choice.${NC}"
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
