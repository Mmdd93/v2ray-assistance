#!/bin/bash
# Color codes
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

change_dns() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m           Change DNS Configuration\033[0m"
        echo -e "\033[1;36m============================================\033[0m"

        echo -e "\033[1;33mChoose the type of DNS change:\033[0m"
        echo -e "\033[1;35m1.\033[0m Change DNS"
        echo -e "\033[1;32m2.\033[0m Restore Default DNS"
        echo -e "\033[1;32m3.\033[0m Test current DNS"
        echo -e "\033[1;32m4.\033[0m Edit /etc/systemd/resolved.conf using nano"
        echo -e "\033[1;32m5.\033[0m Edit /etc/resolv.conf using nano"
        echo -e "\033[1;32m6.\033[0m Restart resolv.conf"
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
                    color=${colors[index % ${#colors[@]}]}  # Cycle through colors
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
                    # Validate the input in a loop
                    while true; do
                        if ! [[ "$dns_selection" =~ ^[0-9]+$ ]] || [ "$dns_selection" -gt "${#dns_servers_list[@]}" ]; then
                            echo -e "\033[1;31mInvalid DNS selection. Please try again.\033[0m"
                            read -p "Enter your choice: " dns_selection
                        else
                            IFS=":" read -r dns_name dns_primary dns_secondary <<< "${dns_servers_list[$dns_selection]}"
                            dns_servers=("$dns_primary" "$dns_secondary")
                            break  # Valid input, exit the loop
                        fi
                    done
                fi

                echo -e "\033[1;33mSetting up permanent DNS...\033[0m"

                # Update DNS settings in /etc/systemd/resolved.conf
                {
                    echo "[Resolve]"
                    for dns in "${dns_servers[@]}"; do
                        [ -n "$dns" ] && echo "DNS=$dns"
                    done
                    echo "DNSStubListener=no"
                } | sudo tee /etc/systemd/resolved.conf > /dev/null

                

                # Create symbolic link for /etc/resolv.conf
                sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
                echo -e "\033[1;32mSymbolic link created: /etc/resolv.conf -> /run/systemd/resolve/resolv.conf\033[0m"
                
                # Restart systemd-resolved to apply changes
                sudo systemctl restart systemd-resolved.service

                # Create the DNS configuration script
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
                    echo "    # Loop through each DNS server and add it to the resolved.conf"
                    echo "    for dns in \"\${dns_servers[@]}\"; do"
                    echo "        [ -n \"\$dns\" ] && echo \"DNS=\$dns\""
                    echo "    done"
                    echo "    # Disable the DNS stub listener to avoid conflicts with /etc/resolv.conf"
                    echo "    echo \"DNSStubListener=no\""
                    echo "} | sudo tee /etc/systemd/resolved.conf > /dev/null"
                    echo ""
                    echo "# Create symbolic link for /etc/resolv.conf to use systemd-resolved DNS settings"
                    echo "sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf"
                    echo "echo -e \"\033[1;32mSymbolic link created: /etc/resolv.conf -> /run/systemd/resolve/resolv.conf\033[0m\""
                    echo ""
                    echo "# Restart systemd-resolved to apply the new DNS configuration"
                    echo "sudo systemctl restart systemd-resolved.service"
                    echo "echo -e \"\033[1;32mDNS settings updated and systemd-resolved service restarted.\033[0m\""
                } > "$dns_script_path"

                chmod +x "$dns_script_path"
                echo -e "\033[1;32mScript created at $dns_script_path\033[0m"

                # Check if the cron job already exists and overwrite if necessary
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
                    ping -c 4 "$domain"
                done
                ;;

            4)
                sudo nano /etc/systemd/resolved.conf
                ;;

            5)
                sudo nano /etc/resolv.conf
                ;;

            6)
                sudo systemctl restart systemd-resolved.service
                echo -e "\033[1;32mresolv.conf restarted.\033[0m"
                ;;

            0)
                break  # Return to the main menu
                ;;

            *)
                echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
                ;;
        esac
    done
}

change_dns