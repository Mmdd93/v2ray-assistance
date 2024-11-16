#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW="\033[1;33m"
RESET='\033[0m'

# Function to generate a random name for the service between 1 and 100
generate_random_name() {
    echo "sit-$(shuf -i 1-100 -n 1)"
}


# Function to get the local machine's IP address (IPv4)
get_local_ip() {
    echo $(hostname -I | awk '{print $1}')
}

# Function to generate a random IPv6 address
generate_random_ipv6() {
    # Generate 4 random 16-bit hexadecimal blocks for the IPv6 address
    local block1=$(printf '%x' $((RANDOM % 65536)))  # Random 16-bit
    local block2=$(printf '%x' $((RANDOM % 65536)))  # Random 16-bit

    # Generate a random IPv6 address in the format: 2001:db8:1::[random blocks]/64
    echo "2001:db8:1::${block2}/64"
}



# Function to create multiple SIT tunnels
create_multi_tunnel() {
   # Ask for the service name, but provide a default random name if no input is given
echo -e "${GREEN}Enter a service name (press Enter for a random name):${RESET}"
read -r service_name

# If no input is given, use the default random name
if [[ -z "$service_name" ]]; then
    service_name=$(generate_random_name)
    echo -e "${GREEN}No name provided. Using random service name: $service_name${RESET}"
fi

# Ensure the service name has the required prefix
if [[ ! "$service_name" =~ ^sit-tunnel- ]]; then
    service_name="sit-$service_name"
    echo -e "${GREEN}Service name doesn't have the required prefix. Adding prefix: $service_name${RESET}"
fi

echo -e "${GREEN}Using service name: $service_name${RESET}"

# Check if the service already exists
local service_file="/usr/lib/systemd/system/$service_name.service"
if [[ -f "$service_file" ]]; then
    echo -e "${RED}A service with this name already exists. Please choose a different name.${RESET}"
    return
fi


    # Ask how many tunnels to create with a default value of 1
    echo -e "${GREEN}How many SIT tunnels do you want to create? (default: 1):${RESET}"
    read -r tunnel_count

    # Set the default tunnel count if the user doesn't provide one
    tunnel_count="${tunnel_count:-1}"

    # Validate if the input is a positive number
    if ! [[ "$tunnel_count" =~ ^[0-9]+$ ]] || [ "$tunnel_count" -le 0 ]; then
        echo -e "${RED}Invalid input. Please enter a positive number.${RESET}"
        return
    fi

    # Get the default local IP (e.g., from the first network interface)
    local local_ip=$(get_local_ip)
    if [[ -z "$local_ip" ]]; then
        echo -e "${RED}No local IP address found. Exiting...${RESET}"
        return
    fi

    declare -a LOCAL_IPS
    declare -a IPV6_ADDRESSES
    declare -a REMOTE_IPS

    echo -e "${GREEN}Enter details for tunnel $tunnel_count.${RESET}"

    for ((i = 1; i <= tunnel_count; i++)); do
        echo -e "${GREEN}Tunnel $i:${RESET}"

        # Ask for the local IP for each tunnel
        echo -e "Ente local IP ${YELLOW}(Default $local_ip )${RESET}:"
        read -r user_local_ip
        local_ip=${user_local_ip:-$local_ip}

        # Generate a random IPv6 address for each tunnel by default
        local ipv6_address=$(generate_random_ipv6)

        # Prompt for custom IPv6 address
        echo -e "${YELLOW}Default IPv6 address: $ipv6_address  ${RESET}"
        echo -e "${GREEN}Enter a custom IPv6 address? (leave empty for $ipv6_address):${RESET}"
        read -r user_ipv6_address

        # Use the custom IPv6 address if provided, otherwise use the generated one
        ipv6_address=${user_ipv6_address:-$ipv6_address}

        echo -e "  Using IPv6 address: $ipv6_address"

        # Ask for the remote IP for each tunnel
        echo -e "${YELLOW}Enter the remote IP for tunnel $i:${RESET}"
        read -r remote_ip

        # Validate if the remote IP is a valid IP address format
if ! [[ "$remote_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Invalid remote IP address format. Please enter a valid IPv4 address.${RESET}"
    return
fi
 

        LOCAL_IPS+=("$local_ip")
        IPV6_ADDRESSES+=("$ipv6_address")
        REMOTE_IPS+=("$remote_ip")
    done

    # Generate systemd service files for each tunnel
    for ((i = 0; i < tunnel_count; i++)); do
        local local_ip="${LOCAL_IPS[$i]}"
        local ipv6_address="${IPV6_ADDRESSES[$i]}"
        local remote_ip="${REMOTE_IPS[$i]}"
        local tunnel_service="${service_name}"

        echo -e "${GREEN}Creating systemd service file for $tunnel_service...${RESET}"

       # Generate the service file content
cat <<EOF > "/usr/lib/systemd/system/$tunnel_service.service"
[Unit]
Description=SIT Tunnel $tunnel_service
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/env sh -c '\
    /sbin/ip tunnel add $tunnel_service mode sit local $local_ip remote $remote_ip && \
    /sbin/ip link set $tunnel_service up && \
    /sbin/ip addr add $ipv6_address dev $tunnel_service'
ExecStop=/sbin/ip tunnel del $tunnel_service
Restart=always
RestartSec=10
TimeoutSec=600

[Install]
WantedBy=multi-user.target
EOF


        # Reload systemd and enable the service
        sudo systemctl daemon-reload
        sudo systemctl enable "$tunnel_service"
        sudo systemctl start "$tunnel_service"

        echo -e "${GREEN}Tunnel $tunnel_service created.${RESET}"
        read -p "Press Enter to continue..."

    done
     
}


manage_tunnels() {
    # List all available SIT tunnel services
    echo -e "${GREEN}Available SIT tunnels:${RESET}"
    local tunnels=()

    # Get all active SIT tunnel services from both directories
    for dir in  /usr/lib/systemd/system; do
        for file in "$dir"/sit-*.service; do
            if [[ -f "$file" ]]; then
                tunnels+=("$(basename "$file" .service)")
            fi
        done
    done

    if [[ ${#tunnels[@]} -eq 0 ]]; then
        echo -e "${RED}No active SIT tunnels found.${RESET}"
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
    
    # Prompt for the next action on the selected tunnel
    echo -e "${GREEN}Select an action to perform on tunnel $selected_tunnel:${RESET}"
    echo "1. Start tunnel"
    echo "2. Stop tunnel"
    echo "3. Restart tunnel"
    echo "4. Enable at boot"
    echo "5. Disable at boot"
    echo "6. Check status"
    echo "7. Remove tunnel"
    echo "8. Edit with nano"
    echo "0. Return to main menu"
    read -p "Choose an option [0-8]: " action

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
            ;;
        2)
            # Stop the selected tunnel
            sudo systemctl stop "$selected_tunnel.service"
            echo -e "${GREEN}Tunnel $selected_tunnel stopped.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        3)
            # Restart the selected tunnel
            sudo systemctl restart "$selected_tunnel.service"
            echo -e "${GREEN}Tunnel $selected_tunnel restarted.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        4)
            # Enable the selected tunnel at boot
            sudo systemctl enable "$selected_tunnel.service"
            echo -e "${GREEN}Tunnel $selected_tunnel enabled at boot.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        5)
            # Disable the selected tunnel at boot
            sudo systemctl disable "$selected_tunnel.service"
            echo -e "${GREEN}Tunnel $selected_tunnel disabled at boot.${RESET}"
            read -p "Press Enter to continue..."
            ;;
        6)
            # Check the status of the selected tunnel
            sudo systemctl status "$selected_tunnel.service"
            read -p "Press Enter to continue..."
            ;;
        7)
            # Remove the selected tunnel
            sudo systemctl stop "$selected_tunnel.service"
            sudo systemctl disable "$selected_tunnel.service"
            sudo rm "/usr/lib/systemd/system/$selected_tunnel.service" "/usr/lib/systemd/system/$selected_tunnel.service"
            echo -e "${GREEN}Tunnel $selected_tunnel removed.${RESET}"
            read -p "Press Enter to continue..."
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
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${RESET}"
            ;;
    esac
}



# Main menu
while true; do
    # Clear the screen for a clean look each time
    clear

    # Main menu with some styling

    echo -e "\033[1;32mSIT tunnel service method\033[0m"


    # Option 1
    echo -e "\033[1;33m1.\033[0m \033[1;36mCreate multiple SIT tunnels\033[0m"
    
    # Option 2
    echo -e "\033[1;33m2.\033[0m \033[1;36mManage SIT tunnels\033[0m"
    
    # Option 0
    echo -e "\033[1;33m0.\033[0m \033[1;31mExit\033[0m"

    # Prompt for user input
    echo -e "\n\033[1;32mPlease select an option [1-3]: \033[0m"
    read -p "Choice: " option

    case $option in
        1) 
            # Create multiple SIT tunnels

            create_multi_tunnel 
            ;;
        2) 
            # Manage SIT tunnels

            manage_tunnels 
            ;;
        0) 
            # Exit
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
