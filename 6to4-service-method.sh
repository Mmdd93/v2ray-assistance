#!/bin/bash

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW="\033[1;33m"
RESET='\033[0m'


    # Remove /root/ipv6.txt if it exists
    if [ -f /root/ipv6.txt ]; then
        rm /root/ipv6.txt
        echo -e "\033[1;33mExisting /root/ipv6.txt file removed.\033[0m"
    fi

# Function to generate a random name for the service between 1 and 100
generate_random_name() {
    echo "$(shuf -i 1-100 -n 1)"
}


# Function to get the local machine's IP address (IPv4)
get_local_ip() {
    echo $(hostname -I | awk '{print $1}')
}
generate_random_ipv6() {
     # Define 100 IPv6 address templates (hidden from display)
    local templates=()
    for i in {1..100}; do
        templates+=("2001:db8:$i::%x/64")
    done
    # Prompt the user to select a template
    echo -e "\033[1;34mSelect an IPv6 template number (1-100):\033[0m"
    local template_number
    read -p " > " template_number
    echo -e "\033[1;31mUse template number [$template_number] on the remote server as well.\033[0m"

    # If the user doesn't provide any input, default to template number 1
    template_number=${template_number:-1}
    # Validate the user's selection
    if [[ ! "$template_number" =~ ^[1-9]$|^[1-9][0-9]$|^100$ ]]; then
        echo -e "\033[1;31mInvalid input. Please select a number between 1 and 100.\033[0m"
        return
    fi
    
    read -p  "Press Enter to continue..."

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
    echo -e "\033[1;33mDefault IPv6 address:\033[0m $ipv6_address"
    echo -e "\033[1;32mEnter a custom IPv6 address [enter to use default:$ipv6_address]\033[0m"
    read -p " > " user_ipv6_address

    # Use the custom IPv6 address if provided, otherwise use the generated one
    ipv6_address=${user_ipv6_address:-$ipv6_address}

    # Display the final IPv6 address
    echo -e "\033[1;32mUsing IPv6 address:\033[0m $ipv6_address"

    # Save the generated or custom IPv6 address to a text file
    echo "ipv6=$ipv6_address" > /root/ipv6.txt
    echo -e "\033[1;33mIPv6 address saved to ipv6.txt\033[0m"
    sleep 3
    echo -e "\033[1;34mReading from /root/ipv6.txt...\033[0m"
    source /root/ipv6.txt
    echo -e "\033[1;32mIPv6 address read from file:\033[0m $ipv6"
}


# Function to create a SIT tunnel
create_sit_tunnel() {


     # Generate a default random name
    local default_name=$(generate_random_name)

    # Ask for the service name, but provide a default random name if no input is given
    read -p "$(echo -e "${GREEN}Enter a service name (default: ${default_name}): ${RESET}")" service_name

    # If no input is given, use the default random name
    if [[ -z "$service_name" ]]; then
        service_name="$default_name"  # Use the default name
        echo -e "${GREEN}No name provided. Using random service name: $service_name${RESET}"
    fi

    # Ensure the service name has the required prefix
    if [[ ! "$service_name" =~ ^sit-tunnel- ]]; then
        service_name="sit-$service_name"
        
    fi

    echo -e "${GREEN}Using service name: $service_name${RESET}"

    # Check if the service already exists
    local service_file="/usr/lib/systemd/system/$service_name.service"
    if [[ -f "$service_file" ]]; then
        echo -e "${RED}A service with this name already exists. Please choose a different name.${RESET}"
        return
    fi


    # Get the default local IP (e.g., from the first network interface)
    local local_ip=$(get_local_ip)  # Assuming get_local_ip is defined elsewhere
    if [[ -z "$local_ip" ]]; then
        echo -e "${RED}No local IP address found. Exiting...${RESET}"
        return
    fi

    # Ask for the local IP for the tunnel
    echo -e "${GREEN}Enter the local IP for the tunnel ${YELLOW}(Default: $local_ip)${RESET}:"
    read -p " > " user_local_ip
    local_ip=${user_local_ip:-$local_ip}

    # Use the function to generate or select a custom IPv6 address
    echo -e "${GREEN}Configuring the IPv6 address for the tunnel.${RESET}"
    generate_random_ipv6  # This function handles template selection and custom input
    local ipv6_address=$ipv6_address  # Generated or chosen IPv6 address is set globally in the function

    # Ask for the remote IP for the tunnel
    echo -e "${GREEN}Enter the remote IP for the tunnel:${RESET}"
    read -p " > " remote_ip

    # Validate if the remote IP is a valid IP address format
    if ! [[ "$remote_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Invalid remote IP address format. Please enter a valid IPv4 address.${RESET}"
        return
    fi

    # Generate the systemd service file
    echo -e "${GREEN}Creating systemd service file for $service_name...${RESET}"
    cat <<EOF > "$service_file"
[Unit]
Description=SIT Tunnel $service_name
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env sh -c '\
    /sbin/ip tunnel add $service_name mode sit local $local_ip remote $remote_ip && \
    /sbin/ip link set $service_name up && \
    /sbin/ip addr add $ipv6 dev $service_name'
ExecStop=/sbin/ip tunnel del $service_name
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable the service
    sudo systemctl daemon-reload
    sudo systemctl enable "$service_name"
    sudo systemctl start "$service_name"

    echo -e "${GREEN}Tunnel $service_name created successfully.${RESET}"
    read -p "Press Enter to continue..."
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
            sudo systemctl daemon-reload
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
    echo -e "\033[1;33m1.\033[0m \033[1;36mCreate  SIT tunnel\033[0m"
    
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

            create_sit_tunnel
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
