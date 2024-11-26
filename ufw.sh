#!/bin/bash
# Function to list used ports with color-coded visibility
used_ports() {

    echo -e "\n\033[1;33mListening Ports:\033[0m"

    echo  ""
    sudo lsof -i -P -n | grep LISTEN | awk '
    BEGIN {
        printf "\033[1;32m%-15s %-10s %-10s %-10s %-20s\033[0m\n", "COMMAND", "PID", "USER", "PORT", "IP"
        printf "\033[1;36m---------------------------------------------------------------\033[0m\n"
    }
    {
        split($9, address, ":");
        ip = address[1];
        port = address[2];
        
        # Alternate colors for each row
        if (NR % 2 == 0)
            printf "\033[1;37m%-15s %-10s %-10s %-10s %-20s\033[0m\n", $1, $2, $3, port, ip;
        else
            printf "\033[1;34m%-15s %-10s %-10s %-10s %-20s\033[0m\n", $1, $2, $3, port, ip;
    }'
    
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\nPress Enter to return..."
    read
}
install_ufw() {
    echo -e "\033[1;34mChecking if UFW is installed...\033[0m"
    if ! command -v ufw >/dev/null 2>&1; then
        echo -e "\033[1;33mUFW is not installed. Installing now...\033[0m"
        sudo apt install -y ufw
        if [ $? -eq 0 ]; then
            echo -e "\033[1;32mUFW successfully installed.\033[0m"
	    return_to_menu
        else
            echo -e "\033[1;31mFailed to install UFW. Please check your system and try again.\033[0m"
            return_to_menu
        fi
    else
        echo -e "\033[1;32mUFW is already installed.\033[0m"
	read -p "Enter to continue... "
    fi
}

find_and_allow_ports() {
    # Display used ports
    echo -e "\033[1;34mFinding all used ports...\033[0m"
    used_ports=$(sudo lsof -i -P -n | grep LISTEN | awk '{print $9}' | awk -F ':' '{print $NF}' | sort -u)

    if [ -z "$used_ports" ]; then
        echo -e "\033[1;31mNo used ports found.\033[0m"
	return_to_menu
        
    fi

    # Convert ports to an indexed array
    ports_array=($used_ports)

    echo -e "\033[1;32mUsed Ports Found:\033[0m"
    for i in "${!ports_array[@]}"; do
        echo -e "\033[1;33m$((i+1)).\033[0m ${ports_array[i]}"
    done

    # Prompt for action
    echo -e "\033[1;33mHow would you like to proceed?\033[0m"
    echo -e "\033[1;32m1.\033[0m Allow all ports"
    echo -e "\033[1;33m2.\033[0m Select ports to allowing"
    echo -e "\033[1;34m0.\033[0m return"
    read -r action

    case "$action" in
        1)
            echo -e "\033[1;32mAllowing all ports on UFW...\033[0m"
            for port in "${ports_array[@]}"; do
                sudo ufw allow "$port"
            done
            ;;
        0)
            echo -e "\033[1;31mReturn\033[0m"
	    return_to_menu
            
            ;;
        2)
            echo -e "\033[1;34mEnter the numbers of the ports(separate with commas, e.g., 1,3,5).\033[0m"
            echo -e "\033[1;34m[ENTER blank to return...]\033[0m"
            read -r selected_numbers

            if [ -z "$selected_numbers" ]; then
                echo -e "\033[1;31mNo ports selected. Exiting.\033[0m"
		return_to_menu
            fi

            # Split input into an array using ',' as a delimiter
            IFS=',' read -ra selected_array <<< "$selected_numbers"

            for num in "${selected_array[@]}"; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#ports_array[@]}" ]; then
                    port="${ports_array[$((num-1))]}"
                    echo -e "\033[1;33mAllowing port $port on UFW...\033[0m"
                    sudo ufw allow "$port"
		    
                else
                    echo -e "\033[1;31mInvalid selection: $num. Skipping.\033[0m"
		    return_to_menu
                fi
		
            done
            ;;
        *)
            echo -e "\033[1;31mInvalid option.\033[0m"
	    return_to_menu
            ;;
    esac

    # Reload UFW to apply changes
    echo -e "\033[1;34mReloading UFW to apply changes...\033[0m"
    sudo ufw reload
    echo -e "\033[1;32mUFW configuration updated.\033[0m"
    return_to_menu
}


# UFW Operations
enable_ufw() {
    sudo ufw enable
    echo -e "\033[0;32mUFW has been enabled.\033[0m"
    
    return_to_menu
}

disable_ufw() {
    sudo ufw disable
    echo -e "\033[0;31mUFW has been disabled.\033[0m"
    
    return_to_menu
}
deny_ip() {
    read -p "Enter the IP address(es) to deny (comma-separated, e.g., 192.168.1.1,10.0.0.2): " ips
    IFS=',' read -ra IPS <<< "$ips"
    for ip in "${IPS[@]}"; do
        sudo ufw deny from "$ip"
        echo -e "\033[0;31mDenied IP $ip.\033[0m"
    done
    return_to_menu
}
allow_ip() {
    read -p "Enter the IP address(es) to allow (comma-separated, e.g., 192.168.1.1,10.0.0.2): " ips
    IFS=',' read -ra IPS <<< "$ips"
    for ip in "${IPS[@]}"; do
        sudo ufw allow from "$ip"
        echo -e "\033[0;32mAllowed IP $ip.\033[0m"
    done
    return_to_menu
}

allow_ports() {
    read -p "Enter the port numbers to allow (comma-separated, e.g., 80,443,2052): " ports
    IFS=',' read -ra PORTS <<< "$ports"
    for port in "${PORTS[@]}"; do
        sudo ufw allow "$port"
        echo -e "\033[0;32mAllowed port $port.\033[0m"
    done
    return_to_menu
}

deny_ports() {
    read -p "Enter the port numbers to deny (comma-separated, e.g., 80,443,2052): " ports
    IFS=',' read -ra PORTS <<< "$ports"
    for port in "${PORTS[@]}"; do
        sudo ufw deny "$port"
        echo -e "\033[0;31mDenied port $port.\033[0m"
    done
    return_to_menu
}

allow_services() {
    read -p "Enter the service names to allow (comma-separated, e.g., ssh,http,https): " services
    IFS=',' read -ra SERVICES <<< "$services"
    for service in "${SERVICES[@]}"; do
        sudo ufw allow "$service"
        echo -e "\033[0;32mAllowed service $service.\033[0m"
    done
    return_to_menu
}

deny_services() {
    read -p "Enter the service names to deny (comma-separated, e.g., ssh,http,https): " services
    IFS=',' read -ra SERVICES <<< "$services"
    for service in "${SERVICES[@]}"; do
        sudo ufw deny "$service"
        echo -e "\033[0;31mDenied service $service.\033[0m"
    done
    return_to_menu
}

# Updated delete_rule function with option 0 to delete all rules
delete_rule() {
    echo -e "\033[1;36mCurrent UFW rules:\033[0m"
    sudo ufw status numbered  # Show numbered rules for easy selection

    echo -e "\033[1;33mEnter the rule numbers to delete (comma-separated, e.g., 1,3,5) or\033[0m"
    echo -e "\033[1;31mEnter 0 to delete all rules and reset UFW:\033[0m"
    
    read -p "$(echo -e "\033[1;33mYour choice: \033[0m")" rule_numbers

    if [[ $rule_numbers == 0 ]]; then
        # Delete all rules by resetting UFW
        sudo ufw reset
        echo -e "\033[0;31mAll UFW rules have been deleted, and UFW has been reset to defaults.\033[0m"
    else
        # Delete specific rules
        IFS=',' read -ra RULES <<< "$rule_numbers"  # Split input by comma
        for rule_number in "${RULES[@]}"; do
            # Check if each entry is a valid number
            if [[ $rule_number =~ ^[0-9]+$ ]]; then
                sudo ufw delete "$rule_number"
                echo -e "\033[0;32mDeleted rule number $rule_number.\033[0m"
            else
                echo -e "\033[0;31mInvalid input. Please enter valid rule numbers.\033[0m"
            fi
        done
    fi

    return_to_menu
}




view_status() {
    echo -e "\033[1;36mUFW Status:\033[0m"
    sudo ufw status verbose
    return_to_menu
}

show_rules() {
    echo -e "\033[1;36mUFW Rules:\033[0m"
    sudo ufw status numbered
    return_to_menu
}

reload_ufw() {
    sudo ufw reload
    echo -e "\033[0;32mUFW has been reloaded.\033[0m"
    return_to_menu
}

set_default_incoming() {
    echo -e "\n\033[1;36m1. Allow\033[0m"
    echo -e "\033[1;36m2. Deny\033[0m"
    read -p "$(echo -e "\033[1;33mChoose default incoming policy [1- Allow, 2- Deny]: \033[0m")" choice
    case $choice in
        1) sudo ufw default allow incoming && echo -e "\033[0;32mSet default incoming policy to Allow.\033[0m" ;;
        2) sudo ufw default deny incoming && echo -e "\033[0;31mSet default incoming policy to Deny.\033[0m" ;;
        *) echo -e "\033[0;31mInvalid option.\033[0m" ;;
    esac
    return_to_menu
}

set_default_outgoing() {
    echo -e "\n\033[1;36m1. Allow\033[0m"
    echo -e "\033[1;36m2. Deny\033[0m"
    read -p "$(echo -e "\033[1;33mChoose default outgoing policy [1- Allow, 2- Deny]: \033[0m")" choice
    case $choice in
        1) sudo ufw default allow outgoing && echo -e "\033[0;32mSet default outgoing policy to Allow.\033[0m" ;;
        2) sudo ufw default deny outgoing && echo -e "\033[0;31mSet default outgoing policy to Deny.\033[0m" ;;
        *) echo -e "\033[0;31mInvalid option.\033[0m" ;;
    esac
    return_to_menu
}

reset_ufw() {
    sudo ufw reset
    echo -e "\033[1;33mUFW has been reset to its default state.\033[0m"
    return_to_menu
}

return_to_menu() {
    read -p "Enter to continue... "
    ufw_menu  # Call the main menu function to return
}

ufw_menu() {
    while true; do
        clear
        echo -e "\n\033[1;36m================= UFW MENU ===================\033[0m"
        echo -e "\033[15;32m 15. \033[0m Install UFW"
        echo -e "\033[1;32m  1. \033[0m Enable UFW"
        echo -e "\033[1;32m  2. \033[0m Disable UFW"
        echo -e "\033[1;32m  3. \033[0m Allow ports"
        echo -e "\033[1;32m  4. \033[0m Deny ports"
        echo -e "\033[1;32m  5. \033[0m Allow services"
        echo -e "\033[1;32m  6. \033[0m Deny services"
        echo -e "\033[1;32m  7. \033[0m Delete a rule"
        echo -e "\033[1;32m  8. \033[0m View UFW status"
        echo -e "\033[1;32m  9. \033[0m View UFW rules"
        echo -e "\033[1;32m 10. \033[0m Reload UFW"
        echo -e "\033[1;32m 11. \033[0m Set default incoming policy"
        echo -e "\033[1;32m 12. \033[0m Set default outgoing policy"
        echo -e "\033[1;32m 13. \033[0m Reset UFW to defaults"
        echo -e "\033[1;32m 14. \033[0m Allow in-use ports"
        echo -e "\033[1;32m 16. \033[0m View in-use ports"
        echo -e "\033[1;32m 17. \033[0m Allow ip"
        echo -e "\033[1;32m 18. \033[0m Deny ip"
        echo -e "\033[1;32m 0. \033[0m Return to main menu"
        echo -e "\033[1;36m===============================================\033[0m"
        echo -n "Select an option : "
        
        read ufw_option
        case $ufw_option in
            1) enable_ufw ;;
            2) disable_ufw ;;
            3) allow_ports ;;
            4) deny_ports ;;
            5) allow_services ;;
            6) deny_services ;;
            7) delete_rule ;;
            8) view_status ;;
            9) show_rules ;;
            10) reload_ufw ;;
            11) set_default_incoming ;;
            12) set_default_outgoing ;;
            13) reset_ufw ;;
            14) find_and_allow_ports ;;
            15) install_ufw ;;
            16) used_ports ;;
            17) allow_ip ;;
            18) deny_ip ;;
            0) exit ;;  # Return to main menu
            *) echo -e "\033[0;31mInvalid option. Please select between 0-18.\033[0m"
	    return_to_menu ;;
        esac
    done
}

# Call the ufw_menu function to display the menu
ufw_menu
