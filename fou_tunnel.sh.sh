#!/bin/bash

CONFIG_DIR="/etc/fou_tunnel"
SERVICE_FILE="/etc/systemd/system/fou-tunnel@.service"
REMOTE_TUNNEL_IP=""

show_menu() {

    echo "1. Create New Tunnel"
    echo "2. List Existing Tunnels"
    echo "3. Check Remote Connection"
    echo "4. Check Tunnel Status"
    echo "5. Remove Tunnel"
    echo "6. Install bbr.sh and tcp.sh"
    echo "7. Exit"
    read -p "Choose an option: " choice
    case $choice in
        1) create_tunnel ;;
        2) list_tunnels ;;
        3) check_remote ;;
        4) check_tunnel_status ;;
        5) remove_tunnel ;;
        6) install_scripts ;;
        7) exit 0 ;;
        *) echo "Invalid option" && sleep 1 && show_menu ;;
    esac
}

create_tunnel() {
    echo -e "\e[1;34m"
    echo "=================================="
    echo "      Create New Tunnel"
    echo "=================================="
    echo -e "\e[0m"
    
    # Create config directory if it doesn't exist
    sudo mkdir -p $CONFIG_DIR
    
    # Get tunnel name
    read -p "Enter tunnel name (e.g., gre1, gre2, office, home): " TUNNEL_NAME
    
    # Validate tunnel name
    if [ -z "$TUNNEL_NAME" ]; then
        echo "Tunnel name cannot be empty!"
        read -p "Press Enter to return to menu..." && show_menu
        return
    fi
    
    # Check if tunnel config already exists
    TUNNEL_CONFIG="$CONFIG_DIR/${TUNNEL_NAME}.conf"
    if [ -f "$TUNNEL_CONFIG" ]; then
        echo "Tunnel '$TUNNEL_NAME' already exists!"
        read -p "Do you want to overwrite? (y/n): " overwrite
        if [[ $overwrite != [yY] && $overwrite != [yY][eE][sS] ]]; then
            read -p "Press Enter to return to menu..." && show_menu
            return
        fi
    fi
    
    # Get tunnel configuration
    read -p "Enter local IP address: " LOCAL_IP
    read -p "Enter remote IP address: " REMOTE_IP
    read -p "Enter local tunnel IP (e.g., 30.30.30.2): " LOCAL_TUNNEL_IP
    read -p "Enter remote tunnel IP (e.g., 30.30.30.1): " REMOTE_TUNNEL_IP
    read -p "Enter IPSec PSK (Pre-Shared Key): " IPSec_PSK
    
    # Optional: Different port for each tunnel
    read -p "Enter TCP port [default: 443]: " TCP_PORT
    TCP_PORT=${TCP_PORT:-443}
    
    # Save configuration
    cat > $TUNNEL_CONFIG << EOL
TUNNEL_NAME=$TUNNEL_NAME
LOCAL_IP=$LOCAL_IP
REMOTE_IP=$REMOTE_IP
LOCAL_TUNNEL_IP=$LOCAL_TUNNEL_IP
REMOTE_TUNNEL_IP=$REMOTE_TUNNEL_IP
IPSec_PSK=$IPSec_PSK
TCP_PORT=$TCP_PORT
EOL
    
    echo "Configuration saved for tunnel '$TUNNEL_NAME'"
    
    # Setup the tunnel
    setup_tunnel $TUNNEL_NAME
    
    read -p "Press Enter to return to menu..." && show_menu
}

setup_tunnel() {
    local TUNNEL_NAME=$1
    local TUNNEL_CONFIG="$CONFIG_DIR/${TUNNEL_NAME}.conf"
    
    if [ ! -f "$TUNNEL_CONFIG" ]; then
        echo "Tunnel configuration not found!"
        return 1
    fi
    
    source $TUNNEL_CONFIG
    
    echo -e "\e[1;33m"
    echo "=================================="
    echo "   Setting up tunnel: $TUNNEL_NAME"
    echo "=================================="
    echo -e "\e[0m"
    
    if ! command -v socat &> /dev/null; then
        echo "Installing required packages..."
        sudo apt-get update
        sudo apt-get install -y socat strongswan strongswan-pki
    fi
    
    # Load GRE module
    sudo modprobe ip_gre
    
    # Remove existing GRE interface with same name if exists
    sudo ip link del $TUNNEL_NAME 2>/dev/null
    
    # Create GRE interface
    sudo ip link add $TUNNEL_NAME type gre remote $REMOTE_IP local $LOCAL_IP ttl 255
    
    # Assign IP to GRE interface
    sudo ip addr add $LOCAL_TUNNEL_IP/24 dev $TUNNEL_NAME
    
    # Set MTU
    sudo ip link set $TUNNEL_NAME mtu 1300
    
    # Bring up the interface
    sudo ip link set $TUNNEL_NAME up
    
    # Add route
    sudo ip route add $REMOTE_TUNNEL_IP/32 dev $TUNNEL_NAME
    
    # Setup socat for this tunnel (using unique port per tunnel)
    sudo pkill -f "socat.*TCP-LISTEN:$TCP_PORT.*TUN:$TUNNEL_NAME" 2>/dev/null
    sudo socat TCP-LISTEN:$TCP_PORT,fork,reuseaddr TUN:$TUNNEL_NAME,up &
    
    # Add iptables rules with tunnel-specific comments
    sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss 1200 -m comment --comment "$TUNNEL_NAME"
    sudo iptables -A INPUT -f -j ACCEPT -m comment --comment "$TUNNEL_NAME"
    sudo iptables -A OUTPUT -f -j ACCEPT -m comment --comment "$TUNNEL_NAME"
    sudo iptables -A FORWARD -f -j ACCEPT -m comment --comment "$TUNNEL_NAME"
    sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu -m comment --comment "$TUNNEL_NAME"
    sudo iptables -A INPUT -p tcp --dport $TCP_PORT -j ACCEPT -m comment --comment "$TUNNEL_NAME"
    sudo iptables -A OUTPUT -p tcp --sport $TCP_PORT -j ACCEPT -m comment --comment "$TUNNEL_NAME"
    
    # Setup IPSec for this tunnel (append to existing config or create new)
    setup_ipsec $TUNNEL_NAME
    
    echo "Tunnel '$TUNNEL_NAME' has been configured successfully!"
    echo "GRE Interface: $TUNNEL_NAME"
    echo "Local IP: $LOCAL_IP -> Remote IP: $REMOTE_IP"
    echo "Tunnel IP: $LOCAL_TUNNEL_IP <-> $REMOTE_TUNNEL_IP"
    echo "Port: $TCP_PORT"
}

setup_ipsec() {
    local TUNNEL_NAME=$1
    local TUNNEL_CONFIG="$CONFIG_DIR/${TUNNEL_NAME}.conf"
    source $TUNNEL_CONFIG
    
    # Create IPSec configuration for this tunnel
    sudo bash -c "cat >> /etc/ipsec.conf" << 'EOL'

conn $TUNNEL_NAME
    left=%any
    leftid=@local-$TUNNEL_NAME
    leftsubnet=0.0.0.0/0
    right=$REMOTE_IP
    rightid=@remote-$TUNNEL_NAME
    rightsubnet=0.0.0.0/0
    auto=add
EOL

    # Add PSK to ipsec.secrets
    echo "@local-$TUNNEL_NAME @remote-$TUNNEL_NAME : PSK \"$IPSec_PSK\"" | sudo tee -a /etc/ipsec.secrets > /dev/null
    
    # Restart strongswan to apply changes
    sudo systemctl restart strongswan
}

list_tunnels() {
    echo -e "\e[1;36m"
    echo "=================================="
    echo "      Existing Tunnels"
    echo "=================================="
    echo -e "\e[0m"
    
    if [ ! -d "$CONFIG_DIR" ] || [ -z "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
        echo "No tunnels configured."
    else
        echo -e "TUNNEL NAME\tLOCAL IP\tREMOTE IP\tSTATUS"
        echo "--------------------------------------------------------"
        for config in $CONFIG_DIR/*.conf; do
            if [ -f "$config" ]; then
                source $config
                # Check if GRE interface is up
                if ip link show $TUNNEL_NAME &>/dev/null; then
                    STATUS="\e[1;32mUP\e[0m"
                else
                    STATUS="\e[1;31mDOWN\e[0m"
                fi
                echo -e "$TUNNEL_NAME\t$LOCAL_IP\t$REMOTE_IP\t$STATUS"
            fi
        done
    fi
    
    read -p "Press Enter to return to menu..." && show_menu
}

check_remote() {
    echo "Available tunnels:"
    list_tunnels_no_pause
    
    read -p "Enter tunnel name to check remote connection: " TUNNEL_NAME
    TUNNEL_CONFIG="$CONFIG_DIR/${TUNNEL_NAME}.conf"
    
    if [ -f "$TUNNEL_CONFIG" ]; then
        source $TUNNEL_CONFIG
        echo "Checking connection to $REMOTE_IP..."
        if ping -c 4 $REMOTE_IP &> /dev/null; then
            echo "Remote IP $REMOTE_IP is reachable."
        else
            echo "Remote IP $REMOTE_IP is not reachable."
        fi
    else
        echo "Tunnel configuration not found."
    fi
    read -p "Press Enter to return to menu..." && show_menu
}

list_tunnels_no_pause() {
    if [ ! -d "$CONFIG_DIR" ] || [ -z "$(ls -A $CONFIG_DIR 2>/dev/null)" ]; then
        echo "No tunnels configured."
        return 1
    else
        echo "Available tunnels:"
        for config in $CONFIG_DIR/*.conf; do
            if [ -f "$config" ]; then
                source $config
                echo "  - $TUNNEL_NAME ($LOCAL_IP -> $REMOTE_IP)"
            fi
        done
        return 0
    fi
}

check_tunnel_status() {
    list_tunnels_no_pause
    
    read -p "Enter tunnel name to check: " TUNNEL_NAME
    TUNNEL_CONFIG="$CONFIG_DIR/${TUNNEL_NAME}.conf"
    
    if [ -f "$TUNNEL_CONFIG" ]; then
        source $TUNNEL_CONFIG
        
        echo "=================================="
        echo "   Tunnel Status: $TUNNEL_NAME"
        echo "=================================="
        
        # Check GRE interface
        if ip link show $TUNNEL_NAME &>/dev/null; then
            echo -e "GRE Interface: \e[1;32mUP\e[0m"
            ip addr show $TUNNEL_NAME | grep -w inet
        else
            echo -e "GRE Interface: \e[1;31mDOWN\e[0m"
        fi
        
        # Check ping to remote tunnel IP
        echo -n "Tunnel Connectivity: "
        if ping -c 2 $REMOTE_TUNNEL_IP &> /dev/null; then
            echo -e "\e[1;32mOK\e[0m"
        else
            echo -e "\e[1;31mFAILED\e[0m"
        fi
        
        # Check socat process
        if pgrep -f "socat.*TCP-LISTEN:$TCP_PORT.*TUN:$TUNNEL_NAME" &>/dev/null; then
            echo -e "Socat Service: \e[1;32mRUNNING\e[0m (Port: $TCP_PORT)"
        else
            echo -e "Socat Service: \e[1;31mSTOPPED\e[0m"
        fi
        
        # Check IPSec connection
        if sudo ipsec status $TUNNEL_NAME 2>/dev/null | grep -q "ESTABLISHED"; then
            echo -e "IPSec: \e[1;32mCONNECTED\e[0m"
        else
            echo -e "IPSec: \e[1;31mDISCONNECTED\e[0m"
        fi
        
    else
        echo "Tunnel configuration not found."
    fi
    read -p "Press Enter to return to menu..." && show_menu
}

remove_tunnel() {
    echo -e "\e[1;31m"
    echo "=================================="
    echo "      Remove Tunnel"
    echo "=================================="
    echo -e "\e[0m"
    
    list_tunnels_no_pause
    
    read -p "Enter tunnel name to remove (or 'all' for all tunnels): " TUNNEL_NAME
    
    if [ "$TUNNEL_NAME" = "all" ]; then
        read -p "Are you sure you want to remove ALL tunnels? (y/n): " confirm
        if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
            echo "Removal cancelled."
            read -p "Press Enter to return to menu..." && show_menu
            return
        fi
        
        # Remove all tunnels
        for config in $CONFIG_DIR/*.conf; do
            if [ -f "$config" ]; then
                source $config
                remove_single_tunnel $TUNNEL_NAME
            fi
        done
        
        # Remove config directory
        sudo rm -rf $CONFIG_DIR
        
        # Remove all IPSec configurations
        sudo rm -f /etc/ipsec.conf
        sudo rm -f /etc/ipsec.secrets
        
        echo "All tunnels removed successfully!"
        
    else
        # Remove single tunnel
        TUNNEL_CONFIG="$CONFIG_DIR/${TUNNEL_NAME}.conf"
        
        if [ ! -f "$TUNNEL_CONFIG" ]; then
            echo "Tunnel '$TUNNEL_NAME' not found."
            read -p "Press Enter to return to menu..." && show_menu
            return
        fi
        
        read -p "Are you sure you want to remove tunnel '$TUNNEL_NAME'? (y/n): " confirm
        if [[ $confirm != [yY] && $confirm != [yY][eE][sS] ]]; then
            echo "Removal cancelled."
            read -p "Press Enter to return to menu..." && show_menu
            return
        fi
        
        source $TUNNEL_CONFIG
        remove_single_tunnel $TUNNEL_NAME
        sudo rm -f $TUNNEL_CONFIG
        
        echo "Tunnel '$TUNNEL_NAME' removed successfully!"
    fi
    
    read -p "Press Enter to return to menu..." && show_menu
}

remove_single_tunnel() {
    local TUNNEL_NAME=$1
    local TUNNEL_CONFIG="$CONFIG_DIR/${TUNNEL_NAME}.conf"
    
    if [ -f "$TUNNEL_CONFIG" ]; then
        source $TUNNEL_CONFIG
    fi
    
    echo "Removing tunnel: $TUNNEL_NAME"
    
    # Kill socat process for this tunnel
    sudo pkill -f "socat.*TCP-LISTEN:$TCP_PORT.*TUN:$TUNNEL_NAME" 2>/dev/null
    
    # Remove GRE interface
    sudo ip link del $TUNNEL_NAME 2>/dev/null
    
    # Remove iptables rules with this tunnel's comments
    sudo iptables-save | grep -v "$TUNNEL_NAME" | sudo iptables-restore
    
    # Remove IPSec connection
    if [ -f "/etc/ipsec.conf" ]; then
        sudo sed -i "/conn $TUNNEL_NAME/,/auto=add/d" /etc/ipsec.conf
    fi
    
    if [ -f "/etc/ipsec.secrets" ]; then
        sudo sed -i "/@local-$TUNNEL_NAME/d" /etc/ipsec.secrets
    fi
    
    # Restart strongswan if there are remaining tunnels
    if [ -d "$CONFIG_DIR" ] && [ "$(ls -A $CONFIG_DIR)" ]; then
        sudo systemctl restart strongswan
    else
        sudo systemctl stop strongswan 2>/dev/null
        sudo systemctl disable strongswan 2>/dev/null
    fi
}

install_scripts() {
    # Install bbr.sh
    wget -N --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh && chmod +x bbr.sh && bash bbr.sh
    
    # Install tcp.sh
    wget -N --no-check-certificate "https://raw.githubusercontent.com/chiakge/Linux-NetSpeed/master/tcp.sh" && chmod +x tcp.sh
    
    # Run tcp.sh with specific inputs
    echo -e "10\n" | ./tcp.sh
    echo "4" | ./tcp.sh
    
    read -p "Press Enter to return to menu..." && show_menu
}

# Create systemd service template
create_service_template() {
    sudo bash -c "cat > $SERVICE_FILE" << 'EOL'
[Unit]
Description=TCP Tunnel for %I
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'source /etc/fou_tunnel/%I.conf && exec socat TCP-LISTEN:$TCP_PORT,fork,reuseaddr TUN:%I,up'
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL
}

# Main execution
create_service_template
show_menu