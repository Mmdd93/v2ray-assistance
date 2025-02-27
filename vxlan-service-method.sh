#!/bin/bash

GREEN='\033[1;32m'
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
# Function to create a vxlan tunnel
create_vxlan_tunnel() {
source /root/ipv4.txt

     # Generate a default random name
    local default_name=$(generate_random_name)

    # Ask for the service name, but provide a default random name if no input is given
    read -p "$(echo -e "\n${GREEN}Enter a service name (default: ${default_name}): ${RESET}")" service_name

    # If no input is given, use the default random name
    if [[ -z "$service_name" ]]; then
        service_name="$default_name"  # Use the default name
    fi

    # Ensure the service name has the required prefix
    if [[ ! "$service_name" =~ ^vxlan-tunnel- ]]; then
        service_name="vxlan-$service_name"
        
    fi

    echo -e "\n${GREEN}Using service name:${RESET} $service_name"

    # Check if the service already exists
    local service_file="/usr/lib/systemd/system/$service_name.service"
    if [[ -f "$service_file" ]]; then
        echo -e "\n${RED}A service with this name already exists. Please choose a different name.${RESET}"
        return
    fi



# Ask for the VNI
default_vni=100

# Display the messages
echo -e "\033[1;33m!For this tunnel: Use equal VNI to communicate servers with each other!\033[0m"
echo -e "\033[1;33m!For next tunnel: Use different VNI to separate this tunnel from other tunnels!\033[0m"

# Prompt user for VNI input
echo -e "\n\033[1;32mEnter the VNI for the tunnel \033[1;33m(Default: $default_vni)\033[0m:"
echo -e "\n\033[1;32mEnter blank for useing\033[1;33m $default_vni\033[0m:"
read -p " > " vni_input

# Use the provided VNI or default if none is entered
vni_input=${vni_input:-$default_vni}

# Validate that the VNI is a valid number (positive integer) and between 1 and 16777215
if [[ ! "$vni_input" =~ ^[0-9]+$ ]] || [ "$vni_input" -lt 1 ] || [ "$vni_input" -gt 16777215 ]; then
    echo -e "\033[1;31mInvalid VNI input. VNI must be a valid number between 1 and 16777215.\033[0m"
    exit 1
fi



vni=$vni_input
echo -e "\033[1;36mUsing VNI: $vni for tunnel communication\033[0m"

# Now, you can use $local_ip (which is the VNI) for your tunnel setup

# Get the default local IP
local_ip=$(get_local_ip)
if [[ -z "$local_ip" ]]; then
    echo -e "\033[1;31mNo local IP address found. Exiting...\033[0m"
    exit 1
fi

# Ask for the local IP or domain for the tunnel
echo -e "\n\033[1;32mEnter the local IP or domain for the tunnel \033[1;33m(Default: $local_ip)\033[0m:"
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
    echo -e "\n${GREEN}Configuring the ipv4 address for the tunnel.${RESET}"
    generate_random_ipv4  # This function handles template selection and custom input
    local ipv4_address=$ipv4  # Generated or chosen ipv4 address is set globally in the function

    # Ask for the route network
    echo -e "\n${GREEN}Enter generated local ipv4 from the remote server for routing (e.g., $ipv4_address):${RESET}"
    read -p " > " route_network

    if [[ -z "$route_network" ]]; then
        echo -e "\n${RED}No route entered. Exiting...${RESET}"
        return
    fi
    echo -e "${CYAN}Using route: $route_network via $service_name${RESET}"
    
    # Ask for the remote IP or domain for the tunnel
    echo -e "\n${GREEN}Enter the remote IP or domain for the tunnel:${RESET}"
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
    

echo -e "${CYAN}🔹 Available network interfaces:${NC}"
    
    # Get all interfaces except loopback (lo)
    interfaces=($(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"))

    if [ ${#interfaces[@]} -eq 0 ]; then
        echo -e "${RED}No network interfaces found.${NC}"
        return 1
    fi

    # Detect the main interface (common names like eth0, ens3, enp*)
    main_interface=""
    for iface in "${interfaces[@]}"; do
        if [[ "$iface" =~ ^(eth0|ens[0-9]+|enp[0-9]+|eth1)$ ]]; then
            main_interface="$iface"
            break
        fi
    done

    # Display interfaces with color, marking the main one
    for i in "${!interfaces[@]}"; do
        if [[ "${interfaces[$i]}" == "$main_interface" ]]; then
            echo -e "${GREEN}$((i+1)). ${interfaces[$i]} (Main Interface)${NC}"
        else
            echo -e "${YELLOW}$((i+1)). ${interfaces[$i]}${NC}"
        fi
    done

    # User selection
    while true; do
        read -p "$(echo -e "${BLUE}➡ Select an interface (1-${#interfaces[@]}): ${NC}")" choice
        if [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#interfaces[@]} )); then
            eth="${interfaces[$((choice-1))]}"
            echo -e "${GREEN}Selected interface: $eth${NC}"
            break
        else
            echo -e "${RED}Invalid selection. Please enter a number between 1 and ${#interfaces[@]}.${NC}"
        fi
    done

    # Generate the systemd service file
echo -e "\n${GREEN}Creating systemd service file for $service_name...${RESET}"
cat <<EOF > "$service_file"
[Unit]
Description=vxlan Tunnel $service_name
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env sh -c '\
    /sbin/ip link add $service_name type vxlan id $vni dev $eth local $local_ip remote $remote_ip && \
	/sbin/ip addr add $ipv4_address dev $service_name && \
    /sbin/ip link set $service_name up && \
    /sbin/ip route add $route_network dev $service_name'
ExecStop=/sbin/ip link del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"

    echo -e "\n${GREEN}Tunnel $service_name created.${RESET}"
    read -p "Press Enter to continue..."
}



manage_tunnels() {
    # List all available vxlan tunnel services
    echo -e "${GREEN}Available vxlan tunnels:${RESET}"
    local tunnels=()

    # Get all active vxlan tunnel services from both directories
    for dir in  /usr/lib/systemd/system; do
        for file in "$dir"/vxlan-*.service; do
            if [[ -f "$file" ]]; then
                tunnels+=("$(basename "$file" .service)")
            fi
        done
    done

    if [[ ${#tunnels[@]} -eq 0 ]]; then
        echo -e "${RED}No active vxlan tunnels found.${RESET}"
        read -p "Press Enter to continue..."
        return 1
    fi

    # Display the available tunnels
    for i in "${!tunnels[@]}"; do
        echo "$((i + 1)). ${tunnels[i]}"
    done

    echo -e "${GREEN}Enter the number corresponding to the tunnel you want to manage:${RESET}"
    read -r choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#tunnels[@]})); then
        echo -e "${RED}Invalid choice. Please try again.${RESET}"
        return 1
    fi

    # Set the selected tunnel for further actions
    selected_tunnel="${tunnels[choice - 1]}"

    echo -e "${GREEN}You selected tunnel: $selected_tunnel${RESET}"
     local service_file
    if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
        service_file="/usr/lib/systemd/system/$selected_tunnel.service"
    elif [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
        service_file="/usr/lib/systemd/system/$selected_tunnel.service"
    else
        echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
        read -p "Press Enter to continue..."
        return
    fi

    # Extract the route IP from the ExecStart line in the service file
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
    echo -e "\033[1;34m10.\033[0m \033[1;36mPing remote local IP\033[0m"
    echo -e "\033[1;31m0.\033[0m \033[1;37mReturn to main menu\033[0m"
    echo -e "\033[1;32m================================================\033[0m"

    read -p "Choose an option: " action

    case $action in
        0) 
            # Return to main menu
            return
            ;;
        1)
            # Start the selected tunnel
            sudo systemctl start "$selected_tunnel.service"
            echo -e "${GREEN}Tunnel $selected_tunnel started.${RESET}"
            read -p "Press Enter to continue..."
            return
            ;;
        2)
            # Stop the selected tunnel
            sudo systemctl stop "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${GREEN}Tunnel $selected_tunnel stopped.${RESET}"
            read -p "Press Enter to continue..."
            return
            ;;
        3)
            # Restart the selected tunnel
            sudo systemctl restart "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${GREEN}Tunnel $selected_tunnel restarted.${RESET}"
            read -p "Press Enter to continue..."
            return
            ;;
        4)
            # Enable the selected tunnel at boot
            sudo systemctl enable "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${GREEN}Tunnel $selected_tunnel enabled at boot.${RESET}"
            read -p "Press Enter to continue..."
            return
            ;;
        5)
            # Disable the selected tunnel at boot
            sudo systemctl disable "$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${GREEN}Tunnel $selected_tunnel disabled at boot.${RESET}"
            read -p "Press Enter to continue..."
            return
            ;;
        6)
            # Check the status of the selected tunnel
            sudo systemctl status "$selected_tunnel.service"
            read -p "Press Enter to continue..."
            return
            ;;
        7)
            # Remove the selected tunnel
            sudo systemctl stop "$selected_tunnel.service"
            sudo systemctl disable "$selected_tunnel.service"
            sudo rm "/usr/lib/systemd/system/$selected_tunnel.service" "/usr/lib/systemd/system/$selected_tunnel.service"
            sudo systemctl daemon-reload
            echo -e "${GREEN}Tunnel $selected_tunnel removed.${RESET}"
            read -p "Press Enter to continue..."
            return
            ;;
        8)
            # Edit the service file with nano
            local service_file
            if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
                service_file="/usr/lib/systemd/system/$selected_tunnel.service"
            elif [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
                service_file="/usr/lib/systemd/system/$selected_tunnel.service"
            else
                echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
                return
            fi
            sudo nano "$service_file"
            sudo systemctl restart "$selected_tunnel.service"
            sudo systemctl daemon-reload
            read -p "Press Enter to continue..."
            return
            ;;
        9)
        local service_file
        local new_remote_ip
        local current_remote_ip

    
    
            # Check if the service file exists in the first path
            if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
                service_file="/usr/lib/systemd/system/$selected_tunnel.service"
            # Add an alternative path if needed (e.g., /etc/systemd/system/)
            elif [[ -f "/etc/systemd/system/$selected_tunnel.service" ]]; then
                service_file="/etc/systemd/system/$selected_tunnel.service"
            else
                echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
                read -p "Press Enter to continue..."
                return
            fi
        # Extract the current remote IP from the service file
        current_remote_ip=$(grep -oP 'remote \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$service_file")
        
        if [[ -n "$current_remote_ip" ]]; then
            echo -e "${CYAN}Current remote IP: ${GREEN}$current_remote_ip${RESET}"
        else
            echo -e "${YELLOW}No remote IP found in the service file.${RESET}"
        fi
        
        # Ask for the new remote IP address
        echo -e "${GREEN}Enter the new remote IP address or Enter blank to cancel:${RESET}"
        read -p "> " new_remote_ip
        
        # Check if the input is blank
        if [[ -z "$new_remote_ip" ]]; then
            echo -e "${YELLOW}No changes made. Returning to the menu.${RESET}"
            read -p "Press Enter to continue..."
            return
        fi
            
            # Use sed to replace the old remote IP with the new one
            sed -i "s/remote [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/remote $new_remote_ip/" "$service_file"
        
            # Reload systemd to apply the changes
            sudo systemctl daemon-reload
        
            # Restart the service to apply the new remote IP
            sudo systemctl restart "$selected_tunnel"
        
            echo -e "${GREEN}Remote IP has been updated to $new_remote_ip in $selected_tunnel.service.${RESET}"
            read -p "Press Enter to continue..."
        return
        ;;
        10)
    # Edit the service file with nano
    local service_file
    if [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
        service_file="/usr/lib/systemd/system/$selected_tunnel.service"
    elif [[ -f "/usr/lib/systemd/system/$selected_tunnel.service" ]]; then
        service_file="/usr/lib/systemd/system/$selected_tunnel.service"
    else
        echo -e "${RED}Service file not found for $selected_tunnel.${RESET}"
        read -p "Press Enter to continue..."
        return
    fi

    # Extract the route IP from the ExecStart line in the service file
    route_ip=$(grep -oP '(?<=route\sadd\s)(\d+\.\d+\.\d+\.\d+)' "$service_file" | head -n 1)
    remote_ip=$(grep -oP '(?<=remote\s)(\d+\.\d+\.\d+\.\d+)' "$service_file" | head -n 1)

    if [[ -z "$route_ip" ]] && [[ -z "$remote_ip" ]]; then
        echo -e "\033[1;31mNo route or remote IP found in the service file.\033[0m"
        read -p "Press Enter to continue..."
        return  # Exit if no route or remote found
    fi

    # Print the extracted route and remote IPs
    echo -e "\033[1;32mFound route IP: $route_ip\033[0m"
    echo -e "\033[1;32mFound remote IP: $remote_ip\033[0m"

    # Try to ping the route IP with 3-second timeout
    echo -e "\033[1;32mPinging route IP: $route_ip...\033[0m"
    if ping -c 4 -W 3 "$route_ip"; then
        echo -e "\033[1;32mPing to route IP successful.\033[0m"
    else
        echo -e "\033[1;31mPing to route IP timed out or failed.\033[0m"
    fi

    # Try to ping the remote IP with 3-second timeout
    echo -e "\033[1;32mPinging remote IP: $remote_ip...\033[0m"
    if ping -c 4 -W 3 "$remote_ip"; then
        echo -e "\033[1;32mPing to remote IP successful.\033[0m"
    else
        echo -e "\033[1;31mPing to remote IP timed out or failed.\033[0m"
    fi

    # Prompt to continue
    read -p "Press Enter to continue..."
    return
    ;;

        *)
            echo -e "${RED}Invalid option...${RESET}"
            read -p "Press Enter to continue..."
            ;;
    esac
}

# Function to stop all vxlan tunnel services
stop_all_vxlan_tunnels() {
    echo -e "${GREEN}Stopping all vxlan tunnel services...${RESET}"
    local stopped_any=false

    # Loop through directories to find vxlan tunnel services
    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/vxlan-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${GREEN}Stopping $service_name...${RESET}"
                systemctl stop "$service_name"
                # Reload systemd to apply the changes
                sudo systemctl daemon-reload
                stopped_any=true
            fi
        done
    done

    if [[ $stopped_any == false ]]; then
        echo -e "${RED}No active vxlan tunnel services found to stop.${RESET}"
        return 1
    fi

    echo -e "${GREEN}All vxlan tunnel services have been stopped.${RESET}"
    read -p  "Press Enter to continue..."
}

# Function to enable and start all vxlan tunnel services
enable_and_start_vxlan_tunnels() {
    echo -e "${GREEN}Enabling and starting all vxlan tunnel services...${RESET}"
    local started_any=false

    # Loop through directories to find vxlan tunnel services
    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/vxlan-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${GREEN}Enabling and starting $service_name...${RESET}"
                systemctl enable "$service_name"
                systemctl start "$service_name"
                # Reload systemd to apply the changes
                sudo systemctl daemon-reload
                started_any=true
            fi
        done
    done

    if [[ $started_any == false ]]; then
        echo -e "${RED}No vxlan tunnel services found to enable or start.${RESET}"
        return 1
    fi

    echo -e "${GREEN}All vxlan tunnel services have been enabled and started.${RESET}"
    read -p  "Press Enter to continue..."
}

# Function to enable and start all vxlan tunnel services
restart_vxlan_tunnels() {
    echo -e "${GREEN}Enabling and starting all vxlan tunnel services...${RESET}"
    local started_any=false

    # Loop through directories to find vxlan tunnel services
    for dir in /usr/lib/systemd/system; do
        for file in "$dir"/vxlan-*.service; do
            if [[ -f "$file" ]]; then
                service_name=$(basename "$file" .service)
                echo -e "${GREEN}Enabling and starting $service_name...${RESET}"
                systemctl restart "$service_name"
                # Reload systemd to apply the changes
                sudo systemctl daemon-reload
                started_any=true
            fi
        done
    done

    if [[ $started_any == false ]]; then
        echo -e "${RED}No vxlan tunnel services found to enable or start.${RESET}"
        return 1
    fi

    echo -e "${GREEN}All vxlan tunnel services have been enabled and started.${RESET}"
    read -p  "Press Enter to continue..."
}



# Function to back up files and directories
backup_files_and_dirs() {
  #!/bin/bash

# File paths and directories to back up
FILES=("/etc/x-ui/x-ui.db" "/var/spool/cron/crontabs/root" "/root/auto_vxlan_update.sh")
DIRS=("/root/vxlan")  # Directories to back up
SERVICE_FILES="/usr/lib/systemd/system/vxlan-*.service"  # Systemd service files for tunnels

# Define colors
GREEN="\033[1;32m"
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
    echo -e "${GREEN}zip has been successfully installed.${RESET}"
  else
    echo -e "${RED}Error:${RESET} Failed to install zip. Please check your system settings." >&2
    exit 1
  fi
else
  echo -e "${GREEN}zip is already installed.${RESET}"
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
  echo -e "${GREEN}Success:${RESET} Local ZIP archive created at $ZIP_FILE."
else
  echo -e "${RED}Error:${RESET} Failed to create local ZIP archive." >&2
fi
  read -p  "Press Enter to continue..."
}


transfer-vxlan() {
#!/bin/bash
# Define colors
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"
BOLD="\033[1m"
UNDERLINE="\033[4m"
# File paths and credentials
FILES=("/etc/x-ui/x-ui.db" "/var/spool/cron/crontabs/root" "/root/auto_vxlan_update.sh" "/root/6to4-service-method.sh")
DIRS=("/root/vxlan")  # Directories to transfer
SERVICE_FILES="/usr/lib/systemd/system/vxlan-*.service"

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
echo -e "\n${GREEN}${BOLD}Credentials Summary:${RESET}"
echo -e "${YELLOW}Remote User:${RESET} ${REMOTE_USER}"
echo -e "${YELLOW}Remote Host:${RESET} ${REMOTE_HOST}"
echo -e "${YELLOW}Remote Port:${RESET} ${REMOTE_PORT}"
echo -e "${YELLOW}Remote PASSWORD:${RESET} ${ROOT_PASSWORD}"
# Ask if the credentials are correct
while true; do
  read -p "Are these credentials correct? (yes/no, default 'yes'):" CONFIRMATION
  CONFIRMATION=${CONFIRMATION:-yes}  # Default to 'yes' if no input is given
  
  if [[ "$CONFIRMATION" == "yes" || "$CONFIRMATION" == "y" ]]; then
    echo -e "${GREEN}Credentials confirmed! Proceeding...${RESET}"
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
    echo -e "\n${GREEN}${BOLD}New Credentials Summary:${RESET}"
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
    echo -e "${GREEN}zip has been successfully installed.${RESET}"
  else
    echo -e "${RED}Error:${RESET} Failed to install zip. Please check your system settings." >&2
    exit 1
  fi
else
  echo -e "${GREEN}zip is already installed.${RESET}"
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
    echo -e "${GREEN}sshpass has been successfully installed.${RESET}"
  else
    echo -e "${RED}Error:${RESET} Failed to install sshpass. Please check your system settings." >&2
    exit 1
  fi
else
  echo -e "${GREEN}sshpass is already installed.${RESET}"
fi

# Verify SSH connection
if sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit; then
  echo -e "${GREEN}SSH connection to $REMOTE_USER@$REMOTE_HOST successful.${RESET}"
else
  echo -e "${RED}Error:${RESET} Failed to connect to $REMOTE_USER@$REMOTE_HOST via SSH." >&2
  exit 1
fi

# Declare an associative array for file-path mappings
declare -A FILE_PATHS=(
  ["/root/auto_vxlan_update.sh"]="/root"
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
      echo -e "${GREEN}Success:${RESET} File $FILE_PATH successfully sent to $REMOTE_USER@$REMOTE_HOST:$DEST_DIR/$FILE_NAME"
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
      echo -e "${GREEN}Success:${RESET} Directory $DIR_PATH successfully sent to $REMOTE_USER@$REMOTE_HOST:$DEST_DIR/"
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
  echo -e "${GREEN}Success:${RESET} Local ZIP archive created at $ZIP_FILE."
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
echo -e "      \033[1;32mvxlan tunnel Service Method\033[0m"
echo -e "\033[1;34m=========================================\033[0m"
echo -e "\033[1;36m 1.\033[0m \033[1;32mCreate vxlan tunnel\033[0m"
echo -e "\033[1;36m 2.\033[0m \033[1;32mManage vxlan tunnels\033[0m"
echo -e "\033[1;36m 3.\033[0m \033[1;32mStart all vxlan tunnels\033[0m"
echo -e "\033[1;36m 4.\033[0m \033[1;32mStop all vxlan tunnels\033[0m"
echo -e "\033[1;36m 5.\033[0m \033[1;32mRestart all vxlan tunnels\033[0m"
echo -e "\033[1;36m 0.\033[0m \033[1;31mExit\033[0m"
echo -e "\n\033[1;34m=========================================\033[0m"
echo -e "\033[1;32mEnter your choice: \033[0m"

    read -p "Choice: " option

    case $option in
        1)
            create_vxlan_tunnel
            ;;
        2)
            manage_tunnels 
            ;;
        3)
            enable_and_start_vxlan_tunnels 
            ;;
        4)
            stop_all_vxlan_tunnels
            ;;
            
        5)
            restart_vxlan_tunnels
            ;;
        6)
            backup_files_and_dirs
            ;;
        7)
           transfer-vxlan
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
