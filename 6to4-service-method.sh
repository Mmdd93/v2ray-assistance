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
    # Define 20 IPv6 address templates with a simplified display format
    local templates=( 
        "2001:db8:1::%x/64"
        "2001:db8:2::%x/64"
        "2001:db8:3::%x/64"
        "2001:db8:4::%x/64"
        "2001:db8:5::%x/64"
        "2001:db8:6::%x/64"
        "2001:db8:7::%x/64"
        "2001:db8:8::%x/64"
        "2001:db8:9::%x/64"
        "2001:db8:10::%x/64"
        "2001:db8:11::%x/64"
        "2001:db8:12::%x/64"
        "2001:db8:13::%x/64"
        "2001:db8:14::%x/64"
        "2001:db8:15::%x/64"
        "2001:db8:16::%x/64"
        "2001:db8:17::%x/64"
        "2001:db8:18::%x/64"
        "2001:db8:19::%x/64"
        "2001:db8:20::%x/64"
    )

    # Display available templates in simplified format
    #echo -e "\033[1;33mAvailable IPv6 templates:\033[0m"
    #for i in "${!templates[@]}"; do
        # Display only the prefix (first part) of the template, like "2001:db8:8"
        #local template_prefix=$(echo "${templates[$i]}" | cut -d':' -f1-4)
        #echo -e "\033[1;32mTemplate $((i + 1)):\033[0m $template_prefix"
    #done

    # Prompt the user to select a template or enter a custom one
local template_number
echo -e "\033[1;34mSelect a template or enter a custom one:\033[0m"
echo -e "\033[1;32m1. \033[0mSelect template"
echo -e "\033[1;32m2. \033[0mEnter custom template"
read -r choice

if [[ "$choice" == "1" ]]; then
    # Display available templates
    echo -e "\033[1;34mAvailable templates:\033[0m"
    for i in "${!templates[@]}"; do
        echo -e "\033[1;33m$((i + 1)). ${templates[i]}\033[0m"
    done

    # Prompt the user to select a template
    echo -e "\033[1;34mEnter a template number (default is 1):\033[0m"
    read -r template_number
    # Default to template 1 if no input
    template_number=${template_number:-1}

    # Validate the user's selection
    if [[ ! "$template_number" =~ ^[1-9]$|^1[0-9]$|^20$ ]]; then
        echo -e "\033[1;31mInvalid input. Please select a number between 1 and 20.\033[0m"
        return
    fi

    # Adjust template number to zero-based index
    local selected_template="${templates[$((template_number - 1))]}"
    echo -e "\033[1;31mUsing template: $selected_template\033[0m"

elif [[ "$choice" == "2" ]]; then
    # Prompt the user to enter a custom IPv6 template
    echo -e "\033[1;34mEnter your custom IPv6 template (e.g., 2001:db8:21::21/64):\033[0m"
    read -r custom_template

    # Validate the custom template format
    if [[ ! "$custom_template" =~ ^([0-9a-fA-F]{1,4}:){2,7}[0-9a-fA-F]{1,4}(/[0-9]{1,3})$ ]]; then
        echo -e "\033[1;31mInvalid custom template format. Please enter a valid IPv6 prefix (e.g., 2001:db8:21::21/64).\033[0m"
        return
    fi

    # Extract the IPv6 address and prefix length
    local ipv6_address=$(echo "$custom_template" | cut -d'/' -f1)
    local prefix_length=$(echo "$custom_template" | cut -d'/' -f2)

    # Validate the prefix length (should be between 1 and 128)
    if ((prefix_length < 1 || prefix_length > 128)); then
        echo -e "\033[1;31mInvalid prefix length. It must be between 1 and 128.\033[0m"
        return
    fi

    # Assign the custom template
    local selected_template="$custom_template"
    echo -e "\033[1;32mUsing custom IPv6 template: $selected_template\033[0m"

else
    echo -e "\033[1;31mInvalid option. Please choose 1 or 2.\033[0m"
    return
fi

# Extract the prefix from the selected template (e.g., "2001:db8:1::")
local template_prefix=$(echo "$selected_template" | cut -d':' -f1-4)

echo -e "\033[1;32mTemplate prefix extracted: $template_prefix\033[0m"
read -p "Press Enter to continue..."


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
    echo -e "\033[1;32mEnter a custom IPv6 address (default:$ipv6_address ):\033[0m"
    read -r user_ipv6_address

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
    read -r user_local_ip
    local_ip=${user_local_ip:-$local_ip}

    # Use the function to generate or select a custom IPv6 address
    echo -e "${GREEN}Configuring the IPv6 address for the tunnel.${RESET}"
    generate_random_ipv6  # This function handles template selection and custom input
    local ipv6_address=$ipv6_address  # Generated or chosen IPv6 address is set globally in the function

    # Ask for the remote IP for the tunnel
    echo -e "${GREEN}Enter the remote IP for the tunnel:${RESET}"
    read -r remote_ip

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
