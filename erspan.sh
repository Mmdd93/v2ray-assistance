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
    # Define 100 IPv4 address templates
    local templates=()
    for i in {1..100}; do
        templates+=("192.168.$i.%d/32")
    done

    # Prompt the user to select a template
    echo -e "\n\033[1;34mSelect an IPv4 template number between (1-100) or Press Enter for a random template:\033[0m"
    local template_number
    read -p " > " template_number
    
    # If the user input is empty, generate a random number between 1 and 100
    if [[ -z "$template_number" ]]; then
        template_number=$(shuf -i 1-100 -n 1)
        echo -e "\n\033[1;33mRandomly selected template number: [$template_number]\033[0m"
    else
        echo -e "\n\033[1;32mYou selected template number: [$template_number]\033[0m"
    fi
    
    # Validate the user's selection
    if [[ ! "$template_number" =~ ^[1-9]$|^[1-9][0-9]$|^100$ ]]; then
        echo -e "\n\033[1;31mInvalid input. Please select a number between 1 and 100.\033[0m"
        return
    fi
    
    echo -e "\n\033[1;31m!! Now! Use template number [$template_number] on the remote server!!\033[0m"
    read -p "Press Enter to continue..."

    # Adjust template number to zero-based index
    local selected_template="${templates[$((template_number - 1))]}"

    # Extract the prefix from the template (e.g., "192.168.1.")
    local template_prefix=$(echo "$selected_template" | cut -d'.' -f1-3)

    # Check if the generated IPv4 prefix is already in use
    if ip -4 addr show | grep -q "$template_prefix"; then
        echo -e "\033[1;31mWarning: The IPv4 prefix $template_prefix is already in use on an interface.\033[0m"
        echo -e "\033[1;33mPlease choose a different template number.\033[0m"
        
        # Prompt the user to choose a new template
        read -p "Press Enter to select a new template..."
        generate_random_ipv4  # Recursively call the function to try again
        return
    fi

    # Generate a random last octet (0-255)
    local last_octet=$((RANDOM % 256))

    # Build the IPv4 address using the selected template
    local ipv4_address="${selected_template//%d/$last_octet}"

    # Prompt for a custom IPv4 address
    echo -e "\n\033[1;32mEnter a custom IPv4 address or enter blank to use \033[0m $ipv4_address"
    read -p " > " user_ipv4_address

    # Use the custom IPv4 address if provided, otherwise use the generated one
    ipv4_address=${user_ipv4_address:-$ipv4_address}

    # Display the final IPv4 address
    echo -e "\033[1;31m!! Save and copy > $ipv4_address < (use it for routing in remote server)!!\033[0m"
    echo -e "\n\033[1;32mLocal IPv4 address:\033[0m $ipv4_address"

    # Save the generated or custom IPv4 address to a text file
    echo "ipv4=$ipv4_address" > /root/ipv4.txt
    echo -e "\n\033[1;33mIPv4 address saved to ipv4.txt\033[0m"
    sleep 1

    source /root/ipv4.txt
}

# Function to get the local machine's IP address (IPv4)
get_local_ip() {
    # Attempt to fetch the first IPv4 address from the hostname command
    local ip=$(hostname -I | awk '{print $1}')
    # Verify the result is a valid IPv4 address
    if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$ip"
    else
        echo ""
    fi
}

# Function to create an ERSPAN tunnel
create_erspan_tunnel() {
    source /root/ipv4.txt

    # Generate a default random name
    local default_name=$(generate_random_name)

    # Ask for the service name, but provide a default random name if no input is given
    read -p "$(echo -e "\n${greEN}Enter a service name (default: ${default_name}): ${RESET}")" service_name

    # If no input is given, use the default random name
    if [[ -z "$service_name" ]]; then
        service_name="$default_name"
    fi

    # Ensure the service name has the required prefix
    if [[ ! "$service_name" =~ ^erspan- ]]; then
        service_name="erspan-$service_name"
    fi

    echo -e "\n${greEN}Using service name:${RESET} $service_name"

    # Check if the service already exists
    local service_file="/usr/lib/systemd/system/$service_name.service"
    if [[ -f "$service_file" ]]; then
        echo -e "\n${RED}A service with this name already exists. Please choose a different name.${RESET}"
        return
    fi

    # Get the default local IP
    local_ip=$(get_local_ip)
    if [[ -z "$local_ip" ]]; then
        echo -e "\033[1;31mNo local IP address found. Exiting...\033[0m"
        exit 1
    fi

    # Ask for the local IP or domain for the tunnel
    echo -e "\n\033[1;32mEnter the local IP or domain for current server or enter blank to use \033[1;33m(Default: $local_ip)\033[0m:"
    read -p " > " user_input

    # Use the provided input or default if none is entered
    user_input=${user_input:-$local_ip}

    # Check if the input is an IPv4 address
    if [[ "$user_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        local_ip="$user_input"
        echo -e "\033[1;36mUsing local IP: $local_ip\033[0m"
    else
        # Resolve the domain to an IP
        resolved_ip=$(dig +short "$user_input" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
        if [[ -n "$resolved_ip" ]]; then
            local_ip="$resolved_ip"
            echo -e "\033[1;36mDomain resolved to IP: $local_ip\033[0m"
        else
            echo -e "\033[1;31mFailed to resolve domain: $user_input. Please enter a valid IP or domain.\033[0m"
            exit 1
        fi
    fi

    # Use the function to generate or select a custom IPv4 address
    echo -e "\n${greEN}Configuring the IPv4 address for the tunnel.${RESET}"
    generate_random_ipv4
    local ipv4_address=$ipv4

    # Ask for the route network
    echo -e "\n${greEN}Enter generated local IPv4 from the remote server for routing (e.g., $ipv4_address):${RESET}"
    read -p " > " route_network

    if [[ -z "$route_network" ]]; then
        echo -e "\n${RED}No route entered. Exiting...${RESET}"
        return
    fi
    echo -e "${CYAN}Using route: $route_network via $service_name${RESET}"
    
    # Ask for the remote IP or domain for the tunnel
    echo -e "\n${greEN}Enter the remote IP or domain:${RESET}"
    read -p " > " remote_input
    
    # Validate if the input is a valid IP address format
    if [[ "$remote_input" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Input is a valid IP address
        remote_ip="$remote_input"
        echo -e "${CYAN}Using remote IP: $remote_ip${RESET}"
    else
        # Input is not an IP address, assume it's a domain and resolve it
        remote_ip=$(dig +short "$remote_input" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
    
        # Check if the domain was successfully resolved
        if [[ -z "$remote_ip" ]]; then
            echo -e "\n${RED}Failed to resolve the domain to an IP address. Please check the domain name.${RESET}"
            return
        fi
    
        echo -e "${CYAN}Resolved domain $remote_input to IP: $remote_ip${RESET}"
    fi

    # Ask for ERSPAN version
    echo -e "\n${greEN}Select ERSPAN version:${RESET}"
    echo -e "1. ERSPAN Version 1 (Simple)"
    echo -e "2. ERSPAN Version 2 (More features)"
    read -p "Enter choice (1 or 2, default 1): " erspan_version
    erspan_version=${erspan_version:-1}

    # Generate the systemd service file for ERSPAN tunnel
    echo -e "\n${greEN}Creating systemd service file for $service_name...${RESET}"
    
    if [[ "$erspan_version" == "1" ]]; then
        cat <<EOF > "$service_file"
[Unit]
Description=ERSPAN Tunnel $service_name (Version 1)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env sh -c '\
    /sbin/ip link add $service_name type erspan seq key 100 local $local_ip remote $remote_ip erspan_ver 1 erspan 123 && \
    /sbin/ip link set $service_name up && \
    /sbin/ip addr add $ipv4_address dev $service_name && \
    /sbin/ip route add $route_network dev $service_name'
ExecStop=/sbin/ip link del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    else
        cat <<EOF > "$service_file"
[Unit]
Description=ERSPAN Tunnel $service_name (Version 2)
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env sh -c '\
    /sbin/ip link add $service_name type erspan seq key 100 local $local_ip remote $remote_ip erspan_ver 2 erspan_dir 1 erspan_hwid 7 && \
    /sbin/ip link set $service_name up && \
    /sbin/ip addr add $ipv4_address dev $service_name && \
    /sbin/ip route add $route_network dev $service_name'
ExecStop=/sbin/ip link del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF
    fi

    # Reload systemd and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"

    echo -e "\n${greEN}ERSPAN Tunnel $service_name created.${RESET}"
    read -p "Press Enter to continue..."
}

# Function to manage ERSPAN tunnels
manage_erspan_tunnels() {
    # List all available ERSPAN tunnel services
    echo -e "${greEN}Available ERSPAN tunnels:${RESET}"
    local tunnels=()

    # Get all active ERSPAN tunnel services
    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/erspan-*.service; do
            if [[ -f "$file" ]]; then
                tunnels+=("$(basename "$file" .service)")
            fi
        done
    done

    if [[ ${#tunnels[@]} -eq 0 ]]; then
        echo -e "${RED}No active ERSPAN tunnels found.${RESET}"
        read -p "Press Enter to continue..."
        return 1
    fi

    # Display the available tunnels
    for i in "${!tunnels[@]}"; do
        echo "$((i + 1)). ${tunnels[i]}"
    done

    echo -e "${greEN}Enter the number corresponding to the tunnel you want to manage:${RESET}"
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#tunnels[@]})); then
        echo -e "${RED}Invalid choice. Please try again.${RESET}"
        return 1
    fi

    # Set the selected tunnel for further actions
    selected_tunnel="${tunnels[choice - 1]}"

    echo -e "${greEN}You selected tunnel: $selected_tunnel${RESET}"
    
    local service_file
    if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
        service_file="/usr/lib/systemd/system/$selected_tunnel.service"
    else
        echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
        read -p "Press Enter to continue..."
        return
    fi

    # Extract tunnel information from the service file
    route_ip1=$(grep -oP '(?<=route\sadd\s)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)
    remote_ip1=$(grep -oP '(?<=remote\s)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)
    local_public_ip1=$(grep -oP '(?<=local\s)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)
    local_ip1=$(grep -oP '(?<=ip addr add\s)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)

    # Prompt for the next action on the selected tunnel
    echo -e "\033[1;32m================================================\033[0m"
    echo -e "\033[1;33mSelect an action to perform on tunnel $selected_tunnel:\033[0m"
    echo -e "\033[1;34m======================local=====================\033[0m"
    echo -e "\033[1;32mPublic IP: $local_public_ip1\033[0m"
    echo -e "\033[1;32mLocal IP: $local_ip1\033[0m"
    echo -e "\033[1;34m======================remote====================\033[0m"
    echo -e "\033[1;32mPublic IP: $remote_ip1\033[0m"
    echo -e "\033[1;32mLocal IP: $route_ip1\033[0m"
    echo -e "\033[1;32m================================================\033[0m"
    echo -e "\033[1;34m1.\033[0m \033[1;36mStart tunnel\033[0m"
    echo -e "\033[1;34m2.\033[0m \033[1;36mStop tunnel\033[0m"
    echo -e "\033[1;34m3.\033[0m \033[1;36mRestart tunnel\033[0m"
    echo -e "\033[1;34m4.\033[0m \033[1;36mEnable at boot\033[0m"
    echo -e "\033[1;34m5.\033[0m \033[1;36mDisable at boot\033[0m"
    echo -e "\033[1;34m6.\033[0m \033[1;36mCheck status\033[0m"
    echo -e "\033[1;34m7.\033[0m \033[1;36mRemove tunnel\033[0m"
    echo -e "\033[1;34m8.\033[0m \033[1;36mEdit with nano\033[0m"
    echo -e "\033[1;34m9.\033[0m \033[1;36mChange remote IP\033[0m"
    echo -e "\033[1;34m10.\033[0m \033[1;36mPing remote server local/public IP\033[0m"
    echo -e "\033[1;34m11.\033[0m \033[1;36mChange local IP\033[0m"
    echo -e "\033[1;31m0.\033[0m \033[1;37mReturn to main menu\033[0m"
    echo -e "\033[1;32m================================================\033[0m"

    read -p "Choose an option: " action

    case $action in
        0) 
            return
            ;;
        1)
            sudo systemctl start "$selected_tunnel.service"
            echo -e "${greEN}Tunnel $selected_tunnel started.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        2)
            sudo systemctl stop "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${greEN}Tunnel $selected_tunnel stopped.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        3)
            sudo systemctl restart "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${greEN}Tunnel $selected_tunnel restarted.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        4)
            sudo systemctl enable "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${greEN}Tunnel $selected_tunnel enabled at boot.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        5)
            sudo systemctl disable "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${greEN}Tunnel $selected_tunnel disabled at boot.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        6)
            sudo systemctl status "$selected_tunnel.service"
            read -p "Press Enter to continue..."
            ;;
        7)
            sudo systemctl stop "$selected_tunnel.service"
            sudo systemctl disable "$selected_tunnel.service"
            sudo rm "/usr/lib/systemd/system/$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${greEN}Tunnel $selected_tunnel removed.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        8)
            sudo nano "$service_file"
            sudo systemctl restart "$selected_tunnel.service"
            sudo systemctl daemon-reload
            read -p "Press Enter to continue..."
            ;;
        9)
            local new_remote_ip
            local current_remote_ip

            if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
                service_file="/usr/lib/systemd/system/$selected_tunnel.service"
            else
                echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
                read -p "Press Enter to continue..."
                return
            fi

            current_remote_ip=$(grep -oP 'remote \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$service_file")
            
            if [[ -n "$current_remote_ip" ]]; then
                echo -e "${CYAN}Current remote IP: ${greEN}$current_remote_ip${RESET}"
            else
                echo -e "${YELLOW}No remote IP found in the service file.${RESET}"
            fi
            
            echo -e "${greEN}Enter the new remote IP address or Enter blank to cancel:${RESET}"
            read -p "> " new_remote_ip
            
            if [[ -z "$new_remote_ip" ]]; then
                echo -e "${YELLOW}No changes made. Returning to the menu.${RESET}"
                read -p "Press Enter to continue..."
                return
            fi
                
            sed -i "s/remote [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/remote $new_remote_ip/" "$service_file"
            sudo systemctl daemon-reload
            sudo systemctl restart "$selected_tunnel"
            echo -e "${greEN}Remote IP has been updated to $new_remote_ip in $selected_tunnel.service.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        10)
            route_ip1=$(grep -oP '(?<=route\sadd\s)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)
            remote_ip1=$(grep -oP '(?<=remote\s)(\d+\.\d+\.\d+\.\d+|\[?[0-9a-fA-F:]+\]?)' "$service_file" | head -n 1)

            if [[ -z "$route_ip1" ]] && [[ -z "$remote_ip1" ]]; then
                echo -e "\033[1;31mNo route or remote IP found in the service file.\033[0m"
                read -p "Press Enter to continue..."
                return
            fi

            echo -e "\033[1;32mroute IP: $route_ip1\033[0m"
            echo -e "\033[1;32mremote IP: $remote_ip1\033[0m"

            echo -e "\033[1;32mPinging route IP: $route_ip1...\033[0m"
            if ping -c 4 -W 3 "$route_ip1"; then
                echo -e "\033[1;32mPing to route IP successful.\033[0m"
            else
                echo -e "\033[1;31mPing to route IP timed out or failed.\033[0m"
            fi

            echo -e "\033[1;32mPinging remote IP: $remote_ip1...\033[0m"
            if ping -c 4 -W 3 "$remote_ip1"; then
                echo -e "\033[1;32mPing to remote IP successful.\033[0m"
            else
                echo -e "\033[1;31mPing to remote IP timed out or failed.\033[0m"
            fi

            read -p "Press Enter to continue..."
            ;;
        11)
            local new_local_ip
            local current_local_ip
            
            if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
                service_file="/usr/lib/systemd/system/$selected_tunnel.service"
            else
                echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
                read -p "Press Enter to continue..."
                return
            fi
            
            current_local_ip=$(grep -oP 'local \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$service_file")
            
            if [[ -n "$current_local_ip" ]]; then
                echo -e "${CYAN}Current saved local IP: ${RED}$current_local_ip${RESET}"
            else
                echo -e "${YELLOW}No local IP found in the service file.${RESET}"
            fi
            
            real_local_ip=$(get_local_ip)
            
            if [[ -n "$real_local_ip" ]]; then
                echo -e "${CYAN}True local IP: ${greEN}$real_local_ip${RESET}"
            else
                echo -e "${YELLOW}Unable to retrieve the local IP address.${RESET}"
            fi

            echo -e "${greEN}Enter the new local IP address or press Enter to cancel:${RESET}"
            read -p "> " new_local_ip
            
            if [[ -z "$new_local_ip" ]]; then
                echo -e "${YELLOW}No changes made. Returning to the menu.${RESET}"
                read -p "Press Enter to continue..."
                return
            fi
            
            sed -i "s/local [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/local $new_local_ip/" "$service_file"
            sudo systemctl daemon-reload
            sudo systemctl restart "$selected_tunnel"
            echo -e "${greEN}Local IP has been updated to $new_local_ip in $selected_tunnel.service.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        *)
            echo -e "${RED}Invalid option...${RESET}"
            read -p "Press Enter to continue..."
            ;;
    esac
}

# Function to stop all ERSPAN tunnel services
stop_all_erspan_tunnels() {
    echo -e "${greEN}Stopping all ERSPAN tunnel services...${RESET}"
    local stopped_any=false

    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/erspan-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${greEN}Stopping $service_name...${RESET}"
                systemctl stop "$service_name"
                sudo systemctl daemon-reload
                stopped_any=true
            fi
        done
    done

    if [[ $stopped_any == false ]]; then
        echo -e "${RED}No active ERSPAN tunnel services found to stop.${RESET}"
        return 1
    fi

    echo -e "${greEN}All ERSPAN tunnel services have been stopped.${RESET}"
    read -p "Press Enter to continue..."
}

# Function to enable and start all ERSPAN tunnel services
enable_and_start_erspan_tunnels() {
    echo -e "${greEN}Enabling and starting all ERSPAN tunnel services...${RESET}"
    local started_any=false

    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/erspan-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${greEN}Enabling and starting $service_name...${RESET}"
                systemctl enable "$service_name"
                systemctl start "$service_name"
                sudo systemctl daemon-reload
                started_any=true
            fi
        done
    done

    if [[ $started_any == false ]]; then
        echo -e "${RED}No ERSPAN tunnel services found to enable or start.${RESET}"
        return 1
    fi

    echo -e "${greEN}All ERSPAN tunnel services have been enabled and started.${RESET}"
    read -p "Press Enter to continue..."
}

# Function to restart all ERSPAN tunnel services
restart_erspan_tunnels() {
    echo -e "${greEN}Restarting all ERSPAN tunnel services...${RESET}"
    local restarted_any=false

    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/erspan-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${greEN}Restarting $service_name...${RESET}"
                systemctl restart "$service_name"
                sudo systemctl daemon-reload
                restarted_any=true
            fi
        done
    done

    if [[ $restarted_any == false ]]; then
        echo -e "${RED}No ERSPAN tunnel services found to restart.${RESET}"
        return 1
    fi

    echo -e "${greEN}All ERSPAN tunnel services have been restarted.${RESET}"
    read -p "Press Enter to continue..."
}

# Main menu
while true; do
    clear
    echo -e "\033[1;34m=========================================\033[0m"
    echo -e "      \033[1;32mERSPAN Tunnel Service Method\033[0m"
    echo -e "\033[1;34m=========================================\033[0m"
    echo -e "\033[1;36m 1.\033[0m \033[1;32mCreate ERSPAN Tunnel\033[0m"
    echo -e "\033[1;36m 2.\033[0m \033[1;32mManage ERSPAN Tunnels\033[0m"
    echo -e "\033[1;36m 3.\033[0m \033[1;32mStart all ERSPAN Tunnels\033[0m"
    echo -e "\033[1;36m 4.\033[0m \033[1;32mStop all ERSPAN Tunnels\033[0m"
    echo -e "\033[1;36m 5.\033[0m \033[1;32mRestart all ERSPAN Tunnels\033[0m"
    echo -e "\033[1;36m 0.\033[0m \033[1;31mExit\033[0m"
    echo -e "\n\033[1;34m=========================================\033[0m"
    echo -e "\033[1;32mEnter your choice: \033[0m"

    read -p "Choice: " option

    case $option in
        1)
            create_erspan_tunnel
            ;;
        2)
            manage_erspan_tunnels
            ;;
        3)
            enable_and_start_erspan_tunnels
            ;;
        4)
            stop_all_erspan_tunnels
            ;;
        5)
            restart_erspan_tunnels
            ;;
        0)
            echo -e "\n\033[1;31mExiting... Goodbye!\033[0m"
            break 
            ;;
        *) 
            echo -e "\n\033[1;31mInvalid option, please try again.\033[0m"
            sleep 1
            ;;
    esac
done