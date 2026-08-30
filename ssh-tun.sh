#!/bin/bash

greEN='\033[1;32m'
RED='\033[1;31m'
YELLOW="\033[1;33m"
RESET='\033[0m'
CYAN='\033[1;36m'

# Remove /root/ipv4.txt if it exists
if [ -f /root/ipv4.txt ]; then
    rm /root/ipv4.txt
    echo -e "\033[1;33mExisting /root/ipv4.txt file removed.\033[0m"
fi

# Function to generate a random name
generate_random_name() {
    tr -dc 'a-z0-9' </dev/urandom | fold -w 5 | head -n 1
}

generate_random_ipv4() {
    local role=$1
    # Define 100 IPv4 address templates
    local templates=()
    for i in {1..100}; do
        templates+=("10.10.$i.%d/24")
    done

    # Prompt the user to select a template
    echo -e "\n\033[1;34mSelect an IPv4 template number between (1-100) or Press Enter for a random template:\033[0m"
    local template_number
    read -p " > " template_number
    
    if [[ -z "$template_number" ]]; then
        template_number=$(shuf -i 1-100 -n 1)
        echo -e "\n\033[1;33mRandomly selected template number: [$template_number]\033[0m"
    else
        echo -e "\n\033[1;32mYou selected template number: [$template_number]\033[0m"
    fi
    
    if [[ ! "$template_number" =~ ^[1-9]$|^[1-9][0-9]$|^100$ ]]; then
        echo -e "\n\033[1;31mInvalid input. Please select a number between 1 and 100.\033[0m"
        return
    fi
    
    echo -e "\n\033[1;31m!! Remember to use template number [$template_number] on the other server too !!\033[0m"

    local selected_template="${templates[$((template_number - 1))]}"
    local template_prefix=$(echo "$selected_template" | cut -d'.' -f1-3)
    
    if ip -4 addr show | grep -q "$template_prefix"; then
        echo -e "\033[1;31mWarning: The IPv4 prefix $template_prefix is already in use on an interface.\033[0m"
        echo -e "\033[1;33mPlease choose a different template number.\033[0m"
        read -p "Press Enter to select a new template..."
        generate_random_ipv4 "$role"
        return
    fi

    # Determine last octet based on server role (.1 for Kharej, .2 for Iran)
    local last_octet="2"
    if [[ "$role" == "kharej" ]]; then
        last_octet="1"
    fi

    local ipv4_address="${selected_template//%d/$last_octet}"

    echo -e "\n\033[1;32mEnter a custom Local TUN IPv4 address (e.g. $ipv4_address) or enter blank to use \033[0m $ipv4_address"
    read -p " > " user_ipv4_address

    ipv4_address=${user_ipv4_address:-$ipv4_address}

    echo -e "\n\033[1;32mLocal TUN IPv4 address:\033[0m $ipv4_address"

    echo "ipv4=$ipv4_address" > /root/ipv4.txt
    sleep 1

    source /root/ipv4.txt
}

get_local_ip() {
    local ip=$(hostname -I | awk '{print $1}')
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
    else
        echo ""
    fi
}

create_ssh_tunnel() {
    source /root/ipv4.txt 2>/dev/null

    echo -e "\n${greEN}Where is this script currently running?${RESET}"
    echo -e "${CYAN}1. Iran Server (Client - Initiates Connection)${RESET}"
    echo -e "${CYAN}2. Kharej Server (Remote Server - Waits for Connection)${RESET}"
    read -p " > " server_role

    local role_name="iran"
    if [[ "$server_role" == "2" ]]; then
        role_name="kharej"
    fi

    local default_name=$(generate_random_name)
    read -p "$(echo -e "\n${greEN}Enter a service name (default: ${default_name}): ${RESET}")" service_name
    if [[ -z "$service_name" ]]; then
        service_name="$default_name"
    fi

    if [[ ! "$service_name" =~ ^sshtun- ]]; then
        service_name="sshtun-$service_name"
    fi

    local service_file="/usr/lib/systemd/system/$service_name.service"
    if [[ -f "$service_file" ]]; then
        echo -e "\n${RED}A service with this name already exists. Please choose a different name.${RESET}"
        return
    fi

    echo -e "\n${greEN}Enter Tunnel Interface Number (e.g., 0 for tun0, 1 for tun1) [Default: 0]:${RESET}"
    read -p " > " tun_num
    tun_num=${tun_num:-0}

    echo -e "\n${greEN}Configuring the Local IPv4 address for the TUN interface.${RESET}"
    generate_random_ipv4 "$role_name"
    local ipv4_address=$ipv4

    local default_route="${ipv4_address%.*}.1"
    if [[ "$role_name" == "kharej" ]]; then
        default_route="${ipv4_address%.*}.2"
    fi
    
    echo -e "\n${greEN}Enter Peer TUN IPv4 address (e.g., $default_route):${RESET}"
    read -p " > " route_network
    route_network=${route_network:-$default_route}
    
    echo -e "${CYAN}Using Peer IP: $route_network on tun$tun_num${RESET}"

    # ==========================================
    # KHAREJ (LISTENER) SETUP
    # ==========================================
    if [[ "$role_name" == "kharej" ]]; then
        echo -e "\n${YELLOW}--- Configuring Kharej (Remote Server) ---${RESET}"
        echo -e "${CYAN}Checking and enabling 'PermitTunnel yes' in sshd_config...${RESET}"
        grep -q '^[[:space:]]*PermitTunnel[[:space:]]\+yes' /etc/ssh/sshd_config || (echo 'PermitTunnel yes' >> /etc/ssh/sshd_config && (systemctl restart ssh || systemctl restart sshd))
        echo -e "${greEN}SSH configured successfully.${RESET}"

        echo -e "\n${greEN}Creating Listener systemd service for $service_name...${RESET}"
        cat <<EOF > "$service_file"
[Unit]
Description=SSH TUN Listener (Kharej) $service_name
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do if ip link show tun$tun_num >/dev/null 2>&1; then if ! ip addr show tun$tun_num | grep -q "peer"; then ip link set dev tun$tun_num up; ip addr add $ipv4_address peer $route_network dev tun$tun_num; ip link set dev tun$tun_num mtu 1350; fi; fi; sleep 3; done'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    # ==========================================
    # IRAN (CLIENT) SETUP
    # ==========================================
    else
        echo -e "\n${YELLOW}--- Configuring Iran (Client Server) ---${RESET}"
        echo -e "\n${greEN}Enter the Remote Server Public IP:${RESET}"
        read -p " > " remote_input
        
        if [[ "$remote_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            remote_ip="$remote_input"
        else
            remote_ip=$(dig +short "$remote_input" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
            if [[ -z "$remote_ip" ]]; then
                echo -e "\n${RED}Failed to resolve the domain to an IP address.${RESET}"
                return
            fi
        fi

        echo -e "\n${greEN}Enter SSH Port of remote server (Default: 22):${RESET}"
        read -p " > " ssh_port
        ssh_port=${ssh_port:-22}

        echo -e "\n${greEN}Do you want to automatically setup SSH Keys and configure 'PermitTunnel yes' on the remote server? (y/n) [Default: y]:${RESET}"
        read -p " > " auto_setup
        auto_setup=${auto_setup:-y}

        local identity_file=""
        if [[ "$auto_setup" =~ ^[Yy]$ ]]; then
            local key_dir="/root/$service_name"
            local key_path="$key_dir/id_rsa"
            
            mkdir -p "$key_dir"
            
            if [[ ! -f "$key_path" ]]; then
                echo -e "${CYAN}Generating new SSH key in $key_path...${RESET}"
                ssh-keygen -t rsa -b 2048 -f "$key_path" -N "" -q
            else
                echo -e "${YELLOW}SSH key already exists in $key_path. Reusing it.${RESET}"
            fi

            echo -e "\n${YELLOW}>> You will now be prompted for the REMOTE SERVER (root) password to transfer the key <<${RESET}"
            ssh-copy-id -i "$key_path.pub" -p "$ssh_port" -o StrictHostKeyChecking=no "root@$remote_ip"
            
            if [[ $? -eq 0 ]]; then
                echo -e "${greEN}SSH key successfully transferred!${RESET}"
                identity_file="-i $key_path"
                
                echo -e "${CYAN}Checking and configuring 'PermitTunnel yes' on the remote server...${RESET}"
                ssh $identity_file -p "$ssh_port" -o StrictHostKeyChecking=no "root@$remote_ip" "grep -q '^[[:space:]]*PermitTunnel[[:space:]]\+yes' /etc/ssh/sshd_config || (echo 'PermitTunnel yes' >> /etc/ssh/sshd_config && (systemctl restart ssh || systemctl restart sshd))"
                
                if [[ $? -eq 0 ]]; then
                    echo -e "${greEN}Remote server configured successfully!${RESET}"
                else
                    echo -e "${RED}Failed to configure remote server. You may need to do it manually.${RESET}"
                fi
            else
                echo -e "${RED}Failed to transfer SSH key. Automatic setup aborted. The tunnel might fail.${RESET}"
            fi
        fi

        echo -e "\n${greEN}Creating systemd service file for $service_name...${RESET}"
        cat <<EOF > "$service_file"
[Unit]
Description=SSH TUN Tunnel (Iran) $service_name
After=network.target

[Service]
Type=simple
Environment="AUTOSSH_GATETIME=0"
ExecStartPre=-/sbin/ip link del dev tun$tun_num
ExecStart=/usr/bin/ssh $identity_file -w $tun_num:$tun_num root@$remote_ip -p $ssh_port -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o StrictHostKeyChecking=no -o TCPKeepAlive=yes -N
ExecStartPost=/bin/sleep 3
ExecStartPost=/sbin/ip link set dev tun$tun_num up
ExecStartPost=/sbin/ip addr add $ipv4_address peer $route_network dev tun$tun_num
ExecStartPost=/sbin/ip link set dev tun$tun_num mtu 1350
ExecStopPost=-/sbin/ip link del dev tun$tun_num
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    fi

    # Common steps for both roles
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"

    echo -e "\n${greEN}SSH TUN Tunnel $service_name created and started.${RESET}"
    read -p "Press Enter to continue..."
}


manage_ssh_tunnels() {
    while true; do
        clear
        echo -e "${greEN}Available SSH TUN tunnels:${RESET}"
        local tunnels=()

        for dir in /usr/lib/systemd/system; do
            for file in "$dir"/sshtun-*.service; do
                if [[ -f "$file" ]]; then
                    tunnels+=("$(basename "$file" .service)")
                fi
            done
        done

        if [[ ${#tunnels[@]} -eq 0 ]]; then
            echo -e "${RED}No active SSH TUN tunnels found.${RESET}"
            read -p "Press Enter to continue..."
            return 1
        fi

        for i in "${!tunnels[@]}"; do
            echo "$((i + 1)). ${tunnels[i]}"
        done

        echo -e "${greEN}Enter the number corresponding to the tunnel you want to manage:${RESET}"
        read -r choice

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#tunnels[@]})); then
            echo -e "${RED}Invalid choice. Please try again.${RESET}"
            read -p "Press Enter to continue..."
            continue
        fi

        selected_tunnel="${tunnels[choice - 1]}"
        
        while true; do
            clear
            local service_file="/usr/lib/systemd/system/$selected_tunnel.service"
            
            if [[ ! -f "$service_file" ]]; then
                break
            fi
            
            route_ip1=$(grep -oP '(?<=peer\s)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)
            remote_ip1=$(grep -oP '(?<=root@)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)
            if [[ -z "$remote_ip1" ]]; then
                remote_ip1="N/A (Listener Mode - Kharej)"
            fi
            local_ip1=$(grep -oP '(?<=ip addr add\s)(\d+\.\d+\.\d+\.\d+(/[0-9]+)?|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)
            tun_num=$(grep -oP 'dev tun\K(\d+)' "$service_file" | head -n 1)

            echo -e "\033[1;32m================================================\033[0m"
            echo -e "\033[1;33mSelect an action to perform on tunnel $selected_tunnel (tun$tun_num):\033[0m"
            echo -e "\033[1;34m======================local=====================\033[0m"
            echo -e "\033[1;32mLocal TUN IP: $local_ip1\033[0m"
            echo -e "\033[1;34m======================remote====================\033[0m"
            echo -e "\033[1;32mRemote Server IP: $remote_ip1\033[0m"
            echo -e "\033[1;32mRemote Peer TUN IP: $route_ip1\033[0m"
            echo -e "\033[1;32m================================================\033[0m"
            echo -e "\033[1;34m1.\033[0m \033[1;36mStart tunnel\033[0m"
            echo -e "\033[1;34m2.\033[0m \033[1;36mStop tunnel\033[0m"
            echo -e "\033[1;34m3.\033[0m \033[1;36mRestart tunnel\033[0m"
            echo -e "\033[1;34m4.\033[0m \033[1;36mEnable at boot\033[0m"
            echo -e "\033[1;34m5.\033[0m \033[1;36mDisable at boot\033[0m"
            echo -e "\033[1;34m6.\033[0m \033[1;36mCheck status\033[0m"
            echo -e "\033[1;34m7.\033[0m \033[1;36mRemove tunnel & SSH Keys\033[0m"
            echo -e "\033[1;34m8.\033[0m \033[1;36mEdit with nano\033[0m"
            echo -e "\033[1;34m9.\033[0m \033[1;36mChange remote Server IP\033[0m"
            echo -e "\033[1;34m10.\033[0m \033[1;36mPing remote TUN peer IP\033[0m"
            echo -e "\033[1;34m11.\033[0m \033[1;36mChange local TUN IP\033[0m"
            echo -e "\033[1;31m0.\033[0m \033[1;37mReturn to main menu\033[0m"
            echo -e "\033[1;32m================================================\033[0m"

            read -p "Choose an option: " action

            case $action in
                0) break ;;
                1)
                    sudo systemctl start "$selected_tunnel.service"
                    echo -e "${greEN}Tunnel $selected_tunnel started.${RESET}"
                    read -p "Press Enter to continue..." ;;
                2)
                    sudo systemctl stop "$selected_tunnel.service"
                    echo -e "${greEN}Tunnel $selected_tunnel stopped.${RESET}"
                    read -p "Press Enter to continue..." ;;
                3)
                    sudo systemctl restart "$selected_tunnel.service"
                    echo -e "${greEN}Tunnel $selected_tunnel restarted.${RESET}"
                    read -p "Press Enter to continue..." ;;
                4)
                    sudo systemctl enable "$selected_tunnel.service"
                    echo -e "${greEN}Tunnel $selected_tunnel enabled at boot.${RESET}"
                    read -p "Press Enter to continue..." ;;
                5)
                    sudo systemctl disable "$selected_tunnel.service"
                    echo -e "${greEN}Tunnel $selected_tunnel disabled at boot.${RESET}"
                    read -p "Press Enter to continue..." ;;
                6)
                    sudo systemctl status "$selected_tunnel.service"
                    read -p "Press Enter to continue..." ;;
                7)
                    sudo systemctl stop "$selected_tunnel.service"
                    sudo systemctl disable "$selected_tunnel.service"
                    sudo rm -f "/usr/lib/systemd/system/$selected_tunnel.service"
                    sudo rm -rf "/root/$selected_tunnel"
                    sudo systemctl daemon-reload
                    echo -e "${greEN}Tunnel $selected_tunnel and its keys removed.${RESET}"
                    read -p "Press Enter to continue..."
                    break ;;
                8)
                    sudo nano "$service_file"
                    sudo systemctl daemon-reload
                    sudo systemctl restart "$selected_tunnel.service"
                    read -p "Press Enter to continue..." ;;
                9)
                    if [[ "$remote_ip1" == *"Listener"* ]]; then
                        echo -e "${YELLOW}This is a Listener service (Kharej). It does not connect to a remote IP.${RESET}"
                    else
                        echo -e "${CYAN}Current remote server IP: ${greEN}$remote_ip1${RESET}"
                        echo -e "${greEN}Enter the new remote Server IP address or Enter blank to cancel:${RESET}"
                        read -p "> " new_remote_ip
                        if [[ -n "$new_remote_ip" ]]; then
                            sed -i "s/root@[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/root@$new_remote_ip/" "$service_file"
                            sudo systemctl daemon-reload
                            sudo systemctl restart "$selected_tunnel"
                            echo -e "${greEN}Remote IP updated to $new_remote_ip.${RESET}"
                        fi
                    fi
                    read -p "Press Enter to continue..." ;;
                10)
                    if [[ -z "$route_ip1" ]]; then
                        echo -e "\033[1;31mNo Remote Peer TUN IP found.\033[0m"
                    else
                        echo -e "\033[1;32mPinging Remote Peer TUN IP: $route_ip1...\033[0m"
                        if ping -c 4 -W 3 "$route_ip1"; then
                            echo -e "\033[1;32mPing successful.${RESET}"
                        else
                            echo -e "\033[1;31mPing timed out or failed.${RESET}"
                        fi
                    fi
                    read -p "Press Enter to continue..." ;;
                11)
                    echo -e "${CYAN}Current local TUN IP: ${RED}$local_ip1${RESET}"
                    echo -e "${greEN}Enter the new local TUN IP (e.g. 10.0.0.2/24) or press Enter to cancel:${RESET}"
                    read -p "> " new_local_ip
                    if [[ -n "$new_local_ip" ]]; then
                        sed -i "s|addr add [0-9\./]* peer|addr add $new_local_ip peer|" "$service_file"
                        sudo systemctl daemon-reload
                        sudo systemctl restart "$selected_tunnel"
                        echo -e "${greEN}Local TUN IP updated to $new_local_ip.${RESET}"
                    fi
                    read -p "Press Enter to continue..." ;;
                *)
                    echo -e "${RED}Invalid option...${RESET}"
                    read -p "Press Enter to continue..." ;;
            esac
        done
    done
}

stop_all_ssh_tunnels() {
    echo -e "${greEN}Stopping all SSH TUN services...${RESET}"
    local stopped_any=false

    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/sshtun-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                systemctl stop "$service_name"
                stopped_any=true
            fi
        done
    done

    if [[ $stopped_any == false ]]; then
        echo -e "${RED}No active SSH TUN services found to stop.${RESET}"
        return 1
    fi
    echo -e "${greEN}All SSH TUN services stopped.${RESET}"
    read -p "Press Enter to continue..."
}

enable_and_start_ssh_tunnels() {
    echo -e "${greEN}Enabling and starting all SSH TUN services...${RESET}"
    local started_any=false

    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/sshtun-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                systemctl enable "$service_name"
                systemctl start "$service_name"
                started_any=true
            fi
        done
    done

    if [[ $started_any == false ]]; then
        echo -e "${RED}No SSH TUN services found.${RESET}"
        return 1
    fi
    echo -e "${greEN}All SSH TUN services enabled and started.${RESET}"
    read -p "Press Enter to continue..."
}

restart_ssh_tunnels() {
    echo -e "${greEN}Restarting all SSH TUN services...${RESET}"
    local restarted_any=false

    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/sshtun-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                systemctl restart "$service_name"
                restarted_any=true
            fi
        done
    done

    if [[ $restarted_any == false ]]; then
        echo -e "${RED}No SSH TUN services found.${RESET}"
        return 1
    fi
    echo -e "${greEN}All SSH TUN services restarted.${RESET}"
    read -p "Press Enter to continue..."
}

# Main menu
while true; do
    clear
    echo -e "\033[1;34m=========================================\033[0m"
    echo -e "      \033[1;32mSSH TUN Tunnel Service Method\033[0m"
    echo -e "\033[1;34m=========================================\033[0m"
    echo -e "\033[1;36m 1.\033[0m \033[1;32mCreate SSH TUN Tunnel\033[0m"
    echo -e "\033[1;36m 2.\033[0m \033[1;32mManage SSH Tunnels\033[0m"
    echo -e "\033[1;36m 3.\033[0m \033[1;32mStart all SSH Tunnels\033[0m"
    echo -e "\033[1;36m 4.\033[0m \033[1;32mStop all SSH Tunnels\033[0m"
    echo -e "\033[1;36m 5.\033[0m \033[1;32mRestart all SSH Tunnels\033[0m"
    echo -e "\033[1;36m 0.\033[0m \033[1;31mExit\033[0m"
    echo -e "\n\033[1;34m=========================================\033[0m"
    echo -e "\033[1;32mEnter your choice: \033[0m"

    read -p "Choice: " option

    case $option in
        1) create_ssh_tunnel ;;
        2) manage_ssh_tunnels ;;
        3) enable_and_start_ssh_tunnels ;;
        4) stop_all_ssh_tunnels ;;
        5) restart_ssh_tunnels ;;
        0)
            echo -e "\n\033[1;31mExiting... Goodbye!\033[0m"
            break ;;
        *) 
            echo -e "\n\033[1;31mInvalid option, please try again.\033[0m"
            sleep 1 ;;
    esac
done
