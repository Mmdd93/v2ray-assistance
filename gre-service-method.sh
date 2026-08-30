#!/bin/bash

greEN='\033[1;32m'
RED='\033[1;31m'
YELLOW="\033[1;33m"
RESET='\033[0m'


    # Remove /root/ipv4.txt if it exists
    if [ -f /root/ipv4.txt ]; then
        rm /root/ipv4.txt
        echo -e "\033[1;33mExisting /root/ipv4.txt file removed.\033[0m"
    fi

# Function to generate a random name
 generate_random_name() {
    tr -dc 'a-z0-9' </dev/urandom | fold -w 5 | head -n 1
}

generate_random_ipv6() {
    # Define 100 IPv6 address templates (hidden from display)
    local templates=()
    for i in {1..100}; do
        templates+=("2001:db8:$i::%x/64")
    done

    # Prompt the user to select a template
    echo -e "\n\033[1;34mSelect an IPv6 template number (1-100) or Press Enter for a random template:\033[0m"
    local template_number
    read -p " > " template_number

    if [[ -z "$template_number" ]]; then
        template_number=$(shuf -i 1-100 -n 1)
        echo -e "\n\033[1;33mRandomly selected template number: [$template_number]\033[0m"
    else
        # Validate user input for template selection
        if [[ ! "$template_number" =~ ^[1-9]$|^[1-9][0-9]$|^100$ ]]; then
            echo -e "\n\033[1;31mInvalid input. Please select a number between 1 and 100.\033[0m"
            return
        fi
        echo -e "\n\033[1;32m!! Now! Use template number [$template_number] on the remote server as well.\033[0m"
        read -p "Press Enter to continue..."
    fi

    # Adjust template number to zero-based index
    local selected_template="${templates[$((template_number - 1))]}"

    # Extract the prefix from the template (e.g., "2001:db8:1::")
    local template_prefix=$(echo "$selected_template" | cut -d':' -f1-4)

    # Check if the generated IPv6 prefix is already in use
    if ip -6 addr show | grep -q "$template_prefix"; then
        echo -e "\033[1;31mWarning: The IPv6 prefix $template_prefix is already in use on an interface.\033[0m"
        echo -e "\033[1;33mPlease choose a different template number.\033[0m"
        
        # Prompt the user to choose a new template
        read -p "Press Enter to select a new template..."
        generate_random_ipv6  # Recursively call the function to try again
        return
    fi

    # Generate random 16-bit hexadecimal blocks, padded to 4 characters
    local block1=$(printf '%04x' $((RANDOM % 65536)))

    # Build the IPv6 address directly by concatenating the blocks with the template
    local ipv6_address="${selected_template//%x/$block1}"
    ipv6_address="${ipv6_address//%x/$block1}"

    # Prompt for a custom IPv6 address
    echo -e "\n\033[1;32mEnter a custom IPv6 address or enter blank to use \033[0m $ipv6_address"
    read -p " > " user_ipv6_address

    # Use the custom IPv6 address if provided, otherwise use the generated one
    ipv6_address=${user_ipv6_address:-$ipv6_address}

   # Display the final IPv4 address
    echo -e "\033[1;31m!! Save and copy > $ipv6_address < (use it for routing in remote server)!!\033[0m"
    echo -e "\n\033[1;32mLocal IPv6 address:\033[0m $ipv64_address"

    # Save the generated or custom IPv6 address to a text file
    echo "ipv6=$ipv6_address" > /root/ipv6.txt
    echo -e "\n\033[1;33mIPv6 address saved to ipv6.txt\033[0m"
    sleep 1

    source /root/ipv6.txt
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
# Function to create a gre tunnel ipv4
create_gre_tunnel_ipv4() {
source /root/ipv4.txt

     # Generate a default random name
    local default_name=$(generate_random_name)

    # Ask for the service name, but provide a default random name if no input is given
    read -p "$(echo -e "\n${greEN}Enter a service name (default: ${default_name}): ${RESET}")" service_name

    # If no input is given, use the default random name
    if [[ -z "$service_name" ]]; then
        service_name="$default_name"  # Use the default name
    fi

    # Ensure the service name has the required prefix
    if [[ ! "$service_name" =~ ^gre-tunnel- ]]; then
        service_name="gre-$service_name"
        
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


    # Use the function to generate or select a custom ipv4 address
    echo -e "\n${greEN}Configuring the ipv4 address for the tunnel.${RESET}"
    generate_random_ipv4  # This function handles template selection and custom input
    local ipv4_address=$ipv4  # Generated or chosen ipv4 address is set globally in the function

    # Ask for the route network
    echo -e "\n${greEN}Enter generated local ipv4 from the remote server for routing (e.g., $ipv4_address):${RESET}"
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


    # Generate the systemd service file
    echo -e "\n${greEN}Creating systemd service file for $service_name...${RESET}"
    cat <<EOF > "$service_file"
[Unit]
Description=gre Tunnel $service_name
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env sh -c '\
    /sbin/ip tunnel add $service_name mode gre local $local_ip remote $remote_ip ttl 255 && \
    /sbin/ip link set $service_name up && \
    /sbin/ip addr add $ipv4_address dev $service_name && \
    /sbin/ip route add $route_network dev $service_name'
ExecStop=/sbin/ip tunnel del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"

    echo -e "\n${greEN}Tunnel $service_name created.${RESET}"
    read -p "Press Enter to continue..."
}


# Function to create a gre tunnel ipv6
create_gre_tunnel_ipv6() {
source /root/ipv6.txt

     # Generate a default random name
    local default_name=$(generate_random_name)

    # Ask for the service name, but provide a default random name if no input is given
    read -p "$(echo -e "\n${greEN}Enter a service name (default: ${default_name}): ${RESET}")" service_name

    # If no input is given, use the default random name
    if [[ -z "$service_name" ]]; then
        service_name="$default_name"  # Use the default name
    fi

    # Ensure the service name has the required prefix
    if [[ ! "$service_name" =~ ^gre-tunnel- ]]; then
        service_name="gre-$service_name"
        
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

# Check if the input is an ipv6 address
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


    # Use the function to generate or select a custom ipv6 address
    echo -e "\n${greEN}Configuring the ipv6 address for the tunnel.${RESET}"
    generate_random_ipv6  # This function handles template selection and custom input
    local ipv6_address=$ipv6  # Generated or chosen ipv6 address is set globally in the function

    # Ask for the route network
    echo -e "\n${greEN}Enter generated local ipv6 from the remote server for routing (e.g., $ipv6_address):${RESET}"
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


    # Generate the systemd service file
    echo -e "\n${greEN}Creating systemd service file for $service_name...${RESET}"
    cat <<EOF > "$service_file"
[Unit]
Description=gre Tunnel $service_name
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env sh -c '\
    /sbin/ip tunnel add $service_name mode gre local $local_ip remote $remote_ip ttl 255 && \
    /sbin/ip link set $service_name up && \
    /sbin/ip addr add $ipv6_address dev $service_name && \
    /sbin/ip route add $route_network dev $service_name'
ExecStop=/sbin/ip tunnel del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"

    echo -e "\n${greEN}Tunnel $service_name created.${RESET}"
    read -p "Press Enter to continue..."
}
manage_tunnels() {
    while true; do
        clear
        # List all available gre tunnel services
        echo -e "${greEN}Available gre tunnels:${RESET}"
        local tunnels=()

        # Get all active gre tunnel services from directory
        for dir in /usr/lib/systemd/system; do
            for file in "$dir"/gre-*.service; do
                if [[ -f "$file" ]]; then
                    tunnels+=("$(basename "$file" .service)")
                fi
            done
        done

        if [[ ${#tunnels[@]} -eq 0 ]]; then
            echo -e "${RED}No active gre tunnels found.${RESET}"
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
            read -p "Press Enter to continue..."
            continue
        fi

        # Set the selected tunnel for further actions
        selected_tunnel="${tunnels[choice - 1]}"

        while true; do
            clear
            local service_file
            if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
                service_file="/usr/lib/systemd/system/$selected_tunnel.service"
            else
                echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
                read -p "Press Enter to continue..."
                break
            fi

            # Extract info from service file
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
            echo -e "\033[1;34m9.\033[0m \033[1;36mPing remote server local/public IP\033[0m"
            echo -e "\033[1;31m0.\033[0m \033[1;37mReturn to main menu\033[0m"
            echo -e "\033[1;32m================================================\033[0m"

            read -p "Choose an option: " action

            case $action in
                0) 
                    break 
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
                    sudo rm -f "/usr/lib/systemd/system/$selected_tunnel.service"
                    sudo systemctl daemon-reload
                    echo -e "${greEN}Tunnel $selected_tunnel removed.${RESET}"
                    read -p "Press Enter to continue..."
                    break
                    ;;
                8)
                    sudo nano "$service_file"
                    sudo systemctl restart "$selected_tunnel.service"
                    sudo systemctl daemon-reload
                    read -p "Press Enter to continue..."
                    ;;
                9)
                    if [[ -z "$route_ip1" ]] && [[ -z "$remote_ip1" ]]; then
                        echo -e "\033[1;31mNo route or remote IP found in the service file.\033[0m"
                    else
                        echo -e "\033[1;32mroute IP: $route_ip1\033[0m"
                        echo -e "\033[1;32mremote IP: $remote_ip1\033[0m"

                        echo -e "\033[1;32mPinging route IP: $route_ip1...\033[0m"
                        if ping -c 4 -W 3 "$route_ip1"; then
                            echo -e "\033[1;32mPing to route IP successful.${RESET}"
                        else
                            echo -e "\033[1;31mPing to route IP timed out or failed.${RESET}"
                        fi

                        echo -e "\033[1;32mPinging remote IP: $remote_ip1...\033[0m"
                        if ping -c 4 -W 3 "$remote_ip1"; then
                            echo -e "\033[1;32mPing to remote IP successful.${RESET}"
                        else
                            echo -e "\033[1;31mPing to remote IP timed out or failed.${RESET}"
                        fi
                    fi
                    read -p "Press Enter to continue..."
                    ;;
                *)
                    echo -e "${RED}Invalid option...${RESET}"
                    read -p "Press Enter to continue..."
                    ;;
            esac
        done
    done
}

# Function to stop all gre tunnel services
stop_all_gre_tunnels() {
    echo -e "${greEN}Stopping all gre tunnel services...${RESET}"
    local stopped_any=false

    # Loop through directories to find gre tunnel services
    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/gre-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${greEN}Stopping $service_name...${RESET}"
                systemctl stop "$service_name"
                # Reload systemd to apply the changes
                sudo systemctl daemon-reload
                stopped_any=true
            fi
        done
    done

    if [[ $stopped_any == false ]]; then
        echo -e "${RED}No active gre tunnel services found to stop.${RESET}"
        return 1
    fi

    echo -e "${greEN}All gre tunnel services have been stopped.${RESET}"
    read -p  "Press Enter to continue..."
}

# Function to enable and start all gre tunnel services
enable_and_start_gre_tunnels() {
    echo -e "${greEN}Enabling and starting all gre tunnel services...${RESET}"
    local started_any=false

    # Loop through directories to find gre tunnel services
    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/gre-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${greEN}Enabling and starting $service_name...${RESET}"
                systemctl enable "$service_name"
                systemctl start "$service_name"
                # Reload systemd to apply the changes
                sudo systemctl daemon-reload
                started_any=true
            fi
        done
    done

    if [[ $started_any == false ]]; then
        echo -e "${RED}No gre tunnel services found to enable or start.${RESET}"
        return 1
    fi

    echo -e "${greEN}All gre tunnel services have been enabled and started.${RESET}"
    read -p  "Press Enter to continue..."
}

# Function to enable and start all gre tunnel services
restart_gre_tunnels() {
    echo -e "${greEN}Enabling and starting all gre tunnel services...${RESET}"
    local started_any=false

    # Loop through directories to find gre tunnel services
    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/gre-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${greEN}Enabling and starting $service_name...${RESET}"
                systemctl restart "$service_name"
                # Reload systemd to apply the changes
                sudo systemctl daemon-reload
                started_any=true
            fi
        done
    done

    if [[ $started_any == false ]]; then
        echo -e "${RED}No gre tunnel services found to enable or start.${RESET}"
        return 1
    fi

    echo -e "${greEN}All gre tunnel services have been enabled and started.${RESET}"
    read -p  "Press Enter to continue..."
}



# Function to back up files and directories
backup_files_and_dirs() {
  #!/bin/bash

# File paths and directories to back up
FILES=("/etc/x-ui/x-ui.db" "/var/spool/cron/crontabs/root" "/root/auto_gre_update.sh")
DIRS=("/root/gre")  # Directories to back up
SERVICE_FILES="/usr/lib/systemd/system/gre-*.service"  # Systemd service files for tunnels

# Define colors
greEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Ensure zip is installed
if ! command -v zip &> /dev/null; then
  echo -e "${RED}zip is not installed. Installing...${RESET}"
  
  # Detect the package manager and install zip
  if command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y zip
  elif command -v yum &> /dev/null; then
    sudo yum install -y zip
  elif command -v dnf &> /dev/null; then
    sudo dnf install -y zip
  elif command -v zypper &> /dev/null; then
    sudo zypper install -y zip
  elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm zip
  else
    echo -e "${RED}Error:${RESET} Unable to determine package manager. Please install zip manually." >&2
    exit 1
  fi

  # Verify installation
  if command -v zip &> /dev/null; then
    echo -e "${greEN}zip has been successfully installed.${RESET}"
  else
    echo -e "${RED}Error:${RESET} Failed to install zip. Please check your system settings." >&2
    exit 1
  fi
else
  echo -e "${greEN}zip is already installed.${RESET}"
fi

# Create a list of all items to back up
TRANSFERRED_ITEMS=()

# Check if each file exists and add it to the backup list
for FILE_PATH in "${FILES[@]}"; do
  if [ -f "$FILE_PATH" ]; then
    TRANSFERRED_ITEMS+=("$FILE_PATH")
    echo -e "${BLUE}Adding file to backup: ${YELLOW}$FILE_PATH${RESET}"
  else
    echo -e "${YELLOW}Warning:${RESET} File does not exist: $FILE_PATH"
  fi
done

# Check if each directory exists and add it to the backup list
for DIR_PATH in "${DIRS[@]}"; do
  if [ -d "$DIR_PATH" ]; then
    TRANSFERRED_ITEMS+=("$DIR_PATH")
    echo -e "${BLUE}Adding directory to backup: ${YELLOW}$DIR_PATH${RESET}"
  else
    echo -e "${YELLOW}Warning:${RESET} Directory does not exist: $DIR_PATH"
  fi
done

# Check if any service files exist and add them to the backup list
if compgen -G "$SERVICE_FILES" > /dev/null; then
  for SERVICE_FILE in $SERVICE_FILES; do
    TRANSFERRED_ITEMS+=("$SERVICE_FILE")
    echo -e "${BLUE}Adding service file to backup: ${YELLOW}$SERVICE_FILE${RESET}"
  done
else
  echo -e "${YELLOW}Warning:${RESET} No tunnel service files found matching $SERVICE_FILES"
fi

# Create a ZIP file locally
# Create a ZIP file on the local system
ZIP_FILE="/root/backup_$(date +[%Y-%m-%d][%H:%M]).zip"
TRANSFERRED_ITEMS=("${FILES[@]}" "${DIRS[@]}" $SERVICE_FILES)  # Combine files, directories, and service files

echo -e "${BLUE}Creating a ZIP archive locally: ${YELLOW}$ZIP_FILE${RESET}"
zip -r "$ZIP_FILE" "${TRANSFERRED_ITEMS[@]}" > /dev/null

if [ $? -eq 0 ]; then
  echo -e "${greEN}Success:${RESET} Local ZIP archive created at $ZIP_FILE."
else
  echo -e "${RED}Error:${RESET} Failed to create local ZIP archive." >&2
fi
  read -p  "Press Enter to continue..."
}


transfer-gre() {
#!/bin/bash
# Define colors
greEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
# File paths and credentials
FILES=("/etc/x-ui/x-ui.db" "/var/spool/cron/crontabs/root" "/root/auto_gre_update.sh" "/root/6to4-service-method.sh")
DIRS=("/root/gre")  # Directories to transfer
SERVICE_FILES="/usr/lib/systemd/system/gre-*.service"

# Ask for credentials
echo -e "${BOLD}${YELLOW}Please enter the SSH connection details:${RESET}"

# Prompt for the remote user
read -p "Remote User (default 'root'):" REMOTE_USER
REMOTE_USER=${REMOTE_USER:-root}

# Check if REMOTE_HOST is provided, if not, prompt for it
if [ -z "$REMOTE_HOST" ]; then
  read -p "Remote Host IP:" REMOTE_HOST
fi

# Prompt for the remote port with default value
read -p "Remote Port (default '22'):" REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}

# Prompt for the root password (hidden input)
read -p "Root Password:" ROOT_PASSWORD
echo  # To move to the next line after password input

# Output confirmation of the entered credentials
echo -e "\n${greEN}${BOLD}Credentials Summary:${RESET}"
echo -e "${YELLOW}Remote User:${RESET} ${REMOTE_USER}"
echo -e "${YELLOW}Remote Host:${RESET} ${REMOTE_HOST}"
echo -e "${YELLOW}Remote Port:${RESET} ${REMOTE_PORT}"
echo -e "${YELLOW}Remote PASSWORD:${RESET} ${ROOT_PASSWORD}"
# Ask if the credentials are correct
while true; do
  read -p "Are these credentials correct? (yes/no, default 'yes'):" CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-yes}  # Default to 'yes' if no input is given
  
  if [[ "$CONFIRMATION" == "yes" || "$CONFIRMATION" == "y" ]]; then
    echo -e "${greEN}Credentials confirmed! Proceeding...${RESET}"
    break
  elif [[ "$CONFIRMATION" == "no" || "$CONFIRMATION" == "n" ]]; then
    echo -e "${RED}Please re-enter the credentials.${RESET}"
    
    # Ask for the credentials again
    read -p "Remote User (default 'root'):" REMOTE_USER
    REMOTE_USER=${REMOTE_USER:-root}

    read -p "Remote Host IP:" REMOTE_HOST

    read -p "Remote Port (default '22'):" REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-22}

    read -p "Root Password:" ROOT_PASSWORD
    echo  # To move to the next line after password input

    # Output confirmation of the new entered credentials
    echo -e "\n${greEN}${BOLD}New Credentials Summary:${RESET}"
    echo -e "${YELLOW}Remote User:${RESET} ${REMOTE_USER}"
    echo -e "${YELLOW}Remote Host:${RESET} ${REMOTE_HOST}"
    echo -e "${YELLOW}Remote Port:${RESET} ${REMOTE_PORT}"
    echo -e "${YELLOW}Remote PASSWORD:${RESET} ${ROOT_PASSWORD}"
  else
    echo -e "${RED}Invalid input. Please enter 'yes' or 'no'.${RESET}"
  fi
done


# Ensure zip is installed
if ! command -v zip &> /dev/null; then
  echo -e "${RED}zip is not installed. Installing...${RESET}"
  
  # Detect the package manager and install zip
  if command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y zip
  elif command -v yum &> /dev/null; then
    sudo yum install -y zip
  elif command -v dnf &> /dev/null; then
    sudo dnf install -y zip
  elif command -v zypper &> /dev/null; then
    sudo zypper install -y zip
  elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm zip
  else
    echo -e "${RED}Error:${RESET} Unable to determine package manager. Please install zip manually." >&2
    exit 1
  fi

  # Verify installation
  if command -v zip &> /dev/null; then
    echo -e "${greEN}zip has been successfully installed.${RESET}"
  else
    echo -e "${RED}Error:${RESET} Failed to install zip. Please check your system settings." >&2
    exit 1
  fi
else
  echo -e "${greEN}zip is already installed.${RESET}"
fi
# Check if sshpass is installed
if ! command -v sshpass &> /dev/null; then
  echo -e "${RED}sshpass is not installed. Installing...${RESET}"
  
  # Detect the package manager and install sshpass
  if command -v apt &> /dev/null; then
    sudo apt update && sudo apt install -y sshpass
  elif command -v yum &> /dev/null; then
    sudo yum install -y sshpass
  elif command -v dnf &> /dev/null; then
    sudo dnf install -y sshpass
  elif command -v zypper &> /dev/null; then
    sudo zypper install -y sshpass
  elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm sshpass
  else
    echo -e "${RED}Error:${RESET} Unable to determine package manager. Please install sshpass manually." >&2
    exit 1
  fi

  # Verify installation
  if command -v sshpass &> /dev/null; then
    echo -e "${greEN}sshpass has been successfully installed.${RESET}"
  else
    echo -e "${RED}Error:${RESET} Failed to install sshpass. Please check your system settings." >&2
    exit 1
  fi
else
  echo -e "${greEN}sshpass is already installed.${RESET}"
fi

# Verify SSH connection
if sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit; then
  echo -e "${greEN}SSH connection to $REMOTE_USER@$REMOTE_HOST successful.${RESET}"
else
  echo -e "${RED}Error:${RESET} Failed to connect to $REMOTE_USER@$REMOTE_HOST via SSH." >&2
  exit 1
fi

# Declare an associative array for file-path mappings
declare -A FILE_PATHS=(
  ["/root/auto_gre_update.sh"]="/root"
  ["/root/6to4-service-method.sh"]="/root"
  ["/etc/x-ui/x-ui.db"]="/etc/x-ui"
  ["/var/spool/cron/crontabs/root"]="/var/spool/cron/crontabs"
)

# Add dynamically matched files
for SERVICE_FILE in $SERVICE_FILES; do
  if [ -f "$SERVICE_FILE" ]; then
    FILES+=("$SERVICE_FILE")
    FILE_PATHS["$SERVICE_FILE"]="/usr/lib/systemd/system"
  else
    echo -e "${YELLOW}Warning:${RESET} No files matching $SERVICE_FILES found locally."
  fi
done

# Create a list of all transferred items
TRANSFERRED_ITEMS=()

# Transfer files
for FILE_PATH in "${FILES[@]}"; do
  DEST_DIR="${FILE_PATHS[$FILE_PATH]}"
  FILE_NAME=$(basename "$FILE_PATH")  # Extract file name from the path

  if [ -f "$FILE_PATH" ]; then
    # Ensure the destination directory exists on the remote server
    echo -e "${BLUE}Ensuring destination directory exists: ${YELLOW}$DEST_DIR${RESET}"
    sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $DEST_DIR"

    # Send the file using scp
    echo -e "${BLUE}Attempting to send file: ${YELLOW}$FILE_PATH${RESET} to ${YELLOW}$DEST_DIR/$FILE_NAME${RESET}"
    if sshpass -p "$ROOT_PASSWORD" scp -P "$REMOTE_PORT" "$FILE_PATH" "$REMOTE_USER@$REMOTE_HOST:$DEST_DIR/$FILE_NAME"; then
      echo -e "${greEN}Success:${RESET} File $FILE_PATH successfully sent to $REMOTE_USER@$REMOTE_HOST:$DEST_DIR/$FILE_NAME"
      TRANSFERRED_ITEMS+=("$DEST_DIR/$FILE_NAME")
    else
      echo -e "${RED}Error:${RESET} Failed to send file $FILE_PATH to $REMOTE_USER@$REMOTE_HOST:$DEST_DIR/$FILE_NAME" >&2
    fi
  else
    echo -e "${YELLOW}Warning:${RESET} File does not exist: $FILE_PATH"
  fi
done

# Transfer directories
for DIR_PATH in "${DIRS[@]}"; do
  DEST_DIR=$(dirname "$DIR_PATH")  # Parent directory as destination

  if [ -d "$DIR_PATH" ]; then
    # Ensure the destination directory exists on the remote server
    echo -e "${BLUE}Ensuring destination directory exists: ${YELLOW}$DEST_DIR${RESET}"
    sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "mkdir -p $DEST_DIR"

    # Send the directory using scp (trailing slash ensures correct structure)
    echo -e "${BLUE}Attempting to send directory: ${YELLOW}$DIR_PATH${RESET} to ${YELLOW}$DEST_DIR/${RESET}"
    if sshpass -p "$ROOT_PASSWORD" scp -P "$REMOTE_PORT" -r "${DIR_PATH%/}/" "$REMOTE_USER@$REMOTE_HOST:$DEST_DIR/"; then
      echo -e "${greEN}Success:${RESET} Directory $DIR_PATH successfully sent to $REMOTE_USER@$REMOTE_HOST:$DEST_DIR/"
      TRANSFERRED_ITEMS+=("$DEST_DIR/")
    else
      echo -e "${RED}Error:${RESET} Failed to send directory $DIR_PATH to $REMOTE_USER@$REMOTE_HOST:$DEST_DIR/" >&2
    fi
  else
    echo -e "${YELLOW}Warning:${RESET} Directory does not exist: $DIR_PATH"
  fi
done

# Create a ZIP file on the local system
ZIP_FILE="/root/backup_$(date +[%Y-%m-%d][%H:%M]).zip"
TRANSFERRED_ITEMS=("${FILES[@]}" "${DIRS[@]}")  # Combine files and directories

echo -e "${BLUE}Creating a ZIP archive locally: ${YELLOW}$ZIP_FILE${RESET}"
zip -r "$ZIP_FILE" "${TRANSFERRED_ITEMS[@]}" > /dev/null

if [ $? -eq 0 ]; then
  echo -e "${greEN}Success:${RESET} Local ZIP archive created at $ZIP_FILE."
else
  echo -e "${RED}Error:${RESET} Failed to create local ZIP archive." >&2
fi
read -p  "Press Enter to continue..."
}
# Main menu
while true; do
    # Clear the screen for a clean look each time
    clear

# Main menu with enhanced styling
clear
echo -e "\033[1;34m=========================================\033[0m"
echo -e "      \033[1;32mgre Tunnel Service Method\033[0m"
echo -e "\033[1;34m=========================================\033[0m"
echo -e "\033[1;36m 1.\033[0m \033[1;32mCreate gre Tunnel ipv4 local \033[0m"
echo -e "\033[1;36m 2.\033[0m \033[1;32mCreate gre Tunnel ipv6 local \033[0m"
echo -e "\033[1;36m 3.\033[0m \033[1;32mManage gre Tunnels\033[0m"
echo -e "\033[1;36m 4.\033[0m \033[1;32mStart all gre Tunnels\033[0m"
echo -e "\033[1;36m 5.\033[0m \033[1;32mStop all gre Tunnels\033[0m"
echo -e "\033[1;36m 6.\033[0m \033[1;32mRestart all gre Tunnels\033[0m"
echo -e "\033[1;36m 0.\033[0m \033[1;31mExit\033[0m"
echo -e "\n\033[1;34m=========================================\033[0m"
echo -e "\033[1;32mEnter your choice: \033[0m"

    read -p "Choice: " option

    case $option in
        1)
            create_gre_tunnel_ipv4
            ;;
        2)
            create_gre_tunnel_ipv6
            ;;
        3)
            manage_tunnels 
            ;;
        4)
            enable_and_start_gre_tunnels 
            ;;
        5)
            stop_all_gre_tunnels
            ;;
            
        6)
            restart_gre_tunnels
            ;;
        7)
            backup_files_and_dirs
            ;;
        8)
           transfer-gre
            ;;
        0)
            echo -e "\n\033[1;31mExiting... Goodbye!\033[0m"
            break 
            ;;
        *) 
            # Invalid option
            echo -e "\n\033[1;31mInvalid option, please try again.\033[0m"
            sleep 1
            ;;
    esac
done
