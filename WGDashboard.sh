#!/bin/bash

WGD_DIR="$HOME/WGDashboard/src"
SERVICE_PATH="/etc/systemd/system/wg-dashboard.service"

# Color codes
GREEN="\033[1;32m"
RED="\033[1;31m"
BLUE="\033[1;34m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
RESET="\033[0m"

function print_header() {
    echo -e "\n${CYAN}===== WGDashboard Management Menu =====${RESET}"
}

function is_installed() {
    if [[ -f "$WGD_DIR/wgd.sh" ]]; then
        return 0
    else
        return 1
    fi
}

function install_wgdashboard() {
    if is_installed; then
        echo -e "${YELLOW}[!] WGDashboard is already installed at: $WGD_DIR${RESET}"
        return
    fi

    echo -e "${BLUE}[+] Updating system and installing dependencies...${RESET}"
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y python3 python3-pip git wireguard-tools net-tools

    echo -e "${BLUE}[+] Cloning WGDashboard...${RESET}"
    git clone https://github.com/donaldzou/WGDashboard.git
    cd "$WGD_DIR" || exit

    echo -e "${BLUE}[+] Installing WGDashboard...${RESET}"
    sudo chmod u+x wgd.sh
    sudo ./wgd.sh install

    echo -e "${BLUE}[+] Setting permissions for /etc/wireguard...${RESET}"
    sudo chmod -R 755 /etc/wireguard

    echo -e "${BLUE}[+] Enabling IP forwarding...${RESET}"
    if ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
    fi
    sudo sysctl -p

    echo -e "${GREEN}[?] WGDashboard installed successfully.${RESET}"
    start_wgdashboard
    enable_service
}

function start_wgdashboard() {
    if ! is_installed; then
        echo -e "${RED}[!] WGDashboard is not installed.${RESET}"
        return
    fi
    echo -e "${BLUE}[~] Starting WGDashboard...${RESET}"
    cd "$WGD_DIR" || return
    sudo ./wgd.sh start
    echo -e "${YELLOW}[!] Access it at: http://your_server_ip:10086 (WGDashboard default port)${RESET}"
    echo -e "${YELLOW}[!] Default first login: admin / admin${RESET}"
}


function stop_wgdashboard() {
    if ! is_installed; then
        echo -e "${RED}[!] WGDashboard is not installed.${RESET}"
        return
    fi
    echo -e "${BLUE}[~] Stopping WGDashboard...${RESET}"
    cd "$WGD_DIR" || return
    sudo ./wgd.sh stop
}

function restart_wgdashboard() {
    if ! is_installed; then
        echo -e "${RED}[!] WGDashboard is not installed.${RESET}"
        return
    fi
    echo -e "${BLUE}[~] Restarting WGDashboard...${RESET}"
    cd "$WGD_DIR" || return
    sudo ./wgd.sh restart
}

function status_wgdashboard() {
    if systemctl list-units --type=service | grep -q "wg-dashboard"; then
        echo -e "${BLUE}[~] Checking systemd service status...${RESET}"
        sudo systemctl status wg-dashboard.service
    else
        echo -e "${YELLOW}[!] WGDashboard is not installed as a systemd service.${RESET}"
    fi
}

function enable_service() {
    if ! is_installed; then
        echo -e "${RED}[!] WGDashboard is not installed.${RESET}"
        return
    fi

    echo -e "${BLUE}[~] Enabling WGDashboard as a service...${RESET}"
    cd "$WGD_DIR" || return
    WGD_PATH=$(pwd)

    cat <<EOF | sudo tee wg-dashboard.service >/dev/null
[Unit]
After=syslog.target network-online.target
Wants=wg-quick.target
ConditionPathIsDirectory=/etc/wireguard

[Service]
Type=forking
PIDFile=${WGD_PATH}/gunicorn.pid
WorkingDirectory=${WGD_PATH}
ExecStart=${WGD_PATH}/wgd.sh start
ExecStop=${WGD_PATH}/wgd.sh stop
ExecReload=${WGD_PATH}/wgd.sh restart
TimeoutSec=120
PrivateTmp=yes
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    sudo cp wg-dashboard.service "$SERVICE_PATH"
    sudo chmod 664 "$SERVICE_PATH"
    sudo systemctl daemon-reload
    sudo systemctl enable wg-dashboard.service
    sudo systemctl start wg-dashboard.service

    echo -e "${GREEN}[?] WGDashboard service enabled and started.${RESET}"
}

function disable_service() {
    if [[ -f "$SERVICE_PATH" ]]; then
        echo -e "${BLUE}[~] Disabling WGDashboard service...${RESET}"
        sudo systemctl stop wg-dashboard.service
        sudo systemctl disable wg-dashboard.service
        sudo rm -f "$SERVICE_PATH"
        sudo systemctl daemon-reload
        echo -e "${GREEN}[?] Service removed.${RESET}"
    else
        echo -e "${YELLOW}[!] No systemd service found.${RESET}"
    fi
}

function uninstall_wgdashboard() {
    if ! is_installed; then
        echo -e "${YELLOW}[!] WGDashboard is not installed.${RESET}"
        return
    fi

    echo -e "${RED}[-] Uninstalling WGDashboard...${RESET}"
    disable_service
    sudo rm -rf "$HOME/WGDashboard"
    echo -e "${GREEN}[?] WGDashboard has been completely removed.${RESET}"
}
function setup_ssl_https() {
    echo -e "\n${CYAN}[*] Starting SSL setup and NGINX reverse proxy configuration...${RESET}"

    echo -e "${BLUE}[1/7] Installing NGINX and Certbot...${RESET}"
    sudo apt update -y
    sudo apt install nginx certbot python3-certbot-nginx -y

    echo -e "${BLUE}[2/7] Gathering configuration input...${RESET}"
    read -rp "Enter your domain (e.g. panel.example.com): " DOMAIN
    [[ -z "$DOMAIN" ]] && { echo -e "${RED}[?] Domain cannot be empty! Exiting.${RESET}"; return 1; }

    # Default values
    DEFAULT_NGINX_PORT=443
    DEFAULT_WG_PORT=10086

    # Ask for ports with default and validation
    while true; do
        read -rp "Enter the port for NGINX to listen on [default: $DEFAULT_NGINX_PORT]: " NGINX_PORT
        NGINX_PORT=${NGINX_PORT:-$DEFAULT_NGINX_PORT}
        if [[ "$NGINX_PORT" =~ ^[0-9]+$ ]] && (( NGINX_PORT >= 1 && NGINX_PORT <= 65535 )); then
            break
        else
            echo -e "${RED}[!] Invalid port. Please enter a number between 1 and 65535.${RESET}"
        fi
    done

    while true; do
        read -rp "Enter the local WGDashboard port [default: $DEFAULT_WG_PORT]: " WG_PORT
        WG_PORT=${WG_PORT:-$DEFAULT_WG_PORT}
        if [[ "$WG_PORT" =~ ^[0-9]+$ ]] && (( WG_PORT >= 1 && WG_PORT <= 65535 )); then
            break
        else
            echo -e "${RED}[!] Invalid port. Please enter a number between 1 and 65535.${RESET}"
        fi
    done

    echo -e "${BLUE}[3/7] Creating NGINX config for WGDashboard...${RESET}"

    if [[ -f /etc/nginx/sites-available/wgdashboard ]]; then
        echo -e "${YELLOW}[!] Config already exists at /etc/nginx/sites-available/wgdashboard. Backing it up.${RESET}"
        sudo mv /etc/nginx/sites-available/wgdashboard /etc/nginx/sites-available/wgdashboard.bak.$(date +%s)
    fi

    sudo bash -c "cat > /etc/nginx/sites-available/wgdashboard" <<EOF
server {
    server_name $DOMAIN;
    listen $NGINX_PORT;

    location / {
        proxy_pass http://127.0.0.1:$WG_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

    echo -e "${BLUE}[4/7] Enabling NGINX site config...${RESET}"
    sudo ln -sf /etc/nginx/sites-available/wgdashboard /etc/nginx/sites-enabled
    sudo nginx -t && sudo systemctl restart nginx

    echo -e "${BLUE}[5/7] Requesting SSL certificate via Certbot...${RESET}"
    read -rp "Enter your email for Let's Encrypt: " EMAIL
    [[ -z "$EMAIL" ]] && { echo -e "${RED}[?] Email cannot be empty! Exiting.${RESET}"; return 1; }

    sudo certbot --nginx -d "$DOMAIN" --agree-tos -m "$EMAIL" --redirect || {
        echo -e "${RED}[?] SSL certificate request failed. Check domain and DNS.${RESET}"
        return 1
    }

    echo -e "${BLUE}[6/7] Restarting NGINX to apply SSL...${RESET}"
    sudo systemctl restart nginx

    echo -e "\n${GREEN}[?] SSL setup completed successfully!${RESET}"
    echo -e "${YELLOW}[??] Access your panel securely at: https://${DOMAIN}${RESET}"
    echo -e "${YELLOW}? NGINX listens on: $NGINX_PORT${RESET}"
    echo -e "${YELLOW}? WGDashboard runs on: http://127.0.0.1:$WG_PORT${RESET}"
}


function show_wireguard_tip() {
    WG_DIR="/etc/wireguard"
    echo -e "${CYAN}WGDashboard Documentation:${RESET}"
    echo -e "https://docs.wgdashboard.dev/install.html\n"

    # Detect main network interface (first default route)
    main_iface=$(ip route | grep '^default' | awk '{print $5}' | head -n 1)
    main_iface=${main_iface:-eth0}

    shopt -s nullglob
    conf_files=("$WG_DIR"/*.conf)
    shopt -u nullglob

    if [ ${#conf_files[@]} -eq 0 ]; then
        echo -e "${RED}No WireGuard configuration files found in ${WG_DIR}.${RESET}"
        return 1
    fi

    echo -e "\033[1;33mIMPORTANT TIPS FOR WIREGUARD CONFIGURATION\033[0m"
    echo -e "\033[1;34mEach config should contain the proper PostUp and PostDown rules:\033[0m"

    for conf_file in "${conf_files[@]}"; do
        wg_iface=$(basename "$conf_file" .conf)

        echo -e "\033[1;35mConfig: $conf_file (Interface: $wg_iface)\033[0m"

        echo -e "\033[1;32mPostUp:\033[0m"
        echo -e "\033[0;36miptables -A FORWARD -i $wg_iface -j ACCEPT; iptables -A FORWARD -o $wg_iface -j ACCEPT; iptables -t nat -A POSTROUTING -o $main_iface -j MASQUERADE;\033[0m"

        echo -e "\033[1;32mPostDown:\033[0m"
        echo -e "\033[0;36miptables -D FORWARD -i $wg_iface -j ACCEPT; iptables -D FORWARD -o $wg_iface -j ACCEPT; iptables -t nat -D POSTROUTING -o $main_iface -j MASQUERADE;\033[0m"
    done

    echo -e "\033[1;31mWithout these lines, WireGuard may not work or route properly!\033[0m\n"
}



function set_postup_postdown() {
    WG_DIR="/etc/wireguard"
    echo -e "\n${CYAN}[*] Adding PostUp and PostDown rules to WireGuard configs...${RESET}"

    shopt -s nullglob
    conf_files=("$WG_DIR"/*.conf)
    shopt -u nullglob

    if [ ${#conf_files[@]} -eq 0 ]; then
        echo -e "${RED}No WireGuard config files found in $WG_DIR.${RESET}"
        return 1
    fi

    # Auto-detect main interface
    detected_iface=$(ip route | grep default | awk '{print $5}' | head -n 1)

    echo -e "${YELLOW}[?] Detected main interface: ${detected_iface}${RESET}"
    read -rp "$(echo -e "${CYAN}[*] Is this correct? (yes/no): ${RESET}")" confirm
    if [[ "$confirm" != "yes" ]]; then
        read -rp "$(echo -e "${CYAN}[?] Enter the correct interface name (e.g., eth0, ens3): ${RESET}")" detected_iface
    fi

    for conf_file in "${conf_files[@]}"; do
        iface=$(basename "$conf_file" .conf)
        echo -e "${BLUE}Processing $conf_file for interface $iface${RESET}"

        postop="iptables -A FORWARD -i $iface -j ACCEPT; iptables -A FORWARD -o $iface -j ACCEPT; iptables -t nat -A POSTROUTING -o $detected_iface -j MASQUERADE;"
        postdown="iptables -D FORWARD -i $iface -j ACCEPT; iptables -D FORWARD -o $iface -j ACCEPT; iptables -t nat -D POSTROUTING -o $detected_iface -j MASQUERADE;"

        awk -v postop="$postop" -v postdown="$postdown" '
        BEGIN { in_interface=0 }
        {
            if ($0 ~ /^\[Interface\]/) {
                print $0
                in_interface=1
                print "PostUp = " postop
                print "PostDown = " postdown
                next
            }

            if (in_interface && $0 ~ /^\[/) {
                in_interface=0
            }

            if (in_interface && ($0 ~ /^PostUp *=/ || $0 ~ /^PostDown *=/)) {
                next
            }

            print $0
        }' "$conf_file" > "${conf_file}.tmp" && sudo mv "${conf_file}.tmp" "$conf_file"

        echo -e "${GREEN}? Updated PostUp and PostDown in $conf_file${RESET}"
    done
}


function clear_postup_postdown() {
    WG_DIR="/etc/wireguard"
    echo -e "\n${CYAN}[*] Removing PostUp and PostDown rules from WireGuard configs and clearing iptables rules...${RESET}"

    shopt -s nullglob
    conf_files=("$WG_DIR"/*.conf)
    shopt -u nullglob

    if [ ${#conf_files[@]} -eq 0 ]; then
        echo -e "${RED}No WireGuard config files found in $WG_DIR.${RESET}"
        return 1
    fi

    # Detect main interface
    detected_iface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    echo -e "${YELLOW}[?] Detected main interface: ${detected_iface}${RESET}"
    read -rp "$(echo -e "${CYAN}[*] Is this correct? (yes/no): ${RESET}")" confirm
    if [[ "$confirm" != "yes" ]]; then
        read -rp "$(echo -e "${CYAN}[?] Enter the correct interface name (e.g., eth0, ens3): ${RESET}")" detected_iface
    fi

    for conf_file in "${conf_files[@]}"; do
        iface=$(basename "$conf_file" .conf)
        echo -e "${BLUE}Processing $conf_file for interface $iface${RESET}"

        # Remove PostUp and PostDown lines from the config
        sudo sed -i '/^PostUp =/d' "$conf_file"
        sudo sed -i '/^PostDown =/d' "$conf_file"

        # Clean up iptables rules
        sudo iptables -D FORWARD -i "$iface" -j ACCEPT 2>/dev/null
        sudo iptables -D FORWARD -o "$iface" -j ACCEPT 2>/dev/null
        sudo iptables -t nat -D POSTROUTING -o "$detected_iface" -j MASQUERADE 2>/dev/null

        echo -e "${GREEN}? Removed PostUp/PostDown from $conf_file and cleared iptables rules for $iface${RESET}"
    done
}

manage_wireguard_interfaces() {
    WG_DIR="/etc/wireguard"

    RED='\033[1;31m'
    GREEN='\033[1;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[1;36m'
    RESET='\033[0m'

    while true; do
        shopt -s nullglob
        conf_files=("$WG_DIR"/*.conf)
        shopt -u nullglob

        if [ ${#conf_files[@]} -eq 0 ]; then
            echo -e "${RED}No WireGuard config files found in $WG_DIR.${RESET}"
            return 1
        fi

        echo -e "\n${CYAN}Available WireGuard config files:${RESET}"
        for i in "${!conf_files[@]}"; do
            iface=$(basename "${conf_files[$i]}" .conf)
            echo -e "${YELLOW}$((i+1)).${RESET} $iface"
        done
        echo -e "${YELLOW}0)${RESET} Return to main menu"

        read -rp "Select interface number to manage (or 0 to return): " choice

        if [[ -z "$choice" || "$choice" == "0" ]]; then
            echo -e "${GREEN}Returning to main menu.${RESET}"
            break
        fi

        if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#conf_files[@]} )); then
            echo -e "${RED}Invalid choice. Returning to main menu.${RESET}"
            break
        fi

        iface=$(basename "${conf_files[$((choice-1))]}" .conf)

        while true; do
            echo -e "\n${CYAN}Selected interface:${RESET} ${GREEN}$iface${RESET}"
            echo -e "${CYAN}Actions:${RESET}"
            echo -e "${YELLOW}1)${RESET} Start"
            echo -e "${YELLOW}2)${RESET} Stop"
            echo -e "${YELLOW}3)${RESET} Restart"
            echo -e "${YELLOW}4)${RESET} Status"
            echo -e "${YELLOW}5)${RESET} Enable (systemd service)"
            echo -e "${YELLOW}6)${RESET} Disable (systemd service)"
            echo -e "${YELLOW}7)${RESET} Remove (stop, disable, delete config)"
            echo -e "${YELLOW}8)${RESET} Edit configuration file"
            echo -e "${YELLOW}0)${RESET} Return to interface list"

            read -rp "Choose action number: " action

            if [[ -z "$action" || "$action" == "0" ]]; then
                echo -e "${GREEN}Returning to interface list.${RESET}"
                break
            fi

            case $action in
                1)
                    if sudo wg-quick up "$iface"; then
                        echo -e "${GREEN}Interface $iface started successfully.${RESET}"
                    else
                        echo -e "${RED}Failed to start interface $iface.${RESET}"
                    fi
                    ;;
                2)
                    if sudo wg-quick down "$iface"; then
                        echo -e "${GREEN}Interface $iface stopped successfully.${RESET}"
                    else
                        echo -e "${RED}Failed to stop interface $iface.${RESET}"
                    fi
                    ;;
                3)
                    if sudo wg-quick down "$iface" && sudo wg-quick up "$iface"; then
                        echo -e "${GREEN}Interface $iface restarted successfully.${RESET}"
                    else
                        echo -e "${RED}Failed to restart interface $iface.${RESET}"
                    fi
                    ;;
                4)
                    echo -e "${CYAN}Status for wg-quick@$iface service:${RESET}"
                    sudo systemctl status wg-quick@"$iface"
                    ;;
                5)
                    if sudo systemctl enable wg-quick@"$iface"; then
                        echo -e "${GREEN}Enabled wg-quick@$iface service.${RESET}"
                    else
                        echo -e "${RED}Failed to enable wg-quick@$iface service.${RESET}"
                    fi
                    ;;
                6)
                    if sudo systemctl disable wg-quick@"$iface"; then
                        echo -e "${GREEN}Disabled wg-quick@$iface service.${RESET}"
                    else
                        echo -e "${RED}Failed to disable wg-quick@$iface service.${RESET}"
                    fi
                    ;;
                7)
                    read -rp "Are you sure you want to ${RED}REMOVE${RESET} interface $iface? This will stop, disable, and delete the config. (y/n): " confirm
                    if [[ "$confirm" =~ ^[Yy]$ ]]; then
                        sudo wg-quick down "$iface" 2>/dev/null
                        sudo systemctl disable wg-quick@"$iface" 2>/dev/null
                        if sudo rm -f "$WG_DIR/$iface.conf"; then
                            echo -e "${GREEN}Interface $iface removed successfully.${RESET}"
                        else
                            echo -e "${RED}Failed to remove configuration file for $iface.${RESET}"
                        fi
                        break
                    else
                        echo -e "${YELLOW}Removal cancelled.${RESET}"
                    fi
                    ;;
                8)
                    echo -e "${CYAN}Opening $WG_DIR/$iface.conf in nano editor...${RESET}"
                    sudo nano "$WG_DIR/$iface.conf"
                    ;;
                *)
                    echo -e "${RED}Invalid action. Please select a valid option.${RESET}"
                    ;;
            esac
        done
    done
}


function main_menu() {
    clear
    print_header
    show_wireguard_tip

    while true; do
        echo -e "${YELLOW}========== WGDashboard Management Menu ==========${RESET}"
        echo -e "${YELLOW}1)${RESET} Install WGDashboard"
        echo -e "${YELLOW}2)${RESET} Start WGDashboard"
        echo -e "${YELLOW}3)${RESET} Stop WGDashboard"
        echo -e "${YELLOW}4)${RESET} Restart WGDashboard"
        echo -e "${YELLOW}5)${RESET} Check WGDashboard Status"
        echo -e "${YELLOW}6)${RESET} Enable WGDashboard as a Service"
        echo -e "${YELLOW}7)${RESET} Disable WGDashboard Service"
        echo -e "${YELLOW}8)${RESET} Uninstall WGDashboard"
        echo -e "${YELLOW}9)${RESET} Show WireGuard Configuration Tip Again"
        echo -e "${YELLOW}10)${RESET} Enable SSL / HTTPS Setup"
        echo -e "${YELLOW}11)${RESET} Set PostUp and PostDown in WireGuard Configs"
        echo -e "${YELLOW}12)${RESET} Remove PostUp and PostDown in WireGuard Configs"
        echo -e "${YELLOW}13)${RESET} Manage WireGuard Configs"
        echo -e "${YELLOW}0)${RESET} Exit"

        # Validate input with 1-12 now
        while true; do
            read -rp $'\nChoose an option: ' choice
            if [[ "$choice" =~ ^([0-9]|1[0-3])$ ]]; then
                break
            else
                echo -e "${RED}[!] Invalid input, please enter a number between 1 and 12.${RESET}"
            fi
        done

        case $choice in
            1) install_wgdashboard ;;
            2) start_wgdashboard ;;
            3) stop_wgdashboard ;;
            4) restart_wgdashboard ;;
            5) status_wgdashboard ;;
            6) enable_service ;;
            7) disable_service ;;
            8) uninstall_wgdashboard ;;
            9) show_wireguard_tip ;;
            10) setup_ssl_https ;;
            0) echo -e "\n${CYAN}Goodbye! Thanks for using WGDashboard manager.${RESET}\n"; exit 0 ;;
            11) set_postup_postdown ;;
            12) clear_postup_postdown ;;
            13) manage_wireguard_interfaces ;;
        esac

        echo -e "\n${GREEN}Press Enter to return to the menu...${RESET}"
        read -r
        clear
        print_header
    done
}
main_menu
