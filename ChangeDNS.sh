#!/bin/bash
# Color codes
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

# Function to display system status
show_status() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m           DNS MANAGER - SYSTEM STATUS\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    
    # DNS resolution status
    echo -e "\033[1;35mDNS RESOLUTION:\033[0m"
    if nslookup google.com &>/dev/null; then
        echo -e "  ${GREEN}✓ DNS Resolution: WORKING${RESET}"
    else
        echo -e "  ${RED}✗ DNS Resolution: BROKEN${RESET}"
    fi
    
    # systemd-resolved status
    echo -e "\033[1;35mSYSTEMD-RESOLVED:\033[0m"
    resolved_status=$(systemctl is-active systemd-resolved 2>/dev/null)
    if [ "$resolved_status" = "active" ]; then
        echo -e "  ${GREEN}✓ Service: ACTIVE${RESET}"
    else
        echo -e "  ${RED}✗ Service: $resolved_status${RESET}"
    fi
    
    # resolv.conf status
    echo -e "\033[1;35mRESOLV.CONF:\033[0m"
    if [ -L "/etc/resolv.conf" ]; then
        echo -e "  ${GREEN}✓ Type: SYMLINK${RESET}"
        echo -e "  ${BLUE}  Target: $(readlink /etc/resolv.conf)${RESET}"
    elif [ -f "/etc/resolv.conf" ]; then
        echo -e "  ${YELLOW}⚠ Type: REGULAR FILE${RESET}"
    else
        echo -e "  ${RED}✗ Type: MISSING${RESET}"
    fi
    
    # Current DNS servers
    echo -e "\033[1;35mCURRENT DNS SERVERS:\033[0m"
    if [ -f "/etc/resolv.conf" ]; then
        grep -E "^nameserver" /etc/resolv.conf 2>/dev/null | head -3 | while read line; do
            echo -e "  ${CYAN}  $line${RESET}"
        done
        if ! grep -q "^nameserver" /etc/resolv.conf 2>/dev/null; then
            echo -e "  ${RED}  No nameservers configured${RESET}"
        fi
    else
        echo -e "  ${RED}  /etc/resolv.conf not found${RESET}"
    fi
    
    # Port 53 usage - ACCURATE detection
    echo -e "\033[1;35mPORT 53 USAGE (DNS PORT):\033[0m"
    port_53_detected=false
    
    # Method 1: Using ss (most reliable)
    if command -v ss &>/dev/null; then
        port_53_info=$(ss -lptn 'sport = :53' 2>/dev/null)
        if [ -n "$port_53_info" ] && echo "$port_53_info" | grep -q LISTEN; then
            echo -e "  ${RED}✗ Port 53 is in use:${RESET}"
            echo "$port_53_info" | while read -r line; do
                if echo "$line" | grep -q LISTEN; then
                    echo -e "  ${YELLOW}  → $line${RESET}"
                fi
            done
            port_53_detected=true
        fi
    fi
    
    # Method 2: Using netstat if ss not available
    if [ "$port_53_detected" = false ] && command -v netstat &>/dev/null; then
        port_53_info=$(netstat -tlnp 2>/dev/null | grep ':53 ')
        if [ -n "$port_53_info" ]; then
            echo -e "  ${RED}✗ Port 53 is in use:${RESET}"
            echo "$port_53_info" | while read -r line; do
                echo -e "  ${YELLOW}  → $line${RESET}"
            done
            port_53_detected=true
        fi
    fi
    
    # Method 3: Using lsof for process details
    if command -v lsof &>/dev/null; then
        lsof_info=$(sudo lsof -i :53 2>/dev/null | grep LISTEN)
        if [ -n "$lsof_info" ]; then
            if [ "$port_53_detected" = false ]; then
                echo -e "  ${RED}✗ Port 53 is in use:${RESET}"
            fi
            echo "$lsof_info" | while read -r line; do
                process=$(echo "$line" | awk '{print $1}')
                pid=$(echo "$line" | awk '{print $2}')
                echo -e "  ${RED}  → $process (PID: $pid) using port 53${RESET}"
            done
            port_53_detected=true
        fi
    fi
    
    if [ "$port_53_detected" = false ]; then
        echo -e "  ${GREEN}✓ Port 53: Available${RESET}"
    fi
    
    # ACCURATE DNS service detection
    echo -e "\033[1;35mDNS SERVICES DETECTION:\033[0m"
    
    # Check systemd services
    echo -e "  ${CYAN}Systemd Services:${RESET}"
    dns_services=("systemd-resolved" "dnsmasq" "named" "bind9" "unbound" "NetworkManager")
    for service in "${dns_services[@]}"; do
        if systemctl is-active "$service" &>/dev/null 2>&1; then
            if [ "$service" = "systemd-resolved" ]; then
                echo -e "    ${GREEN}✓ $service: ACTIVE${RESET}"
            else
                echo -e "    ${RED}⚠ $service: ACTIVE (potential conflict)${RESET}"
            fi
        elif systemctl is-enabled "$service" &>/dev/null 2>&1; then
            echo -e "    ${YELLOW}  $service: ENABLED but not active${RESET}"
        else
            echo -e "    ${BLUE}  $service: Not active${RESET}"
        fi
    done
    
    # Check running processes (more accurate)
    echo -e "  ${CYAN}Running Processes:${RESET}"
    dns_processes=("unbound" "dnsmasq" "named" "bind" "systemd-resolved")
    process_found=false
    for process in "${dns_processes[@]}"; do
        if pgrep -x "$process" &>/dev/null; then
            pids=$(pgrep -x "$process" | tr '\n' ' ')
            # Check if it's managed by systemd
            if systemctl status "$process" &>/dev/null 2>&1; then
                echo -e "    ${GREEN}✓ $process: RUNNING (PID: $pids, systemd)${RESET}"
            else
                echo -e "    ${RED}⚠ $process: RUNNING (PID: $pids, STANDALONE)${RESET}"
            fi
            process_found=true
        fi
    done
    
    if [ "$process_found" = false ]; then
        echo -e "    ${BLUE}  No DNS processes running${RESET}"
    fi
    
    # Check for DNS stub listener conflicts
    echo -e "\033[1;35mDNS STUB LISTENER:\033[0m"
    if [ -f "/etc/systemd/resolved.conf" ]; then
        stub_listener=$(grep "^DNSStubListener" /etc/systemd/resolved.conf 2>/dev/null | tail -1)
        if [[ "$stub_listener" == *"=no"* ]]; then
            echo -e "  ${GREEN}✓ Stub listener: DISABLED${RESET}"
        elif [[ "$stub_listener" == *"=yes"* ]]; then
            echo -e "  ${YELLOW}⚠ Stub listener: ENABLED${RESET}"
        else
            echo -e "  ${YELLOW}⚠ Stub listener: NOT SET (default: enabled)${RESET}"
        fi
    else
        echo -e "  ${RED}✗ /etc/systemd/resolved.conf not found${RESET}"
    fi
    
    echo -e "\033[1;36m============================================\033[0m"
    echo ""
}

# Enhanced troubleshooting function with accurate detection
troubleshoot_dns() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m           DNS TROUBLESHOOTING\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    
    # Test 1: Basic DNS resolution
    echo -e "\033[1;35m1. Testing DNS Resolution:\033[0m"
    if timeout 5 nslookup google.com &>/dev/null; then
        echo -e "   ${GREEN}✓ Basic DNS resolution: SUCCESS${RESET}"
    else
        echo -e "   ${RED}✗ Basic DNS resolution: FAILED${RESET}"
    fi
    
    # Test 2: Check systemd-resolved service
    echo -e "\033[1;35m2. Checking systemd-resolved service:\033[0m"
    resolved_status=$(systemctl is-active systemd-resolved 2>/dev/null)
    resolved_enabled=$(systemctl is-enabled systemd-resolved 2>/dev/null)
    if [ "$resolved_status" = "active" ]; then
        echo -e "   ${GREEN}✓ systemd-resolved: ACTIVE${RESET}"
    else
        echo -e "   ${RED}✗ systemd-resolved: $resolved_status${RESET}"
    fi
    echo -e "   ${CYAN}   Enabled: $resolved_enabled${RESET}"
    
    # Test 3: Check port 53 conflicts - ACCURATE
    echo -e "\033[1;35m3. Checking Port 53 conflicts:\033[0m"
    port_53_conflict=false
    
    # Check using multiple methods
    if command -v ss &>/dev/null; then
        port_53_users=$(ss -lptn 'sport = :53' 2>/dev/null | grep LISTEN)
    elif command -v netstat &>/dev/null; then
        port_53_users=$(netstat -tlnp 2>/dev/null | grep ':53 ')
    fi
    
    if [ -n "$port_53_users" ]; then
        echo -e "   ${RED}✗ Port 53 conflict detected:${RESET}"
        echo "$port_53_users" | while read -r line; do
            echo -e "   ${YELLOW}   $line${RESET}"
        done
        port_53_conflict=true
    fi
    
    # Check with lsof for process details
    if command -v lsof &>/dev/null; then
        lsof_users=$(sudo lsof -i :53 2>/dev/null | grep LISTEN)
        if [ -n "$lsof_users" ]; then
            if [ "$port_53_conflict" = false ]; then
                echo -e "   ${RED}✗ Port 53 conflict detected:${RESET}"
            fi
            echo "$lsof_users" | while read -r line; do
                process=$(echo "$line" | awk '{print $1}')
                pid=$(echo "$line" | awk '{print $2}')
                echo -e "   ${RED}   → $process (PID: $pid) using port 53${RESET}"
            done
            port_53_conflict=true
        fi
    fi
    
    if [ "$port_53_conflict" = false ]; then
        echo -e "   ${GREEN}✓ Port 53: No conflicts${RESET}"
    fi
    
    # Test 4: Check resolv.conf
    echo -e "\033[1;35m4. Checking /etc/resolv.conf:\033[0m"
    if [ -e "/etc/resolv.conf" ]; then
        echo -e "   ${GREEN}✓ File exists${RESET}"
        echo -e "   ${CYAN}  Content:${RESET}"
        if [ -s "/etc/resolv.conf" ]; then
            cat /etc/resolv.conf | while read line; do
                echo -e "      $line"
            done
        else
            echo -e "      ${RED}File is empty${RESET}"
        fi
    else
        echo -e "   ${RED}✗ File missing${RESET}"
    fi
    
    # Test 5: Network connectivity
    echo -e "\033[1;35m5. Testing network connectivity:\033[0m"
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo -e "   ${GREEN}✓ Network connectivity: OK${RESET}"
    else
        echo -e "   ${RED}✗ Network connectivity: FAILED${RESET}"
    fi
    
    # Test 6: Check DNS configuration files
    echo -e "\033[1;35m6. Checking DNS configuration files:\033[0m"
    if [ -f "/etc/systemd/resolved.conf" ]; then
        echo -e "   ${GREEN}✓ /etc/systemd/resolved.conf exists${RESET}"
        dns_configured=$(grep -c "^DNS=" /etc/systemd/resolved.conf 2>/dev/null || echo "0")
        if [ "$dns_configured" -gt 0 ]; then
            echo -e "   ${GREEN}✓ DNS servers configured in resolved.conf${RESET}"
            grep "^DNS=" /etc/systemd/resolved.conf | while read line; do
                echo -e "   ${CYAN}   $line${RESET}"
            done
        else
            echo -e "   ${YELLOW}⚠ No DNS servers in resolved.conf${RESET}"
        fi
        
        # Check DNSStubListener setting
        stub_listener=$(grep "^DNSStubListener" /etc/systemd/resolved.conf)
        if [ -n "$stub_listener" ]; then
            echo -e "   ${CYAN}   $stub_listener${RESET}"
        fi
    else
        echo -e "   ${YELLOW}⚠ /etc/systemd/resolved.conf missing${RESET}"
    fi
    
    # Test 7: Check for standalone processes
    echo -e "\033[1;35m7. Checking for standalone DNS processes:\033[0m"
    standalone_found=false
    for process in unbound dnsmasq named bind; do
        if pgrep -x "$process" &>/dev/null; then
            pids=$(pgrep -x "$process" | tr '\n' ' ')
            # Check if it's NOT managed by systemd
            if ! systemctl status "$process" &>/dev/null 2>&1; then
                echo -e "   ${RED}✗ Standalone $process running (PID: $pids)${RESET}"
                standalone_found=true
            fi
        fi
    done
    
    if [ "$standalone_found" = false ]; then
        echo -e "   ${GREEN}✓ No standalone DNS processes${RESET}"
    fi
    
    echo ""
    echo -e "\033[1;33mQuick Fix Options:\033[0m"
    echo -e "   ${CYAN}a) Reset to default DNS${RESET}"
    echo -e "   ${CYAN}b) Create basic resolv.conf${RESET}"
    echo -e "   ${CYAN}c) Restart network services${RESET}"
    echo -e "   ${RED}d) Fix Port 53 conflicts (Kill processes)${RESET}"
    echo -e "   ${RED}e) Kill standalone DNS processes${RESET}"
    echo -e "   ${CYAN}f) Disable DNSStubListener${RESET}"
    echo -e "   ${CYAN}g) Return to menu${RESET}"
    
    read -p "Select option (a/b/c/d/e/f/g): " fix_choice
    
    case "$fix_choice" in
        a)
            echo -e "\033[1;33mResetting to default DNS...${RESET}"
            sudo systemctl enable --now systemd-resolved.service 2>/dev/null
            sudo rm -f /etc/resolv.conf
            sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf 2>/dev/null
            sudo systemctl restart systemd-resolved.service
            echo -e "${GREEN}DNS reset completed${RESET}"
            ;;
        b)
            echo -e "\033[1;33mCreating basic resolv.conf...${RESET}"
            sudo tee /etc/resolv.conf > /dev/null << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
options timeout:2
options attempts:2
EOF
            echo -e "${GREEN}Basic resolv.conf created${RESET}"
            ;;
        c)
            echo -e "\033[1;33mRestarting network services...${RESET}"
            sudo systemctl restart systemd-resolved
            sudo systemctl restart systemd-networkd 2>/dev/null
            echo -e "${GREEN}Network services restarted${RESET}"
            ;;
        d)
            echo -e "\033[1;33mFixing Port 53 conflicts...${RESET}"
            # Stop common services that use port 53
            sudo systemctl stop dnsmasq 2>/dev/null
            sudo systemctl stop bind9 2>/dev/null
            sudo systemctl stop named 2>/dev/null
            sudo systemctl stop unbound 2>/dev/null
            
            # Kill any processes using port 53
            sudo pkill -f dnsmasq 2>/dev/null
            sudo pkill -f unbound 2>/dev/null
            sudo pkill -f named 2>/dev/null
            sudo pkill -f bind 2>/dev/null
            
            # Kill processes using port 53 directly
            if command -v fuser &>/dev/null; then
                sudo fuser -k 53/udp 2>/dev/null
                sudo fuser -k 53/tcp 2>/dev/null
            fi
            
            # Force kill if needed
            sudo pkill -9 -f ":53" 2>/dev/null
            
            sudo systemctl restart systemd-resolved
            echo -e "${GREEN}Port 53 conflicts resolved${RESET}"
            ;;
        e)
            echo -e "\033[1;33mKilling standalone DNS processes...${RESET}"
            # Kill all standalone DNS processes
            for process in unbound dnsmasq named bind; do
                if pgrep -x "$process" &>/dev/null; then
                    if ! systemctl status "$process" &>/dev/null 2>&1; then
                        echo -e "${YELLOW}Killing standalone $process...${RESET}"
                        sudo pkill -x "$process" 2>/dev/null
                        sudo pkill -9 -x "$process" 2>/dev/null
                    fi
                fi
            done
            sudo systemctl restart systemd-resolved
            echo -e "${GREEN}Standalone processes killed${RESET}"
            ;;
        f)
            echo -e "\033[1;33mDisabling DNSStubListener...${RESET}"
            # Create resolved.conf if it doesn't exist
            if [ ! -f "/etc/systemd/resolved.conf" ]; then
                sudo mkdir -p /etc/systemd
                sudo touch /etc/systemd/resolved.conf
            fi
            # Disable DNSStubListener
            if grep -q "^DNSStubListener" /etc/systemd/resolved.conf; then
                sudo sed -i 's/^#*DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
            else
                echo -e "[Resolve]\nDNSStubListener=no" | sudo tee /etc/systemd/resolved.conf > /dev/null
            fi
            sudo systemctl restart systemd-resolved
            echo -e "${GREEN}DNSStubListener disabled${RESET}"
            ;;
        g)
            return
            ;;
        *)
            echo -e "${RED}Invalid option${RESET}"
            ;;
    esac
    
    # Test again after fix
    echo ""
    echo -e "\033[1;33mTesting after fix...${RESET}"
    sleep 2
    if timeout 5 nslookup google.com &>/dev/null; then
        echo -e "${GREEN}✓ DNS resolution is now working!${RESET}"
    else
        echo -e "${RED}✗ DNS resolution still failing${RESET}"
        echo -e "${YELLOW}More advanced troubleshooting may be needed${RESET}"
    fi
    
    # Show status after fix
    echo ""
    show_status
}


change_dns() {
    while true; do
        # Show status header
        show_status
        
        echo -e "\033[1;33mChoose the type of DNS change:\033[0m"
        echo -e "\033[1;35m1.\033[0m Change DNS"
        echo -e "\033[1;32m2.\033[0m Restore Default DNS"
        echo -e "\033[1;32m3.\033[0m Test current DNS"
        echo -e "\033[1;31m4.\033[0m TROUBLESHOOT DNS Problems"
        echo -e "\033[1;32m5.\033[0m Edit /etc/systemd/resolved.conf using nano"
        echo -e "\033[1;32m6.\033[0m Edit /etc/resolv.conf using nano"
        echo -e "\033[1;32m7.\033[0m Restart resolv.conf"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        read -p "Enter your choice: " dns_choice

        # DNS List with descriptions
        declare -A dns_servers_list=(  
            [1]="Cisco:208.67.222.222:208.67.222.220"
            [2]="Verisign:64.6.64.6:64.6.65.6"
            [3]="Electro:78.157.42.100:78.157.42.101"
            [4]="Shecan:178.22.122.100:185.51.200.2"
            [5]="Radar:10.202.10.10:10.202.10.11"
            [6]="Cloudflare:1.1.1.1:1.0.0.1"
            [7]="Yandex:77.88.8.8:77.88.8.1"
            [8]="Google:8.8.8.8:8.8.4.4"
            [9]="403:10.202.10.102:10.202.10.202"
            [10]="Shelter:91.92.255.160:91.92.255.24"
        )

        case "$dns_choice" in
            1)
                echo -e "\033[1;36m============================================\033[0m"
                echo -e "\033[1;33mChoose the DNS provider from the list or set custom DNS:\033[0m"
                echo -e "\033[1;36m============================================\033[0m"
                colors=(31 32 33)

                for index in "${!dns_servers_list[@]}"; do
                    IFS=":" read -r dns_name dns_primary dns_secondary <<< "${dns_servers_list[$index]}"
                    color=${colors[index % ${#colors[@]}]}
                    echo -e "\033[${color}m$index. $dns_name: Primary: [$dns_primary] Secondary: [$dns_secondary]\033[0m"
                    echo -e "\033[1;36m---------------------------------------------\033[0m"
                done
                
                echo -e "\033[1;31m11. Set Custom DNS\033[0m"
                echo -e "\033[1;36m---------------------------------------------\033[0m"

                read -p "Enter your choice: " dns_selection

                if [[ $dns_selection == 11 ]]; then
                    echo -e "\033[1;33mEnter custom primary DNS:\033[0m"
                    read -p "Enter your choice: " custom_primary_dns
                    echo -e "\033[1;33mEnter custom secondary DNS (optional):\033[0m"
                    read -p "Enter your choice: " custom_secondary_dns
                    dns_servers=("$custom_primary_dns" "$custom_secondary_dns")
                else
                    while true; do
                        if ! [[ "$dns_selection" =~ ^[0-9]+$ ]] || [ "$dns_selection" -gt "${#dns_servers_list[@]}" ]; then
                            echo -e "\033[1;31mInvalid DNS selection. Please try again.\033[0m"
                            read -p "Enter your choice: " dns_selection
                        else
                            IFS=":" read -r dns_name dns_primary dns_secondary <<< "${dns_servers_list[$dns_selection]}"
                            dns_servers=("$dns_primary" "$dns_secondary")
                            break
                        fi
                    done
                fi

                echo -e "\033[1;33mSetting up permanent DNS...\033[0m"

                {
                    echo "[Resolve]"
                    for dns in "${dns_servers[@]}"; do
                        [ -n "$dns" ] && echo "DNS=$dns"
                    done
                    echo "DNSStubListener=no"
                } | sudo tee /etc/systemd/resolved.conf > /dev/null

                sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                echo -e "\033[1;32mSymbolic link created: /etc/resolv.conf -> /run/systemd/resolve/resolv.conf\033[0m"
                
                sudo systemctl restart systemd-resolved.service

                dns_script_path="/root/configure-dns.sh"
                echo -e "\033[1;33mCreating DNS configuration script...\033[0m"

                {
                    echo "#!/bin/bash"
                    echo ""
                    echo "# Define the DNS servers to be used"
                    echo "dns_servers=(\"${dns_servers[0]}\" \"${dns_servers[1]}\")"
                    echo ""
                    echo "# Update DNS settings in /etc/systemd/resolved.conf"
                    echo "{"
                    echo "    echo \"[Resolve]\""
                    echo "    for dns in \"\${dns_servers[@]}\"; do"
                    echo "        [ -n \"\$dns\" ] && echo \"DNS=\$dns\""
                    echo "    done"
                    echo "    echo \"DNSStubListener=no\""
                    echo "} | sudo tee /etc/systemd/resolved.conf > /dev/null"
                    echo ""
                    echo "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
                    echo "sudo systemctl restart systemd-resolved.service"
                } > "$dns_script_path"

                chmod +x "$dns_script_path"
                echo -e "\033[1;32mScript created at $dns_script_path\033[0m"

                cron_job="@reboot $dns_script_path"
                if crontab -l 2>/dev/null | grep -qF "$cron_job"; then
                    echo -e "\033[1;33mCron job already exists. Overwriting...\033[0m"
                    (crontab -l 2>/dev/null | grep -vF "$cron_job"; echo "$cron_job") | crontab -
                else
                    echo -e "\033[1;33mAdding cron job for DNS configuration script...\033[0m"
                    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
                fi

                echo -e "\033[1;32mCron job added to run DNS configuration script at reboot.\033[0m"
                ;;

            2)
                echo -e "\033[1;33mRestoring DNS settings to system default...\033[0m"
                sudo systemctl enable --now systemd-resolved.service
                sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                sudo systemctl restart systemd-resolved.service
                echo -e "\033[1;32mDNS restored to default settings.\033[0m"
                ;;

            3)
                echo -e "\033[1;33mDisplaying /etc/resolv.conf content:\033[0m"
                cat /etc/resolv.conf
                sudo systemctl status systemd-resolved.service --no-pager
                echo -e "\n\033[1;33mTesting DNS resolution by pinging domains:\033[0m"
                for domain in "google.com" "yahoo.com" "cloudflare.com"; do
                    echo -e "\033[1;36mPinging $domain:\033[0m"
                    ping -c 2 "$domain" 2>/dev/null && echo -e "${GREEN}Success${RESET}" || echo -e "${RED}Failed${RESET}"
                done
                ;;

            4)
                troubleshoot_dns
                ;;

            5)
                sudo nano /etc/systemd/resolved.conf
                ;;

            6)
                sudo nano /etc/resolv.conf
                ;;

            7)
                sudo systemctl restart systemd-resolved.service
                echo -e "\033[1;32mresolv.conf restarted.\033[0m"
                ;;

            0)
                break
                ;;

            *)
                echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

change_dns
