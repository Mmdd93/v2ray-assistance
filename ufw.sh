# UFW Operations
#!/bin/bash
# Function to list used ports with color-coded visibility
# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
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
    echo -e "\033[1;34mFinding all used ports...\033[0m"
    used_ports=$(sudo lsof -i -P -n | grep LISTEN | awk '{print $9}' | awk -F ':' '{print $NF}' | sort -u)

    if [ -z "$used_ports" ]; then
        echo -e "\033[1;31mNo used ports found.\033[0m"
        return_to_menu
    fi

    ports_array=($used_ports)

    echo -e "\033[1;32mUsed Ports Found:\033[0m"
    for i in "${!ports_array[@]}"; do
        echo -e "\033[1;33m$((i+1)).\033[0m ${ports_array[i]}"
    done

    echo -e "\033[1;33mHow would you like to proceed?\033[0m"
    echo -e "\033[1;32m1.\033[0m Allow all ports"
    echo -e "\033[1;33m2.\033[0m Select ports to allow"
    echo -e "\033[1;34m0.\033[0m Return"
    read -r action

    case "$action" in
        1)
            echo -e "\033[1;36mSelect direction for ALL ports:\033[0m"
            echo -e "\033[1;32m1.\033[0m Incoming only"
            echo -e "\033[1;33m2.\033[0m Outgoing only"
            echo -e "\033[1;34m3.\033[0m Both directions"
            echo -e "\033[1;31m0.\033[0m Return"
            read -r direction
            
            case "$direction" in
                1) 
                    for port in "${ports_array[@]}"; do
                        sudo ufw allow "$port" comment "In Use Ports"
                    done
                    ;;
                2)
                    for port in "${ports_array[@]}"; do
                        sudo ufw allow out "$port" comment "In Use Ports"
                    done
                    ;;
                3)
                    for port in "${ports_array[@]}"; do
                        sudo ufw allow "$port" comment "In Use Ports"
                        sudo ufw allow out "$port" comment "In Use Ports"
                    done
                    ;;
                0) 
                    echo -e "\033[1;31mReturn\033[0m"
                    return_to_menu
                    ;;
                *) 
                    echo -e "\033[1;31mInvalid choice. Skipping all.\033[0m"
                    ;;
            esac
            ;;
        0)
            echo -e "\033[1;31mReturn\033[0m"
            return_to_menu
            ;;
        2)
            echo -e "\033[1;34mEnter the numbers of the ports (comma-separated, e.g., 1,3,5).\033[0m"
            echo -e "\033[1;34m[ENTER blank to return...]\033[0m"
            read -r selected_numbers

            if [ -z "$selected_numbers" ]; then
                echo -e "\033[1;31mNo ports selected. Exiting.\033[0m"
                return_to_menu
            fi

            echo -e "\033[1;36mSelect direction for selected ports:\033[0m"
            echo -e "\033[1;32m1.\033[0m Incoming only"
            echo -e "\033[1;33m2.\033[0m Outgoing only"
            echo -e "\033[1;34m3.\033[0m Both directions"
            echo -e "\033[1;31m0.\033[0m Return"
            read -r direction

            IFS=',' read -ra selected_array <<< "$selected_numbers"
            for num in "${selected_array[@]}"; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#ports_array[@]}" ]; then
                    port="${ports_array[$((num-1))]}"
                    case "$direction" in
                        1) sudo ufw allow "$port" comment "In Use Ports" ;;
                        2) sudo ufw allow out "$port" comment "In Use Ports" ;;
                        3) 
                            sudo ufw allow "$port" comment "In Use Ports"
                            sudo ufw allow out "$port" comment "In Use Ports"
                            ;;
                        0) 
                            echo -e "\033[1;31mReturn\033[0m"
                            break
                            ;;
                        *) echo -e "\033[1;31mInvalid choice for port $port. Skipping.\033[0m" ;;
                    esac
                else
                    echo -e "\033[1;31mInvalid selection: $num. Skipping.\033[0m"
                fi
            done
            ;;
        *)
            echo -e "\033[1;31mInvalid option.\033[0m"
            return
            ;;
    esac

    echo -e "\033[1;34mReloading UFW to apply changes...\033[0m"
    sudo ufw reload
    echo -e "\033[1;32mUFW configuration updated.\033[0m"
    
}

allow_ports() {
    read -p "Enter the port numbers to allow (comma-separated, e.g., 80,443,53,123): " ports
    
    echo -e "\033[1;36mSelect direction:\033[0m"
    echo -e "\033[1;32m1.\033[0m Incoming only"
    echo -e "\033[1;33m2.\033[0m Outgoing only"
    echo -e "\033[1;34m3.\033[0m Both directions"
    echo -e "\033[1;31m0.\033[0m Return"
    read -r direction

    IFS=',' read -ra PORTS <<< "$ports"
    for port in "${PORTS[@]}"; do
        case "$direction" in
            1) sudo ufw allow "$port" comment "custom allow ports" && echo -e "\033[0;32mAllowed incoming port $port.\033[0m" ;;
            2) sudo ufw allow out "$port" comment "custom allow ports" && echo -e "\033[0;32mAllowed outgoing port $port.\033[0m" ;;
            3) 
                sudo ufw allow "$port" comment "custom allow ports"
                sudo ufw allow out "$port" comment "custom allow ports"
                echo -e "\033[0;32mAllowed both directions for port $port.\033[0m"
                ;;
            0) 
                echo -e "\033[1;31mReturn\033[0m"
                return_to_menu
                ;;
            *) echo -e "\033[0;31mInvalid choice. Skipping port $port.\033[0m" ;;
        esac
    done
    return_to_menu
}

deny_ports() {
    read -p "Enter the port numbers to deny (comma-separated, e.g., 80,443,2052): " ports
    
    echo -e "\033[1;36mSelect direction:\033[0m"
    echo -e "\033[1;32m1.\033[0m Incoming only"
    echo -e "\033[1;33m2.\033[0m Outgoing only"
    echo -e "\033[1;34m3.\033[0m Both directions"
    echo -e "\033[1;31m0.\033[0m Return"
    read -r direction

    IFS=',' read -ra PORTS <<< "$ports"
    for port in "${PORTS[@]}"; do
        case "$direction" in
            1) sudo ufw deny "$port" comment "custom deny ports" && echo -e "\033[0;31mDenied incoming port $port.\033[0m" ;;
            2) sudo ufw deny out "$port" comment "custom deny ports" && echo -e "\033[0;31mDenied outgoing port $port.\033[0m" ;;
            3) 
                sudo ufw deny "$port" comment "custom deny ports"
                sudo ufw deny out "$port" comment "custom deny ports"
                echo -e "\033[0;31mDenied both directions for port $port.\033[0m"
                ;;
            0) 
                echo -e "\033[1;31mReturn\033[0m"
                return_to_menu
                ;;
            *) echo -e "\033[0;31mInvalid choice. Skipping port $port.\033[0m" ;;
        esac
    done
    return_to_menu
}

allow_services() {
    read -p "Enter the service names to allow (comma-separated, e.g., ssh,http,https): " services
    
    echo -e "\033[1;36mSelect direction:\033[0m"
    echo -e "\033[1;32m1.\033[0m Incoming only"
    echo -e "\033[1;33m2.\033[0m Outgoing only"
    echo -e "\033[1;34m3.\033[0m Both directions"
    echo -e "\033[1;31m0.\033[0m Return"
    read -r direction

    IFS=',' read -ra SERVICES <<< "$services"
    for service in "${SERVICES[@]}"; do
        case "$direction" in
            1) sudo ufw allow "$service" comment "custom allow services" && echo -e "\033[0;32mAllowed incoming service $service.\033[0m" ;;
            2) sudo ufw allow out "$service" comment "custom allow services" && echo -e "\033[0;32mAllowed outgoing service $service.\033[0m" ;;
            3) 
                sudo ufw allow "$service" comment "custom allow services"
                sudo ufw allow out "$service" comment "custom allow services"
                echo -e "\033[0;32mAllowed both directions for service $service.\033[0m"
                ;;
            0) 
                echo -e "\033[1;31mReturn\033[0m"
                return_to_menu
                ;;
            *) echo -e "\033[0;31mInvalid choice. Skipping service $service.\033[0m" ;;
        esac
    done
    return_to_menu
}

deny_services() {
    read -p "Enter the service names to deny (comma-separated, e.g., ssh,http,https): " services
    
    echo -e "\033[1;36mSelect direction:\033[0m"
    echo -e "\033[1;32m1.\033[0m Incoming only"
    echo -e "\033[1;33m2.\033[0m Outgoing only"
    echo -e "\033[1;34m3.\033[0m Both directions"
    echo -e "\033[1;31m0.\033[0m Return"
    read -r direction

    IFS=',' read -ra SERVICES <<< "$services"
    for service in "${SERVICES[@]}"; do
        case "$direction" in
            1) sudo ufw deny "$service" comment "custom deny services" && echo -e "\033[0;31mDenied incoming service $service.\033[0m" ;;
            2) sudo ufw deny out "$service" comment "custom deny services" && echo -e "\033[0;31mDenied outgoing service $service.\033[0m" ;;
            3) 
                sudo ufw deny "$service" comment "custom deny services"
                sudo ufw deny out "$service" comment "custom deny services"
                echo -e "\033[0;31mDenied both directions for service $service.\033[0m"
                ;;
            0) 
                echo -e "\033[1;31mReturn\033[0m"
                return_to_menu
                ;;
            *) echo -e "\033[0;31mInvalid choice. Skipping service $service.\033[0m" ;;
        esac
    done
    return_to_menu
}

disable_log() {
    sudo ufw logging off
    echo -e "\033[0;32mUFW logs has been disabled.\033[0m"
    
    return_to_menu
}
enable_ufw() {
    if ! command -v ufw &> /dev/null; then
        apt update
        apt install -y ufw
    fi

    # Check if UFW is active
    ufw_status=$(ufw status | grep "Status:")
    
    # Find SSH port
    ssh_port=$(grep -E "^Port\s+[0-9]+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    if [ -z "$ssh_port" ]; then
        ssh_port=22  # Default SSH port
    fi
    
    clear
    echo "=== UFW Configuration Check ==="
    echo "Detected SSH port: $ssh_port"
    echo "Current UFW status: $ufw_status"
    echo ""
    
    # Ensure SSH port is allowed before enabling UFW
    if ! ufw status | grep -q "Status: active"; then
        echo "UFW is currently inactive."
        
        # Default YES for SSH port
        echo -n "Do you want to allow SSH port $ssh_port before enabling UFW? [Y/n] Default[Y]: "
        read allow_ssh
        allow_ssh=${allow_ssh:-Y}  # Default to Y if empty
        
        if [[ $allow_ssh == [Yy]* ]]; then
            ufw allow $ssh_port/tcp comment "SSH access"
            echo "SSH port $ssh_port has been allowed."
        fi
        
        echo ""
        # Default YES for in-use ports
        echo -n "Do you want to allow other currently in-use ports? [Y/n] Default[Y]: "
        read allow_ports
        allow_ports=${allow_ports:-Y}  # Default to Y if empty
        
        if [[ $allow_ports == [Yy]* ]]; then
            find_and_allow_ports
        fi
        
        echo ""
        # Default YES for enabling UFW
        echo -n "Ready to enable UFW? [Y/n] Default[Y]: "
        read enable_ufw_confirm
        enable_ufw_confirm=${enable_ufw_confirm:-Y}  # Default to Y if empty
        
        if [[ $enable_ufw_confirm == [Yy]* ]]; then
            sudo ufw --force enable
            echo -e "\033[0;32mUFW has been enabled.\033[0m"
        else
            echo -e "\033[0;33mUFW was not enabled.\033[0m"
        fi
    else
        echo "UFW is already active."
        # Check if SSH port is already allowed
        if ! ufw status | grep -q "$ssh_port/tcp"; then
            # Default YES for SSH port
            echo -n "SSH port $ssh_port is not allowed. Do you want to allow it? [Y/n] Default[Y]: "
            read allow_ssh
            allow_ssh=${allow_ssh:-Y}  # Default to Y if empty
            
            if [[ $allow_ssh == [Yy]* ]]; then
                ufw allow $ssh_port/tcp comment "SSH access"
                echo "SSH port $ssh_port has been allowed."
            fi
        fi
        echo -e "\033[0;32mUFW is already enabled.\033[0m"
    fi
    
    return_to_menu
}

disable_ufw() {
    sudo ufw disable
    echo -e "\033[0;31mUFW has been disabled.\033[0m"
    
    return_to_menu
}
deny_ip() {
    read -p "Enter the IP address(es) to deny (comma-separated, e.g., 192.168.1.1,10.0.0.2): " ips
    
    echo -e "\033[1;36mSelect direction:\033[0m"
    echo -e "\033[1;32m1.\033[0m Incoming only"
    echo -e "\033[1;33m2.\033[0m Outgoing only"
    echo -e "\033[1;34m3.\033[0m Both directions"
    echo -e "\033[1;31m0.\033[0m Return"
    read -r direction
    
    IFS=',' read -ra IPS <<< "$ips"
    for ip in "${IPS[@]}"; do
        case "$direction" in
            1) sudo ufw deny from "$ip" comment "custom deny ip" && echo -e "\033[0;31mDenied incoming IP $ip.\033[0m" ;;
            2) sudo ufw deny out to "$ip" comment "custom deny ip" && echo -e "\033[0;31mDenied outgoing IP $ip.\033[0m" ;;
            3) 
                sudo ufw deny from "$ip" comment "custom deny ip"
                sudo ufw deny out to "$ip" comment "custom deny ip"
                echo -e "\033[0;31mDenied both directions for IP $ip.\033[0m"
                ;;
            0) 
                echo -e "\033[1;31mReturn\033[0m"
                return_to_menu
                ;;
            *) echo -e "\033[0;31mInvalid choice. Skipping IP $ip.\033[0m" ;;
        esac
    done
    return_to_menu
}

allow_ip() {
    read -p "Enter the IP address(es) to allow (comma-separated, e.g., 192.168.1.1,10.0.0.2): " ips
    
    echo -e "\033[1;36mSelect direction:\033[0m"
    echo -e "\033[1;32m1.\033[0m Incoming only"
    echo -e "\033[1;33m2.\033[0m Outgoing only"
    echo -e "\033[1;34m3.\033[0m Both directions"
    echo -e "\033[1;31m0.\033[0m Return"
    read -r direction
    
    IFS=',' read -ra IPS <<< "$ips"
    for ip in "${IPS[@]}"; do
        case "$direction" in
            1) sudo ufw allow from "$ip" comment "custom allow ip" && echo -e "\033[0;32mAllowed incoming IP $ip.\033[0m" ;;
            2) sudo ufw allow out to "$ip" comment "custom allow ip" && echo -e "\033[0;32mAllowed outgoing IP $ip.\033[0m" ;;
            3) 
                sudo ufw allow from "$ip" comment "custom allow ip"
                sudo ufw allow out to "$ip" comment "custom allow ip"
                echo -e "\033[0;32mAllowed both directions for IP $ip.\033[0m"
                ;;
            0) 
                echo -e "\033[1;31mReturn\033[0m"
                return_to_menu
                ;;
            *) echo -e "\033[0;31mInvalid choice. Skipping IP $ip.\033[0m" ;;
        esac
    done
    return_to_menu
}



# Updated delete_rule function with option 0 to delete all rules
delete_rule() {
    while true; do
        clear
        echo -e "\033[1;36mCurrent UFW rules:\033[0m"
        sudo ufw status numbered  # Show numbered rules for easy selection

        echo -e "\033[1;33mChoose deletion method:\033[0m"
        echo -e "  \033[1;32m1\033[0m - Delete by rule numbers (comma-separated, e.g., 1,3,5)"
        echo -e "  \033[1;32m2\033[0m - Delete by comment (select from list)"
        echo -e "  \033[1;31m0\033[0m - Delete all rules and reset UFW"
        echo -e "  \033[1;35mr\033[0m - Return to main menu"
        
        read -p "$(echo -e "\033[1;33mYour choice [0-2/r]: \033[0m")" choice

        case $choice in
            r|R)
                echo -e "\033[0;33mReturning to main menu...\033[0m"
                return_to_menu
                return
                ;;
            0)
                # Delete all rules by resetting UFW
                echo -e "\033[1;31mAre you sure you want to delete ALL rules and reset UFW?\033[0m"
                read -p "$(echo -e "\033[1;33mThis cannot be undone! [y/N]: \033[0m")" confirm_reset
                
                if [[ $confirm_reset == [Yy] ]]; then
                    sudo ufw reset
                    echo -e "\033[0;31mAll UFW rules have been deleted, and UFW has been reset to defaults.\033[0m"
                    read -p "$(echo -e "\033[1;33mPress Enter to continue...\033[0m")"
                else
                    echo -e "\033[0;33mReset cancelled.\033[0m"
                    read -p "$(echo -e "\033[1;33mPress Enter to continue...\033[0m")"
                fi
                ;;
            1)
                while true; do
                    echo -e "\033[1;33mEnter the rule numbers to delete (comma-separated, e.g., 1,3,5):\033[0m"
                    echo -e "  \033[1;35mr\033[0m - Return to deletion method menu"
                    read -p "$(echo -e "\033[1;33mRule numbers: \033[0m")" rule_numbers

                    if [[ $rule_numbers == [rR] ]]; then
                        break
                    fi

                    if [[ -n "$rule_numbers" ]]; then
                        IFS=',' read -ra RULES <<< "$rule_numbers"  # Split input by comma
                        # Sort in reverse order to avoid renumbering issues
                        sorted_rules=($(printf '%s\n' "${RULES[@]}" | sort -nr))
                        
                        deleted_count=0
                        for rule_number in "${sorted_rules[@]}"; do
                            # Check if each entry is a valid number
                            if [[ $rule_number =~ ^[0-9]+$ ]]; then
                                sudo ufw --force delete "$rule_number"
                                echo -e "\033[0;32mDeleted rule number $rule_number.\033[0m"
                                deleted_count=$((deleted_count + 1))
                            else
                                echo -e "\033[0;31mInvalid input: '$rule_number'. Please enter valid rule numbers.\033[0m"
                            fi
                        done
                        
                        if [[ $deleted_count -gt 0 ]]; then
                            echo -e "\033[0;32mSuccessfully deleted $deleted_count rules.\033[0m"
                        fi
                        
                        read -p "$(echo -e "\033[1;33mPress Enter to continue or 'r' to return: \033[0m")" continue_choice
                        if [[ $continue_choice == [rR] ]]; then
                            break
                        fi
                    else
                        echo -e "\033[0;31mNo rule numbers entered.\033[0m"
                    fi
                done
                ;;
            2)
                while true; do
                    echo -e "\033[1;33mAvailable comments in UFW rules:\033[0m"
                    
                    # Get unique comments without counts
                    comments_list=()
                    i=1
                    while IFS= read -r comment; do
                        if [[ -n "$comment" ]]; then
                            comments_list[$i]="$comment"
                            echo -e "  \033[1;32m$i\033[0m - $comment"
                            ((i++))
                        fi
                    done <<< "$(sudo ufw status numbered | grep -oP '# \K.*' | sort -u)"
                    
                    total_comments=$((i-1))
                    
                    if [[ $total_comments -eq 0 ]]; then
                        echo -e "\033[0;31mNo comments found in UFW rules.\033[0m"
                        read -p "$(echo -e "\033[1;33mPress Enter to return...\033[0m")"
                        break
                    fi
                    
                    echo -e "  \033[1;32m0\033[0m - Refresh list"
                    echo -e "  \033[1;35mr\033[0m - Return to deletion method menu"
                    echo -e "\033[1;33mSelect a comment to delete all rules with that comment:\033[0m"
                    read -p "$(echo -e "\033[1;33mEnter choice [0-$total_comments/r]: \033[0m")" comment_choice

                    if [[ $comment_choice == [rR] ]]; then
                        break
                    elif [[ $comment_choice -eq 0 ]]; then
                        echo -e "\033[0;33mRefreshing comment list...\033[0m"
                        continue
                    elif [[ $comment_choice -ge 1 && $comment_choice -le $total_comments ]]; then
                        selected_comment="${comments_list[$comment_choice]}"
                        
                        # Show how many rules will be deleted
                        rule_count=$(sudo ufw status numbered | grep -F "# $selected_comment" | wc -l)
                        echo -e "\033[1;31mThis will delete $rule_count rules with comment: '$selected_comment'\033[0m"
                        
                        # Confirm deletion
                        read -p "$(echo -e "\033[1;33mConfirm deletion [y/N]: \033[0m")" confirm_delete
                        
                        if [[ $confirm_delete == [Yy] ]]; then
                            # Get rule numbers with the specified comment (in reverse order)
                            rule_numbers=$(sudo ufw status numbered | grep -F "# $selected_comment" | awk -F'[][]' '{print $2}' | sort -nr)
                            
                            if [[ -n "$rule_numbers" ]]; then
                                count=0
                                # Delete all rules at once without asking for each one
                                for rule_number in $rule_numbers; do
                                    sudo ufw --force delete "$rule_number"
                                    count=$((count + 1))
                                done
                                echo -e "\033[0;32mSuccessfully deleted $count rules with comment: '$selected_comment'\033[0m"
                            else
                                echo -e "\033[0;31mNo rules found with comment: '$selected_comment'\033[0m"
                            fi
                        else
                            echo -e "\033[0;33mDeletion cancelled.\033[0m"
                        fi
                        
                        read -p "$(echo -e "\033[1;33mPress Enter to continue or 'r' to return: \033[0m")" continue_choice
                        if [[ $continue_choice == [rR] ]]; then
                            break
                        fi
                    else
                        echo -e "\033[0;31mInvalid choice. Please enter a number between 0 and $total_comments or 'r' to return.\033[0m"
                        read -p "$(echo -e "\033[1;33mPress Enter to continue...\033[0m")"
                    fi
                done
                ;;
            *)
                echo -e "\033[0;31mInvalid choice. Please enter 0, 1, 2, or 'r'.\033[0m"
                read -p "$(echo -e "\033[1;33mPress Enter to continue...\033[0m")"
                ;;
        esac
    done
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


# Gaming Ports Function
gaming_ports() {
    while true; do
        clear
        show_status_bar
        echo -e "${CYAN}ðŸŽ® GAMING PORTS SELECTION${NC}"
        echo -e "${BLUE}=================================${NC}"
        echo -e "${GREEN}1.${NC} Steam & PC Gaming"
        echo -e "${GREEN}2.${NC} Minecraft"
        echo -e "${GREEN}3.${NC} Counter-Strike / Source Games"
        echo -e "${GREEN}4.${NC} Call of Duty"
        echo -e "${GREEN}5.${NC} Battlefield Series"
        echo -e "${GREEN}6.${NC} Fortnite"
        echo -e "${GREEN}7.${NC} GTA Online / Rockstar"
        echo -e "${GREEN}8.${NC} Rainbow Six Siege"
        echo -e "${GREEN}9.${NC} Valorant"
        echo -e "${GREEN}10.${NC} Apex Legends"
        echo -e "${GREEN}11.${NC} Overwatch"
        echo -e "${GREEN}12.${NC} PlayStation Network"
        echo -e "${GREEN}13.${NC} Xbox Live"
        echo -e "${GREEN}14.${NC} Minimal Gaming Setup"
        echo -e "${GREEN}15.${NC} Maximum Gaming (All Ports)"
        echo -e "${RED}0.${NC} Return to Main Menu"
        echo -e "${BLUE}=================================${NC}"
        read -p "Select gaming option [0-15]: " game_choice

        case $game_choice in
            1)
                echo -e "${YELLOW}Adding Steam & PC Gaming ports...${NC}"
                sudo ufw allow out 27015:27030/tcp comment "Gaming ports"
                sudo ufw allow out 27015:27030/udp comment "Gaming ports"
                sudo ufw allow out 27036:27037/tcp comment "Gaming ports"
                sudo ufw allow out 4380/udp comment "Gaming ports"
                sudo ufw allow out 27014:27050/tcp comment "Gaming ports"
                echo -e "${GREEN}âœ… Steam gaming ports added${NC}"
                ;;
            2)
                echo -e "${YELLOW}Adding Minecraft ports...${NC}"
                sudo ufw allow out 25565/tcp comment "Gaming ports"
                echo -e "${GREEN}âœ… Minecraft port added${NC}"
                ;;
            3)
                echo -e "${YELLOW}Adding Counter-Strike ports...${NC}"
                sudo ufw allow out 27015/tcp comment "Gaming ports"
                sudo ufw allow out 27015/udp comment "Gaming ports"
                sudo ufw allow out 27020/udp comment "Gaming ports"
                echo -e "${GREEN}âœ… Counter-Strike ports added${NC}"
                ;;
            4)
                echo -e "${YELLOW}Adding Call of Duty ports...${NC}"
                sudo ufw allow out 3074/tcp comment "Gaming ports"
                sudo ufw allow out 3074/udp comment "Gaming ports"
                sudo ufw allow out 3075:3076/tcp comment "Gaming ports"
                echo -e "${GREEN}âœ… Call of Duty ports added${NC}"
                ;;
            5)
                echo -e "${YELLOW}Adding Battlefield ports...${NC}"
                sudo ufw allow out 3659/udp comment "Gaming ports"
                sudo ufw allow out 10000:20000/udp comment "Gaming ports"
                echo -e "${GREEN}âœ… Battlefield ports added${NC}"
                ;;
            6)
                echo -e "${YELLOW}Adding Fortnite ports...${NC}"
                sudo ufw allow out 5222/tcp comment "Gaming ports"
                sudo ufw allow out 5223/tcp comment "Gaming ports"
                sudo ufw allow out 3478:3479/udp comment "Gaming ports"
                sudo ufw allow out 3074:4380/udp comment "Gaming ports"
                echo -e "${GREEN}âœ… Fortnite ports added${NC}"
                ;;
            7)
                echo -e "${YELLOW}Adding GTA Online ports...${NC}"
                sudo ufw allow out 6672/udp comment "Gaming ports"
                sudo ufw allow out 61455:61458/udp comment "Gaming ports"
                sudo ufw allow out 1000:2000/udp comment "Gaming ports"
                echo -e "${GREEN}âœ… GTA Online ports added${NC}"
                ;;
            8)
                echo -e "${YELLOW}Adding Rainbow Six Siege ports...${NC}"
                sudo ufw allow out 6015:6016/tcp comment "Gaming ports"
                sudo ufw allow out 10000:20000/udp comment "Gaming ports"
                echo -e "${GREEN}âœ… Rainbow Six Siege ports added${NC}"
                ;;
            9)
                echo -e "${YELLOW}Adding Valorant ports...${NC}"
                sudo ufw allow out 5223/tcp comment "Gaming ports"
                sudo ufw allow out 2099/tcp comment "Gaming ports"
                sudo ufw allow out 8080/tcp comment "Gaming ports"
                sudo ufw allow out 8443/tcp comment "Gaming ports"
                sudo ufw allow out 5000:5500/udp comment "Gaming ports"
                echo -e "${GREEN}âœ… Valorant ports added${NC}"
                ;;
            10)
                echo -e "${YELLOW}Adding Apex Legends ports...${NC}"
                sudo ufw allow out 1024:1124/udp comment "Gaming ports"
                sudo ufw allow out 3216/udp comment "Gaming ports"
                sudo ufw allow out 9960:9969/udp comment "Gaming ports"
                sudo ufw allow out 18000:18100/udp comment "Gaming ports"
                echo -e "${GREEN}âœ… Apex Legends ports added${NC}"
                ;;
            11)
                echo -e "${YELLOW}Adding Overwatch ports...${NC}"
                sudo ufw allow out 1119:1120/udp comment "Gaming ports"
                sudo ufw allow out 3724/tcp comment "Gaming ports"
                sudo ufw allow out 4000:4001/tcp comment "Gaming ports"
                echo -e "${GREEN}âœ… Overwatch ports added${NC}"
                ;;
            12)
                echo -e "${YELLOW}Adding PlayStation Network ports...${NC}"
                sudo ufw allow out 3478:3480/tcp comment "Gaming ports"
                sudo ufw allow out 3478:3479/udp comment "Gaming ports"
                sudo ufw allow out 10070:10080/tcp comment "Gaming ports"
                echo -e "${GREEN}âœ… PlayStation Network ports added${NC}"
                ;;
            13)
                echo -e "${YELLOW}Adding Xbox Live ports...${NC}"
                sudo ufw allow out 3074 comment "Gaming ports"
                echo -e "${GREEN}âœ… Xbox Live ports added${NC}"
                ;;
            14)
                echo -e "${YELLOW}Adding Minimal Gaming Setup...${NC}"
                sudo ufw allow out 53 comment "Gaming ports"
                sudo ufw allow out 80 comment "Gaming ports"
                sudo ufw allow out 443 comment "Gaming ports"
                sudo ufw allow out 3074 comment "Gaming ports"
                sudo ufw allow out 27015:27030 comment "Gaming ports"
                echo -e "${GREEN}âœ… Minimal gaming ports added${NC}"
                ;;
            15)
                echo -e "${YELLOW}âš ï¸  Adding Maximum Gaming Ports (Wide Range)...${NC}"
                read -p "Are you sure? This opens many ports! (y/N): " confirm
                if [[ $confirm =~ ^[Yy]$ ]]; then
                    sudo ufw allow out 1000:65000/udp comment "Gaming ports"
                    sudo ufw allow out 1000:65000/tcp comment "Gaming ports"
                    echo -e "${GREEN}âœ… Maximum gaming ports added${NC}"
                else
                    echo -e "${YELLOW}Operation cancelled${NC}"
                fi
                ;;
            0)
                echo -e "${YELLOW}Returning to main menu...${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo ""
        echo -e "${CYAN}Current UFW Rules:${NC}"
        sudo ufw status numbered | grep -E "(ALLOW OUT|Game|Steam)" | head -10
        echo ""
        read -p "Press Enter to continue..."
    done
}
# Function to check UFW status
get_ufw_status() {
    if ! command -v ufw >/dev/null 2>&1; then
        echo -e "${RED}NOT INSTALLED${NC}"
        return
    fi
    
    ufw_status=$(sudo ufw status 2>/dev/null | grep -i status | awk '{print $2}')
    case $ufw_status in
        "active") echo -e "${GREEN}ENABLED${NC}" ;;
        "inactive") echo -e "${RED}DISABLED${NC}" ;;
        *) echo -e "${YELLOW}UNKNOWN${NC}" ;;
    esac
}

# Function to display status bar
# Function to display status bar
show_status_bar() {
    local status=$(ufw status | grep "Status:" | awk '{print $2}')
    local default_in=$(ufw status verbose | grep "Default:" | awk '{print $2}')
    local default_out=$(ufw status verbose | grep "Default:" | awk '{print $4}')
    
    # Count different types of rules
    local total_rules=$(ufw status numbered | grep -c "^\[")
    local allowed_in=$(ufw status numbered | grep "ALLOW IN" | grep -c "^\[")
    local allowed_out=$(ufw status numbered | grep "ALLOW OUT" | grep -c "^\[")
    local denied_in=$(ufw status numbered | grep "DENY IN" | grep -c "^\[")
    local denied_out=$(ufw status numbered | grep "DENY OUT" | grep -c "^\[")
    
    # Get unique comments and their counts
    local comments_count=$(ufw status numbered | grep -oP '# \K.*' | sort | uniq -c | sort -rn)
    
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${NC}UFW: ${GREEN}$status${NC} | Default: ${CYAN}In:$default_in${NC}/${CYAN}Out:$default_out${NC} | Total Rules: $total_rules${BLUE}${NC}"
    echo -e "${BLUE}${NC}Allowed: ${GREEN}In:$allowed_in${NC}/${GREEN}Out:$allowed_out${NC} | Blocked: ${RED}In:$denied_in${NC}/${RED}Out:$denied_out${NC}${BLUE}${NC}"
    
    # Display top comments
    while IFS= read -r line; do
        if [ -n "$line" ]; then
            count=$(echo "$line" | awk '{print $1}')
            comment=$(echo "$line" | cut -d' ' -f2-)
            echo -e "${BLUE}$comment${NC}"
        fi
    done <<< "$comments_count"
    
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════╝${NC}"
}


function block_ips {
    clear
    if ! command -v ufw &> /dev/null; then
        apt update
        apt install -y ufw
    fi

    # Check if UFW is active
    ufw_status=$(ufw status | grep "Status:")
    
    # Find SSH port
    ssh_port=$(grep -E "^Port\s+[0-9]+" /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    if [ -z "$ssh_port" ]; then
        ssh_port=22  # Default SSH port
    fi

    echo "=== UFW Configuration Check ==="
    echo "Detected SSH port: $ssh_port"
    echo "Current UFW status: $ufw_status"
    echo ""
    
    # Ensure SSH port is allowed before enabling UFW
    if ! ufw status | grep -q "Status: active"; then
        echo ""
        echo "UFW is currently inactive."
        read -p "Do you want to allow SSH port $ssh_port before enabling UFW? [Y/N] default[Y]: " allow_ssh
        
        # Default to Y if empty
        if [[ -z "$allow_ssh" ]]; then
            allow_ssh="Y"
        fi
        
        if [[ $allow_ssh == [Yy]* ]]; then
            ufw allow $ssh_port/tcp comment "SSH access"
            echo "SSH port $ssh_port has been allowed."
        fi
        
        echo ""
        read -p "Ready to enable UFW? [Y/N] default[Y]: " enable_ufw
        
        # Default to Y if empty
        if [[ -z "$enable_ufw" ]]; then
            enable_ufw="Y"
        fi
        
        if [[ $enable_ufw == [Yy]* ]]; then
            ufw --force enable
            echo "UFW has been enabled."
        else
            echo "UFW remains disabled. Continuing with rule setup..."
        fi
    else
        echo "UFW is already active."
        # Check if SSH port is already allowed
        if ! ufw status | grep -q "$ssh_port/tcp"; then
            read -p "SSH port $ssh_port is not allowed. Do you want to allow it? [Y/N] default[Y]: " allow_ssh
            
            # Default to Y if empty
            if [[ -z "$allow_ssh" ]]; then
                allow_ssh="Y"
            fi
            
            if [[ $allow_ssh == [Yy]* ]]; then
                ufw allow $ssh_port/tcp comment "SSH access"
                echo "SSH port $ssh_port has been allowed."
            fi
        fi
    fi
    
    echo ""
    read -p "Do you want to allow other currently in-use ports? [Y/N] default[Y]: " allow_ports
    
    # Default to Y if empty
    if [[ -z "$allow_ports" ]]; then
        allow_ports="Y"
    fi
    
    if [[ $allow_ports == [Yy]* ]]; then
        find_and_allow_ports
    fi

    echo ""
    read -p "Are you sure about blocking abuse IP-Ranges? [Y/N] default[Y]: " confirm

    # Default to Y if empty
    if [[ -z "$confirm" ]]; then
        confirm="Y"
    fi

    if [[ $confirm == [Yy]* ]]; then
        echo ""
        read -p "Do you want to delete the previous rules? [Y/N] default[Y]: " clear_rules
        
        # Default to Y if empty
        if [[ -z "$clear_rules" ]]; then
            clear_rules="Y"
        fi
        
        if [[ $clear_rules == [Yy]* ]]; then
            # Remove all existing abuse-defender rules
            ufw status numbered | grep "abuse-defender" | awk -F"[][]" '{print $2}' | sort -rn | while read num; do
                yes | ufw delete $num
            done
            echo "Previous abuse-defender rules have been deleted."
        fi
        
        sudo ufw default allow outgoing
        echo -e "\033[0;32mSet default outgoing policy to Allow.\033[0m"
        echo -e "\033[0;32mFetching abuse IP ranges...\033[0m"
        
        IP_LIST=$(curl -s 'https://raw.githubusercontent.com/Mmdd93/Abuse-Defender/main/abuse-ips.ipv4')

        if [ $? -ne 0 ] || [ -z "$IP_LIST" ]; then
            echo "Failed to fetch the IP-Ranges list from GitHub, using built-in list..."
            # Fallback to inline IP ranges
            IP_LIST="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 198.18.0.0/15 169.254.0.0/16 192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 233.252.0.0/24 102.0.0.0/8 25.0.0.0/8 240.0.0.0/24 185.235.86.0/24 185.235.87.0/24 114.208.187.0/24 216.218.185.0/24 206.191.152.0/24 45.14.174.0/24 195.137.167.0/24 103.58.50.0/24 103.58.82.0/24 103.29.38.0/24 103.49.99.0/24 25.214.65.0/24 185.158.175.2 141.101.0.0/16 173.245.0.0/16 1.39.95.0/24 128.0.0.0/8 13.0.0.0/8 14.128.226.0/24 14.131.185.0/24 14.15.84.0/24 15.0.0.0/8 16.0.0.0/8 18.24.123.0/24 18.65.165.0/24 19.0.0.0/8 2.2.234.0/24 2.31.64.0/24 20.147.24.0/24 20.179.40.0/24 20.183.240.0/24 23.0.0.0/8 24.239.188.0/24 24.27.139.0/24 27.112.27.0/24 31.0.0.0/8 32.0.0.0/8 35.46.240.0/24 36.193.191.0/24 36.193.239.0/24 36.194.137.0/24 36.195.197.0/24 36.207.138.0/24 36.254.82.0/24 37.128.17.0/24 4.135.150.0/24 4.139.120.0/24 40.0.0.0/8 41.16.199.0/24 42.0.0.0/8 43.103.13.0/24 43.28.22.0/24 43.30.165.0/24 43.5.185.0/24 43.75.166.0/24 46.62.156.0/24 5.154.150.0/24 5.199.31.0/24 5.221.177.0/24 5.60.108.0/24 6.3.224.0/24 6.3.90.0/24 6.5.233.0/24 8.151.29.0/24 8.167.36.0/24 8.170.190.0/24 8.229.180.0/24 8.236.21.0/24 9.0.0.0/8 62.213.0.0/16"
        fi

        echo -e "\033[0;32mAdding blocking rules for $(echo "$IP_LIST" | wc -w) IP ranges...\033[0m"        
        count=0
        for IP in $IP_LIST; do
            ufw deny out from any to $IP comment "abuse-defender"
            count=$((count + 1))
            echo -ne "Progress: $count IP ranges blocked\r"
        done

        echo '127.0.0.1 appclick.co' | tee -a /etc/hosts >/dev/null
        echo '127.0.0.1 pushnotificationws.com' | tee -a /etc/hosts >/dev/null
		
        echo -e "\033[0;32mAbuse IP-Ranges blocked successfully.\033[0m"
        echo -e "\033[0;32mTotal IP ranges blocked: $count\033[0m"

        read -p "Press enter to return to Menu" dummy
        ufw_menu
    else
        echo "Cancelled."
        read -p "Press enter to return to Menu" dummy
        ufw_menu
    fi
}
function clear_block_ips {
    clear
    # Remove all abuse-defender rules
    ufw status numbered | grep "abuse-defender" | awk -F"[][]" '{print $2}' | sort -rn | while read num; do
        yes | sudo ufw --force delete $num
    done
    
    sed -i '/127.0.0.1 appclick.co/d' /etc/hosts
    sed -i '/127.0.0.1 pushnotificationws.com/d' /etc/hosts
    
    clear
    echo "All Rules cleared successfully."
    read -p "Press enter to return to Menu" dummy
    ufw_menu
}
ufw_menu() {
    while true; do
        clear
		show_status_bar
        echo -e "\033[1;36m================= UFW MENU ===================\033[0m"
        
        echo -e "\033[1;32m  1. \033[0m Enable UFW"
        echo -e "\033[1;32m  2. \033[0m Disable UFW"
        echo -e "\033[1;32m  3. \033[0m Allow ports"
        echo -e "\033[1;32m  4. \033[0m Deny ports"
        echo -e "\033[1;32m  5. \033[0m Allow services"
        echo -e "\033[1;32m  6. \033[0m Deny services"
        echo -e "\033[1;32m  7. \033[0m Delete rules"
        echo -e "\033[1;32m  8. \033[0m View UFW status verbose"
        echo -e "\033[1;32m  9. \033[0m View UFW rules numbered"
        echo -e "\033[1;32m 10. \033[0m Reload UFW"
        echo -e "\033[1;32m 11. \033[0m Set default Incoming"
        echo -e "\033[1;32m 12. \033[0m Set default Outgoing"
        echo -e "\033[1;32m 13. \033[0m clear all UFW rules"
        echo -e "\033[1;32m 14. \033[0m Allow in-use ports"
        echo -e "\033[15;32m 15. \033[0m Install UFW"
        echo -e "\033[1;32m 16. \033[0m View in-use ports"
        echo -e "\033[1;32m 17. \033[0m Allow ip"
        echo -e "\033[1;32m 18. \033[0m Deny ip"
		echo -e "\033[1;32m 19. \033[0m Disable logs (better performance)"
		echo -e "\033[1;32m 20. \033[0m Allow Gaming Ports [out]"
		echo -e "\033[1;32m 21. \033[0m Block Abuse IP-Ranges"
		echo -e "\033[1;32m 22. \033[0m Clear Abuse IP-Ranges rules"
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
	    	19) disable_log ;;
			20) gaming_ports ;;
			21) block_ips ;;
			22) clear_block_ips ;;
            0) exit ;;  # Return to main menu
            *) echo -e "\033[0;31mInvalid option. Please select between 0-18.\033[0m"
	    return_to_menu ;;
        esac
    done
}

# Call the ufw_menu function to display the menu
ufw_menu
install_ufw
