
#!/bin/bash

# Function to check and install GOST if missing
check_and_install_gost() {
    if ! command -v gost &> /dev/null; then
        echo -e "\033[1;31m? GOST is not installed!\033[0m"
        install_gost
    fi
}
# Show GOST version
gost_version=$(gost -V 2>&1)

# Main Menu Function
main_menu() {
    while true; do
        clear
        echo -e "\033[1;32m===================================\033[0m"
        echo -e "          \033[1;36mGOST Management Menu\033[0m"
        echo -e "\033[1;32m===================================\033[0m"

        echo -e " \033[1;34m1.\033[0m Install GOST"
        echo -e " \033[1;34m2.\033[0m forwarding mode (SSH,h2,gRPC,WSS,WS,QUIC,KCP)"
        echo -e " \033[1;34m3.\033[0m rely mode (SSH,h2,gRPC,WSS,WS,QUIC,KCP)"
        echo -e " \033[1;34m4.\033[0m simple port forwarding (TCP/UDP)"
        echo -e " \033[1;34m5.\033[0m Manage Tunnels Services"
        echo -e " \033[1;34m6.\033[0m Remove GOST"
        echo -e " \033[1;31m0. Exit\033[0m"
        echo -e "\033[1;32m===================================\033[0m"

        read -p "Please select an option: " option

        case $option in
            1) install_gost ;;
            2) configure_port_forwarding;;
            3) configure_relay ;;
            4) tcpudp_forwarding ;;
            5) select_service_to_manage ;;
            6) remove_gost ;;
            
            0) 
                echo -e "\033[1;31mExiting... Goodbye!\033[0m"
                exit 0
                ;;
            *) 
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                sleep 1
                ;;
        esac
    done
}


tcpudp_forwarding() {
    echo -e "\033[1;34mConfigure Port Forwarding (Client Side Only)\033[0m"

    # Ask for the protocol type
    echo -e "\033[1;33mSelect protocol type:\033[0m"
    echo -e "\033[1;32m1.\033[0m \033[1;36mTCP mode\033[0m"
    echo -e "\033[1;32m2.\033[0m \033[1;36mUDP mode\033[0m"
    read -p "Enter your choice [1-2]: " type_choice

    case $type_choice in
        1) transport="tcp" ;;
        2) transport="udp" ;;
        *) echo -e "\033[1;31mInvalid choice! Exiting...\033[0m"; return ;;
    esac

    # Ask for required inputs
    read -p "Enter remote server IP (kharej): " raddr_ip
    read -p "Enter inbound (config) port: " lport

    # Validate inputs
    if [[ -z "$raddr_ip" || -z "$lport" ]]; then
        echo -e "\033[1;31mError: All fields are required!\033[0m"
        return
    fi

    # Generate GOST_OPTIONS for TCP or UDP forwarding
    GOST_OPTIONS="-L ${transport}://:${lport}/${raddr_ip}:${lport}"

    # Prompt for a custom service name
    read -p "Enter a custom name for this service (leave blank for a random name): " service_name
    if [[ -z "$service_name" ]]; then
        service_name="gost_$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
    fi

    echo -e "\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"

    # Call the function to create the service and start it
    create_gost_service "$service_name"
    start_service "$service_name"

    read -p "Press Enter to continue..."
}

# Ensure script is run as root
check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "$(tput setaf 1)Error: You must run this script as root!$(tput sgr0)"
        exit 1
    fi
}

# Fetch the latest GOST releases from GitHub
fetch_gost_versions() {
    releases=$(curl -s https://api.github.com/repos/ginuerzh/gost/releases | jq -r '.[].tag_name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$')
    if [[ -z "$releases" ]]; then
        echo -e "\033[1;31m? Error: Unable to fetch releases from GitHub!\033[0m"
        exit 1
    fi
    echo "$releases"
}

install_gost() {
    check_root

    # Install dependencies
    echo "Installing wget and nano..."
    sudo apt install wget nano -y

    # Fetch and display versions
    versions=$(fetch_gost_versions)
    if [[ -z "$versions" ]]; then
        echo -e "\033[1;31m? No releases found! Exiting...\033[0m"
        exit 1
    fi

    # Display available versions
    echo -e "\n\033[1;34mAvailable GOST versions:\033[0m"
    select version in $versions; do
        if [[ -n "$version" ]]; then
            echo -e "\033[1;32mYou selected: $version\033[0m"
            break
        else
            echo -e "\033[1;31m? Invalid selection! Please select a valid version.\033[0m"
        fi
    done

    # Define the correct GOST binary URL format
    download_url="https://github.com/ginuerzh/gost/releases/download/$version/gost_${version//v/}_linux_amd64.tar.gz"

    # Check if the URL is valid by testing with curl
    echo "Checking URL: $download_url"
    if ! curl --head --silent --fail "$download_url" > /dev/null; then
        echo -e "\033[1;31m? The release URL does not exist! Please check the release version.\033[0m"
        exit 1
    fi

    # Download and install the selected GOST version
    echo "Downloading GOST $version..."
    if ! sudo wget -q "$download_url"; then
        echo -e "\033[1;31m? Failed to download GOST! Exiting...\033[0m"
        exit 1
    fi

    # Extract the downloaded file
    echo "Extracting GOST..."
    if ! sudo tar -xvzf "gost_${version//v/}_linux_amd64.tar.gz"; then
        echo -e "\033[1;31m? Failed to extract GOST! Exiting...\033[0m"
        exit 1
    fi

    # Move the binary to /usr/local/bin and make it executable
    echo "Installing GOST..."
    sudo mv gost /usr/local/bin/gost
    sudo chmod +x /usr/local/bin/gost

    # Verify the installation
    if [[ -f /usr/local/bin/gost ]]; then
        echo -e "\033[1;32mGOST $version installed successfully!\033[0m"
    else
        echo -e "\033[1;31mError: GOST installation failed!\033[0m"
        exit 1
    fi

    read -p "Press Enter to continue..."
}



# Remove GOST
remove_gost() {
    check_root
    if [[ -f "/usr/local/bin/gost" ]]; then
        echo "Removing GOST..."
        rm -f /usr/local/bin/gost
        echo "GOST removed successfully!"
    else
        echo "GOST is not installed!"
    fi
    read -p "Press Enter to continue..."
}

configure_port_forwarding() {
    echo -e "\033[1;34mConfigure Port Forwarding\033[0m"

    # Ask whether the setup is for the client or server
    echo -e "\033[1;33mIs this the client or server side?\033[0m"
    echo -e "\033[1;32m1.\033[0m \033[1;36mClient Side (iran)\033[0m"
    echo -e "\033[1;32m2.\033[0m \033[1;36mServer Side (kharej)\033[0m"
    read -p "Enter your choice [1-2]: " side_choice

    case $side_choice in
        1)  # Client-side configuration
            echo -e "\033[1;33mSelect inbound (config) protocol type:\033[0m"
            echo -e "\033[1;32m1.\033[0m \033[1;36mTCP mode (grpc, xhttp, ws, tcp, etc.)\033[0m"
            echo -e "\033[1;32m2.\033[0m \033[1;36mUDP mode (WireGuard, kcp, hysteria, quic, etc.)\033[0m"
            read -p "Enter your choice [1-2]: " type_choice

            case $type_choice in
                1) transport="tcp" ;;
                2) transport="udp" ;;
                *) echo -e "\033[1;31mInvalid choice! Exiting...\033[0m"; return ;;
            esac

            echo -e "\033[1;33mSelect a protocol for communication between servers:\033[0m"
            echo -e "\033[1;32m1.\033[0m KCP"
            echo -e "\033[1;32m2.\033[0m QUIC"
            echo -e "\033[1;32m3.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m4.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m5.\033[0m gRPC"
            echo -e "\033[1;32m6.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m7.\033[0m SSH"
            read -p "Enter your choice [1-7]: " proto_choice

            # Ask for required inputs
            read -p "Enter remote server IP (kharej): " raddr_ip
            read -p "Enter servers communicate port: " raddr_port
            read -p "Enter inbound (config) port: " lport

            # Validate inputs
            if [[ -z "$raddr_ip" || -z "$raddr_port" || -z "$lport" ]]; then
                echo -e "\033[1;31mError: All fields are required!\033[0m"
                return
            fi

            # Mapping protocols
            case $proto_choice in
                1) proto="kcp" ;;
                2) proto="quic" ;;
                3) proto="ws" ;;
                4) proto="wss" ;;
                5) proto="grpc" ;;
                6) proto="h2" ;;
                7) proto="ssh" ;;
                *) echo -e "\033[1;31mInvalid protocol choice! Exiting...\033[0m"; return ;;
            esac

            # Generate GOST_OPTIONS
            GOST_OPTIONS="-L ${transport}://:${lport}/127.0.0.1:${lport} -F ${proto}://${raddr_ip}:${raddr_port}"
            ;;

        2)  # Server-side configuration
            echo -e "\033[1;33mSelect a protocol for communication between servers:\033[0m"
            echo -e "\033[1;32m1.\033[0m SSH"
            echo -e "\033[1;32m2.\033[0m KCP"
            echo -e "\033[1;32m3.\033[0m gRPC"
            echo -e "\033[1;32m4.\033[0m QUIC"
            echo -e "\033[1;32m5.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m6.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m7.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m8.\033[0m TCP"
            echo -e "\033[1;32m9.\033[0m UDP"
            read -p "Enter your choice [1-7]: " proto_choice

            read -p "Enter servers communicate port: " sport

            case $proto_choice in
                1) GOST_OPTIONS="-L ssh://:${sport}" ;;
                2) GOST_OPTIONS="-L kcp://:${sport}" ;;
                3) GOST_OPTIONS="-L grpc://:${sport}" ;;
                4) GOST_OPTIONS="-L quic://:${sport}" ;;
                5) GOST_OPTIONS="-L ws://:${sport}" ;;
                6) GOST_OPTIONS="-L wss://:${sport}" ;;
                7) GOST_OPTIONS="-L h2://:${sport}" ;;
                8) GOST_OPTIONS="-L tcp://:${sport}" ;;
                9) GOST_OPTIONS="-L udp://:${sport}" ;;
                *) echo -e "\033[1;31mInvalid protocol choice!\033[0m"; return ;;
            esac
            ;;

        *)
            echo -e "\033[1;31mInvalid choice!\033[0m"
            return
            ;;
    esac

    # Prompt for a custom service name
    read -p "Enter a custom name for this service (leave blank for a random name): " service_name
    if [[ -z "$service_name" ]]; then
        service_name="gost_$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
    fi

    echo -e "\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"

    # Call the function to create the service and start it
    create_gost_service "$service_name"
    start_service "$service_name"

    read -p "Press Enter to continue..."
}





configure_relay() {
      echo -e "\033[1;33mIs this the client or server side?\033[0m"
      echo -e "\033[1;32m[1]\033[0m \033[1;36mServer-Side (Kharej) - Remote server\033[0m"
      echo -e "\033[1;32m[2]\033[0m \033[1;36mClient-Side (Iran) - Local machine\033[0m"
      read -p $'\033[1;33mEnter your choice [1-2]: \033[0m' side_choice


    case $side_choice in
        1)
            # Server-side configuration
            echo -e "\n\033[1;34m Configure Server-Side (Kharej)\033[0m"
            read -p $'\033[1;33m Enter server communication port: \033[0m' lport_relay
            
            # Ask for the transmission type
            echo -e "\n\033[1;34mSelect Transmission Type for Communication:\033[0m"
            echo -e "\033[1;32m[1]\033[0m \033[1;36mKCP\033[0m"
            echo -e "\033[1;32m[2]\033[0m \033[1;36mQUIC\033[0m"
            echo -e "\033[1;32m[3]\033[0m \033[1;36mWS (WebSocket)\033[0m"
            echo -e "\033[1;32m[4]\033[0m \033[1;36mWSS (WebSocket Secure)\033[0m"
            echo -e "\033[1;32m[5]\033[0m \033[1;36mgRPC\033[0m"
            echo -e "\033[1;32m[6]\033[0m \033[1;36mh2 (HTTP/2)\033[0m"
            echo -e "\033[1;32m[7]\033[0m \033[1;36mSSH\033[0m"
            
            read -p $'\033[1;33m? Enter your choice [1-7]: \033[0m' trans_choice


            case $trans_choice in
                1) TRANSMISSION="kcp" ;;
                2) TRANSMISSION="quic" ;;
                3) TRANSMISSION="ws" ;;
                4) TRANSMISSION="wss" ;;
                5) TRANSMISSION="grpc" ;;
                6) TRANSMISSION="h2" ;;
                7) TRANSMISSION="ssh" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; TRANSMISSION="tcp" ;;
            esac

            GOST_OPTIONS="-L relay+${TRANSMISSION}://:${lport_relay}"

            read -p "Enter a custom name for this service (leave blank for a random name): " service_name
            [[ -z "$service_name" ]] && service_name=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)

            echo -e "\033[1;32mCreating Gost service for ${service_name}...\033[0m"
            create_gost_service "$service_name"
            start_service "$service_name"
            read -p "Press Enter to continue..."
            ;;
        
        2)
            # Client-side configuration
            echo -e "\n\033[1;34mConfigure Client-Side (Iran)\033[0m"
            read -p $'\033[1;33mEnter inbound (config) port: \033[0m' lport_client
            read -p $'\033[1;33mEnter remote server IP (kharej): \033[0m' relay_ip
            read -p $'\033[1;33mEnter servers communicate port: \033[0m' relay_port
            
            # Select listen type (TCP/UDP)
            echo -e "\n\033[1;34mSelect Listen Type:\033[0m"
            echo -e "\033[1;32m[1]\033[0m \033[1;36mTCP mode\033[0m (gRPC, XHTTP, WS, TCP, etc.)"
            echo -e "\033[1;32m[2]\033[0m \033[1;36mUDP mode\033[0m (WireGuard, KCP, Hysteria, QUIC, etc.)"
            
            read -p $'\033[1;33mEnter listen transmission type [1-2]: \033[0m' listen_choice

            
            case $listen_choice in
                1) LISTEN_TRANSMISSION="tcp" ;;
                2) LISTEN_TRANSMISSION="udp" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; LISTEN_TRANSMISSION="tcp" ;;
            esac

            # Select relay transmission type
            echo -e "\n\033[1;34mSelect Relay Transmission Type:\033[0m"
            echo -e "\033[1;32m[1]\033[0m \033[1;36mKCP\033[0m"
            echo -e "\033[1;32m[2]\033[0m \033[1;36mQUIC\033[0m"
            echo -e "\033[1;32m[3]\033[0m \033[1;36mWS (WebSocket)\033[0m"
            echo -e "\033[1;32m[4]\033[0m \033[1;36mWSS (WebSocket Secure)\033[0m"
            echo -e "\033[1;32m[5]\033[0m \033[1;36mgRPC\033[0m"
            echo -e "\033[1;32m[6]\033[0m \033[1;36mh2 (HTTP/2)\033[0m"
            echo -e "\033[1;32m[7]\033[0m \033[1;36mSSH\033[0m"
            
            read -p $'\033[1;33m?? Enter your choice for relay transmission type [1-7]: \033[0m' trans_choice

            
            case $trans_choice in
                1) TRANSMISSION="kcp" ;;
                2) TRANSMISSION="quic" ;;
                3) TRANSMISSION="ws" ;;
                4) TRANSMISSION="wss" ;;
                5) TRANSMISSION="grpc" ;;
                6) TRANSMISSION="h2" ;;
                7) TRANSMISSION="ssh" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; TRANSMISSION="tcp" ;;
            esac

            # Corrected the `-L` and `-F` parameters
            GOST_OPTIONS="-L ${LISTEN_TRANSMISSION}://:${lport_client}/127.0.0.1:${lport_client} -F relay+${TRANSMISSION}://${relay_ip}:${relay_port}"

            read -p "Enter a custom name for this service (leave blank for a random name): " service_name
            [[ -z "$service_name" ]] && service_name=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 6)

            echo -e "\033[1;32mCreating Gost service for ${service_name}...\033[0m"
            create_gost_service "$service_name"
            start_service "$service_name"
            read -p "Press Enter to continue..."
            ;;
        
        *)
            echo -e "\033[1;31mInvalid choice! Exiting.\033[0m"
            ;;
    esac
}



# Function to create a service for Gost (port forwarding or relay mode)
create_gost_service() {
    local service_name=$1
    echo -e "\033[1;34mCreating Gost service for $service_name...\033[0m"

    # Create the systemd service file
    cat <<EOF > /etc/systemd/system/gost-${service_name}.service
[Unit]
Description=GOST ${service_name} Service
After=network.target

[Service]
ExecStart=/usr/local/bin/gost ${GOST_OPTIONS}
Environment="GOST_LOGGER_LEVEL=fatal"
StandardOutput=null
StandardError=null
Restart=always
User=root
WorkingDirectory=/root
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd to recognize the new service
    systemctl daemon-reload
    sleep 1
}

# Function to start the service
start_service() {
    local service_name=$1
    echo -e "\033[1;32mStarting $service_name service...\033[0m"
    systemctl start gost-${service_name}
    systemctl enable gost-${service_name}  # Ensure it starts on boot
    systemctl status gost-${service_name}
    sleep 1
}


# **Function to Select a Service to Manage**
select_service_to_manage() {
    # Get a list of all GOST service files in /etc/systemd/system/ directory
    gost_services=($(find /etc/systemd/system/ -maxdepth 1 -name 'gost*.service' | sed 's/\/etc\/systemd\/system\///'))

    if [ ${#gost_services[@]} -eq 0 ]; then
        echo -e "\033[1;31mNo GOST services found in /etc/systemd/system/!\033[0m"
        read -p "Press Enter to continue..."
        return
    fi

    echo -e "\033[1;34mSelect a GOST service to manage:\033[0m"
    select service_name in "${gost_services[@]}"; do
        if [[ -n "$service_name" ]]; then
            echo -e "\033[1;32mYou selected: $service_name\033[0m"
            # Call a function to manage the selected service's action (start, stop, etc.)
            manage_service_action "$service_name"
            break
        else
            echo -e "\033[1;31mInvalid selection. Please choose a valid service.\033[0m"
        fi
    done
}


# **Function to Perform Actions (start, stop, restart, etc.) on Selected Service**
manage_service_action() {
    local service_name=$1

    while true; do
        clear
        echo -e "\n\033[1;34m==============================\033[0m"
        echo -e "    \033[1;36mManage Service: $service_name\033[0m"
        echo -e "\033[1;34m==============================\033[0m"
        echo -e " \033[1;34m1.\033[0m Start the Service"
        echo -e " \033[1;34m2.\033[0m Stop the Service"
        echo -e " \033[1;34m3.\033[0m Restart the Service"
        echo -e " \033[1;34m4.\033[0m Check Service Status"
        echo -e " \033[1;34m5.\033[0m Remove the Service"
        echo -e " \033[1;31m0.\033[0m Return"
        echo -e "\033[1;34m==============================\033[0m"

        read -p "Please select an action: " action_option

        case $action_option in
            1)
                systemctl start "$service_name" && echo -e "\033[1;32mService $service_name started.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            2)
                systemctl stop "$service_name" && echo -e "\033[1;32mService $service_name stopped.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            3)
                systemctl restart "$service_name" && echo -e "\033[1;32mService $service_name restarted.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            4)
                systemctl status "$service_name"
                read -p "Press Enter to continue..."
                ;;
            5)
                systemctl stop "$service_name"
                systemctl disable "$service_name"
                rm "/etc/systemd/system/$service_name"
                systemctl daemon-reload
                echo -e "\033[1;32mService $service_name removed.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            0)
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                sleep 2
                ;;
        esac
    done
}



# Start the main menu
check_and_install_gost
main_menu
