#!/bin/bash
clear
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\033[1;31mError:\033[0m This script must be run as root."
        exit 1
    fi
}
# Function to check and install GOST if missing
check_and_install_gost() {
    if [[ ! -f /usr/local/bin/gost ]]; then
        echo -e "\033[1;31m? GOST is not installed!\033[0m"
        install_gost
    else
        echo -e "\033[1;32m✓ GOST is already installed.\033[0m"
    fi
}


# Check if GOST is installed and get its version
if command -v gost &> /dev/null; then
    gost_version=$(gost -V 2>&1)
else
    gost_version="GOST not installed"
fi

# Main Menu Function
main_menu() {
    while true; do
        clear
        echo -e "\033[1;32mTransmission:\033[0m SSH,h2,gRPC,WSS,WS,QUIC,KCP,TLS,MWSS,H2C,OBFS4,OHTTP,OTLS,MTL "
        echo -e "\033[1;32mTip:\033[0m You can create infinite tunnels"
        echo -e "\033[1;32mgost version:\033[0m ${gost_version}"
        echo -e "\033[1;32m===================================\033[0m"
        echo -e "          \033[1;36mGOST Management Menu\033[0m"
        echo -e "\033[1;32m===================================\033[0m"
        echo -e " \033[1;34m1.\033[0m Install GOST"
        echo -e " \033[1;34m2.\033[0m Basic Transmission (multi-port) "
        echo -e " \033[1;34m3.\033[0m rely + Transmission (multi-port) "
        echo -e " \033[1;34m4.\033[0m forward + Transmissions (single port) "
        echo -e " \033[1;34m5.\033[0m simple port forward (only client-side) (multi-port)"
        echo -e " \033[1;34m6.\033[0m Manage Tunnels Services"
        echo -e " \033[1;34m7.\033[0m Remove GOST"
        
        echo -e " \033[1;31m0. Exit\033[0m"
        echo -e "\033[1;32m===================================\033[0m"

        read -p "Please select an option: " option

        case $option in
            1) install_gost ;;
            2) configure_port_forwarding;;
            3) configure_relay ;;
            4) configure_forward ;;
            5) tcpudp_forwarding ;;
            8) configure_sni ;;
            6) select_service_to_manage ;;
            7) remove_gost ;;
            
            
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
    echo -e "\033[1;34mConfigure Multi-Port Forwarding (Client Side Only)\033[0m"

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
    read -p "Enter inbound (config) ports (comma-separated, e.g., 8080,9090): " lports

    # Validate inputs
    if [[ -z "$raddr_ip" || -z "$lports" ]]; then
        echo -e "\033[1;31mError: All fields are required!\033[0m"
        return
    fi
    
    # Check if input is an IPv6 address and format it properly
    if [[ $raddr_ip =~ : ]]; then
        raddr_ip="[$raddr_ip]"
    fi
    
    echo "Formatted IP: $raddr_ip"

    # Ask about connection stability
    echo -e "\n\033[1;34m🔧 Connection Stability\033[0m"
    echo -e "Do you have an unstable connection or frequent disconnections?"
    echo -e "\033[1;32m1.\033[0m \033[1;36mYes - I need stability options\033[0m"
    echo -e "\033[1;32m2.\033[0m \033[1;36mNo - Use default settings\033[0m"
    read -p $'\033[1;33mEnter your choice (default: 2): \033[0m' stability_choice
    stability_choice=${stability_choice:-2}
    
    # Set default values
    TIMEOUT_VALUE="30s"
    RWTIMEOUT_VALUE="30s"
    RETRY_VALUE="3"
    HEARTBEAT_VALUE="30s"
    MAXCONN_VALUE="100"
    
    # If user has unstable connection, show advanced options
    if [[ "$stability_choice" == "1" ]]; then
        echo -e "\n\033[1;34m⚡ Advanced Stability Options (for unstable connections)\033[0m"
        
        # Ask about timeout
        echo -e "\n\033[1;34mConnection Timeout:\033[0m"
        echo -e "\033[1;32m1.\033[0m Short (10 seconds - faster detection of disconnections) 🔥"
        echo -e "\033[1;32m2.\033[0m Default (30 seconds)"
        echo -e "\033[1;32m3.\033[0m Long (60 seconds - for unstable networks)"
        echo -e "\033[1;32m4.\033[0m Custom value"
        read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' timeout_choice
        timeout_choice=${timeout_choice:-1}
        
        case $timeout_choice in
            1) TIMEOUT_VALUE="10s" ;;
            2) TIMEOUT_VALUE="30s" ;;
            3) TIMEOUT_VALUE="60s" ;;
            4)
                read -p "Enter timeout in seconds (e.g., 15): " custom_timeout
                if [[ "$custom_timeout" =~ ^[0-9]+$ ]]; then
                    TIMEOUT_VALUE="${custom_timeout}s"
                else
                    echo -e "\033[1;31mInvalid input! Using 10s.\033[0m"
                    TIMEOUT_VALUE="10s"
                fi
                ;;
            *) TIMEOUT_VALUE="10s" ;;
        esac
        
        # Ask about read/write timeout
        echo -e "\n\033[1;34mRead/Write Timeout:\033[0m"
        echo -e "\033[1;32m1.\033[0m Short (15 seconds) 🔥"
        echo -e "\033[1;32m2.\033[0m Default (30 seconds)"
        echo -e "\033[1;32m3.\033[0m Same as connection timeout ($TIMEOUT_VALUE)"
        read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' rwtimeout_choice
        rwtimeout_choice=${rwtimeout_choice:-1}
        
        case $rwtimeout_choice in
            1) RWTIMEOUT_VALUE="15s" ;;
            2) RWTIMEOUT_VALUE="30s" ;;
            3) RWTIMEOUT_VALUE="$TIMEOUT_VALUE" ;;
            *) RWTIMEOUT_VALUE="15s" ;;
        esac
        
        # Ask about retry attempts
        echo -e "\n\033[1;34mRetry Attempts (reconnect on failure):\033[0m"
        echo -e "\033[1;32m1.\033[0m 5 retries (for very unstable connections) 🔥"
        echo -e "\033[1;32m2.\033[0m Infinite retry (always reconnect)"
        echo -e "\033[1;32m3.\033[0m 3 retries (normal)"
        echo -e "\033[1;32m4.\033[0m Custom retry count"
        read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' retry_choice
        retry_choice=${retry_choice:-1}
        
        case $retry_choice in
            1) RETRY_VALUE="5" ;;
            2) RETRY_VALUE="-1" ;;
            3) RETRY_VALUE="3" ;;
            4)
                read -p "Enter retry count (0 for no retry, -1 for infinite): " custom_retry
                if [[ "$custom_retry" =~ ^-?[0-9]+$ ]]; then
                    RETRY_VALUE="$custom_retry"
                else
                    echo -e "\033[1;31mInvalid input! Using 5 retries.\033[0m"
                    RETRY_VALUE="5"
                fi
                ;;
            *) RETRY_VALUE="5" ;;
        esac
        
        # Ask about heartbeat (keepalive interval)
        echo -e "\n\033[1;34mHeartbeat Interval (keepalive ping):\033[0m"
        echo -e "\033[1;32m1.\033[0m Frequent (10 seconds - faster detection) 🔥"
        echo -e "\033[1;32m2.\033[0m Default (30 seconds)"
        echo -e "\033[1;32m3.\033[0m Custom interval"
        read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' heartbeat_choice
        heartbeat_choice=${heartbeat_choice:-1}
        
        case $heartbeat_choice in
            1) HEARTBEAT_VALUE="10s" ;;
            2) HEARTBEAT_VALUE="30s" ;;
            3)
                read -p "Enter heartbeat interval in seconds (e.g., 20): " custom_heartbeat
                if [[ "$custom_heartbeat" =~ ^[0-9]+$ ]]; then
                    HEARTBEAT_VALUE="${custom_heartbeat}s"
                else
                    echo -e "\033[1;31mInvalid input! Using 10s.\033[0m"
                    HEARTBEAT_VALUE="10s"
                fi
                ;;
            *) HEARTBEAT_VALUE="10s" ;;
        esac
        
        # Ask about max connections (for mux)
        echo -e "\n\033[1;34mMax Connections (for multiplexing):\033[0m"
        echo -e "\033[1;32m1.\033[0m Low (50 connections - less resource usage) 🔥"
        echo -e "\033[1;32m2.\033[0m Default (100 connections)"
        echo -e "\033[1;32m3.\033[0m Custom value"
        read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' maxconn_choice
        maxconn_choice=${maxconn_choice:-1}
        
        case $maxconn_choice in
            1) MAXCONN_VALUE="50" ;;
            2) MAXCONN_VALUE="100" ;;
            3)
                read -p "Enter max connections: " custom_maxconn
                if [[ "$custom_maxconn" =~ ^[0-9]+$ ]]; then
                    MAXCONN_VALUE="$custom_maxconn"
                else
                    echo -e "\033[1;31mInvalid input! Using 50.\033[0m"
                    MAXCONN_VALUE="50"
                fi
                ;;
            *) MAXCONN_VALUE="50" ;;
        esac
        
        # Display recommended settings
        echo -e "\n\033[1;32m✅ Optimized for unstable connections:\033[0m"
        echo -e "   • Timeout: $TIMEOUT_VALUE (quick disconnection detection)"
        echo -e "   • Retries: $RETRY_VALUE (auto-reconnect)"
        echo -e "   • Heartbeat: $HEARTBEAT_VALUE (frequent keepalive)"
        echo -e "   • Max Connections: $MAXCONN_VALUE (lower resource usage)"
    fi

    # Basic options for all users
    echo -e "\n\033[1;34m🔧 Basic Options\033[0m"
    
    # Ask about keepAlive
    echo -e "\n\033[1;34mEnable KeepAlive?\033[0m"
    echo -e "\033[1;32m1.\033[0m Yes (Recommended for persistent connections)"
    echo -e "\033[1;32m2.\033[0m No"
    read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' keepalive_choice
    keepalive_choice=${keepalive_choice:-1}
    
    # Ask about compression
    echo -e "\n\033[1;34mEnable Compression?\033[0m"
    echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
    echo -e "\033[1;32m2.\033[0m No"
    read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
    compress_choice=${compress_choice:-1}
    
    # Ask about multiplexing
    echo -e "\n\033[1;34mEnable Multiplexing (mux)?\033[0m"
    echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
    echo -e "\033[1;32m2.\033[0m No"
    read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
    mux_choice=${mux_choice:-1}

    # Build base options
    KEEPALIVE_OPTION=""
    if [[ "$keepalive_choice" == "1" ]]; then
        KEEPALIVE_OPTION="keepAlive=true"
    fi
    
    COMPRESS_OPTION=""
    if [[ "$compress_choice" == "1" ]]; then
        COMPRESS_OPTION="compress=true"
    fi
    
    MUX_OPTION=""
    if [[ "$mux_choice" == "1" ]]; then
        MUX_OPTION="mux=true"
    fi
    
    # Build connection stability options
    TIMEOUT_OPTION="timeout=${TIMEOUT_VALUE}"
    RWTIMEOUT_OPTION="rwTimeout=${RWTIMEOUT_VALUE}"
    RETRY_OPTION="retries=${RETRY_VALUE}"
    MAXCONN_OPTION="maxConnections=${MAXCONN_VALUE}"
    HEARTBEAT_OPTION="heartbeat=${HEARTBEAT_VALUE}"

    # Generate multiple GOST forwarding rules
    GOST_OPTIONS=""
    IFS=',' read -ra PORT_ARRAY <<< "$lports"
    
    for lport in "${PORT_ARRAY[@]}"; do
        # Start building the URL
        URL="${transport}://:${lport}/${raddr_ip}:${lport}?"
        
        # Build parameters string
        PARAMS=""
        
        # Add connection stability options
        PARAMS+="$TIMEOUT_OPTION"
        PARAMS+="&$RWTIMEOUT_OPTION"
        PARAMS+="&$RETRY_OPTION"
        PARAMS+="&$MAXCONN_OPTION"
        PARAMS+="&$HEARTBEAT_OPTION"
        
        # Add other options
        if [[ -n "$KEEPALIVE_OPTION" ]]; then
            PARAMS+="&$KEEPALIVE_OPTION"
        fi
        
        if [[ -n "$COMPRESS_OPTION" ]]; then
            PARAMS+="&$COMPRESS_OPTION"
        fi
        
        if [[ -n "$MUX_OPTION" ]]; then
            PARAMS+="&$MUX_OPTION"
        fi
        
        # Add the parameters to URL
        URL+="$PARAMS"
        
        GOST_OPTIONS+="-L $URL "
    done

    # Prompt for a custom service name
    read -p "Enter a custom name for this service (leave blank for a random name): " service_name
    if [[ -z "$service_name" ]]; then
        service_name="gost_$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
    fi

    echo -e "\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"
    
    # Show summary
    if [[ "$stability_choice" == "1" ]]; then
        echo -e "\n\033[1;32m📊 Connection Settings Summary:\033[0m"
        echo -e "   • Timeout: $TIMEOUT_VALUE"
        echo -e "   • Read/Write Timeout: $RWTIMEOUT_VALUE"
        echo -e "   • Retries: $RETRY_VALUE"
        echo -e "   • Heartbeat: $HEARTBEAT_VALUE"
        echo -e "   • Max Connections: $MAXCONN_VALUE"
    else
        echo -e "\n\033[1;36m📊 Using default stable connection settings\033[0m"
    fi

    # Call the function to create the service and start it
    create_gost_service "$service_name"
    start_service "$service_name"

    read -p "Press Enter to continue..."
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
# Fetch the latest GOST releases from GitHub
fetch_gost_versions3() {
    releases=$(curl -s https://api.github.com/repos/go-gost/gost/releases | jq -r '.[].tag_name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$')
    if [[ -z "$releases" ]]; then
        echo -e "\033[1;31m? Error: Unable to fetch releases from GitHub!\033[0m"
        exit 1
    fi
    echo "$releases"
}

install_gost() {
    check_root

    while true; do
        echo -e "\033[1;34mSelect which version of GOST to install:\033[0m"
        echo -e "1) GOST 2"
        echo -e "2) GOST 3"
        echo -e "0) Return to the main menu"
        read -p "Enter your choice: " choice

        case "$choice" in
            1) install_gost2; break ;;
            2) install_gost3; break ;;
            0) return ;;
            *) echo -e "\033[1;31mInvalid choice! Please select a valid option.\033[0m" ;;
        esac
    done
}


install_gost2() {
    check_root

    # Install dependencies
    echo "Installing wget and nano..."
    sudo apt install wget unzip nano lsof -y

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


install_gost3() {
    check_root

    # Install dependencies
    echo "Installing wget and nano..."
    sudo apt install wget unzip nano lsof -y

   repo="go-gost/gost"
base_url="https://api.github.com/repos/$repo/releases"

# Function to download and install gost
install_gost() {
    version=$1
    # Detect the operating system
    if [[ "$(uname)" == "Linux" ]]; then
        os="linux"
    elif [[ "$(uname)" == "Darwin" ]]; then
        os="darwin"
    elif [[ "$(uname)" == "MINGW"* ]]; then
        os="windows"
    else
        echo "Unsupported operating system."
        exit 1
    fi

    # Detect the CPU architecture
    arch=$(uname -m)
    case $arch in
    x86_64)
        cpu_arch="amd64"
        ;;
    armv5*)
        cpu_arch="armv5"
        ;;
    armv6*)
        cpu_arch="armv6"
        ;;
    armv7*)
        cpu_arch="armv7"
        ;;
    aarch64)
        cpu_arch="arm64"
        ;;
    i686)
        cpu_arch="386"
        ;;
    mips64*)
        cpu_arch="mips64"
        ;;
    mips*)
        cpu_arch="mips"
        ;;
    mipsel*)
        cpu_arch="mipsle"
        ;;
    *)
        echo "Unsupported CPU architecture."
        exit 1
        ;;
    esac
    get_download_url="$base_url/tags/$version"
    download_url=$(curl -s "$get_download_url" | grep -Eo "\"browser_download_url\": \".*${os}.*${cpu_arch}.*\"" | awk -F'["]' '{print $4}')

    # Download the binary
    echo "Downloading gost version $version..."
    curl -fsSL -o gost.tar.gz $download_url

    # Extract and install the binary
    echo "Installing gost..."
    tar -xzf gost.tar.gz
    chmod +x gost
    mv gost /usr/local/bin/gost

    echo "gost installation completed!"
}

# Retrieve available versions from GitHub API
versions=$(curl -s "$base_url" | grep -oP 'tag_name": "\K[^"]+')

# Check if --install option provided
if [[ "$1" == "--install" ]]; then
    # Install the latest version automatically
    latest_version=$(echo "$versions" | head -n 1)
    install_gost $latest_version
else
    # Display available versions to the user
    echo "Available gost versions:"
    select version in $versions; do
        if [[ -n $version ]]; then
            install_gost $version
            break
        else
            echo "Invalid choice! Please select a valid option."
        fi
    done
fi

    read -p "Press Enter to continue..."
}


# Remove GOST
remove_gost() {
    check_root

    if [[ -f "/usr/local/bin/gost" ]]; then
        read -rp "Are you sure you want to remove GOST? [y/N]: " confirm
        case "$confirm" in
            [yY]|[yY][eE][sS])
                echo "Removing GOST..."
                rm -f /usr/local/bin/gost
                echo "GOST removed successfully!"
                ;;
            *)
                echo "Operation cancelled."
                ;;
        esac
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
            # Select inbound transport protocol
            echo -e "\033[1;33mSelect inbound (config) protocol type:\033[0m"
            echo -e "\033[1;32m1.\033[0m \033[1;36mTCP mode (grpc, xhttp, ws, tcp, etc.)\033[0m"
            echo -e "\033[1;32m2.\033[0m \033[1;36mUDP mode (WireGuard, kcp, hysteria, quic, etc.)\033[0m"
            read -p "Enter your choice [1-2]: " type_choice
            
            case $type_choice in
                1) transport="tcp" ;;
                2) transport="udp" ;;
                *) echo -e "\033[1;31mInvalid choice! Exiting...\033[0m"; return ;;
            esac
            
            # Select server communication protocol
            echo -e "\033[1;33mSelect a protocol for communication between servers:\033[0m"
            echo -e "\033[1;32m1.\033[0m KCP"
            echo -e "\033[1;32m2.\033[0m QUIC"
            echo -e "\033[1;32m3.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m4.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m5.\033[0m gRPC"
            echo -e "\033[1;32m6.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m7.\033[0m SSH"
            echo -e "\033[1;32m8.\033[0m TLS"
            echo -e "\033[1;32m9.\033[0m MWSS (Multiplex Websocket)"
            echo -e "\033[1;32m10.\033[0m h2c (HTTP2 Cleartext)"
            echo -e "\033[1;32m11.\033[0m OBFS4"
            echo -e "\033[1;32m12.\033[0m ohttp (HTTP Obfuscation)"
            echo -e "\033[1;32m13.\033[0m otls (TLS Obfuscation)"
            echo -e "\033[1;32m14.\033[0m mtls (Multiplex TLS)"
            echo -e "\033[1;32m15.\033[0m mws (Multiplex Websocket)"
            echo -e "\033[1;32m16.\033[0m icmp (ping tunnel)"
            #echo -e "\033[1;32m17.\033[0m sni+host (Host obfuscation)"
            read -p "Enter your choice: " proto_choice
            
            # Ask for required inputs
            read -p "Enter remote server IP (kharej): " raddr_ip
            
            # Check if input is an IPv6 address and format it properly
            if [[ $raddr_ip =~ : ]]; then
                raddr_ip="[$raddr_ip]"
            fi
            
            echo "Formatted IP: $raddr_ip"
            
            # Prompt the user for the server communication port
            while true; do
                read -p "Enter server communication port (default: 9001): " raddr_port
                raddr_port=${raddr_port:-9001}
                
                # Check if the entered port is numeric and validate it
                if ! [[ "$raddr_port" =~ ^[0-9]+$ ]]; then
                    echo "Invalid input! Please enter a valid numeric port."
                    continue
                fi
                
                # Check if the port is already in use
                if is_port_used $raddr_port; then
                    echo "Port $raddr_port is already in use. Please enter a different port."
                else
                    echo "Port $raddr_port is available."
                    break  # Exit the loop if the port is free
                fi
            done

            # Prompt the user for inbound ports
            while true; do
                read -p "Enter inbound (config) ports (comma-separated, e.g., 1234,5678): " lports
                
                # Convert the comma-separated input into an array
                IFS=',' read -ra lport_array <<< "$lports"
                
                # Flag to track if all ports are available
                all_ports_available=true
                
                # Check each port to see if it is in use
                for port in "${lport_array[@]}"; do
                    # Validate if the port is numeric
                    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
                        echo "Invalid port: $port. Please enter valid numeric ports."
                        all_ports_available=false
                        break
                    fi
                    
                    # Check if the port is already in use
                    if is_port_used $port; then
                        echo "Port $port is already in use. Please enter a different port."
                        all_ports_available=false
                        break
                    fi
                done
                
                # If all ports are available, break out of the loop
                if $all_ports_available; then
                    echo "All ports are available: ${lport_array[*]}"
                    break
                fi
            done

            # Validate inputs
            if [[ -z "$raddr_ip" || -z "$raddr_port" || -z "$lports" ]]; then
                echo -e "\033[1;31mError: All fields are required!\033[0m"
                return
            fi
            
            # Mapping protocols - using + prefix for most protocols
            case $proto_choice in
                1) proto="kcp" ;;
                2) proto="quic" ;;
                3) proto="ws" ;;
                4) proto="wss" ;;
                5) proto="grpc" ;;
                6) proto="h2" ;;
                7) proto="ssh" ;;
                8) proto="tls" ;;
                9) proto="mwss" ;;
                10) proto="h2c" ;;
                11) proto="obfs4" ;;
                12) proto="ohttp" ;;
                13) proto="otls" ;;
                14) proto="mtls" ;;
                15) proto="mws" ;;
                16) proto="icmp" ;;
                *) echo -e "\033[1;31mInvalid protocol choice! Exiting...\033[0m"; return ;;
            esac
            
            # Ask about compression
            echo -e "\n\033[1;34mEnable Compression?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing
            echo -e "\n\033[1;34mEnable Multiplexing (mux)?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}
            
            # Ask about keepAlive
            echo -e "\n\033[1;34mEnable KeepAlive?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for persistent connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' keepalive_choice
            keepalive_choice=${keepalive_choice:-1}

            # Build parameters string
            PARAMS=""
            if [[ "$keepalive_choice" == "1" ]]; then
                PARAMS+="keepAlive=true"
            fi
            
            if [[ "$compress_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="compress=true"
            fi
            
            if [[ "$mux_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="mux=true"
            fi
            
            # Generate multiple `-L` options
            GOST_OPTIONS=""
            IFS=',' read -ra PORT_ARRAY <<< "$lports"
            for port in "${PORT_ARRAY[@]}"; do
                port=$(echo "$port" | xargs) # Trim spaces
                if [[ -n "$port" ]]; then
                    GOST_OPTIONS+=" -L ${transport}://:${port}/127.0.0.1:${port}"
                fi
            done
            
            # Add the -F option with parameters
            if [[ -n "$PARAMS" ]]; then
                GOST_OPTIONS+=" -F ${proto}://${raddr_ip}:${raddr_port}?${PARAMS}"
            else
                GOST_OPTIONS+=" -F ${proto}://${raddr_ip}:${raddr_port}"
            fi
            
            # Display the final GOST command
            echo -e "\033[1;34mGenerated GOST command:\033[0m"
            echo "gost $GOST_OPTIONS"
            ;;

        2)  # Server-side configuration
            # Select server communication protocol
            echo -e "\033[1;33mSelect a protocol for communication between servers:\033[0m"
            echo -e "\033[1;32m1.\033[0m KCP"
            echo -e "\033[1;32m2.\033[0m QUIC"
            echo -e "\033[1;32m3.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m4.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m5.\033[0m gRPC"
            echo -e "\033[1;32m6.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m7.\033[0m SSH"
            echo -e "\033[1;32m8.\033[0m TLS"
            echo -e "\033[1;32m9.\033[0m MWSS (Multiplex Websocket)"
            echo -e "\033[1;32m10.\033[0m h2c (HTTP2 Cleartext)"
            echo -e "\033[1;32m11.\033[0m OBFS4"
            echo -e "\033[1;32m12.\033[0m ohttp (HTTP Obfuscation)"
            echo -e "\033[1;32m13.\033[0m otls (TLS Obfuscation)"
            echo -e "\033[1;32m14.\033[0m mtls (Multiplex TLS)"
            echo -e "\033[1;32m15.\033[0m mws (Multiplex Websocket)"
            echo -e "\033[1;32m16.\033[0m icmp (ping tunnel)"
            read -p "Enter your choice: " proto_choice
            
            # Mapping protocols for server-side
            case $proto_choice in
                1) proto="kcp" ;;
                2) proto="quic" ;;
                3) proto="ws" ;;
                4) proto="wss" ;;
                5) proto="grpc" ;;
                6) proto="h2" ;;
                7) proto="ssh" ;;
                8) proto="tls" ;;
                9) proto="mwss" ;;
                10) proto="h2c" ;;
                11) proto="obfs4" ;;
                12) proto="ohttp" ;;
                13) proto="otls" ;;
                14) proto="mtls" ;;
                15) proto="mws" ;;
                16) proto="icmp" ;;
                *) echo -e "\033[1;31mInvalid protocol choice!\033[0m"; return ;;
            esac
            
            # Prompt the user for the server communication port
            while true; do
                read -p "Enter server communication port (default: 9001): " sport
                sport=${sport:-9001}
                # Check if the entered port is numeric and validate it
                if ! [[ "$sport" =~ ^[0-9]+$ ]]; then
                    echo "Invalid input! Please enter a valid numeric port."
                    continue
                fi
                
                # Check if the port is already in use
                if is_port_used $sport; then
                    echo "Port $sport is already in use. Please enter a different port."
                else
                    echo "Port $sport is available."
                    break  # Exit the loop if the port is free
                fi
            done
            
            # Ask about compression for server side
            echo -e "\n\033[1;34mEnable Compression?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing for server side
            echo -e "\n\033[1;34mEnable Multiplexing (mux)?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}
            
            # Ask about bind (only for server side)
            echo -e "\n\033[1;34mEnable Bind?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Bind to all interfaces)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' bind_choice
            bind_choice=${bind_choice:-1}
            
            # Ask about keepAlive for server side
            echo -e "\n\033[1;34mEnable KeepAlive?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for persistent connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' keepalive_choice
            keepalive_choice=${keepalive_choice:-1}

            # Build GOST options for server side
            GOST_OPTIONS="-L ${proto}://:${sport}"
            
            # Build parameters string
            PARAMS=""
            if [[ "$bind_choice" == "1" ]]; then
                PARAMS+="bind=true"
            fi
            
            if [[ "$keepalive_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="keepAlive=true"
            fi
            
            if [[ "$compress_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="compress=true"
            fi
            
            if [[ "$mux_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="mux=true"
            fi
            
            # Add parameters if any
            if [[ -n "$PARAMS" ]]; then
                GOST_OPTIONS+="?${PARAMS}"
            fi
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
    echo -e "\033[1;32m1.\033[0m \033[1;36mServer-Side (Kharej)\033[0m"
    echo -e "\033[1;32m2.\033[0m \033[1;36mClient-Side (Iran)\033[0m"
    read -p $'\033[1;33mEnter your choice: \033[0m' side_choice

    case $side_choice in
        1)
            # Server-side configuration
            echo -e "\n\033[1;34m Configure Server-Side (Kharej)\033[0m"

            # Prompt the user for a port until a free one is provided
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' lport_relay
                lport_relay=${lport_relay:-9001}
                if is_port_used $lport_relay; then
                    echo -e "\033[1;31mPort $lport_relay is already in use. Please enter a different port.\033[0m"
                else
                    echo -e "\033[1;32mPort $lport_relay is available.\033[0m"
                    break  # Exit the loop if the port is free
                fi
            done
            
            # Ask for the transmission type
            echo -e "\n\033[1;34mSelect Transmission Type for Communication:\033[0m"
            echo -e "\033[1;32m1.\033[0m KCP"
            echo -e "\033[1;32m2.\033[0m QUIC"
            echo -e "\033[1;32m3.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m4.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m5.\033[0m gRPC"
            echo -e "\033[1;32m6.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m7.\033[0m SSH"
            echo -e "\033[1;32m8.\033[0m tls (TLS)"
            echo -e "\033[1;32m9.\033[0m mwss (Multiplex Websocket)"
            echo -e "\033[1;32m10.\033[0m h2c (HTTP2 Cleartext)"
            echo -e "\033[1;32m11.\033[0m obfs4 (OBFS4)"
            echo -e "\033[1;32m12.\033[0m ohttp (HTTP Obfuscation)"
            echo -e "\033[1;32m13.\033[0m otls (TLS Obfuscation)"
            echo -e "\033[1;32m14.\033[0m mtls (Multiplex TLS)"
            echo -e "\033[1;32m15.\033[0m mws (Multiplex Websocket)"
            echo -e "\033[1;32m16.\033[0m icmp (ping tunnel)"
            echo -e "\033[1;32m17.\033[0m relay"
            read -p $'\033[1;33m? Enter your choice: \033[0m' trans_choice

            case $trans_choice in
                1) TRANSMISSION="+kcp" ;;
                2) TRANSMISSION="+quic" ;;
                3) TRANSMISSION="+ws" ;;
                4) TRANSMISSION="+wss" ;;
                5) TRANSMISSION="+grpc" ;;
                6) TRANSMISSION="+h2" ;;
                7) TRANSMISSION="+ssh" ;;
                8) TRANSMISSION="+tls" ;;
                9) TRANSMISSION="+mwss" ;;
                10) TRANSMISSION="+h2c" ;;
                11) TRANSMISSION="+obfs4" ;;
                12) TRANSMISSION="+ohttp" ;;
                13) TRANSMISSION="+otls" ;;
                14) TRANSMISSION="+mtls" ;;
                15) TRANSMISSION="+mws" ;;
                16) TRANSMISSION="+icmp" ;;
                17) TRANSMISSION="" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; TRANSMISSION="+tcp" ;;
            esac
            
            # Ask about bind (for server side)
            echo -e "\n\033[1;34mEnable Bind?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Bind to all interfaces)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' bind_choice
            bind_choice=${bind_choice:-1}
            
            # Ask about keepAlive
            echo -e "\n\033[1;34mEnable KeepAlive?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for persistent connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' keepalive_choice
            keepalive_choice=${keepalive_choice:-1}
            
            # Ask about compression
            echo -e "\n\033[1;34mEnable Compression?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing
            echo -e "\n\033[1;34mEnable Multiplexing (mux)?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}

            # Build GOST options
            GOST_OPTIONS="-L relay${TRANSMISSION}://:${lport_relay}"
            
            # Build parameters string
            PARAMS=""
            if [[ "$bind_choice" == "1" ]]; then
                PARAMS+="bind=true"
            fi
            
            if [[ "$keepalive_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="keepAlive=true"
            fi
            
            if [[ "$compress_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="compress=true"
            fi
            
            if [[ "$mux_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="mux=true"
            fi
            
            # Add parameters if any
            if [[ -n "$PARAMS" ]]; then
                GOST_OPTIONS+="?${PARAMS}"
            fi

            echo -e "\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"

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
            
            # Select listen type (TCP/UDP)
            echo -e "\n\033[1;34mSelect Listen Type:\033[0m"
            echo -e "\033[1;32m1.\033[0m \033[1;36mTCP mode\033[0m (gRPC, XHTTP, WS, TCP, etc.)"
            echo -e "\033[1;32m2.\033[0m \033[1;36mUDP mode\033[0m (WireGuard, KCP, Hysteria, QUIC, etc.)"
            read -p $'\033[1;33mEnter listen transmission type: \033[0m' listen_choice
            
            case $listen_choice in
                1) LISTEN_TRANSMISSION="tcp" ;;
                2) LISTEN_TRANSMISSION="udp" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; LISTEN_TRANSMISSION="tcp" ;;
            esac
            
            # Multiple inbound ports input
            while true; do
                read -p $'\033[1;33mEnter inbound (config) ports (comma-separated, e.g., 1234,5678): \033[0m' lport
                
                # Convert the comma-separated input into an array
                IFS=',' read -ra lport_array <<< "$lport"
                
                # Flag to track if all ports are available
                all_ports_available=true
                
                # Check each port to see if it is in use
                for port in "${lport_array[@]}"; do
                    # Validate if the port is numeric
                    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
                        echo -e "\033[1;31mInvalid port: $port. Please enter valid numeric ports.\033[0m"
                        all_ports_available=false
                        break
                    fi
            
                    # Check if the port is already in use
                    if is_port_used $port; then
                        echo -e "\033[1;31mPort $port is already in use. Please enter a different port.\033[0m"
                        all_ports_available=false
                        break
                    fi
                done
                
                # If all ports are available, break out of the loop
                if $all_ports_available; then
                    echo -e "\033[1;32mAll ports are available: ${lport_array[*]}\033[0m"
                    break
                fi
            done

            read -p $'\033[1;33mEnter remote server IP (kharej): \033[0m' relay_ip
            
            # Check if input is an IPv6 address
            if [[ $relay_ip =~ : ]]; then
                relay_ip="[$relay_ip]"
            fi
            
            echo -e "\033[1;36mFormatted IP:\033[0m $relay_ip"
            
            # Prompt the user for a port until a free one is provided
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' relay_port
                relay_port=${relay_port:-9001}
                if is_port_used $relay_port; then
                    echo -e "\033[1;31mPort $relay_port is already in use. Please enter a different port.\033[0m"
                else
                    echo -e "\033[1;32mPort $relay_port is available.\033[0m"
                    break  # Exit the loop if the port is free
                fi
            done
                        
            # Select relay transmission type
            echo -e "\n\033[1;34mSelect Relay Transmission Type:\033[0m"
            echo -e "\033[1;32m1.\033[0m KCP"
            echo -e "\033[1;32m2.\033[0m QUIC"
            echo -e "\033[1;32m3.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m4.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m5.\033[0m gRPC"
            echo -e "\033[1;32m6.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m7.\033[0m SSH"
            echo -e "\033[1;32m8.\033[0m TLS"
            echo -e "\033[1;32m9.\033[0m MWSS (Multiplex Websocket)"
            echo -e "\033[1;32m10.\033[0m h2c (HTTP2 Cleartext)"
            echo -e "\033[1;32m11.\033[0m OBFS4 (OBFS4)"
            echo -e "\033[1;32m12.\033[0m oHTTP (HTTP Obfuscation)"
            echo -e "\033[1;32m13.\033[0m oTLS (TLS Obfuscation)"
            echo -e "\033[1;32m14.\033[0m mTLS (Multiplex TLS)"
            echo -e "\033[1;32m15.\033[0m MWS (Multiplex Websocket)"
            echo -e "\033[1;32m16.\033[0m icmp (ping tunnel)"
            echo -e "\033[1;32m17.\033[0m relay"
            read -p $'\033[1;33mEnter your choice for relay transmission type: \033[0m' trans_choice
            
            case $trans_choice in
                1) TRANSMISSION="+kcp" ;;
                2) TRANSMISSION="+quic" ;;
                3) TRANSMISSION="+ws" ;;
                4) TRANSMISSION="+wss" ;;
                5) TRANSMISSION="+grpc" ;;
                6) TRANSMISSION="+h2" ;;
                7) TRANSMISSION="+ssh" ;;
                8) TRANSMISSION="+tls" ;;
                9) TRANSMISSION="+mwss" ;;
                10) TRANSMISSION="+h2c" ;;
                11) TRANSMISSION="+obfs4" ;;
                12) TRANSMISSION="+ohttp" ;;
                13) TRANSMISSION="+otls" ;;
                14) TRANSMISSION="+mtls" ;;
                15) TRANSMISSION="+mws" ;;
                16) TRANSMISSION="+icmp" ;;
                17) TRANSMISSION="" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; TRANSMISSION="+tcp" ;;
            esac
            
            # Ask about keepAlive for listen ports
            echo -e "\n\033[1;34mEnable KeepAlive for local ports?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for persistent connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' listen_keepalive_choice
            listen_keepalive_choice=${listen_keepalive_choice:-1}
            
            # Ask about compression for relay
            echo -e "\n\033[1;34mEnable Compression for relay?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing for relay
            echo -e "\n\033[1;34mEnable Multiplexing (mux) for relay?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}

            # Construct multi-port -L parameters
            GOST_OPTIONS=""
            for lport in "${lport_array[@]}"; do
                # Start building the listen URL
                URL="${LISTEN_TRANSMISSION}://:${lport}/127.0.0.1:${lport}"
                
                # Add keepAlive if enabled for listen ports
                if [[ "$listen_keepalive_choice" == "1" ]]; then
                    URL+="?keepAlive=true"
                fi
                
                GOST_OPTIONS+=" -L $URL"
            done
            
            # Build parameters for relay (-F)
            PARAMS=""
            if [[ "$compress_choice" == "1" ]]; then
                PARAMS+="compress=true"
            fi
            
            if [[ "$mux_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="mux=true"
            fi
            
            # Add the -F option with parameters
            if [[ -n "$PARAMS" ]]; then
                GOST_OPTIONS+=" -F relay${TRANSMISSION}://${relay_ip}:${relay_port}?${PARAMS}"
            else
                GOST_OPTIONS+=" -F relay${TRANSMISSION}://${relay_ip}:${relay_port}"
            fi
            
            echo -e "\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"
            
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

configure_forward() {
    echo -e "\033[1;33mIs this the client or server side?\033[0m"
    echo -e "\033[1;32m1.\033[0m \033[1;36mServer-Side (Kharej)\033[0m"
    echo -e "\033[1;32m2.\033[0m \033[1;36mClient-Side (Iran)\033[0m"
    read -p $'\033[1;33mEnter your choice: \033[0m' side_choice

    case $side_choice in
        1)
            # Server-side configuration
            echo -e "\n\033[1;34m Configure Server-Side (Kharej)\033[0m"
            
            # Prompt the user for a port until a free one is provided
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' relay_port
                relay_port=${relay_port:-9001}
                if is_port_used $relay_port; then
                    echo -e "\033[1;31mPort $relay_port is already in use. Please enter a different port.\033[0m"
                else
                    echo -e "\033[1;32mPort $relay_port is available.\033[0m"
                    break  # Exit the loop if the port is free
                fi
            done
            
            # Multiple inbound ports input
            read -p $'\033[1;33mEnter inbound (config) ports (only support one port): \033[0m' lport_client
            
            # Ask for the transmission type
            echo -e "\n\033[1;34mSelect Transmission Type for Communication:\033[0m"
            echo -e "\033[1;32m1.\033[0m KCP"
            echo -e "\033[1;32m2.\033[0m QUIC"
            echo -e "\033[1;32m3.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m4.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m5.\033[0m gRPC"
            echo -e "\033[1;32m6.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m7.\033[0m SSH"
            echo -e "\033[1;32m8.\033[0m tls (TLS)"
            echo -e "\033[1;32m9.\033[0m mwss (Multiplex Websocket)"
            echo -e "\033[1;32m10.\033[0m h2c (HTTP2 Cleartext)"
            echo -e "\033[1;32m11.\033[0m obfs4 (OBFS4)"
            echo -e "\033[1;32m12.\033[0m ohttp (HTTP Obfuscation)"
            echo -e "\033[1;32m13.\033[0m otls (TLS Obfuscation)"
            echo -e "\033[1;32m14.\033[0m mtls (Multiplex TLS)"
            echo -e "\033[1;32m15.\033[0m mws (Multiplex Websocket)"
            read -p $'\033[1;33m? Enter your choice: \033[0m' trans_choice

            case $trans_choice in
                1) TRANSMISSION="kcp" ;;
                2) TRANSMISSION="quic" ;;
                3) TRANSMISSION="ws" ;;
                4) TRANSMISSION="wss" ;;
                5) TRANSMISSION="grpc" ;;
                6) TRANSMISSION="h2" ;;
                7) TRANSMISSION="ssh" ;;
                8) TRANSMISSION="tls" ;;
                9) TRANSMISSION="mwss" ;;
                10) TRANSMISSION="h2c" ;;
                11) TRANSMISSION="obfs4" ;;
                12) TRANSMISSION="ohttp" ;;
                13) TRANSMISSION="otls" ;;
                14) TRANSMISSION="mtls" ;;
                15) TRANSMISSION="mws" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; TRANSMISSION="tcp" ;;
            esac
            
            # Ask about keepAlive for server side
            echo -e "\n\033[1;34mEnable KeepAlive?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for persistent connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' keepalive_choice
            keepalive_choice=${keepalive_choice:-1}
            
            # Ask about compression for server side
            echo -e "\n\033[1;34mEnable Compression?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing for server side
            echo -e "\n\033[1;34mEnable Multiplexing (mux)?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}

            # Build GOST options
            GOST_OPTIONS="-L ${TRANSMISSION}://:${relay_port}/:${lport_client}"
            
            # Build parameters string
            PARAMS=""
            if [[ "$keepalive_choice" == "1" ]]; then
                PARAMS+="keepAlive=true"
            fi
            
            if [[ "$compress_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="compress=true"
            fi
            
            if [[ "$mux_choice" == "1" ]]; then
                if [[ -n "$PARAMS" ]]; then
                    PARAMS+="&"
                fi
                PARAMS+="mux=true"
            fi
            
            # Add parameters if any
            if [[ -n "$PARAMS" ]]; then
                GOST_OPTIONS+="?${PARAMS}"
            fi

            echo -e "\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"

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
            
            # Select listen type (TCP/UDP)
            echo -e "\n\033[1;34mSelect Listen Type:\033[0m"
            echo -e "\033[1;32m1.\033[0m \033[1;36mTCP mode\033[0m (gRPC, XHTTP, WS, TCP, etc.)"
            echo -e "\033[1;32m2.\033[0m \033[1;36mUDP mode\033[0m (WireGuard, KCP, Hysteria, QUIC, etc.)"
            read -p $'\033[1;33mEnter listen transmission type: \033[0m' listen_choice
            
            case $listen_choice in
                1) LISTEN_TRANSMISSION="tcp" ;;
                2) LISTEN_TRANSMISSION="udp" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; LISTEN_TRANSMISSION="tcp" ;;
            esac
            
            # Prompt the user for a port until a free one is provided
            while true; do
                read -p $'\033[1;33mEnter server communication port (default: 9001): \033[0m' relay_port
                relay_port=${relay_port:-9001}
                if is_port_used $relay_port; then
                    echo -e "\033[1;31mPort $relay_port is already in use. Please enter a different port.\033[0m"
                else
                    echo -e "\033[1;32mPort $relay_port is available.\033[0m"
                    break  # Exit the loop if the port is free
                fi
            done

            # Prompt the user for an inbound port until a free one is provided
            while true; do
                read -p $'\033[1;33mEnter inbound (config) port (only support one port): \033[0m' lport
                
                # Check if the entered port is numeric and validate it
                if ! [[ "$lport" =~ ^[0-9]+$ ]]; then
                    echo -e "\033[1;31mInvalid input! Please enter a valid numeric port.\033[0m"
                    continue
                fi
                
                if is_port_used $lport; then
                    echo -e "\033[1;31mPort $lport is already in use. Please enter a different port.\033[0m"
                else
                    echo -e "\033[1;32mPort $lport is available.\033[0m"
                    break  # Exit the loop if the port is free
                fi
            done

            read -p $'\033[1;33mEnter remote server IP (kharej): \033[0m' relay_ip
            
            # Check if input is an IPv6 address
            if [[ $relay_ip =~ : ]]; then
                relay_ip="[$relay_ip]"
            fi
            
            echo -e "\033[1;36mFormatted IP:\033[0m $relay_ip"
            
            # Select relay transmission type
            echo -e "\n\033[1;34mSelect Relay Transmission Type:\033[0m"
            echo -e "\033[1;32m1.\033[0m KCP"
            echo -e "\033[1;32m2.\033[0m QUIC"
            echo -e "\033[1;32m3.\033[0m WS (WebSocket)"
            echo -e "\033[1;32m4.\033[0m WSS (WebSocket Secure)"
            echo -e "\033[1;32m5.\033[0m gRPC"
            echo -e "\033[1;32m6.\033[0m h2 (HTTP/2)"
            echo -e "\033[1;32m7.\033[0m SSH"
            echo -e "\033[1;32m8.\033[0m TLS"
            echo -e "\033[1;32m9.\033[0m MWSS (Multiplex Websocket)"
            echo -e "\033[1;32m10.\033[0m h2c (HTTP2 Cleartext)"
            echo -e "\033[1;32m11.\033[0m OBFS4 (OBFS4)"
            echo -e "\033[1;32m12.\033[0m oHTTP (HTTP Obfuscation)"
            echo -e "\033[1;32m13.\033[0m oTLS (TLS Obfuscation)"
            echo -e "\033[1;32m14.\033[0m mTLS (Multiplex TLS)"
            echo -e "\033[1;32m15.\033[0m MWS (Multiplex Websocket)"
            read -p $'\033[1;33mEnter your choice for relay transmission type: \033[0m' trans_choice
            
            case $trans_choice in
                1) TRANSMISSION="kcp" ;;
                2) TRANSMISSION="quic" ;;
                3) TRANSMISSION="ws" ;;
                4) TRANSMISSION="wss" ;;
                5) TRANSMISSION="grpc" ;;
                6) TRANSMISSION="h2" ;;
                7) TRANSMISSION="ssh" ;;
                8) TRANSMISSION="tls" ;;
                9) TRANSMISSION="mwss" ;;
                10) TRANSMISSION="h2c" ;;
                11) TRANSMISSION="obfs4" ;;
                12) TRANSMISSION="ohttp" ;;
                13) TRANSMISSION="otls" ;;
                14) TRANSMISSION="mtls" ;;
                15) TRANSMISSION="mws" ;;
                *) echo -e "\033[1;31mInvalid choice! Defaulting to TCP.\033[0m"; TRANSMISSION="tcp" ;;
            esac
            
            # Ask about keepAlive for listen port
            echo -e "\n\033[1;34mEnable KeepAlive for local port?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for persistent connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' listen_keepalive_choice
            listen_keepalive_choice=${listen_keepalive_choice:-1}
            
            # Ask about compression for forward
            echo -e "\n\033[1;34mEnable Compression for forward?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for better performance)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' compress_choice
            compress_choice=${compress_choice:-1}
            
            # Ask about multiplexing for forward
            echo -e "\n\033[1;34mEnable Multiplexing (mux) for forward?\033[0m"
            echo -e "\033[1;32m1.\033[0m Yes (Recommended for multiple connections)"
            echo -e "\033[1;32m2.\033[0m No"
            read -p $'\033[1;33mEnter your choice (default: 1): \033[0m' mux_choice
            mux_choice=${mux_choice:-1}

            # Build GOST options for listen port
            GOST_OPTIONS="-L ${LISTEN_TRANSMISSION}://:${lport}"
            
            # Add keepAlive if enabled for listen port
            if [[ "$listen_keepalive_choice" == "1" ]]; then
                GOST_OPTIONS+="?keepAlive=true"
            fi
            
            # Build parameters for forward (-F)
            FORWARD_PARAMS=""
            if [[ "$compress_choice" == "1" ]]; then
                FORWARD_PARAMS+="compress=true"
            fi
            
            if [[ "$mux_choice" == "1" ]]; then
                if [[ -n "$FORWARD_PARAMS" ]]; then
                    FORWARD_PARAMS+="&"
                fi
                FORWARD_PARAMS+="mux=true"
            fi
            
            # Add the -F option with parameters
            if [[ -n "$FORWARD_PARAMS" ]]; then
                GOST_OPTIONS+=" -F forward+${TRANSMISSION}://${relay_ip}:${relay_port}?${FORWARD_PARAMS}"
            else
                GOST_OPTIONS+=" -F forward+${TRANSMISSION}://${relay_ip}:${relay_port}"
            fi
            
            echo -e "\033[1;32mGenerated GOST options:\033[0m $GOST_OPTIONS"
            
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
# Function to check if a port is already in use
is_port_used() {
    local port=$1
    if sudo lsof -i :$port >/dev/null 2>&1; then
        return 0  # Port is in use
    else
        return 1  # Port is not in use
    fi
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
Type=simple
ExecStart=/usr/local/bin/gost ${GOST_OPTIONS}
Environment="GOST_LOGGER_LEVEL=fatal"
StandardOutput=null
StandardError=null
Restart=on-failure
RestartSec=5
User=root
WorkingDirectory=/root
LimitNOFILE=1000000
LimitNPROC=10000
Nice=-20
CPUQuota=90%
LimitFSIZE=infinity
LimitCPU=infinity
LimitRSS=infinity
NoNewPrivileges=true

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
        echo -e " \033[1;34m6.\033[0m Edit the Service with nano"
        echo -e " \033[1;34m7.\033[0m Auto Restart Service (Cron)"
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
            6)
                service_file="/etc/systemd/system/$service_name"
            
                if [[ -f "$service_file" ]]; then
                    echo -e "\033[1;33mOpening $service_file for editing...\033[0m"
                    sleep 1
                    nano "$service_file"
                    systemctl daemon-reload
                    # Ask if the user wants to restart the service
                    read -p $'\033[1;33mDo you want to restart the service? [y/n] (default: y): \033[0m' restart_choice
                    restart_choice="${restart_choice:-y}"  # Default to "y" if empty
            
                    if [[ "$restart_choice" == "y" || "$restart_choice" == "yes" ]]; then
                        # Reload systemd and restart the service after editing
                        systemctl restart "$service_name"
                        echo -e "\033[1;32mService $service_name reloaded and restarted.\033[0m"
                    else
                        echo -e "\033[1;33mService $service_name was not restarted.\033[0m"
                    fi
                else
                    echo -e "\033[1;31mError: Service file not found!\033[0m"
                fi
            
                read -p "Press Enter to continue..."

                ;;
7)
    echo -e "\n\033[1;34mManage Service Cron Jobs:\033[0m"
    echo -e " \033[1;34m1.\033[0m Add/Update Cron Job"
    echo -e " \033[1;34m2.\033[0m Remove Cron Job"
    echo -e " \033[1;34m3.\033[0m Edit Cron Jobs with Nano"
    echo -e " \033[1;31m0.\033[0m Return"

    read -p "Select an option: " cron_option

    case $cron_option in
        1)
    echo -e "\n\033[1;34mChoose the restart interval type:\033[0m"
    echo -e " \033[1;34m1.\033[0m Every X minutes"
    echo -e " \033[1;34m2.\033[0m Every X hours"
    echo -e " \033[1;34m3.\033[0m Every X days"
    read -p "Select interval type (1-3): " interval_type

    case $interval_type in
        1)
            read -p "Enter the interval in minutes (1-59): " interval
            if [[ ! "$interval" =~ ^[1-9]$|^[1-5][0-9]$ ]]; then
                echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 59.\033[0m"
                break
            fi
            cron_job="*/$interval * * * * /bin/systemctl restart $service_name"
            ;;
        2)
            read -p "Enter the interval in hours (1-23): " interval
            if [[ ! "$interval" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
                echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 23.\033[0m"
                break
            fi
            cron_job="0 */$interval * * * /bin/systemctl restart $service_name"
            ;;
        3)
            read -p "Enter the interval in days (1-30): " interval
            if [[ ! "$interval" =~ ^[1-9]$|^[12][0-9]$|^30$ ]]; then
                echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 30.\033[0m"
                break
            fi
            cron_job="0 0 */$interval * * /bin/systemctl restart $service_name"
            ;;
        *)
            echo -e "\033[1;31mInvalid option! Returning...\033[0m"
            break
            ;;
    esac

    # Remove any existing cron job for this service
    (crontab -l 2>/dev/null | grep -v "/bin/systemctl restart $service_name") | crontab -

    # Add the new cron job
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

    echo -e "\033[1;32mCron job updated: Restart $service_name every $interval unit(s).\033[0m"
    ;;

        2)
            # Remove the cron job related to the service
            crontab -l 2>/dev/null | grep -v "/bin/systemctl restart $service_name" | crontab -
            echo -e "\033[1;32mCron job for $service_name removed.\033[0m"
            ;;
        3)
            echo -e "\033[1;33mOpening crontab for manual editing...\033[0m"
            sleep 1
            crontab -e
            ;;
        0)
            echo -e "\033[1;33mReturning to previous menu...\033[0m"
            ;;
        *)
            echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
            sleep 2
            ;;
    esac
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
