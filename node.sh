#!/bin/bash

set -euo pipefail

# Constants
MARZBAN_NODE_DIR=~/Marzban-node
MARZBAN_NODE_DATA_DIR="/var/lib/marzban-node"
# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color
NC="\033[0m" # No Color
echo_green() {
    echo -e "\033[1;32m$1\033[0m" # Prints text in green
}
echo_red() {
    echo -e "\033[1;31m$1\033[0m" # Prints text in red
}
echo_yellow() {
    echo -e "\033[1;33m$1\033[0m" # Prints text in yellow
}
# Function to prompt for input with default value
prompt_input() {
    local prompt="$1"
    local default_value="${2:-}"
    local prompt_text="$prompt"
    if [ -n "$default_value" ]; then
        prompt_text="$prompt_text [$default_value]"
    fi

    # Clear input buffer before prompting for input
    read -t 0.1 -n 10000 discard_input

    read -p "$prompt_text: " user_input
    echo "${user_input:-$default_value}"
}
#update_marzban_node
update_marzban_node() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m        Updating Marzban Node\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    cd $MARZBAN_NODE_DIR || { echo -e "\033[1;31mFailed to change directory to Marzban-node.\033[0m"; return; }

    echo -e "\033[1;32mPulling the latest images...\033[0m"
    docker compose pull

    echo -e "\033[1;32mStopping and removing orphaned containers...\033[0m"
    docker compose down --remove-orphans

    echo -e "\033[1;32mStarting services...\033[0m"
    docker compose up -d

    echo -e "\033[1;32mMarzban node update completed successfully.\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\nPress Enter to return to the main menu."
    read
}

# Function to set or disable custom Xray version and display the installed version
set_custom_xray_version() {

    local docker_compose_file="$MARZBAN_NODE_DIR/docker-compose.yml"
    local xray_dir="/var/lib/marzban-node/xray-core"
    local xray_binary_path="$xray_dir/xray"
    local changes_made=false

    # Check if docker-compose.yml exists
    if [ ! -f "$docker_compose_file" ]; then
        echo_red "Error: docker-compose.yml not found in $MARZBAN_NODE_DIR"
        return
    fi

    # Check if Xray directory exists
    if [ ! -d "$xray_dir" ]; then
        echo_red "Error: Xray directory not found at $xray_dir."
        echo_red "Please download custom Xray version."
        echo_yellow "Returning to the Marzban node management menu..."
        sleep 3
        manage_marzban_node  # Return to the Marzban node management menu
        return
    fi

    # Check if Xray binary exists and display its version
    if [ -f "$xray_binary_path" ]; then
        echo_yellow "Checking Xray version..."
        local xray_version
        xray_version=$("$xray_binary_path" -version 2>&1 | grep "Xray" || echo "Unknown version")
        echo_green "Installed Xray version: $xray_version"
    else
        echo_red "Xray binary not found at $xray_binary_path."
        echo_red "Ensure Xray is installed correctly."
        echo_yellow "Returning to the Marzban node management menu..."
        sleep 3
        manage_marzban_node  # Return to the Marzban node management menu
        return
    fi

    # Check if XRAY_EXECUTABLE_PATH is set in docker-compose.yml
    if grep -q 'XRAY_EXECUTABLE_PATH:' "$docker_compose_file"; then
        echo_yellow "Custom Xray version is currently enabled."
        local disable
        disable=$(prompt_input "Do you want to disable it? (yes/no)" "no")
        
        if [[ "$disable" == "yes" ]]; then
            echo_green "Disabling custom Xray..."
            sed -i '/XRAY_EXECUTABLE_PATH:/d' "$docker_compose_file"
            echo_green "Custom Xray version has been disabled."
           
            changes_made=true
        else
            echo_green "Custom Xray remains enabled."
            sleep 3
        fi
    else
        echo_yellow "Custom Xray version is currently disabled."
        local enable
        enable=$(prompt_input "Do you want to enable the custom Xray version? (yes/no)" "no")
        
        if [[ "$enable" == "yes" ]]; then
            echo_green "Enabling custom Xray..."
            local xray_path="\"$xray_binary_path\""
            sed -i '/environment:/a\      XRAY_EXECUTABLE_PATH: '"$xray_path" "$docker_compose_file"
            echo_green "Custom Xray version has been enabled."
            
            changes_made=true
        else
            echo_green "Custom Xray remains disabled."
            sleep 3
        fi
    fi

    # If changes were made, prompt for restarting Docker Compose
    if [ "$changes_made" = true ]; then
        echo_yellow "Changes were made to docker-compose.yml."
        local restart
        restart=$(prompt_input "Do you want to restart Docker Compose now? (yes/no)" "yes")

        if [[ "$restart" == "yes" ]]; then
            echo_yellow "Restarting Docker Compose..."
            restart_docker_compose
        else
            echo_green "Docker Compose will not be restarted now."
            sleep 2
        fi
    fi
}



# Function to list Xray core versions and download the selected one
list_and_download_xray_core() {
    local xray_core_dir="/var/lib/marzban-node/xray-core"
    local github_api_url="https://api.github.com/repos/XTLS/Xray-core/releases"
    local versions_file="/tmp/xray_versions.txt"

    echo_yellow "Fetching the list of available Xray core versions..."
    # Fetch latest 10 versions from GitHub API
    curl -s "$github_api_url?per_page=15" | grep -oP '"tag_name": "\K(.*?)(?=")' > "$versions_file"

    if [ ! -s "$versions_file" ]; then
        echo_red "Failed to fetch Xray core versions."
       
        return 1
    fi

    # Display the list of latest versions
    echo -e "\n${CYAN}Available Xray Core Versions:${NC}"
    echo -e "${BLUE}========================${NC}"

    cat -n "$versions_file" | while read -r line_number line_content; do
        if (( line_number % 2 == 0 )); then
            echo -e "${GREEN}$line_number: $line_content${NC}"
        else
            echo -e "$line_number: $line_content"
        fi
    done

    echo -e "${BLUE}========================${NC}\n"

    local version_choice
    version_choice=$(prompt_input "Enter the number of the version you want to download" "")

    local selected_version
    selected_version=$(sed -n "${version_choice}p" "$versions_file")

    if [ -z "$selected_version" ]; then
        echo_red "Invalid selection."
        return 1
    fi

    local xray_core_url="https://github.com/XTLS/Xray-core/releases/download/${selected_version}/Xray-linux-64.zip"



    # Check for unzip installation
    if ! command -v unzip &> /dev/null; then
        echo_yellow "Unzip is not installed. Installing now..."
      

        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y unzip
        elif command -v yum &> /dev/null; then
            sudo yum install -y unzip
        else
            echo_red "Could not determine package manager. Please install unzip manually."
           
            return 1
        fi

        if ! command -v unzip &> /dev/null; then
            echo_red "Failed to install unzip."
           
            return 1
        fi
    fi

    if [ ! -d "$xray_core_dir" ]; then
        echo_green "Creating directory $xray_core_dir..."
        sudo mkdir -p "$xray_core_dir"
    fi

    cd "$xray_core_dir"

    echo_yellow "Downloading Xray core version $selected_version..."
   
    sudo curl -L -o Xray-linux-64.zip "$xray_core_url"

    if [ $? -ne 0 ]; then
        echo_red "Failed to download Xray core."
       
        return 1
    fi

    echo_yellow "Unzipping Xray core..."
    sudo unzip -o Xray-linux-64.zip

    if [ $? -ne 0 ]; then
        echo_red "Failed to unzip Xray core."
        
        return 1
    fi

    sudo rm Xray-linux-64.zip

    echo_green "Version $selected_version downloaded and unzipped successfully in $xray_core_dir."
   

    rm "$versions_file"

    sleep 3
}






# Function to check if Docker is installed and running
install_docker() {
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo_yellow "Docker is not installed. Installing Docker..."
       
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh

        if [ $? -eq 0 ]; then
            echo_green "Docker installed successfully."
           
            sudo usermod -aG docker $USER
            echo "Please log out and log back in to finalize Docker installation and permissions."
           
        else
            echo_red "Installation of Docker failed."
           
            return 1
        fi
        sudo rm get-docker.sh
    else
        echo_green "Docker is already installed."
       
    fi

    # Check if Docker is running
    if ! docker info &> /dev/null; then
        echo_yellow "Docker is not running. Attempting to start Docker..."
      

        # Attempt to start Docker if not running
        sudo systemctl start docker
        if ! docker info &> /dev/null; then
            echo_red "Failed to start Docker. Please manually start Docker."
          
            return 1
        fi
    fi

    echo_green "Docker is running."
  
}


# Function to check if Docker Compose is installed and install it if not
check_docker_compose() {
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo_yellow "jq is not installed. Installing now..."
     

        # Install jq based on the package manager available
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y epel-release && sudo yum install -y jq
        elif command -v brew &> /dev/null; then
            brew install jq
        else
            echo_red "Could not determine package manager. Please install jq manually."
          
            return 1
        fi

        if ! command -v jq &> /dev/null; then
            echo_red "Failed to install jq."
          
            return 1
        fi
    fi

    # Check if docker-compose command is available
    if ! command -v docker-compose &> /dev/null; then
        # Docker Compose is not installed
        echo_yellow "Docker Compose is not installed. Installing now..."
     

        # Fetch the latest version of Docker Compose using GitHub API and jq to parse JSON
        latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
        
        # Check if fetching the latest version was successful
        if [ -z "$latest_version" ]; then
            echo_red "Failed to fetch the latest Docker Compose version."
          
            return 1
        fi

        # Download the latest Docker Compose binary to /usr/local/bin
        sudo curl -L "https://github.com/docker/compose/releases/download/$latest_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        
        # Check if the download was successful
        if [ $? -ne 0 ]; then
            echo_red "Failed to download Docker Compose."
           
            return 1
        fi

        # Make the Docker Compose binary executable
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Verify that Docker Compose was installed correctly
        if ! docker-compose --version &> /dev/null; then
            echo_red "Failed to install Docker Compose."
         
            return 1
        fi

        # Installation successful
        echo_green "Docker Compose installed successfully."
       
    else
        # Docker Compose is already installed
        echo_green "Docker Compose is already installed."
     
    fi
}




# Function to validate port numbers
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        echo_red "Error: Port must be a number."
     
        exit 1
    fi
    if (( port < 1 || port > 65535 )); then
        echo_red "Error: Port number out of range (1-65535)."
   
        exit 1
    fi
}



# Function to update and upgrade the system
update_system() {
    echo_yellow "Updating package lists..."
    sudo apt-get update

    echo_yellow "Upgrading installed packages..."
    sudo apt-get upgrade -y
 
}

# Function to install necessary packages
install_packages() {
    echo_green "Checking and installing necessary packages..."

    # Update the package list
    sudo apt-get update

    # List of necessary packages
    necessary_packages=(
        curl
        socat
        nano
        cron
        dos2unix
        git
        wget
        net-tools
        iputils-ping
        traceroute
        jq
        rsync
        build-essential
        docker.io
        docker-compose
        btop
        htop
        ufw
    )

    # Install packages if not already installed
    for package in "${necessary_packages[@]}"; do
        if ! dpkg -l | grep -q "$package"; then
            sudo apt-get install "$package" -y
            echo_green "$package installed."
        else
            echo_yellow "$package is already installed."
        fi
    done

   
}

# Function to install marzban node
setup_marzban_node() {
    if [ -d "$MARZBAN_NODE_DIR" ]; then
        echo_red "Removing existing directory $MARZBAN_NODE_DIR..."
        rm -rf "$MARZBAN_NODE_DIR"
    fi

    if [ -d "$MARZBAN_NODE_DATA_DIR" ]; then
        echo_red "Removing existing directory $MARZBAN_NODE_DATA_DIR..."
        sudo rm -rf "$MARZBAN_NODE_DATA_DIR"
    fi

    echo_green "Cloning the Marzban-node repository..."
    git clone https://github.com/Gozargah/Marzban-node "$MARZBAN_NODE_DIR"

    echo_green "Changing directory to $MARZBAN_NODE_DIR..."
    cd "$MARZBAN_NODE_DIR"

    if [ -f docker-compose.yml ]; then
        echo_red "Removing existing docker-compose.yml..."
        rm docker-compose.yml
    fi

    echo_green "Creating the directory $MARZBAN_NODE_DATA_DIR..."
    sudo mkdir -p "$MARZBAN_NODE_DATA_DIR"

    while true; do
        NUM_NODES=$(prompt_input "How many nodes do you need? [1-2-3]" 1)
        if [[ "$NUM_NODES" =~ ^[1-3]$ ]]; then
            break
        else
            echo_red "Error: Invalid number of nodes. Please enter a number between 1 and 3."
        fi
    done

    echo "services:" >> docker-compose.yml
    for ((i = 1; i <= NUM_NODES; i++)); do
        # Default ports
        DEFAULT_SERVICE_PORT=5000
        DEFAULT_XRAY_API_PORT=5001
        
        # Set default ports based on node number
        case $i in
            2)
                DEFAULT_SERVICE_PORT=3000
                DEFAULT_XRAY_API_PORT=3001
                ;;
            3)
                DEFAULT_SERVICE_PORT=4000
                DEFAULT_XRAY_API_PORT=4001
                ;;
        esac

        # Prompt user for ports and use defaults if input is empty
        SERVICE_PORT=$(prompt_input "Enter service port for marzban-node-$i " $DEFAULT_SERVICE_PORT)
        XRAY_API_PORT=$(prompt_input "Enter XRAY API port for marzban-node-$i " $DEFAULT_XRAY_API_PORT)

        # Validate ports
        validate_port "$SERVICE_PORT"
        validate_port "$XRAY_API_PORT"

        echo_green "Using ports for node $i: SERVICE_PORT=$SERVICE_PORT, XRAY_API_PORT=$XRAY_API_PORT"

        cat <<EOF >> docker-compose.yml
  marzban-node-$i:
    image: gozargah/marzban-node:latest
    restart: always
    network_mode: host
    environment:
      SSL_CLIENT_CERT_FILE: "$MARZBAN_NODE_DATA_DIR/ssl_client_cert_$i.pem"
      SERVICE_PORT: $SERVICE_PORT
      XRAY_API_PORT: $XRAY_API_PORT
      SERVICE_PROTOCOL: "rest"
    volumes:
      - $MARZBAN_NODE_DATA_DIR:/var/lib/marzban-node
EOF
    done
	for ((i = 1; i <= NUM_NODES; i++)); do
    CERT_FILE="$MARZBAN_NODE_DATA_DIR/ssl_client_cert_$i.pem"

    # Prompt the user to press Enter to continue
    read -p "Press Enter to edit the certificate for marzban-node-$i"

    # Open the certificate file with nano
    sudo nano "$CERT_FILE"

    # Confirm successful editing
    echo_green "Certificate marzban-node-$i file edited successfully."
    sleep 2
done

	# Restart Docker Compose after setup
    restart_docker_compose
}



# Function to manage Docker Compose
manage_docker_compose() {
    if docker-compose ps &> /dev/null; then
        echo_red "Docker Compose is already running. Bringing it down..."
        docker-compose down --remove-orphans
    fi
    sleep 1
    echo_green "Starting Docker containers..."
    docker-compose up -d
    echo_green "Docker containers have been started successfully!"
    # Add a delay to allow services to start up
    sleep 1
}

# Function to change node ports
change_node_ports() {
    if [ ! -f "$MARZBAN_NODE_DIR/docker-compose.yml" ]; then
        echo_red "Error: docker-compose.yml not found in $MARZBAN_NODE_DIR"
        return
    fi

    local current_dir
    current_dir=$(pwd)

    cd "$MARZBAN_NODE_DIR" || return

    # Create a backup of the original docker-compose.yml
    cp docker-compose.yml docker-compose.yml.bak

    # Find existing panels
    existing_nodes=$(grep -oE 'marzban-node-[0-9]*:' "docker-compose.yml" | sort -u)
    NUM_NODES=$(echo "$existing_nodes" | wc -w)

    echo_yellow "Available marzban-nodes:"
    for node in $existing_nodes; do
        node_number=$(echo "$node" | cut -d '-' -f 3 | tr -d ':')
        echo "  marzban-node $node_number:"
    done

    selected_node=""
    while true; do
        selected_node=$(prompt_input "Enter the marzban-node number to edit: ")
        if [[ "$selected_node" =~ ^[0-9]+$ && "$selected_node" -ge 1 && "$selected_node" -le "$NUM_NODES" ]]; then
            break
        else
            echo_red "Error: Invalid marzban-node number. Please select a valid marzban-node."
        fi
    done

    echo_green "Modifying ports for marzban-node $selected_node..."

    # Prompt for new ports directly
    while true; do
        SERVICE_PORT=$(prompt_input "Enter new service port for marzban-node-$selected_node: ")
        if [[ -z "$SERVICE_PORT" ]]; then
            echo_red "Error: Port cannot be empty. Please enter a valid port."
        else
            validate_port "$SERVICE_PORT" && break
            echo_red "Error: Port must be a valid number."
        fi
    done

    while true; do
        XRAY_API_PORT=$(prompt_input "Enter new XRAY API port for marzban-node-$selected_node: ")
        if [[ -z "$XRAY_API_PORT" ]]; then
            echo_red "Error: Port cannot be empty. Please enter a valid port."
        else
            validate_port "$XRAY_API_PORT" && break
            echo_red "Error: Port must be a valid number."
        fi
    done

    # Update ports in docker-compose.yml using sed
    sed -i "/marzban-node-$selected_node:/,/^  [^ ]/ s/SERVICE_PORT: .*/SERVICE_PORT: $SERVICE_PORT/" "docker-compose.yml"
    sed -i "/marzban-node-$selected_node:/,/^  [^ ]/ s/XRAY_API_PORT: .*/XRAY_API_PORT: $XRAY_API_PORT/" "docker-compose.yml"

    echo_green "Ports for marzban-node-$selected_node updated to SERVICE_PORT: $SERVICE_PORT, XRAY_API_PORT: $XRAY_API_PORT."

    # Prompt to restart Docker container
    while true; do
        read -p "Do you want to restart the Docker container for marzban-node-$selected_node? (yes/no) [yes]: " restart_choice
        restart_choice=${restart_choice:-yes}  # Default to 'yes' if no input

        if [[ "$restart_choice" == "yes" || "$restart_choice" == "no" ]]; then
            break
        else
            echo_red "Error: Please enter 'yes' or 'no'."
        fi
    done

    if [[ "$restart_choice" == "yes" ]]; then
        echo_green "Restarting Docker container for marzban-node-$selected_node..."
        # Stop the container
        docker-compose down --remove-orphans "marzban-node-$selected_node" || echo_red "Error: Failed to stop the container."
        
        # Start the container again
        docker-compose up -d "marzban-node-$selected_node" || echo_red "Error: Failed to start the container."
    else
        echo_green "Docker container for marzban-node-$selected_node will not be restarted."
    fi

    # Add a delay to allow services to start up
    sleep 3

    cd "$current_dir" || return
}


# Function to change node cert
edit_node_certificates() {
    local MARZBAN_NODE_DATA_DIR="/var/lib/marzban-node"

    if [ ! -f "$MARZBAN_NODE_DIR/docker-compose.yml" ]; then
        echo_red "Error: docker-compose.yml not found in $MARZBAN_NODE_DIR"
        return
    fi

    if [ ! -d "$MARZBAN_NODE_DATA_DIR" ]; then
        echo_red "Error: Directory $MARZBAN_NODE_DATA_DIR does not exist."
        return
    fi

    cd "$MARZBAN_NODE_DIR"

    existing_nodes=$(grep -oE 'marzban-node-[0-9]*:' "docker-compose.yml" | sort -u)
    NUM_NODES=$(echo "$existing_nodes" | wc -w)

    echo_yellow "Available nodes certificate:"
    for node in $existing_nodes; do
        node_number=$(echo "$node" | cut -d '-' -f 3)
        echo "  marzban-node-$node_number"
    done

    selected_node=""
    while true; do
        selected_node=$(prompt_input "Enter the marzban-node number to edit: ")
        if [[ "$selected_node" =~ ^[0-9]+$ && "$selected_node" -ge 1 && "$selected_node" -le "$NUM_NODES" ]]; then
            break
        else
            echo_red "Error: Invalid panel number. Please select a valid panel."
        fi
    done

    echo_green "Editing certificate for marzban-node-$selected_node"

    CERT_FILE="$MARZBAN_NODE_DATA_DIR/ssl_client_cert_$selected_node.pem"
    if [ -f "$CERT_FILE" ]; then
        # Prompt the user to press Enter to continue
        read -p "Press Enter to edit the certificate for marzban-node-$selected_node..."

        sudo nano "$CERT_FILE"
        echo_green "Certificate for marzban-node-$selected_node edited successfully."
        
        # Prompt to restart Docker container
        while true; do
            read -p "Do you want to restart the Docker container for marzban-node-$selected_node? (yes/no) [yes]: " restart_choice
            restart_choice=${restart_choice:-yes}  # Default to 'yes' if no input

            if [[ "$restart_choice" == "yes" || "$restart_choice" == "no" ]]; then
                break
            else
                echo_red "Error: Please enter 'yes' or 'no'."
            fi
        done

        if [[ "$restart_choice" == "yes" ]]; then
            echo_green "Restarting Docker container for marzban-node-$selected_node..."
            # Bring down the container and remove orphan containers
            docker-compose down --remove-orphans "marzban-node-$selected_node" || echo_red "Error: Failed to stop the container."
            
            # Bring up the container again
            docker-compose up -d "marzban-node-$selected_node" || echo_red "Error: Failed to start the container."
        else
            echo_green "Docker container for marzban-node-$selected_node will not be restarted."
        fi

    else
        echo_red "Error: Certificate file $CERT_FILE not found."
    fi

    # Add a delay to allow services to start up
    sleep 3
}






# Function to edit docker-compose.yml with nano
edit_docker_compose() {
    local current_dir
    current_dir=$(pwd)
    
    cd "$MARZBAN_NODE_DIR"
    sudo nano docker-compose.yml
    echo_green "docker-compose.yml edited successfully."
    
    cd "$current_dir"
}

# Function to restart Docker Compose services and show status
restart_docker_compose() {
    local current_dir
    current_dir=$(pwd)
    
    cd "$MARZBAN_NODE_DIR"
    
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found in $MARZBAN_NODE_DIR"
        cd "$current_dir"
        return
    fi
    
    echo_yellow "Restarting Docker Compose services..."
    docker-compose down --remove-orphans
    docker-compose up -d
    echo_green "Docker Compose services have been restarted successfully."
    
    # Add a delay to allow services to start up
    sleep 3
    
    cd "$current_dir"
}
# isp blocker
isp_blocker_script() {
    local remote_script_url="https://raw.githubusercontent.com/Mmdd93/IR-ISP-Blocker/main/ir-isp-blocker.sh"
    
    echo_yellow "Fetching and running the ISP blocker from $remote_script_url..."
    
    # Use curl to fetch and execute the script
    bash <(curl -s "$remote_script_url")
    
    # Check if the script executed successfully
    if [ $? -eq 0 ]; then
        echo_green "isp blocker executed successfully."
    else
        echo_red "Failed to execute the ISP blocker."
    fi
}

# Function to update system, install packages, and LightKnightBBR V 1.2
bbr_script() {
    echo_yellow "Updating system and installing necessary packages..."
    
    # Update system and install packages
    sudo apt update && sudo apt install -y python3 python3-pip
    
    echo_yellow "Fetching and running the Python script..."
    
    # Run the Python script from the URL
    python3 <(curl -Ls https://raw.githubusercontent.com/kalilovers/LightKnightBBR/main/bbr.py --ipv4)
    
    # Check if the script executed successfully
    if [ $? -eq 0 ]; then
        echo_green "Python script executed successfully."
    else
        echo_red "Failed to execute the Python script."
    fi
}
#!/bin/bash

# Function to install Speedtest CLI
install_speedtest_cli() {
    echo -e "\033[1;34mInstalling Speedtest CLI...\033[0m"
    
    # Remove existing speedtest-cli if it exists
    if dpkg -l | grep -q speedtest-cli; then
        echo -e "\033[1;33mRemoving existing Speedtest CLI...\033[0m"
        sudo apt-get remove -y speedtest-cli
    fi
    
    # Install curl if not installed
    if ! command -v curl &> /dev/null; then
        echo -e "\033[1;33mCurl is not installed. Installing curl...\033[0m"
        sudo apt-get install -y curl
    fi
    

    
    # Install Speedtest CLI
    echo -e "\033[1;34mInstalling Speedtest CLI...\033[0m"
    sudo apt-get install speedtest-cli

    echo -e "\033[1;32mSpeedtest CLI installed successfully!\033[0m"
}

# Function to run benchmarks and tests
# Function to run benchmarks and tests
run_system_benchmark() {
    while true; do
        echo -e "\n\033[1;34m=========================\033[0m"
        echo -e "\033[1;34m    Speedtest CLI Menu   \033[0m"
        echo -e "\033[1;34m=========================\033[0m"
        echo -e "\033[1;32m1. \033[0mSystem Benchmark + Speed Test"
        echo -e "\033[1;32m2. \033[0mInstall Speedtest CLI"
        echo -e "\033[1;32m3. \033[0mstart Speedtest"
        echo -e "\033[1;32m4. \033[0mUninstall Speedtest CLI"
        echo -e "\033[1;32m0. \033[0mReturn"
        
        read -p $'\033[1;34mEnter your choice (0-4): \033[0m' choice

        case $choice in
            1)
                echo -e "\033[1;34mRunning system benchmark...\033[0m"
                if wget -qO- bench.sh | bash; then
                    echo -e "\n\033[1;32mBenchmark completed successfully.\033[0m"
                else
                    echo -e "\n\033[1;31mFailed to run the benchmark. Please check your connection or the script.\033[0m"
                fi
                ;;
          
              3) speedtest ;;
              2) install_speedtest_cli  ;;
              4) apt-get remove speedtest-cli ;;  
            0)
                echo -e "\033[1;32mExiting...\033[0m"
                main_menu
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please select 0, 1, 2, 3, or 4.\033[0m"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}



# Function to list used ports with color-coded visibility
used_ports() {
    echo -e "\n\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m      Currently Listening Ports\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    
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
    echo -e "\nPress Enter to return to the main menu."
    read
}




setup_cache_and_reboot() {
    reboot_command="sudo /sbin/shutdown -r +5"

    # Default settings
    default_cache_clear_hours="2"
    default_reboot_hour="4"
    default_reboot_days="2"

    while true; do
        echo -e "\033[1;33mSelect an option:\033[0m"
        echo -e "\033[1;32m1. Setup cache clearing\033[0m"
        echo -e "\033[1;32m2. Setup reboot schedule\033[0m"
        echo -e "\033[1;32m3. Edit cron jobs using nano\033[0m"
        echo -e "\033[1;32m0. Exit to main menu\033[0m"
        read -p "Enter your choice: " choice

        case $choice in
            1)
                # Prompt user for cache clearing interval in hours only
                echo -e "\033[1;33mEnter the cache clearing interval in hours:\033[0m"
                read -p "Enter hours (default $default_cache_clear_hours hours): " cache_hours

                # Use default if no input is provided
                cache_hours=${cache_hours:-$default_cache_clear_hours}

                # Clear cache command
                clear_cache_command="/usr/bin/sync; echo 3 > /proc/sys/vm/drop_caches >/dev/null 2>&1"

                # Remove old cache clearing job if it exists
                if crontab -l | grep -q "$clear_cache_command"; then
                    echo -e "\033[1;33mUpdating existing cache clearing job...\033[0m"
                    crontab -l | grep -v "$clear_cache_command" | crontab - || {
                        echo -e "\033[1;31mFailed to remove the existing cache clearing job.\033[0m"
                        return 1
                    }
                fi

                # Add new cache clearing job (if user inputs 0 hours, it will run every hour)
                if [[ "$cache_hours" -eq 0 ]]; then
                    echo -e "\033[1;31mWarning: Cache clearing will run every hour!\033[0m"
                    (crontab -l 2>/dev/null | grep -v "$clear_cache_command"; echo "0 * * * * $clear_cache_command") | crontab - || {
                        echo -e "\033[1;31mFailed to set cron job for cache clearing.\033[0m"
                        return 1
                    }
                else
                    # Set cache clearing job to run every specified hour
                    (crontab -l 2>/dev/null | grep -v "$clear_cache_command"; echo "0 */$cache_hours * * * $clear_cache_command") | crontab - || {
                        echo -e "\033[1;31mFailed to set cron job for cache clearing.\033[0m"
                        return 1
                    }
                fi

                # Reload cron service
                if ! sudo service cron reload; then
                    echo -e "\033[1;31mFailed to reload cron service.\033[0m"
                    return 1
                fi

                sleep 1
                echo -e "\033[1;32mCache clearing job set to run every $cache_hours hour(s).\033[0m"
                ;;

2)
    # Prompt user for reboot interval
    echo -e "\033[1;33mEnter the reboot schedule:\033[0m"
    read -p "Enter days (default every $default_reboot_days days): " reboot_days
    read -p "Enter hour time in 24-hour format (default $default_reboot_hour AM): " reboot_hour

    # Use defaults if no input is provided
    reboot_days=${reboot_days:-$default_reboot_days}
    reboot_hour=${reboot_hour:-$default_reboot_hour}

    # Convert to 12-hour format with AM/PM
    if (( reboot_hour >= 12 )); then
        am_pm="PM"
        (( reboot_hour == 12 )) || reboot_hour=$((reboot_hour - 12))
    else
        am_pm="AM"
        (( reboot_hour == 0 )) && reboot_hour=12
    fi

    # Remove old reboot job if it exists
    if crontab -l | grep -q "$reboot_command"; then
        echo -e "\033[1;33mUpdating existing reboot schedule...\033[0m"
        crontab -l | grep -v "$reboot_command" | crontab - || {
            echo -e "\033[1;31mFailed to remove the existing reboot job.\033[0m"
            return 1
        }
    fi

    # Add new reboot job
    (crontab -l; echo "0 $reboot_hour */$reboot_days * * $reboot_command") | crontab - || {
        echo -e "\033[1;31mFailed to set cron job for reboot.\033[0m"
        return 1
    }

    # Reload cron service
    if ! sudo service cron reload; then
        echo -e "\033[1;31mFailed to reload cron service.\033[0m"
        return 1
    fi

    sleep 1
    echo -e "\033[1;32mServer reboot scheduled at $reboot_hour:00 $am_pm every $reboot_days day(s).\033[0m"
    ;;


            3)
                # Edit cron jobs using nano
                echo -e "\033[1;33mEditing cron jobs...\033[0m"
                sudo EDITOR=nano crontab -e
                echo -e "\033[1;32mCron jobs updated.\033[0m"
                
                # Reload cron service
                sudo service cron reload
                sleep 1
                ;;

            0)
                echo -e "\033[1;32mReturning to the main menu...\033[0m"
                return
                ;;

            *)
                echo -e "\033[1;31mInvalid choice. Please enter 1, 2, 3, or 0.\033[0m"
                ;;
        esac
    done
}








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


#xui panel
xui() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m         Select panel\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    echo -e "\033[1;32m1.\033[0m Alireza x-ui"
    echo -e "\033[1;32m2.\033[0m Sanaei 3x-ui"
    echo -e "\033[1;32m3.\033[0m X-UI comand"
    echo -e "\033[1;32m0.\033[0m return to the main menu"
    
    read -p "Select an option (1-2): " option

    case "$option" in
        1)
            script="bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)"
            ;;
        2)
            script="bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)"
            ;;
        3) x-ui ;;
        0) return ;;  
        *)
            echo -e "\033[1;31mInvalid option. Please choose 1 or 2.\033[0m"
            return
            ;;
    esac

    echo -e "\033[1;32mRunning command: $script...\033[0m"
    eval "$script"
    if [[ $? -eq 0 ]]; then
        echo -e "\033[1;32mCommand completed successfully.\033[0m"
    else
        echo -e "\033[1;31mCommand encountered an error.\033[0m"
    fi

    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\nPress Enter to return to the main menu."
    read
}
#marzban
marzban_commands() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m           Marzban Commands\033[0m"
        echo -e "\033[1;36m============================================\033[0m"

        echo -e "\033[1;32mAvailable commands:\033[0m"
        echo -e "\033[1;32m1.\033[0m Install Marzban"
        echo -e "\033[1;31m2.\033[0m Create sudo admin"
        echo -e "\033[1;32m3.\033[0m Edit admin"
        echo -e "\033[1;32m4.\033[0m Start services"
        echo -e "\033[1;32m5.\033[0m Stop services"
        echo -e "\033[1;32m6.\033[0m Restart services"
        echo -e "\033[1;32m7.\033[0m Marzban status"
        echo -e "\033[1;32m8.\033[0m Show logs"
        echo -e "\033[1;32m9.\033[0m Update latest version"
        echo -e "\033[1;32m10.\033[0m Uninstall Marzban"
        echo -e "\033[1;32m11.\033[0m Install Marzban script"
        echo -e "\033[1;32m12.\033[0m Update/Change Xray core"
        echo -e "\033[1;32m13.\033[0m Edit .env"
        echo -e "\033[1;32m14.\033[0m Edit docker-compose.yml"
        echo -e "\033[1;32m15.\033[0m Change database to MySql"
	echo -e "\033[1;32m16.\033[0m bypass ssl"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        echo -e "\033[1;36m============================================\033[0m"

        read -p "Select a command number (0-15): " command_choice

        case $command_choice in
            1) install_marzban ;;
            2) sudo marzban cli admin create --sudo || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            3) marzban_cli_commands || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            4) sudo marzban up || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            5) sudo marzban down || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            6) sudo marzban restart || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            7) sudo marzban status || echo -e "\033[1;31m Marzban not installed.\033[0m" ;;
            8) sudo marzban logs || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            9) sudo marzban update || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            10) sudo marzban uninstall || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            11) sudo marzban install-script || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            12) sudo marzban core-update || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            13) sudo nano /opt/marzban/.env || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            14) sudo nano /opt/marzban/docker-compose.yml || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            15) mysql || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
	    16) bypass ;;
            0) return ;;  
            *)
                echo -e "\033[1;31mInvalid choice. Please enter a number between 0 and 15.\033[0m" ;;
        esac

        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the Marzban Commands."
        read
    done
}
bypass() {
    echo -e "\033[1;34mTo bypass SSL for Marzban:\033[0m"
    echo -e "\033[1;32m\033[0m Install Nginx if it's not already installed."
    echo -e "\033[1;32m\033[0m use bypass option (13) in Nginx configuration."
    echo -e "\033[1;32m\033[0m Restart Nginx to apply the changes."
    # Prompt to continue
    read -p "Press Enter to continue..."
    
    # Call manage_nginx function
    manage_nginx
}

install_marzban() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m        Installing Marzban\033[0m"
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;31m1. Press ctrl+c anytime to stop viewing the logs after installation.\033[0m"
        echo -e "\033[1;31m2. You need to create a sudo admin after installing to access the panel.\033[0m"
        echo -e "\033[1;31m3. Access the panel at: http://YOUR_SERVER_IP:8000/dashboard/\033[0m"
        
        echo -e "\033[1;36mChoose installation version:\033[0m"
        echo -e "\033[1;32m1. Latest version\033[0m"
        echo -e "\033[1;32m2. Development version\033[0m"
        echo -e "\033[1;32m0. Return\033[0m"
        read -p "Enter your choice: " version_choice

        case $version_choice in
            1)
                echo -e "\033[1;32mRunning the Latest Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
                ;;
            2)
                echo -e "\033[1;32mRunning the Dev Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install dev
                ;;
            0)
                echo -e "\033[1;31mReturning to Marzban Commands.\033[0m"
                marzban_commands
                break  # Break out of the loop and return to the main menu
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please enter [0, 1, or 2].\033[0m"
                ;;
        esac

        # Wait for user to press Enter before returning to the loop
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the Marzban Commands."
        read
    done
}








marzban_cli_commands() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m           Marzban CLI Commands\033[0m"
        echo -e "\033[1;36m============================================\033[0m"

        echo -e "\033[1;32mAvailable CLI commands:\033[0m"
        echo -e "\033[1;32m1.\033[0m Create an admin"
        echo -e "\033[1;32m2.\033[0m Delete the admin"
        echo -e "\033[1;32m3.\033[0m Import the sudo admin from env"
        echo -e "\033[1;32m4.\033[0m Display list of admins"
        echo -e "\033[1;32m5.\033[0m Edit and update admin"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        echo -e "\033[1;36m============================================\033[0m"

        read -p "Select a CLI command number (0-5): " cli_choice

        case $cli_choice in
            1)
                read -p "Enter the admin name to create: " admin_name
                sudo marzban cli admin create "$admin_name" || echo -e "\033[1;31mError occurred while creating admin. Returning to CLI commands.\033[0m"
                ;;
            2)
                read -p "Enter the admin name to delete: " admin_name
                sudo marzban cli admin delete "$admin_name" || echo -e "\033[1;31mError occurred while deleting admin. Returning to CLI commands.\033[0m"
                ;;
            3)
                sudo marzban cli admin import-from-env || echo -e "\033[1;31mError occurred while importing admin. Returning to CLI commands.\033[0m"
                ;;
            4)
                sudo marzban cli admin list || echo -e "\033[1;31mError occurred while displaying admin list. Returning to CLI commands.\033[0m"
                ;;
            5)
                read -p "Enter the admin name to update: " admin_name
                sudo marzban cli admin update "$admin_name" || echo -e "\033[1;31mError occurred while updating admin. Returning to CLI commands.\033[0m"
                ;;
            0)
                return
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please enter a number between 0 and 5.\033[0m"
                ;;
        esac

        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the CLI commands."
        read
    done
}

#ssl
# Function to handle port 80 conflicts
handle_port_80() {
    # Check if port 80 is in use
    # Check if port 80 is in use
    if sudo lsof -i :80 | grep LISTEN &> /dev/null; then
        service_name=$(sudo lsof -i :80 | grep LISTEN | awk '{print $1}' | head -n 1)
        pid=$(sudo lsof -i :80 | grep LISTEN | awk '{print $2}' | head -n 1)
        echo -e "\033[1;31mPort 80 is in use by: $service_name (PID: $pid)\033[0m"

        # Display menu options
        while true; do
            echo -e "\033[1;33mPlease choose an option:\033[0m"
            echo "1) Stop $service_name to proceed with HTTP-01 challenge."
            echo "2) Continue  (not recommended) ."
            echo "3) Return."
            read -p "Enter your choice (1-3): " menu_choice

            case $menu_choice in
                1)
                    # Stop the service
                    if sudo systemctl list-units --type=service | grep -q "$service_name"; then
                        sudo systemctl stop "$service_name" || { echo -e "\033[1;31mFailed to stop $service_name using systemctl.\033[0m"; }
                    else
                        # Kill the process if systemctl does not recognize the service
                        echo -e "\033[1;33mAttempting to kill process $pid...\033[0m"
                        sudo kill -9 "$pid" || { echo -e "\033[1;31mFailed to kill process $pid.\033[0m"; return 1; }
                        echo -e "\033[1;32mProcess $pid ($service_name) has been killed.\033[0m"
                    fi
                    break
                    ;;
                2)
                    ssl1
                    ;;
                3)
                    echo -e "\033[1;31mReturning to main menu...\033[0m"
                    ssl
                    ;;
                *)
                    echo -e "\033[1;31mInvalid choice. Please enter a number between 1 and 3.\033[0m"
                    ;;
            esac
        done
    fi
}
# SSL issuance function
ssl() {
while true; do
    echo -e "\033[1;32mSSL Installation Options\033[0m"
    echo -e "1. Use \033[1;34macme single domain\033[0m "
    echo -e "2. Use \033[1;34mCertbot multi domain\033[0m "
    echo -e "3. Use \033[1;34mCertbot wildcard single domain\033[0m "
    echo -e "0. Return"
    echo -e "\033[1;32mEnter your choice:\033[0m"
    
    read -r ssl_choice

    case "$ssl_choice" in
        1)
            echo -e "\033[1;32mYou selected acme.\033[0m"
            handle_port_80
            ssl1
            ;;
        2)
            echo -e "\033[1;32mYou selected certbot method.\033[0m"
            get_ssl_with_certbot
            ;;
            
        3) get_wildcard_ssl_with_certbot ;;
        0)
            echo -e "\033[1;32mReturning to the previous menu.\033[0m"
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Please select 0, 1, or 2.\033[0m"
            ;;
    esac
done
}

ssl1() {
    # Step 1: Handle port 80 conflicts
    

    # Step 2: Proceed with SSL issuance
    echo -e "\033[1;33mProceeding with SSL certificate issuance...\033[0m"

    # Prompt user for domain and email, with validation
    while true; do
        read -p "Please enter the domain name: " DOMAIN
        if [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]]; then
            break
        else
            echo -e "\033[1;31mInvalid domain format. Please try again.\033[0m"
        fi
    done

    while true; do
        read -p "Please enter your email address: " EMAIL
        if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            echo -e "\033[1;31mInvalid email format. Please try again.\033[0m"
        fi
    done

    # Prompt for Certificate Authority (CA)
    echo "Please choose a Certificate Authority (CA):"
    echo "1) Let's Encrypt"
    echo "2) Buypass"
    echo "3) ZeroSSL"
    read -p "Enter your choice (1, 2, or 3): " CA_OPTION

    case $CA_OPTION in
        1) CA_SERVER="letsencrypt" ;;
        2) CA_SERVER="buypass" ;;
        3) CA_SERVER="zerossl" ;;
        *) echo -e "\033[1;31mInvalid choice.\033[0m"; exit 1 ;;
    esac

    # System and firewall handling based on OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Unable to determine the operating system type, please install the dependencies manually."
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y curl socat git cron
            ;;
        centos)
            sudo yum update -y
            sudo yum install -y curl socat git cronie
            sudo systemctl start crond
            sudo systemctl enable crond
            ;;
        *)
            echo -e "\033[1;31mUnsupported operating system: $OS.\033[0m"
            exit 1
            ;;
    esac

    # Check if acme.sh is installed
    if ! command -v acme.sh >/dev/null 2>&1; then
        curl https://get.acme.sh | sh
    else
        echo -e "\033[1;32macme.sh is already installed.\033[0m"
    fi

    # Register the account and issue the SSL certificate
    export PATH="$HOME/.acme.sh:$PATH"
    acme.sh --register-account -m "$EMAIL" --server "$CA_SERVER"

    if ! ~/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" --server "$CA_SERVER"; then
        echo -e "\033[1;31mCertificate request failed.\033[0m"
        ~/.acme.sh/acme.sh --remove -d "$DOMAIN"
        exit 1
    fi

    # Install the SSL certificate
    ~/.acme.sh/acme.sh --installcert -d "$DOMAIN" \
        --key-file /root/${DOMAIN}.key \
        --fullchain-file /root/${DOMAIN}.crt

    echo -e "\033[1;32mSSL certificate and private key have been generated:\033[0m"
    echo -e "\033[1;34mCertificate:\033[0m /root/${DOMAIN}.crt"
    echo -e "\033[1;34mPrivate Key:\033[0m /root/${DOMAIN}.key"

    # Set up cron job for renewal
    echo -e "\033[1;32mSetting up automatic renewal...\033[0m"
    cat << EOF > /root/renew_cert.sh
#!/bin/bash
export PATH="\$HOME/.acme.sh:\$PATH"
acme.sh --renew -d $DOMAIN --server $CA_SERVER
EOF
    chmod +x /root/renew_cert.sh
    (crontab -l 2>/dev/null; echo "0 0 * * * /root/renew_cert.sh > /dev/null 2>&1") | crontab -

    echo -e "\033[1;32mSSL certificate renewal is scheduled daily at midnight.\033[0m"
}
get_ssl_with_certbot() {
    # Function to check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo -e "\033[1;31mCertbot is not installed.\033[0m"
        while true; do
            read -p "Do you want to install Certbot now? (yes/no): " install_choice
            if [[ "$install_choice" == "yes" ]]; then
                if [[ -f /etc/debian_version ]]; then
                    echo -e "\033[1;32mInstalling Certbot for Debian/Ubuntu...\033[0m"
                    sudo apt install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                elif [[ -f /etc/redhat-release ]]; then
                    echo -e "\033[1;32mInstalling Certbot for CentOS/RHEL...\033[0m"
                    sudo yum install epel-release -y && sudo yum install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                else
                    echo -e "\033[1;31mUnsupported OS.\033[0m"
                    return 1
                fi
                break
            elif [[ "$install_choice" == "no" ]]; then
                echo -e "\033[1;31mCertbot is required to proceed.\033[0m"
                return 1
            else
                echo -e "\033[1;31mInvalid choice. Please enter 'yes' or 'no'.\033[0m"
            fi
        done
    else
        echo -e "\033[1;32mCertbot is already installed.\033[0m"
    fi

    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m      Certbot multi domain SSL Generation\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    # Check if port 80 is in use
    if sudo lsof -i :80 | grep LISTEN &> /dev/null; then
        service_name=$(sudo lsof -i :80 | grep LISTEN | awk '{print $1}' | head -n 1)
        pid=$(sudo lsof -i :80 | grep LISTEN | awk '{print $2}' | head -n 1)
        echo -e "\033[1;31mPort 80 is in use by: $service_name (PID: $pid)\033[0m"

        # Display menu options
        while true; do
            echo -e "\033[1;33mPlease choose an option:\033[0m"
            echo "1) Stop $service_name to proceed with HTTP-01 challenge."
            echo "2) DNS challenge ."
            echo "3) Return to main menu."
            read -p "Enter your choice (1-3): " menu_choice

            case $menu_choice in
                1)
                    # Stop the service
                    if sudo systemctl list-units --type=service | grep -q "$service_name"; then
                        sudo systemctl stop "$service_name" || { echo -e "\033[1;31mFailed to stop $service_name using systemctl.\033[0m"; }
                    else
                        # Kill the process if systemctl does not recognize the service
                        echo -e "\033[1;33mAttempting to kill process $pid...\033[0m"
                        sudo kill -9 "$pid" || { echo -e "\033[1;31mFailed to kill process $pid.\033[0m"; return 1; }
                        echo -e "\033[1;32mProcess $pid ($service_name) has been killed.\033[0m"
                    fi
                    break
                    ;;
                2)
                    certbot certonly --manual --preferred-challenges dns || { echo -e "\033[1;31mFailed to issue SSL with DNS-01 challenge.\033[0m"; return 1; }
                    return
                    ;;
                3)
                    echo -e "\033[1;31mReturning to main menu...\033[0m"
                    return
                    ;;
                *)
                    echo -e "\033[1;31mInvalid choice. Please enter a number between 1 and 3.\033[0m"
                    ;;
            esac
        done
    fi

   # Loop for entering domains
   
# Get the public IP of the server
   # Get the public IP of the server
    server_ip=$(curl -s ifconfig.me)

    while true; do
        read -p "Enter your email (leave blank if you don't want to provide one): " email
        read -p "Enter your domains (comma separated, e.g., example.com,www.example.com): " domains
        
        # Check if domains are empty
        if [[ -z "$domains" ]]; then
            echo -e "\033[1;31mError: You must enter at least one domain.\033[0m"
            continue
        fi

        IFS=',' read -r -a domain_array <<< "$domains"

        # Check if the IPs behind the domains match the server's public IP
        for domain in "${domain_array[@]}"; do
            domain_ip=$(dig +short "$domain" | tail -n1)  # Get the last resolved IP
            if [[ "$domain_ip" != "$server_ip" ]]; then
                echo -e "\033[1;31mError: Domain '$domain' does not resolve to the server's public IP ($server_ip).\033[0m"
                echo -e "\033[1;33mResolved IP for '$domain' is $domain_ip.\033[0m"
                echo -e "\033[1;33mPlease ensure that the DNS records are correctly set before continuing.\033[0m"
                echo -e "\033[1;33mReturning to domain entry.\033[0m"
                continue 2  # Go back to the start of the while loop to prompt for domains again
            fi
        done

        # If all domains resolve correctly, break out of the loop
        break
    done

    domain_args=""
    for domain in "${domain_array[@]}"; do
        domain_args="$domain_args -d $domain"
    done

    # Check if email was provided
    if [[ -z "$email" ]]; then
        # No email provided, use the option to register without email
        certbot_command="certbot certonly --standalone --agree-tos --register-unsafely-without-email $domain_args"
    else
        # Email provided, validate email format
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "\033[1;31mError: Invalid email format. Please enter a valid email.\033[0m"
            continue  # Go back to the start of the loop to re-enter the email and domains
        fi
        certbot_command="certbot certonly --standalone --agree-tos --email \"$email\" $domain_args"
    fi

    # Run certbot command and display its output
    if ! eval "$certbot_command"; then
        echo -e "\033[1;31mSSL certificate generation failed.\033[0m"
        echo -e "\033[1;31mReturning to domain entry.\033[0m"
        continue  # Go back to the start of the loop if certbot fails
    fi

    echo -e "\033[1;32mSSL certificate generation completed successfully.\033[0m"
}

# Function to generate wildcard SSL certificates using certbot with DNS challenge
get_wildcard_ssl_with_certbot() {

    # Function to check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo -e "\033[1;31mCertbot is not installed.\033[0m"
        while true; do
            read -p "Do you want to install Certbot now? (yes/no): " install_choice
            if [[ "$install_choice" == "yes" ]]; then
                if [[ -f /etc/debian_version ]]; then
                    echo -e "\033[1;32mInstalling Certbot for Debian/Ubuntu...\033[0m"
                    sudo apt install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                elif [[ -f /etc/redhat-release ]]; then
                    echo -e "\033[1;32mInstalling Certbot for CentOS/RHEL...\033[0m"
                    sudo yum install epel-release -y && sudo yum install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                else
                    echo -e "\033[1;31mUnsupported OS.\033[0m"
                    return 1
                fi
                break
            elif [[ "$install_choice" == "no" ]]; then
                echo -e "\033[1;31mCertbot is required to proceed.\033[0m"
                return 1
            else
                echo -e "\033[1;31mInvalid choice. Please enter 'yes' or 'no'.\033[0m"
            fi
        done
    else
        echo -e "\033[1;32mCertbot is already installed.\033[0m"
    fi

    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m      Certbot Wildcard SSL Generation\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    
    while true; do
        read -p "Enter your email (leave blank if you don't want to provide one): " email
        read -p "Enter the base domain (e.g., example.com): " base_domain

        # Check if the base domain is empty
        if [[ -z "$base_domain" ]]; then
            echo -e "\033[1;31mError: You must enter a base domain.\033[0m"
            continue
        fi

        break
    done

    # Construct the domain arguments for the wildcard SSL request
    domain_args="-d $base_domain -d *.$base_domain"

    # Check if email was provided
    if [[ -z "$email" ]]; then
        # No email provided, use the option to register without email
        certbot_command="certbot certonly --manual --preferred-challenges=dns --server https://acme-v02.api.letsencrypt.org/directory --agree-tos --register-unsafely-without-email $domain_args"
    else
        # Validate the email format
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "\033[1;31mError: Invalid email format. Please enter a valid email.\033[0m"
            continue  # Go back to the start of the loop to re-enter the email and domain
        fi
        certbot_command="certbot certonly --manual --preferred-challenges=dns --email \"$email\" --server https://acme-v02.api.letsencrypt.org/directory --agree-tos $domain_args"
    fi
sleep 1
    # Inform the user about the manual DNS challenge
    echo -e "\033[1;33mNote:\033[0m This process requires you to manually add DNS TXT records for domain verification."
    sleep 1
    echo -e "\033[1;32mCertbot will prompt you to create a TXT record for each domain.\033[0m"
    sleep 1
    echo -e "\033[1;32mYou will need to log into your DNS provider's control panel and add the TXT records.\033[0m"
    sleep 1
    echo -e "\033[1;34mPress Enter when you're ready to continue...\033[0m"
    read -r  # Wait for the user to press Enter

    # Run certbot command and display its output
    if ! eval "$certbot_command"; then
        echo -e "\033[1;31mWildcard SSL certificate generation failed.\033[0m"
        echo -e "\033[1;31mReturning to base domain entry.\033[0m"
        ssl  # Return to allow retry from the main menu or calling function
    fi

    echo -e "\033[1;32mWildcard SSL certificate generation completed successfully.\033[0m"
    ssl
}




#manage_marzban_node
manage_marzban_node() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m        Manage Marzban Node\033[0m"
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;32m1.\033[0m Setup Marzban-node"
echo -e "\033[1;32m2.\033[0m Change node ports"
echo -e "\033[1;32m3.\033[0m Edit node certificates"
echo -e "\033[1;32m4.\033[0m Edit docker-compose.yml with nano"
echo -e "\033[1;32m5.\033[0m Restart Docker Compose services"
echo -e "\033[1;32m6.\033[0m Download custom Xray version"
echo -e "\033[1;32m7.\033[0m Enable/disable custom Xray version"
echo -e "\033[1;32m8.\033[0m Update Marzban Node"
echo -e "\033[1;32m0.\033[0m Return"
        read -p "Enter your choice: " choice

        case $choice in
            1)  install_docker
                check_docker_compose
                setup_marzban_node
                manage_docker_compose
                ;;
            2) change_node_ports ;;
            3) edit_node_certificates ;;
            4) edit_docker_compose ;;
            5) restart_docker_compose ;;
            6) list_and_download_xray_core ;;
            7) set_custom_xray_version ;;
            8) update_marzban_node ;;
            0) return ;;
            *) echo -e "\033[1;31mInvalid choice. Please enter a number between 1 and 10.\033[0m" ;;
        esac
        
        echo -e "\nPress Enter to continue..."
        read
    done
}
# Swap Management Script

# Function to add a delay for better readability
pause() {
    sleep 1
}

initial_check() {
    SWAP_INFO=$(free | grep Swap)
    SWAPPINESS=$(cat /proc/sys/vm/swappiness)
    CACHE_PRESSURE=$(cat /proc/sys/vm/vfs_cache_pressure)

    if [[ $SWAP_INFO ]]; then
        TOTAL_SWAP=$(echo $SWAP_INFO | awk '{print $2}')
        USED_SWAP=$(echo $SWAP_INFO | awk '{print $3}')
        FREE_SWAP=$(echo $SWAP_INFO | awk '{print $4}')

        if [ "$TOTAL_SWAP" -gt 0 ]; then
            echo -e "\033[1;32mNotice:\033[0m Swap space is available."
            echo -e "\033[1;36mTotal Swap:\033[0m $(numfmt --to=iec $TOTAL_SWAP) (Used: $(numfmt --to=iec $USED_SWAP), Free: $(numfmt --to=iec $FREE_SWAP))"
        else
            echo -e "\033[1;31mNotice:\033[0m No swap space is currently configured."
        fi
    else
        echo -e "\033[1;31mNotice:\033[0m No swap space is currently active."
    fi

    echo -e "\033[1;33mCurrent swappiness value:\033[0m $SWAPPINESS"
    echo -e "\033[1;33mCurrent vfs_cache_pressure value:\033[0m $CACHE_PRESSURE"
    pause
}


# Function to set the swappiness value
set_swappiness() {
    echo -e "\033[1;34mTip:\033[0m Swappiness values range from 0 to 100."
    echo -e " - \033[1;34mLow\033[0m values (0-30) keep more data in RAM for better performance."
    echo -e " - \033[1;34mMedium\033[0m values (40-60) offer a balanced approach."
    echo -e " - \033[1;34mHigh\033[0m values (70-100) may lead to increased latency."
    echo -e "\033[1;34mDefault swappiness:\033[0m 1"

    while true; do
        read -p "Enter new swappiness value (0-100) [default: 1]: " NEW_SWAPPINESS
        NEW_SWAPPINESS=${NEW_SWAPPINESS:-1}  # Set default to 1 if no input is provided

        if [[ "$NEW_SWAPPINESS" =~ ^[0-9]{1,2}$ ]] && [ "$NEW_SWAPPINESS" -ge 0 ] && [ "$NEW_SWAPPINESS" -le 100 ]; then
            sudo sysctl vm.swappiness=$NEW_SWAPPINESS
            echo -e "\033[1;32mSwappiness set to\033[0m $NEW_SWAPPINESS"
            break
        else
            echo -e "\033[1;31mInvalid input. Please enter a number between 0 and 100.\033[0m"
        fi
    done

    read -p "Do you want to make this swappiness value persistent? (yes/no, default: yes): " PERSIST
    PERSIST=${PERSIST:-yes}

    if [ "$PERSIST" = "yes" ]; then
        sudo sed -i '/vm.swappiness/d' /etc/sysctl.conf
        echo "vm.swappiness=$NEW_SWAPPINESS" | sudo tee -a /etc/sysctl.conf
        echo -e "\033[1;32mSwappiness value will persist across reboots.\033[0m"
    fi
    pause
}

# Function to set the vfs_cache_pressure value
set_vfs_cache_pressure() {
    echo -e "\033[1;34mTip:\033[0m vfs_cache_pressure controls how much the kernel prioritizes caching of directory and inode structures."
    echo -e " - \033[1;34mLower\033[0m values (e.g., 1) will cache more for faster directory access."
    echo -e " - Higher values will favor freeing up memory used by cache over other data."

    while true; do
        read -p "Enter new vfs_cache_pressure value (1-1000, default: 1): " NEW_VFS_CACHE_PRESSURE
        NEW_VFS_CACHE_PRESSURE=${NEW_VFS_CACHE_PRESSURE:-1}  # Set default to 1 if no input is provided

        if [[ "$NEW_VFS_CACHE_PRESSURE" =~ ^[0-9]+$ ]] && [ "$NEW_VFS_CACHE_PRESSURE" -ge 1 ] && [ "$NEW_VFS_CACHE_PRESSURE" -le 1000 ]; then
            sudo sysctl vm.vfs_cache_pressure=$NEW_VFS_CACHE_PRESSURE
            echo -e "\033[1;32mvfs_cache_pressure set to\033[0m $NEW_VFS_CACHE_PRESSURE"
            break
        else
            echo -e "\033[1;31mInvalid input. Please enter a number between 1 and 1000.\033[0m"
        fi
    done

    read -p "Do you want to make this vfs_cache_pressure value persistent? (yes/no, default: yes): " PERSIST
    PERSIST=${PERSIST:-yes}

    if [ "$PERSIST" = "yes" ]; then
        sudo sed -i '/vm.vfs_cache_pressure/d' /etc/sysctl.conf
        echo "vm.vfs_cache_pressure=$NEW_VFS_CACHE_PRESSURE" | sudo tee -a /etc/sysctl.conf
        echo -e "\033[1;32mvfs_cache_pressure value will persist across reboots.\033[0m"
    fi
    pause
}




backup_fstab() {
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    sudo cp /etc/fstab "/etc/fstab.backup_$TIMESTAMP"
    echo -e "\033[1;32mBackup of /etc/fstab created as /etc/fstab.backup_$TIMESTAMP\033[0m"
    pause
}

recover_fstab() {
    echo -e "\033[1;33mAvailable backups:\033[0m"
    ls /etc/fstab.backup_*
    
    read -p "Enter the timestamp of the backup you want to recover (e.g., 20240921_142530): " RECOVER_TIMESTAMP
    
    if [ -f "/etc/fstab.backup_$RECOVER_TIMESTAMP" ]; then
        sudo cp "/etc/fstab.backup_$RECOVER_TIMESTAMP" /etc/fstab
        echo -e "\033[1;32m/etc/fstab restored from backup /etc/fstab.backup_$RECOVER_TIMESTAMP\033[0m"
    else
        echo -e "\033[1;31mBackup with timestamp $RECOVER_TIMESTAMP not found.\033[0m"
    fi
    pause
}

add_swap() {
    echo -e "\033[1;32mNotice:\033[0m A backup of the /etc/fstab file will be created first."
    backup_fstab
    
    while true; do
        read -p "Enter swap file size (1-9 GB): " SWAP_SIZE
        
        if [[ "$SWAP_SIZE" =~ ^[1-9]$ ]]; then
            SWAP_SIZE="${SWAP_SIZE}G"
            break
        else
            echo -e "\033[1;31mInvalid input. Please enter a number between 1 and 9.\033[0m"
        fi
    done
    
    read -p "Do you want to enable swap permanently? (yes/no, default: yes): " PERMANENT
    if [ -z "$PERMANENT" ]; then
        PERMANENT="yes"
    fi

    # Create swap file
    sudo fallocate -l "$SWAP_SIZE" /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile

    # Make it permanent if chosen
    if [ "$PERMANENT" = "yes" ]; then
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi

    echo -e "\033[1;32mSwap space of\033[0m $SWAP_SIZE \033[1;32madded and activated.\033[0m"
    pause
}

remove_swap() {
    echo -e "\033[1;32mNotice:\033[0m A backup of the /etc/fstab file will be created first."
    backup_fstab
    sudo swapoff -a
    sudo sed -i '/\/swapfile/d' /etc/fstab
    echo -e "\033[1;32mSwap space removed.\033[0m"
    pause
}
swap() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m        Manage Swap\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    initial_check  # Perform initial checks

    while true; do
        echo -e "\033[1;32m1.\033[0m Install SWAP"
        echo -e "\033[1;32m2.\033[0m Uninstall SWAP"
        echo -e "\033[1;32m3.\033[0m Recover /etc/fstab from backup"
        echo -e "\033[1;32m4.\033[0m Set swappiness value"
	echo -e "\033[1;32m5.\033[0m Set Cache Pressure value"
        echo -e "\033[1;32m6.\033[0m SWAP status"
	echo -e "\033[1;32m7.\033[0m Edit sysctl.conf"
	echo -e "\033[1;32m8.\033[0m Edit fstab"
	echo -e "\033[1;32m9.\033[0m apply changes"
        echo -e "\033[1;32m0.\033[0m Return to Main Menu"

        read -p "Choose an option (1-5): " OPTION

        case $OPTION in
            1) add_swap ;;
            2) remove_swap ;;
            3) recover_fstab ;;
            4) set_swappiness ;;
	    5) set_vfs_cache_pressure ;;
            6) initial_check ;;
	    7) sudo nano /etc/sysctl.conf ;;
	    8) sudo nano /etc/fstab ;;
	    9) sudo sysctl -p ;;
            0) return ;;  # Exit to the main menu
            *) 
                echo -e "\033[1;31mInvalid option. Please choose again.\033[0m" 
                continue ;;
        esac
    done
}
# webtop
webtop() {
    install_webtop() {
        check_webtop
        check_ram_and_swap
        install_docker
        check_docker

        # Prompt the user for custom username and password
        read -p "Enter the custom username (default Admin): " CUSTOM_USER
        CUSTOM_USER=${CUSTOM_USER:-Admin}  # Set default if empty

        read -p "Enter the custom password (default Admin1234): " PASSWORD
        PASSWORD=${PASSWORD:-Admin1234}  # Set default if empty

        

        # Run the Webtop Docker container with fixed ports 3000 for HTTP and 3001 for HTTPS
        sudo docker run -d \
            --name=webtop \
            --security-opt seccomp=unconfined \
            -e PUID=1000 \
            -e PGID=1000 \
            -e TZ=Etc/UTC \
            -e SUBFOLDER=/ \
            -e TITLE=Webtop \
            -e CUSTOM_USER=$CUSTOM_USER \
            -e PASSWORD=$PASSWORD \
            -p 3000:3000 \
            -p 3001:3001 \
            -v /var/run/docker.sock:/var/run/docker.sock \
            --shm-size="1gb" \
            --restart unless-stopped \
            lscr.io/linuxserver/webtop:latest || handle_error

        echo -e "\033[1;32mWebtop container is being installed with username: $CUSTOM_USER and password: $PASSWORD\033[0m"
        echo -e "\033[1;32mAccess Webtop on HTTP: 3000 and HTTPS: 3001\033[0m"
        sleep 3
        
    }
    check_webtop() {
    # Check if Webtop container already exists
    if sudo docker ps -a --filter "name=webtop" --format '{{.Names}}' | grep -q 'webtop'; then
        # Check if Webtop container is running
        if sudo docker ps --filter "name=webtop" --format '{{.Names}}' | grep -q 'webtop'; then
            echo -e "\033[1;32mWebtop is already running.\033[0m"
            echo -e "\033[1;33mPlease stop and remove Webtop before attempting a reinstallation.\033[0m"
            webtop  # Return to Webtop menu
        else
            echo -e "\033[1;33mWebtop container exists but is stopped.\033[0m"
            echo -e "\033[1;33mPlease remove the Webtop container first before reinstalling.\033[0m"
            webtop  # Return to Webtop menu
        fi
    else
        echo -e "\033[1;33mNo existing Webtop container found. Proceeding with installation...\033[0m"
        
    fi
}


    check_ram_and_swap() {
    # Get the total memory in GB
    total_mem=$(awk '/MemTotal/ { printf "%.2f \n", $2/1024/1024 }' /proc/meminfo)

    # Check if total memory is less than 1.5 GB
    if (( $(echo "$total_mem < 1.5" | bc -l) )); then
        echo -e "\033[1;33mYour system has $total_mem GB of RAM.\033[0m"
        echo -e "\033[1;31mIt is recommended to have at least 2 GB of RAM.\033[0m"
        echo -e "\033[1;31mConsider upgrading your RAM or enabling swap.\033[0m"

        # Check if swap is enabled and its size
        swap_total=$(awk '/SwapTotal/ { printf "%.2f \n", $2/1024 }' /proc/meminfo)

        if (( $(echo "$swap_total >= 500" | bc -l) )); then
            echo -e "\033[1;32mSwap is already enabled and its size is ${swap_total}MB, which is sufficient.\033[0m"
        else
            echo -e "\033[1;31mSwap is either not enabled or less than 500MB.\033[0m"
            read -p "Do you want to enable or increase swap size? (yes/no): " enable_swap
            if [[ "$enable_swap" == "yes" ]]; then
                swap  # Call your swap function
            else
                echo -e "\033[1;33mSwap not enabled. Proceed with caution on low memory.\033[0m"
            fi
        fi
    else
        echo -e "\033[1;32mYour system has $total_mem GB of RAM, which is sufficient.\033[0m"
    fi
}

    check_docker() {
        # Check if Docker is installed
        if ! command -v docker &> /dev/null; then
            echo -e "\033[1;31mDocker is not installed. Installing Docker...\033[0m"
            sudo apt update
            sudo apt install -y docker.io || handle_error
            sudo systemctl start docker
            sudo systemctl enable docker
            echo -e "\033[1;32mDocker installed and started successfully.\033[0m"
        else
            echo -e "\033[1;32mDocker is already installed.\033[0m"
        fi

        # Check if Docker service is running
        if ! sudo systemctl is-active --quiet docker; then
            echo -e "\033[1;33mDocker service is not running. Starting Docker service...\033[0m"
            sudo systemctl start docker || handle_error
            echo -e "\033[1;32mDocker service started successfully.\033[0m"
        else
            echo -e "\033[1;32mDocker service is already running.\033[0m"
        fi
    }

    edit_webtop() {
        echo -e "\033[1;33mStopping the Webtop container...\033[0m"
        sudo docker stop webtop || handle_error
        sudo docker rm webtop || handle_error
        install_webtop
    }

    start_webtop() {
        if sudo docker ps --filter "name=webtop" --format '{{.Names}}' | grep -q 'webtop'; then
            echo -e "\033[1;32mWebtop container is already running.\033[0m"
        else
            echo -e "\033[1;33mStarting the Webtop container...\033[0m"
            sudo docker start webtop || handle_error
            echo -e "\033[1;32mWebtop container started successfully.\033[0m"
        fi
    }

    stop_webtop() {
        if sudo docker ps --filter "name=webtop" --format '{{.Names}}' | grep -q 'webtop'; then
            echo -e "\033[1;33mStopping the Webtop container...\033[0m"
            sudo docker stop webtop || handle_error
            echo -e "\033[1;32mWebtop container stopped successfully.\033[0m"
        else
            echo -e "\033[1;31mWebtop container is not running.\033[0m"
        fi
    }

    restart_webtop() {
        echo -e "\033[1;33mRestarting the Webtop container...\033[0m"
        sudo docker restart webtop || handle_error
        echo -e "\033[1;32mWebtop container restarted successfully.\033[0m"
    }

    remove_webtop() {
        if sudo docker ps -a --filter "name=webtop" --format '{{.Names}}' | grep -q 'webtop'; then
            echo -e "\033[1;33mStopping and removing the Webtop container...\033[0m"
            sudo docker stop webtop || handle_error
            sudo docker rm webtop || handle_error
            echo -e "\033[1;32mWebtop container removed successfully.\033[0m"
        else
            echo -e "\033[1;31mWebtop container not found.\033[0m"
        fi
    }

    handle_error() {
        echo -e "\033[1;31mAn error occurred. Please check the Docker commands.\033[0m"
        webtop
    }

    # Main Menu
    while true; do
        echo -e "\n\033[1;34m\033[1m=====Webtop Management Menu=====\033[0m"
        echo -e "\033[1;32m1. Install Webtop\033[0m"
        echo -e "\033[1;32m2. Start Webtop\033[0m"
        echo -e "\033[1;32m3. Reinstall webtop\033[0m"
        echo -e "\033[1;32m4. Stop Webtop\033[0m"
        echo -e "\033[1;32m5. Restart Webtop\033[0m"
        echo -e "\033[1;32m6. Remove Webtop\033[0m"
        echo -e "\033[1;32m7. Return to menu\033[0m"

        read -p "Choose an option: " choice

        case $choice in
            1) install_webtop ;;
            2) start_webtop ;;
            3) edit_webtop ;;
            4) stop_webtop ;;
            5) restart_webtop ;;
            6) remove_webtop ;;
            7) break ;;
            *) echo -e "\033[1;31mInvalid option. Please try again.\033[0m" ;;
        esac
    done
}
# Backup Menu Function
backup_menu() {
    echo -e "\033[1;34mBackup Menu:\033[0m"
    echo -e "\033[1;32m1.\033[0m Transfer panel to another server"
    echo -e "\033[1;32m2.\033[0m Backup by Erfan (Marzban X-ui Hiddify Custom)"
    echo -e "\033[1;32m3.\033[0m Backup by AC-Lover (Marzban X-ui Hiddify)"
    echo -e "\033[1;32m5.\033[0m Return to Main Menu"

    read -p "Choose an option [1-5]: " choice

    # Script 1: Transfer-me backup script
    script_1="sudo bash -c \"\$(curl -sL https://github.com/iamtheted/transfer-me/raw/main/install.sh)\""

    # Script 2: Backuper backup script
    script_2="sudo bash -c \"\$(curl -sL https://github.com/erfjab/Backuper/raw/master/install.sh)\""

    # Script 3: AC-Lover backup script
    script_3="sudo bash -c \"\$(curl -sL https://github.com/AC-Lover/backup/raw/main/backup.sh)\""

    case $choice in
        1)
            echo -e "\033[1;32mRunning Backup Script 1 (Transfer-me)...\033[0m"
            eval $script_1 || { echo -e "\033[1;31mError running Backup Script 1.\033[0m"; return 1; }
            ;;
        2)
            echo -e "\033[1;32mRunning Backup Script 2 (Backuper)...\033[0m"
            eval $script_2 || { echo -e "\033[1;31mError running Backup Script 2.\033[0m"; return 1; }
            ;;
        3)
            echo -e "\033[1;32mRunning Backup Script 3 (AC-Lover)...\033[0m"
            eval $script_3 || { echo -e "\033[1;31mError running Backup Script 3.\033[0m"; return 1; }
            ;;
        5)
            echo -e "\033[1;32mReturning to the Main Menu...\033[0m"
            main_menu  # Assuming this is defined elsewhere in your script
            ;;
        *)
            echo -e "\033[1;31mInvalid option, please choose a valid option [1-5].\033[0m"
            backup_menu  # Recursively call the menu if an invalid option is selected
            ;;
    esac
}
#mysql
# Define file paths
env_file="/opt/marzban/.env"
compose_file="/opt/marzban/docker-compose.yml"
backup_dir="/opt/marzban/backups"
marzban_lib_dir="/var/lib/marzban"
timestamp=$(date +%Y%m%d_%H%M%S)

# Function to update Docker Compose configuration
update_docker_compose() {
    if [[ -f "$compose_file" ]]; then
        echo -e "\033[1;34mUpdating Docker Compose configuration...\033[0m"
        cat <<EOL > "$compose_file"
services:
  marzban:
    image: gozargah/marzban:dev
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban

    depends_on:
      - mysql
      
  mysql:
    image: mysql:latest
    restart: always
    env_file: .env
    network_mode: host
    command: --bind-address=127.0.0.1 --mysqlx-bind-address=127.0.0.1 --disable-log-bin
    environment:
      MYSQL_DATABASE: marzban
    volumes:
      - /var/lib/marzban/mysql:/var/lib/mysql
      
  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    restart: always
    env_file: .env
    network_mode: host
    environment:
      PMA_HOST: 127.0.0.1
      APACHE_PORT: 8010
      UPLOAD_LIMIT: 1024M
    depends_on:
      - mysql
EOL
        echo -e "\033[1;32mDocker Compose updated successfully.\033[0m"
    else
        echo -e "\033[1;31mError: $compose_file not found.\033[0m"
    fi
}

update_env_variables() {
    # Ask for the MySQL root password twice
    read -p "Enter the MySQL root password: " db_password_1
    echo
    read -p "Confirm the MySQL root password: " db_password_2
    echo

    # Check if both passwords match
    if [[ "$db_password_1" != "$db_password_2" ]]; then
        echo -e "\033[1;31mError: Passwords do not match. Please try again.\033[0m"
        return 1
    fi

    # Ensure the password is not empty
    if [[ -z "$db_password_1" ]]; then
        echo -e "\033[1;31mError: Password cannot be empty.\033[0m"
        return 1
    fi



    if [[ -f "$env_file" ]]; then
        echo -e "\033[1;34mUpdating environment variables in $env_file...\033[0m"

        # Remove existing MySQL-related variables
        sed -i '/^SQLALCHEMY_DATABASE_URL=mysql+pymysql:.*$/d' "$env_file"
        sed -i '/^MYSQL_ROOT_PASSWORD=.*$/d' "$env_file"

        # Comment out existing SQLite configuration if it exists
        sed -i 's|^SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"|#&|' "$env_file"

        # Add MySQL-related variables
        sed -i "\$aSQLALCHEMY_DATABASE_URL=mysql+pymysql://root:$db_password_1@127.0.0.1/marzban" "$env_file"
        sed -i "\$aMYSQL_ROOT_PASSWORD=$db_password_1" "$env_file"

        echo -e "\033[1;32mEnvironment variables updated successfully.\033[0m"
    else
        echo -e "\033[1;31mError: $env_file not found.\033[0m"
        return 1
    fi
}


# Function to backup essential directories
backup_essential_folders() {
    backup_file="$backup_dir/backup_$timestamp.tar.gz"
    echo -e "\033[1;34mBacking up essential folders...\033[0m"

    mkdir -p "$backup_dir"
    tar -czvf "$backup_file" "$env_file" "$compose_file" "$marzban_lib_dir" "$backup_dir" || {
        echo -e "\033[1;31mBackup failed. Please check the error messages above.\033[0m"
        return 1
    }
    
    echo -e "\033[1;32mBackup created successfully at $backup_file\033[0m"
}

# Function to restore from a backup
restore_from_backup() {
    echo -e "\033[1;34mAvailable backups:\033[0m"
    ls "$backup_dir"

    read -p "Enter the name of the backup file to restore (e.g., backup_YYYYMMDD_HHMMSS.tar.gz): " backup_file

    if [[ -f "$backup_dir/$backup_file" ]]; then
        echo -e "\033[1;34mRestoring from $backup_file...\033[0m"
        tar -xzvf "$backup_dir/$backup_file" -C / || {
            echo -e "\033[1;31mRestore failed. Please check the error messages above.\033[0m"
            return 1
        }
        echo -e "\033[1;32mRestore completed successfully.\033[0m"
    else
        echo -e "\033[1;31mError: Backup file not found.\033[0m"
    fi
}
# Function to check if necessary applications are installed
check_and_install_dependencies() {
    for cmd in sqlite3 sed docker-compose; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "\033[1;31mError: $cmd is not installed. Attempting to install...\033[0m"
            if [[ "$cmd" == "sqlite3" ]]; then
                if [[ -x "$(command -v apt)" ]]; then
                    sudo apt update && sudo apt install -y sqlite3 || { echo -e "\033[1;31mFailed to install sqlite3.\033[0m"; exit 1; }
                elif [[ -x "$(command -v yum)" ]]; then
                    sudo yum install -y sqlite || { echo -e "\033[1;31mFailed to install sqlite3.\033[0m"; exit 1; }
                else
                    echo -e "\033[1;31mPackage manager not supported. Please install sqlite3 manually.\033[0m"
                    exit 1
                fi
            else
                echo -e "\033[1;31mPlease install $cmd manually.\033[0m"
                exit 1
            fi
        fi
    done
}

# Function to dump SQLite database
dump_sqlite_database() {
    echo -e "\033[1;34mDumping SQLite database...\033[0m"
    sqlite3 /var/lib/marzban/db.sqlite3 '.dump --data-only' | sed "s/INSERT INTO \([^ ]*\)/REPLACE INTO \`\\1\`/g" > /tmp/dump.sql || {
        echo -e "\033[1;31mFailed to dump the database. Please check the error messages above.\033[0m"
        return 1
    }
    echo -e "\033[1;32mDatabase dumped successfully to /tmp/dump.sql\033[0m"
}

# Function to restore from the dump file to MySQL
restore_from_dump() {
    echo -e "\033[1;34mRestoring database from dump file to MySQL...\033[0m"

    # Change to the Marzban directory
    cd /opt/marzban || {
        echo -e "\033[1;31mError: Could not change to /opt/marzban directory.\033[0m"
        return 1
    }

    # Copy the dump.sql file to the MySQL container
    docker-compose cp /tmp/dump.sql mysql:/dump.sql || {
        echo -e "\033[1;31mError: Failed to copy dump.sql to MySQL container.\033[0m"
        return 1
    }

    # Execute the SQL commands in the MySQL container
    read -s -p "Enter the MySQL root password: " db_password
    echo

    docker-compose exec mysql mysql -u root -p"$db_password" -h 127.0.0.1 marzban -e "SET FOREIGN_KEY_CHECKS = 0; SET NAMES utf8mb4; SOURCE /dump.sql;" || {
        echo -e "\033[1;31mError: Failed to execute SQL commands in MySQL container.\033[0m"
        return 1
    }

    echo -e "\033[1;32mDatabase restored successfully from dump.sql to MySQL.\033[0m"
}

# Function to transfer data from SQLite to MySQL
transfer_data() {
    check_and_install_dependencies
    dump_sqlite_database
    restore_from_dump
}
# Main menu function
mysql() {
    while true; do
        echo -e "\033[1;34mChange database to MySql:\033[0m"
        echo -e "\033[1;32m1.\033[0m Update Docker Compose for mysql"
        echo -e "\033[1;32m2.\033[0m Update env for mysql"
        echo -e "\033[1;32m3.\033[0m Create Backup"
        echo -e "\033[1;32m4.\033[0m Restore backup"
        echo -e "\033[1;32m5.\033[0m Transfer data from SQLite to MySQL"
        echo -e "\033[1;32m6.\033[0m Edit .env using nano"
        echo -e "\033[1;32m7.\033[0m Edit compose_file using nano"
        echo -e "\033[1;32m8.\033[0m Restart Marzban"
        echo -e "\033[1;32m0.\033[0m return"

        read -p "Choose an option [0-8]: " choice

        case $choice in
            1) update_docker_compose ;;
            2) update_env_variables ;;
            3) backup_essential_folders ;;
            4) restore_from_backup ;;
            5) transfer_data ;;
            6) nano "$env_file" ;;
            7) nano "$compose_file" ;;
            8) marzban restart ;;
            0) 
                 echo -e "\033[1;32mExiting...\033[0m"; 
                 marzban_commands
                ;;
            *) echo -e "\033[1;31mInvalid option. Please choose a valid option [0-8].\033[0m" 
        esac
        echo -e "\033[1;34mReturning to the main menu...\033[0m"
    done
}
###################################

# Function to check if specific ports are busy (TCP only)
check_ports() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m         Check Ports Status\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    ports=(443 80 53) # Ports to check
    any_port_busy=false  # Track if any port is busy

    for port in "${ports[@]}"; do
        if lsof -iTCP -P -n | grep -q ":$port (LISTEN)"; then
            any_port_busy=true
            echo -e "\033[1;31mPort $port is in use (TCP).\033[0m"
            lsof -iTCP -P -n | grep ":$port (LISTEN)" | awk '{print $1, $2, $9}'  # Show process name, PID, and connection
        else
            echo -e "\033[1;32mPort $port is available.\033[0m"
        fi
    done

    if [[ "$any_port_busy" == false ]]; then
        echo -e "\033[1;32mNo TCP ports are busy.\033[0m"
    fi

    # Wait for user to press Enter to return to DNS setup
    echo -e "\033[1;33mPress Enter to return to DNS setup...\033[0m"
    read -r  # Wait for the user to press Enter
    create_dns  # Call the create_dns function
}



# Function to get the current SSH user's IP address
get_current_ssh_user_ip() {
    current_ip=$(who am i | awk '{print $5}' | tr -d '()') # Extract the IP address
    echo "$current_ip"
}


create_custom_dns() {
    # Check if the ports are available
    ports=(443 80 53) # Ports to check
    any_port_busy=false  # Track if any port is busy

    for port in "${ports[@]}"; do
        if lsof -iTCP -P -n | grep -q ":$port (LISTEN)"; then
            any_port_busy=true
            echo -e "\033[1;31mPort $port is in use (TCP).\033[0m"
            lsof -iTCP -P -n | grep ":$port (LISTEN)" | awk '{print $1, $2, $9}'  # Show process name, PID, and connection
        else
            echo -e "\033[1;32mPort $port is available.\033[0m"
        fi
    done

    if [[ "$any_port_busy" == false ]]; then
        echo -e "\033[1;32mNo TCP ports are busy.\033[0m"
    fi
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m            Create Your Custom DNS (snidust)\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    # Check if the container is already running
    container_name="snidust"
    if [ "$(docker ps -q -f name="$container_name")" ]; then
        echo -e "\033[1;31mDocker container '$container_name' is already running.\033[0m"
        echo -e "\033[1;33mPlease stop and remove the existing container before creating a new one.\033[0m"
        manage_container
    fi
      echo -e "\033[1;33mStarting Create Your Custom DNS (snidust)\033[0m"
      
    select_allowed_clients() {
        # Get current SSH user IP
        default_ip=$(get_current_ssh_user_ip)


    echo -e "\033[1;32m1)\033[0m \033[1;37mDefault [Your IP: $default_ip]\033[0m"
    echo -e "\033[1;32m2)\033[0m \033[1;37mUse 0.0.0.0/0 for all clients\033[0m"
    echo -e "\033[1;32m3)\033[0m \033[1;37mEnter allowed clients (comma-separated) [Default: $default_ip]\033[0m"
    echo -e "\033[1;32m4)\033[0m \033[1;37mLoad allowed clients from /root/allowed.txt\033[0m"

    echo -e "\033[1;36m--------------------------------------------\033[0m"
    read -p "$(echo -e "\033[1;33mEnter allowed clients [1-4]: \033[0m")" option

    case $option in
        1)
            ALLOWED_CLIENTS="$default_ip"
            ;;
        2)
            ALLOWED_CLIENTS="0.0.0.0/0"
            ;;
        3)
            read -p "Enter the allowed clients (separate with a comma): " custom_clients
            ALLOWED_CLIENTS=${custom_clients:-$default_ip}  # Use default IP if no input is provided
            ;;
        4)
            if [ -f /root/allowed.txt ]; then
                # Extract IPs and domains from /root/allowed.txt
                ALLOWED_CLIENTS=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' /root/allowed.txt | paste -sd, -)
                
                if [ -z "$ALLOWED_CLIENTS" ]; then
                    echo -e "\033[1;31mNo valid clients (IPs or domains) found in /root/allowed.txt. Defaulting to your IP: $default_ip.\033[0m"
                    ALLOWED_CLIENTS="$default_ip"
                else
                    echo -e "\033[1;32mAllowed clients from /root/allowed.txt: $ALLOWED_CLIENTS\033[0m"
                fi
            else
                echo -e "\033[1;31mFile /root/allowed.txt not found. Defaulting to your IP: $default_ip.\033[0m"
                ALLOWED_CLIENTS="$default_ip"
            fi
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Defaulting to your IP: $default_ip.\033[0m"
            ALLOWED_CLIENTS="$default_ip"
            ;;
    esac

    echo -e "\033[1;32mAllowed clients set to: $ALLOWED_CLIENTS\033[0m"
}

    # Call select_allowed_clients to determine allowed clients
    select_allowed_clients

    # Prompt for external IP, with a method to find public IP
    echo -e "\033[1;33mEnter your server IP: [$(curl -s ifconfig.me)]:\033[0m"
    read -p " > " external_ip
    external_ip=${external_ip:-$(curl -s ifconfig.me)} # Use public IP as default

    # Prompt for using custom domains with default set to 'yes'
echo -e "\033[1;33mDo you have custom domains? (yes/no) [yes]:\033[0m"
echo -e "\033[1;33mSelect no to spoof all domains\033[0m"
read -p " > " custom_domains_input
custom_domains_input=${custom_domains_input,,} # Convert to lowercase

# Default to 'yes' if no input is provided
if [[ -z "$custom_domains_input" ]]; then
    custom_domains_input="yes"
fi

if [[ "$custom_domains_input" == "yes" ]]; then
    # Prompt to download the domain list file
    echo -e "\033[1;33mDo you want to download the domain list file from the server? (yes/no) [no]:\033[0m"
    read -p " > " download_choice
    download_choice=${download_choice,,} # Convert to lowercase

    if [[ "$download_choice" == "yes" ]]; then
        # Download the custom domains file
        echo -e "\033[1;33mDownloading the custom domains file...\033[0m"
        wget -O /root/99-custom.lst https://sub-s3.s3.eu-central-1.amazonaws.com/99-custom.lst
        if [[ $? -eq 0 ]]; then
            echo -e "\033[1;32mDownload successful! The file has been saved to /root/99-custom.lst.\033[0m"
        else
            echo -e "\033[1;31mDownload failed. Please check your connection or URL.\033[0m"
        fi
    fi

    custom_domains="-v /root/99-custom.lst:/etc/snidust/domains.d/99-custom.lst:ro"
    spoof_domains="false" # Disable spoofing if custom domains are used
else
    custom_domains=""
    spoof_domains="true" # Set to true if no custom domains are provided
    echo -e "\033[1;32mSelected all domains for spoofing.\033[0m"
fi


    # Prepare the Docker command
    docker_command="docker run -d \
        --name \"$container_name\" \
        -e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\" \
        -e EXTERNAL_IP=\"$external_ip\" \
        -e SPOOF_ALL_DOMAINS=\"$spoof_domains\" \
        -p 443:8443 \
        -p 80:8080 \
        -p 53:5300/udp \
        $custom_domains \
        ghcr.io/seji64/snidust:1.0.15"

    # Run Docker container with snidust image
    echo -e "\033[1;32mRunning the Docker container with snidust configuration...\033[0m"
    eval "$docker_command"

    # Verify that the container is running
    if [ "$(docker ps -q -f name="$container_name")" ]; then
        echo -e "\033[1;32mDocker container '$container_name' is up and running with snidust DNS settings.\033[0m"
    else
        echo -e "\033[1;31mFailed to start the Docker container. Please check your settings and try again.\033[0m"
    fi
}

# Function to manage the Docker container (start, stop, restart, remove)
manage_container() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m            Manage Docker Container\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;32m1. Start Container\033[0m"
    echo -e "\033[1;32m2. Stop Container\033[0m"
    echo -e "\033[1;32m3. Restart Container\033[0m"
    echo -e "\033[1;32m4. Remove Container\033[0m"
    echo -e "\033[1;32m5. Return to Main Menu\033[0m"
    read -p "> " choice

    case $choice in
        1) 
            echo -e "\033[1;32mStarting Docker container 'snidust'...\033[0m"
            docker start snidust
            ;;
        2) 
            echo -e "\033[1;32mStopping Docker container 'snidust'...\033[0m"
            docker stop snidust
            ;;
        3) 
            echo -e "\033[1;32mRestarting Docker container 'snidust'...\033[0m"
            docker restart snidust
            ;;
        4) 
            echo -e "\033[1;32mRemoving Docker container 'snidust'...\033[0m"
            docker rm -f snidust
            ;;
        5) 
            return
            ;;
        *) 
            echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
            ;;
    esac
}

manage_custom_domains() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m         Edit Custom Domains\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    echo -e "\033[1;33mExample for editing:\033[0m"
    echo -e "\033[1;33mcheck-host.net\033[0m"
    echo -e "\033[1;33mxbox.com\033[0m"

    # Main menu for managing custom domains
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33mOptions:\033[0m"
        echo -e "\033[1;32m1.\033[0m Edit custom domains file"
        echo -e "\033[1;32m2.\033[0m Download custom domains file"
        echo -e "\033[1;32m0.\033[0m Return to DNS menu"
        echo -e "\033[1;36m============================================\033[0m"

        read -p "Choose an option: " choice
        case $choice in
            1)
                echo -e "\033[1;33mOpening the custom domains file for editing...\033[0m"
                nano /root/99-custom.lst
                ;;

            2)
                # Download the custom domains file
                echo -e "\033[1;33mDownloading the custom domains file...\033[0m"
                wget -O /root/99-custom.lst https://sub-s3.s3.eu-central-1.amazonaws.com/99-custom.lst
                if [[ $? -eq 0 ]]; then
                    echo -e "\033[1;32mDownload successful! The file has been saved to /root/99-custom.lst.\033[0m"
                else
                    echo -e "\033[1;31mDownload failed. Please check your connection or URL.\033[0m"
                fi
                ;;

            0)
                echo -e "\033[1;31mReturning to the DNS menu...\033[0m"
                create_dns
                
                ;;

            *)
                echo -e "\033[1;31mInvalid option. Please choose again.\033[0m"
                ;;
        esac

        # Ask the user if they want to restart the container after editing/downloading
        while true; do
            read -p "Do you want to restart the container? (yes/no): " restart_choice
            if [[ "$restart_choice" == "yes" ]]; then
                echo -e "\033[1;33mRestarting the container...\033[0m"
                docker restart snidust
                create_dns
                
            elif [[ "$restart_choice" == "no" ]]; then
                echo -e "\033[1;31mContainer restart skipped.\033[0m"
                create_dns
            else
                echo -e "\033[1;31mInvalid input. Please enter 'yes' or 'no'.\033[0m"
            fi
        done
    done
}


edit_clients() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m         Edit Allowed Clients\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    echo -e "\033[1;33mSeparate with a comma, for example:\033[0m"
    echo -e "\033[1;32m192.168.1.1,ddns.com,1.2.3.4\033[0m"

    read -p "Press Enter to edit with nano, or type '0' to return: " input
    if [[ "$input" == "0" ]]; then
        echo -e "\033[1;31mExiting without changes.\033[0m"
        create_dns
        return
    fi

    # Open the custom domains file with nano
    nano /root/allowed.txt

    # Ask the user if they want to recreate the container
    read -p "Do you want to recreate the container? (yes/no): " restart_choice
    if [[ "$restart_choice" == "yes" ]]; then
        echo -e "\033[1;33mRecreating the container...\033[0m"
        docker stop snidust
        docker rm -f snidust
        create_custom_dns
    elif [[ "$restart_choice" == "no" ]]; then
        echo -e "\033[1;31mContainer recreate skipped.\033[0m"
    else
        echo -e "\033[1;31mInvalid input. Please enter 'yes' or 'no'.\033[0m"
    fi

    create_dns  # Exit after handling the restart
}

# create_dns
create_dns() {
    while true; do
        echo -e "\033[1;36m===========create custom dns==============\033[0m"
        echo -e "\033[1;31mport 80 443 53 must be free \033[0m"
        echo -e "\033[1;31m[set custom dns] to free up port 53 (from main menu) \033[0m"
        echo -e "\033[1;32m1. Create DNS\033[0m"
        echo -e "\033[1;32m2. Edit Custom Domains\033[0m"
        echo -e "\033[1;32m3. Edit Docker Container\033[0m"
        echo -e "\033[1;32m4. Check Ports Status\033[0m"
        echo -e "\033[1;32m5. Edit Allowed clients\033[0m"
        echo -e "\033[1;32m0. Main menu\033[0m"
        read -p "> " choice

        case $choice in
            1) create_custom_dns ;;
            2) manage_custom_domains ;;
            3) manage_container ;;
            4) check_ports ;;
            5) edit_clients ;;
            0) main_menu ;;
            *) echo -e "\033[1;31mInvalid option. Please try again.\033[0m" ;;
        esac
    done
}
# ping
manage_ping() {
    while true; do
        echo -e "${BLUE}==============================${NC}"
        echo -e "${YELLOW}Select an option:${NC}"
        echo -e "${GREEN}1) Disable ping responses${NC}"
        echo -e "${GREEN}2) Enable ping responses${NC}"
        echo -e "${RED}0) Exit${NC}"
        echo -e "${BLUE}==============================${NC}"
        read -p "Enter your choice: " choice

        case $choice in
            1)
                echo -e "${YELLOW}Disabling ping responses...${NC}"
                echo 1 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all
                echo -e "${GREEN}Ping responses have been disabled.${NC}"
                ;;
            2)
                echo -e "${YELLOW}Enabling ping responses...${NC}"
                echo 0 | sudo tee /proc/sys/net/ipv4/icmp_echo_ignore_all
                echo -e "${GREEN}Ping responses have been enabled.${NC}"
                ;;
            0)
                echo -e "${RED}Exiting...${NC}"
                break
                ;;
            *)
                echo -e "${RED}Invalid option. Please enter 1, 2, or 0.${NC}"
                ;;
        esac

        # Make the change permanent
        echo -e "${BLUE}Updating /etc/sysctl.conf...${NC}"
        sudo sed -i.bak '/net.ipv4.icmp_echo_ignore_all/d' /etc/sysctl.conf
        if [ "$choice" -eq 1 ]; then
            echo "net.ipv4.icmp_echo_ignore_all=1" | sudo tee -a /etc/sysctl.conf
        elif [ "$choice" -eq 2 ]; then
            echo "net.ipv4.icmp_echo_ignore_all=0" | sudo tee -a /etc/sysctl.conf
        fi

        # Apply changes
        sudo sysctl -p
    done
}
#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash

#!/bin/bash

# Function to check if required packages are installed
check_requirements() {
    if ! command -v cron &> /dev/null; then
        echo "Installing cron..."
        sudo apt update && sudo apt install -y cron
    fi

    if ! command -v nano &> /dev/null; then
        echo "Installing nano..."
        sudo apt update && sudo apt install -y nano
    fi
}

# Function to check if required packages are installed
check_requirements() {
    if ! command -v cron &> /dev/null; then
        echo -e "${YELLOW}Installing cron...${RESET}"
        sudo apt update && sudo apt install -y cron
    fi

    if ! command -v nano &> /dev/null; then
        echo -e "${YELLOW}Installing nano...${RESET}"
        sudo apt update && sudo apt install -y nano
    fi
}

#!/bin/bash

# ANSI color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Function to check if required packages are installed
check_requirements() {
    if ! command -v cron &> /dev/null; then
        echo -e "${YELLOW}Installing cron...${RESET}"
        sudo apt update && sudo apt install -y cron
    fi

    if ! command -v nano &> /dev/null; then
        echo -e "${YELLOW}Installing nano...${RESET}"
        sudo apt update && sudo apt install -y nano
    fi
}

#!/bin/bash



# Function to check if required packages are installed
check_requirements() {
    if ! command -v cron &> /dev/null; then
        echo -e "${GREEN}Installing cron...${RESET}"
        sudo apt update && sudo apt install -y cron
    fi

    if ! command -v nano &> /dev/null; then
        echo -e "${GREEN}Installing nano...${RESET}"
        sudo apt update && sudo apt install -y nano
    fi
}

# Function to add cron job for restarting Marzban or x-ui
panels_restart_cron() {
    check_requirements # Ensure cron and nano are installed

    while true; do
        # Prompt to select which panel to manage
        echo -e "${CYAN}Select the service to manage:${RESET}"
        echo -e "${GREEN}1. Restart Marzban${RESET}"
        echo -e "${GREEN}2. Restart x-ui${RESET}"
        echo -e "${GREEN}3. Edit Crontab${RESET}"
        echo -e "${GREEN}4. Reload Cron${RESET}"
        echo -e "${GREEN}5. Exit${RESET}"
        
        read -rp "Enter your choice (1-5): " choice
        
        case "$choice" in
            1)
                service_command="marzban restart" # Set command for restarting Marzban
                echo -e "${BLUE}You selected to restart Marzban.${RESET}"
                ;;
            2)
                service_command="systemctl restart x-ui" # Command for restarting x-ui
                echo -e "${BLUE}You selected to restart x-ui.${RESET}"
                ;;
            3)
                echo -e "${CYAN}Opening crontab in nano for editing...${RESET}"
                nano <(crontab -l)
                echo -e "${GREEN}Crontab updated.${RESET}"
                continue
                ;;
            4)
                echo -e "${GREEN}Reloading cron service...${RESET}"
                sudo service cron reload
                echo -e "${GREEN}Cron service reloaded.${RESET}"
                continue
                ;;
            5)
                echo -e "${RED}Exiting...${RESET}"
                return
                ;;
            *)
                echo -e "${RED}Invalid selection. Please try again.${RESET}"
                continue
                ;;
        esac

        # Ask for the specific hour to run the restart
        while true; do
            read -rp "Enter the hour to restart (0-23): " hour

            # Validate hour
            if [[ "$hour" =~ ^[0-9]$ || "$hour" =~ ^1[0-9]$ || "$hour" == "2[0-3]" ]]; then
                break # Exit the loop if the input is valid
            else
                echo -e "${RED}Invalid hour. Please enter a valid hour (0-23).${RESET}"
            fi
        done

        # Ask for the number of days between restarts with validation
        while true; do
            read -rp "Enter the number of days between restarts (1 for daily, 2 for every 2 days, etc.): " days

            # Ensure valid number for days (1 or greater)
            if [[ "$days" =~ ^[1-9][0-9]*$ ]]; then
                break # Exit the loop if the input is valid
            else
                echo -e "${RED}Invalid input. Please enter a valid number (1 or greater).${RESET}"
            fi
        done

        # Schedule the cron job for the specified time and day interval (minutes set to 00)
        cron_time="00 $hour */$days * *"
        echo -e "${CYAN}Scheduling cron job: $cron_time $service_command${RESET}"

        # Create a temporary file to hold the new cron job
        temp_crontab=$(mktemp)

        # Add existing cron jobs to the temporary file
        crontab -l > "$temp_crontab" 2>/dev/null

        # Check for existing cron jobs to avoid duplicates
        if grep -q "$service_command" "$temp_crontab"; then
            echo -e "${GREEN}Cron job for $service_command already exists. Skipping addition.${RESET}"
        else
            # Add the new cron job
            echo "$cron_time $service_command" >> "$temp_crontab"
            echo -e "${GREEN}Cron job added: $cron_time $service_command${RESET}"
        fi

        # Install the new crontab from the temporary file
        crontab "$temp_crontab"
        rm "$temp_crontab" # Clean up temporary file

        # Reload cron service to apply changes
        echo -e "${GREEN}Reloading cron service...${RESET}"
        sudo service cron reload

        # Optionally, run the service command immediately to verify it works
        echo -e "${CYAN}Running the command now to check if it works...${RESET}"
        eval "$service_command"

        echo # Print a newline for better readability
    done
}


#!/bin/bash
#!/bin/bash

setup_docker() {
    while true; do
        echo -e "\033[1;34mSelect an option:\033[0m"
        echo "1. Set DNS"
        echo "2. Setup Docker"
        echo "0. Main menu"

        read -p "Enter your choice: " choice
        
        case $choice in
            1)
                # Display current DNS settings
                echo -e "\033[1;34mCurrent DNS settings:\033[0m"
                cat /etc/resolv.conf | grep "nameserver"

                # Display DNS recommendations for 3 seconds
                echo -e "\033[1;33m1: It is recommended to use Electro or Shecan DNS for better access.\033[0m"
                echo -e "\033[1;33m2: Reboot your server after changing the DNS.\033[0m"
                echo -e "\033[1;33m3: After Reboot change the DNS again and run test.\033[0m"
                # Ask if they want to change DNS
                read -p "Do you want to change your DNS? (yes/no): " change_dns_answer
                if [[ "$change_dns_answer" == "yes" ]]; then
                    change_dns  # Call the function to change DNS
                else
                    echo -e "\033[1;34mNo DNS change requested.\033[0m"
                fi
                ;;

            2)
                echo -e "\033[1;34mStarting Docker setup...\033[0m"

                # Step 1: Check if Docker is already installed
                if command -v docker &> /dev/null; then
                    echo -e "\033[1;33m update Docker? (yes/no):\033[0m"
                    read -p "" docker_update_response
                    if [[ "$docker_update_response" != "yes" ]]; then
                        echo -e "\033[1;34mDocker setup aborted.\033[0m"
                        continue
                    fi
                fi

                # Docker installation process
                {
                    # Update the apt package index
                    echo -e "\033[1;32m1. Updating apt package index...\033[0m"
                    sudo apt-get update

                    # Install required packages
                    echo -e "\033[1;32m2. Installing ca-certificates and curl...\033[0m"
                    sudo apt-get install -y ca-certificates curl

                    # Create keyrings directory
                    echo -e "\033[1;32m3. Creating /etc/apt/keyrings directory...\033[0m"
                    sudo install -m 0755 -d /etc/apt/keyrings

                    # Download Docker's GPG key
                    echo -e "\033[1;32m4. Downloading Docker's GPG key...\033[0m"
                    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

                    # Set appropriate permissions on the GPG key
                    echo -e "\033[1;32m5. Setting permissions for the GPG key...\033[0m"
                    sudo chmod a+r /etc/apt/keyrings/docker.asc

                    # Add Docker's repository to Apt sources
                    echo -e "\033[1;32m6. Adding Docker repository to apt sources...\033[0m"
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

                    # Update apt package index again
                    echo -e "\033[1;32m7. Updating apt package index...\033[0m"
                    sudo apt-get update

                    # Install Docker and related components
                    echo -e "\033[1;32m8. Installing Docker CE, CLI, and related plugins...\033[0m"
                    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

                    # Verify Docker installation by running the hello-world image
                    echo -e "\033[1;32m9. Verifying Docker installation by running hello-world...\033[0m"
                    sudo docker run hello-world
                } || {
                    echo -e "\033[1;31mAn error occurred during the installation. Please check the logs.\033[0m"
                    continue
                }

                # Check if Docker was installed successfully
                if command -v docker &> /dev/null; then
                    echo -e "\033[1;32mDocker setup and verification complete.\033[0m"
                else
                    echo -e "\033[1;31mDocker installation failed. Please check the logs and try again.\033[0m"
                fi

                # Check for Docker Compose
                if ! command -v docker-compose &> /dev/null; then
                    echo -e "\033[1;33mDocker Compose is not installed. Do you want to install it? (yes/no):\033[0m"
                    read -p "" compose_install_response
                    if [[ "$compose_install_response" == "yes" ]]; then
                        echo -e "\033[1;32mInstalling Docker Compose...\033[0m"
                        {
                            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                            sudo chmod +x /usr/local/bin/docker-compose
                            echo -e "\033[1;32mDocker Compose installed successfully.\033[0m"
                        } || {
                            echo -e "\033[1;31mAn error occurred during Docker Compose installation. Please check the logs.\033[0m"
                        }
                    else
                        echo -e "\033[1;34mDocker Compose installation skipped.\033[0m"
                    fi
                else
                    echo -e "\033[1;32mDocker Compose is already installed.\033[0m"
                fi
                ;;

            0) main_menu ;;

            *)
                echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
                ;;
        esac
    done
}


#!/bin/bash

# Function to set up monthly traffic report
setup_show_monthly_traffic() {
    echo -e "\033[1;34m--- Setup Monthly Traffic Report ---\033[0m"
    
    if [[ -f /root/telegram_info.txt ]]; then
        echo -e "\033[1;33mTelegram information already exists in /root/telegram_info.txt:\033[0m"
        cat /root/telegram_info.txt
        read -p "Do you want to overwrite the current settings? (yes/no): " overwrite_choice
        
        if [[ "$overwrite_choice" != "yes" ]]; then
            echo -e "\033[1;32mKeeping the existing settings.\033[0m"
            return
        fi
    fi
    
    read -p "Enter your Telegram Bot Token: " TELEGRAM_BOT_TOKEN
    read -p "Enter your Telegram Chat ID: " TELEGRAM_CHAT_ID
    read -p "Enter the traffic threshold in GiB: " THRESHOLD_GIB
    read -p "Enter the title: " TITLE
    
    # Ask for UFW ports to allow and save them in the file
    read -p "Enter the ports to allow (comma-separated, e.g., 4422,22,5000,5001,3000,3001): " UFW_PORTS
    if [[ -z "$UFW_PORTS" ]]; then
        # Set default ports if none are provided
        UFW_PORTS="4422,22,5000,5001,3000,3001"
        echo "No ports entered. Using default ports: $UFW_PORTS"
    fi

    # Save the variables to a text file in the root folder
    {
        echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\""
        echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\""
        echo "THRESHOLD_GIB=\"$THRESHOLD_GIB\""
        echo "TITLE=\"$TITLE\""
        # Save UFW commands for each port
        IFS=',' read -ra PORTS <<< "$UFW_PORTS"
        for port in "${PORTS[@]}"; do
            echo "sudo ufw allow $port"
        done
    } > /root/telegram_info.txt

    echo -e "\033[1;32mInformation saved to /root/telegram_info.txt\033[0m"

    # Download the script
    echo -e "\033[1;33mDownloading the traffic script...\033[0m"
    wget -O /root/show_monthly_traffic.sh https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/show_monthly_traffic.sh

    # Make the script executable
    chmod +x /root/show_monthly_traffic.sh

    # Set default cron time
    echo -e "\033[1;32mSetting up default cron job to run every 2 hours.\033[0m"
    set_cron_job 
}


# Function to set up the cron job for running the traffic script with a default interval of 2 hours
set_cron_job() {
    # Set default interval to 2 hours
    local default_hours="2"
    local hours

    echo -e "\033[1;34m--- Set Traffic Script Cron Job ---\033[0m"
    read -p "Enter the interval in hours to run the traffic script (default is $default_hours hours): " hours

    # Use default if no input is provided
    hours=${hours:-$default_hours}

    # Traffic script command
    traffic_script_command="/root/show_monthly_traffic.sh"

    # Remove any existing cron jobs that call the traffic script
    if crontab -l | grep -q "$traffic_script_command"; then
        echo -e "\033[1;33mUpdating existing traffic script cron job...\033[0m"
        crontab -l | grep -v "$traffic_script_command" | crontab - || {
            echo -e "\033[1;31mFailed to remove the existing traffic script cron job.\033[0m"
            return 1
        }
    fi

    # Add new cron job for the traffic script
    if [[ "$hours" -eq 0 ]]; then
        echo -e "\033[1;31mWarning: Traffic script will run every hour!\033[0m"
        (crontab -l 2>/dev/null | grep -v "$traffic_script_command"; echo "0 * * * * $traffic_script_command") | crontab - || {
            echo -e "\033[1;31mFailed to set cron job for the traffic script.\033[0m"
            return 1
        }
    else
        # Set cron job to run every specified hour
        (crontab -l 2>/dev/null | grep -v "$traffic_script_command"; echo "0 */$hours * * * $traffic_script_command") | crontab - || {
            echo -e "\033[1;31mFailed to set cron job for the traffic script.\033[0m"
            return 1
        }
    fi

    # Reload cron service
    if ! sudo service cron reload; then
        echo -e "\033[1;31mFailed to reload cron service.\033[0m"
        return 1
    fi

    sleep 1
    echo -e "\033[1;32mTraffic script cron job set to run every $hours hour(s).\033[0m"
}


# Function to edit the cron time
edit_cron_time() {
    echo -e "\033[1;34m--- Edit Cron Job Time ---\033[0m"
    echo -e "\033[1;33mCurrent Cron Jobs:\033[0m"
    crontab -l

    read -p "Enter the new hours to run the script: " new_hours

    new_cron_time="0 */$new_hours * * * /root/show_monthly_traffic.sh"

    # Check if the new cron job already exists
    if crontab -l | grep -q -F "$new_cron_time"; then
        echo -e "\033[1;33mThis cron job already exists: $new_cron_time\033[0m"
    else
        # Remove old cron job and add the new one
        crontab -l | grep -v -F "/root/show_monthly_traffic.sh" | crontab -
        (crontab -l 2>/dev/null; echo "$new_cron_time") | crontab -
        echo -e "\033[1;32mCron job updated to run /root/show_monthly_traffic.sh every $new_hours hour(s).\033[0m"
    fi

    # Restart the cron service
    if sudo systemctl restart cron; then
        echo -e "\033[1;32mCron service restarted successfully.\033[0m"
    else
        echo -e "\033[1;31mFailed to restart cron service.\033[0m"
    fi
}


edit_telegram_info() {
    echo -e "\033[1;34m--- Edit Telegram Info, Title, Threshold, and UFW Ports ---\033[0m"
    
    if [[ -f /root/telegram_info.txt ]]; then
        echo -e "\033[1;33mCurrent Telegram Information:\033[0m"
        cat /root/telegram_info.txt
        echo ""

        read -p "Enter your new Telegram Bot Token (enter keep current): " new_token
        read -p "Enter your new Telegram Chat ID (enter keep current): " new_chat_id
        read -p "Enter the new traffic threshold in GiB (enter keep current): " new_threshold
        read -p "Enter the new title (enter keep current): " new_title
        read -p "Enter new UFW ports to allow (comma-separated, enter keep current): " new_ports

        # Read the current values from the file
        source /root/telegram_info.txt

        # Update values only if new ones are provided
        TELEGRAM_BOT_TOKEN="${new_token:-$TELEGRAM_BOT_TOKEN}"
        TELEGRAM_CHAT_ID="${new_chat_id:-$TELEGRAM_CHAT_ID}"
        THRESHOLD_GIB="${new_threshold:-$THRESHOLD_GIB}"
        TITLE="${new_title:-$TITLE}"

        # Update UFW ports if new ones are provided
        if [[ -n "$new_ports" ]]; then
            UFW_PORTS="$new_ports"
        fi

        # Save updated values
        {
            echo "TELEGRAM_BOT_TOKEN=\"$TELEGRAM_BOT_TOKEN\""
            echo "TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT_ID\""
            echo "THRESHOLD_GIB=\"$THRESHOLD_GIB\""
            echo "TITLE=\"$TITLE\""
            # Save UFW commands for each port
            IFS=',' read -ra PORTS <<< "$UFW_PORTS"
            for port in "${PORTS[@]}"; do
                echo "sudo ufw allow $port"
            done
        } > /root/telegram_info.txt

        echo -e "\033[1;32mTelegram information, title, and UFW ports updated in /root/telegram_info.txt\033[0m"
    else
        echo -e "\033[1;31mTelegram information file not found. Please set it up first.\033[0m"
    fi
    
}



# Function to edit the crontab directly
edit_cron() {
    echo -e "\033[1;34m--- Edit Cron Job ---\033[0m"
    sudo EDITOR=nano crontab -e

    # Restart the cron service after editing
    if sudo systemctl restart cron; then
        echo -e "\033[1;32mCron service restarted successfully.\033[0m"
    else
        echo -e "\033[1;31mFailed to restart cron service.\033[0m"
    fi
}

# Main menu for the user
traffic() {
    while true; do
        echo -e "\033[1;34m--- Monthly Traffic Report Menu ---\033[0m"
        echo -e "\033[1;32m1.\033[0m Set up monthly traffic"
        echo -e "\033[1;32m2.\033[0m Edit Telegram Info,Threshold,title,ufw ports"
        echo -e "\033[1;32m3.\033[0m setup Time"
        echo -e "\033[1;32m4.\033[0m Edit Cron Job with nano"
        echo -e "\033[1;32m5.\033[0m start monthly traffic script "
        echo -e "\033[1;32m6.\033[0m edit source "
        echo -e "\033[1;32m0.\033[0m return to main menu"
        read -p "Enter your choice: " choice

        case $choice in
            1)
                setup_show_monthly_traffic
		sudo bash /root/show_monthly_traffic.sh
                ;;
            2)
                edit_telegram_info
                ;;
            3)
                edit_cron_time
                ;;
            4)
                edit_cron
                ;;
            5) sudo bash /root/show_monthly_traffic.sh ;;  
            6) sudo nano /root/telegram_info.txt ;;
            7) edit_ufw ;;
            0)
                echo -e "\033[1;31m return to main menu\033[0m"
                main_menu
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please select 1, 2, 3, 4, or 5.\033[0m"
                ;;
        esac
    done
}


check_and_install_htop() {
    # Check if htop is installed
    if ! command -v htop &> /dev/null; then
        echo -e "\033[1;31mhtop is not installed. Installing htop...\033[0m"
        sudo apt-get update && sudo apt-get install -y htop
    fi
}

check_and_install_btop() {
    # Check if btop is installed
    if ! command -v btop &> /dev/null; then
        echo -e "\033[1;31mbtop is not installed. Installing btop...\033[0m"
        sudo apt-get update && sudo apt-get install -y btop
    fi
}

usage() {
    echo -e "\033[1;34m=========================\033[0m"
    echo -e "\033[1;36m    SYSTEM MONITORING    \033[0m"
    echo -e "\033[1;34m=========================\033[0m"
    echo -e "\033[1;32m1.\033[0m CPU and RAM usage"
    echo -e "\033[1;32m2.\033[0m htop"
    echo -e "\033[1;32m3.\033[0m btop"
    echo -e "\033[1;32m0.\033[0m Return to main menu"
    echo -e "\033[1;34m=========================\033[0m"
    
    read -p "Enter your choice: " choice
    
    case $choice in
        1)
            show_usage
            ;;
        2)
            check_and_install_htop
            trap usage SIGINT  # Capture Ctrl+C and return to usage menu
            htop
            usage  # Return to usage after htop is exited
            ;;
        3)
            check_and_install_btop
            trap usage SIGINT  # Capture Ctrl+C and return to usage menu
            btop
            usage  # Return to usage after btop is exited
            ;;
        0)
            echo -e "\033[1;33mReturning to the main menu...\033[0m"
            main_menu
            ;;
        *)
            echo -e "\033[1;31mInvalid option, please try again.\033[0m"
            usage
            ;;
    esac
}

show_usage() {
    echo -e "\033[1;35mPress [Enter] to return to the menu...\033[0m"
    while true; do
        # Get CPU usage and round to the nearest integer
        cpu_usage=$(top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print int(100 - $1)}')
        
        # Get RAM usage and round to the nearest integer
        ram_usage=$(free | grep Mem | awk '{print int($3/$2 * 100.0)}')
        
        # Clear the line and print the usage with carriage return to overwrite the line
        tput cr     # Move cursor to the beginning of the line
        tput el     # Clear the line
        echo -ne "\033[1;36mCPU Usage: \033[1;32m${cpu_usage}%\033[0m  |  \033[1;36mRAM Usage: \033[1;32m${ram_usage}%\033[0m   "
        
        # Sleep for 1 second
        sleep 1
        
        # Check for user input
        if read -t 1 -n 1; then
            usage  # Exit the loop if user presses Enter
        fi
    done
    echo -e "\nReturning to the menu..."
}

#ufw
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
	return_to_menu
    fi
}
return_to_menu() {
    echo ""
    read -p "$(echo -e "\033[1;33mPress Enter to return...\033[0m")"
    show_ufw_menu
}
find_and_allow_ports() {
    # Display used ports
    echo -e "\033[1;34mFinding all used ports...\033[0m"
    used_ports=$(sudo lsof -i -P -n | grep LISTEN | awk '{print $9}' | awk -F ':' '{print $NF}' | sort -u)

    if [ -z "$used_ports" ]; then
        echo -e "\033[1;31mNo used ports found.\033[0m"
	read -p "Enter to continue... "
        return
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
	    read -p "Enter to continue... "
            return
            ;;
        2)
            echo -e "\033[1;34mEnter the numbers of the ports(separate with commas, e.g., 1,3,5).\033[0m"
            echo -e "\033[1;34m[ENTER blank to return...]\033[0m"
            read -r selected_numbers

            if [ -z "$selected_numbers" ]; then
                echo -e "\033[1;31mNo ports selected. Exiting.\033[0m"
		read -p "Enter to continue... "
                return
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
		    read -p "Enter to continue... "
                fi
		
            done
            ;;
        *)
            echo -e "\033[1;31mInvalid option.\033[0m"
	    read -p "Enter to continue... "
            return
            ;;
    esac

    # Reload UFW to apply changes
    echo -e "\033[1;34mReloading UFW to apply changes...\033[0m"
    sudo ufw reload
    echo -e "\033[1;32mUFW configuration updated.\033[0m"
    read -p "Enter to continue... "
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
# UFW Subcategory Menu
show_ufw_menu() {

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
    echo -e "\033[1;32m 0. \033[0m Return to main menu"
    echo -e "\033[1;36m===============================================\033[0m"
    echo -n "Select an option : "
}
# Handle UFW menu selection
ufw_menu() {
    while true; do
        show_ufw_menu
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
            0) main_menu && break ;;  # Return to main menu
            *) echo -e "\033[0;31mInvalid option. Please select between 1-14.\033[0m" ;;
        esac
    done
}




download_and_start_api() {
    while true; do
        echo -e "\033[1;34mSelect an option:\033[0m"
        echo "1. Download script"
        echo "2. Rename folder"
        echo "3. Start script"
        echo "4. Set cron jobs"
        echo "5. Edit cron jobs"
        echo "0. Exit"

        read -p "Enter your choice: " choice

        case $choice in
            1)
                echo "Downloading api.sh to /root..."
                if curl -o /root/api.sh https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/api.sh; then
                    chmod +x /root/api.sh
                    echo -e "\033[1;32mDownload complete and permissions set.\033[0m"
                else
                    echo -e "\033[1;31mDownload failed. Please try again.\033[0m"
                fi
                ;;
            2)
                existing_folder=$(grep -oP '(?<=CONFIG_FILE="/root/)[^/]*' /root/api.sh | head -n 1)

                if [ -z "$existing_folder" ]; then
                    echo -e "\033[1;31mNo folder name found in api.sh.\033[0m"
                    continue
                fi
                
                echo "Current folder name is: '$existing_folder'"
                read -p "Enter the new name to replace '$existing_folder' in api.sh: " user_name
                
                sed -i "s|/root/${existing_folder}/|/root/${user_name}/|g" /root/api.sh
                echo -e "\033[1;32mReplacement complete: '$existing_folder' replaced with '${user_name}' in api.sh.\033[0m"
                ;;
            3)
                echo "Starting api.sh..."
                if /root/api.sh; then
                    echo -e "\033[1;32mapi.sh started successfully.\033[0m"
                else
                    echo -e "\033[1;31mFailed to start api.sh. Please check for errors.\033[0m"
                fi
                ;;
            4) 
    echo "Setting up cron jobs..."
    
    # Ask for hours to run api.sh, default is 3
    read -p "Enter the hours to run api.sh (default is 3): " hours
    hours=${hours:-3}  # Default to 3 if no input is provided
    
    # Create or update the cron job
    cron_expression="0 */$hours * * * /root/api.sh"
    echo "Adding/overwriting cron job: $cron_expression"
    
    # Overwrite the existing cron job
    (crontab -l 2>/dev/null | grep -v '/root/api.sh'; echo "$cron_expression") | crontab -
    echo -e "\033[1;32mCron job added/overwritten: $cron_expression\033[0m"
    ;;


            5)
                echo "Editing cron jobs..."
                # Open the crontab file in nano for editing
                EDITOR=nano crontab -e
                
                # Reload cron service (optional)
                sudo service cron reload
                echo -e "\033[1;32mCron jobs updated and service reloaded.\033[0m"
                ;;
            0)
                echo "Returning to main menu..."
                main_menu
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
                ;;
        esac
        
        read -p "Press Enter to return..."
    done
}

#ip quality
ip_quality_check() {
    while true; do
	
        echo -e "\n\033[1;34mPlease select an option:\033[0m"
	echo -e "\033[1;32m1.\033[0m Basic IPv4 Check"
        echo -e "\033[1;32m2.\033[0m Advanced IPv4 check"
        echo -e "\033[1;32m3.\033[0m Advanced IPv6 check"
        echo -e "\033[1;32m4.\033[0m Advanced IPv4 IPv6 check"
        echo -e "\033[1;32m0.\033[0m Return to Main Menu"
        read -p "Enter your choice: " choice
        case $choice in
            2)
                echo -e "\033[1;32mRunning command for IPv4...\033[0m"
                bash <(curl -L -s check.unlock.media) -E en -R 0 -M 4
                ;;
            3)
                echo -e "\033[1;32mRunning command for IPv6...\033[0m"
                bash <(curl -L -s check.unlock.media) -E en -R 0 -M 6
                ;;
            4)
                echo -e "\033[1;32mRunning command for both IPv4 and IPv6...\033[0m"
                bash <(curl -L -s check.unlock.media) -E en
                ;;
	     1)
                echo -e "\033[1;32m Basic IPv4 Check...\033[0m"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/ip-check.sh -o ip-check.sh
		sudo bash ip-check.sh
  		read -p "Enter to continue "
                ;;
            0)
                echo -e "\033[1;34mReturning to Main Menu...\033[0m"
                main_menu
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
                ;;
        esac
    done
}


manage_nginx() {
    while true; do
        echo -e "\033[1;34mNginx Management Menu:\033[0m"
        echo -e "\033[1;32m1. Install Nginx\033[0m"
        echo -e "\033[1;32m2. Start Nginx\033[0m"
        echo -e "\033[1;32m3. Stop Nginx\033[0m"
        echo -e "\033[1;32m4. Restart Nginx\033[0m"
        echo -e "\033[1;32m5. Nginx Status\033[0m"
        echo -e "\033[1;32m6. Configuration Test\033[0m"
        echo -e "\033[1;32m7. Add New Server Block\033[0m"
        echo -e "\033[1;32m8. Enable/Disable/Remove Server Block\033[0m"
        echo -e "\033[1;32m10. Edit Server Block\033[0m"
        echo -e "\033[1;32m11. Nginx Logs\033[0m"
        echo -e "\033[1;32m12. Set Up a Reverse Proxy\033[0m"
	echo -e "\033[1;32m13. bypass marzban ssl with Reverse Proxy\033[0m"
        echo -e "\033[1;32m14. Remove Nginx\033[0m"
        echo -e "\033[1;32m0. return to main menu \033[0m"

        read -p "Choose an option: " option

        case $option in
            1)
                echo -e "\033[1;33mInstalling Nginx...\033[0m"
                if sudo apt update && sudo apt install -y nginx; then
                    echo -e "\033[1;32mNginx installed successfully.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to install Nginx.\033[0m"
                fi
                ;;
            2)
                echo -e "\033[1;33mStarting Nginx...\033[0m"
                if sudo systemctl start nginx; then
                    echo -e "\033[1;32mNginx started.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to start Nginx.\033[0m"
                fi
                ;;
            3)
                echo -e "\033[1;33mStopping Nginx...\033[0m"
                if sudo systemctl stop nginx; then
                    echo -e "\033[1;32mNginx stopped.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to stop Nginx.\033[0m"
                fi
                ;;
            4)
                echo -e "\033[1;33mRestarting Nginx...\033[0m"
                if sudo systemctl restart nginx; then
                    echo -e "\033[1;32mNginx restarted.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to restart Nginx.\033[0m"
                fi
                ;;
            5)
                echo -e "\033[1;33mChecking Nginx status...\033[0m"
                if sudo systemctl status nginx; then
                    echo -e "\033[1;32mNginx is running.\033[0m"
                else
                    echo -e "\033[1;31mError: Nginx service could not be found or is not running.\033[0m"
                fi
                ;;
            6)
                echo -e "\033[1;33mTesting Nginx configuration...\033[0m"
                if sudo nginx -t; then
                    echo -e "\033[1;32mNginx configuration is valid.\033[0m"
                else
                    echo -e "\033[1;31mError: Nginx configuration is invalid.\033[0m"
                fi
                ;;
            7)
               read -p "Enter the domain name (e.g., example.com) or 0 to return: " domain

if [[ "$domain" != "0" && -n "$domain" ]]; then
    # Prompt for the custom port
    read -p "Enter the port number (default is 80): " port
    port=${port:-80}  # Default to port 80 if no input

    # Define both IPv4 and IPv6 listen directives
    listen_ipv4="listen $port;"
    listen_ipv6="listen [::]:$port;"

    # Create the Nginx server block configuration
    sudo tee /etc/nginx/sites-available/$domain > /dev/null <<EOF
server {
    $listen_ipv4
    $listen_ipv6
    server_name $domain www.$domain;

    location / {
        root /var/www/$domain;
        index index.html index.htm;
    }
}
EOF

    # Create the web root directory
    sudo mkdir -p /var/www/$domain

    # Download the HTML template (Insertion) for the site
    echo -e "\033[1;33mDownloading the Insertion HTML template for $domain...\033[0m"
    wget -O /var/www/$domain/template.zip https://www.tooplate.com/zip-templates/2101_insertion.zip >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31mError: Failed to download the HTML template.\033[0m"
        exit 1
    fi

    # Unzip the template into a temporary folder under the domain directory
    echo -e "\033[1;33mExtracting the template to /var/www/$domain/2101_insertion/ ...\033[0m"
    sudo unzip -o /var/www/$domain/template.zip -d /var/www/$domain/ >/dev/null 2>&1
    sudo rm /var/www/$domain/template.zip  # Remove the zip file after extraction

    # Move the content from 2101_insertion/ to the domain root
    if [ -d "/var/www/$domain/2101_insertion" ]; then
        echo -e "\033[1;33mMoving template content to /var/www/$domain/ ...\033[0m"
        sudo mv /var/www/$domain/2101_insertion/* /var/www/$domain/
        sudo rm -rf /var/www/$domain/2101_insertion  # Remove the now-empty folder
    fi

    # Check if the symbolic link already exists, and create it if it doesn't
    if [ ! -L /etc/nginx/sites-enabled/$domain ]; then
        sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    else
        echo -e "\033[1;33mSymbolic link already exists for $domain. Skipping...\033[0m"
    fi

    # Reload Nginx to apply changes
    if sudo systemctl reload nginx; then
        echo -e "\033[1;32mServer block for $domain created on ports $port (IPv4) and [::]:$port (IPv6), and Nginx reloaded.\033[0m"
    else
        echo -e "\033[1;31mError: Failed to reload Nginx. Please check the configuration.\033[0m"
    fi
fi




                ;;

            8)
                while true; do
                    echo -e "\033[1;33mAvailable Server Blocks:\033[0m"
                    local index=1
                    for file in /etc/nginx/sites-available/*; do
                        if [[ -f $file ]]; then
                            echo -e "\033[1;32m$index. $(basename "$file")\033[0m"
                            index=$((index + 1))
                        fi
                    done

                    read -p "Select a server block by number or 0 to return: " server_block_number

                    if [[ "$server_block_number" == "0" ]]; then
                        echo -e "\033[1;34mReturning to the main menu...\033[0m"
                        break
                    fi

                    if [[ -n "$server_block_number" ]]; then
                        selected_block=$(ls /etc/nginx/sites-available/ | sed -n "${server_block_number}p")

                        if [[ -n $selected_block ]]; then
                            echo -e "\033[1;33mYou selected: $selected_block\033[0m"
                            echo -e "\033[1;33mChoose an action:\033[0m"
                            echo -e "\033[1;32m1. Enable the server block\033[0m"
                            echo -e "\033[1;32m2. Disable the server block\033[0m"
                            echo -e "\033[1;32m3. Remove the server block\033[0m"
                            echo -e "\033[1;32m0. Cancel and return to the server block selection\033[0m"

                            read -p "Select an action (1-3) or 0 to cancel: " action_number

                            case $action_number in
                                1)
                                    if [[ ! -L /etc/nginx/sites-enabled/$selected_block ]]; then
                                        sudo ln -s /etc/nginx/sites-available/$selected_block /etc/nginx/sites-enabled/
                                        echo -e "\033[1;32mServer block for $selected_block enabled.\033[0m"
                                    else
                                        echo -e "\033[1;33mServer block for $selected_block is already enabled.\033[0m"
                                    fi
                                    ;;
                                2)
                                    if [[ -L /etc/nginx/sites-enabled/$selected_block ]]; then
                                        sudo rm /etc/nginx/sites-enabled/$selected_block
                                        echo -e "\033[1;32mServer block for $selected_block disabled.\033[0m"
                                    else
                                        echo -e "\033[1;33mServer block for $selected_block is not enabled.\033[0m"
                                    fi
                                    ;;
                                3)
                                    if [[ -f /etc/nginx/sites-available/$selected_block ]]; then
                                        sudo rm /etc/nginx/sites-available/$selected_block
                                        echo -e "\033[1;32mServer block for $selected_block removed.\033[0m"
                                        sudo rm /etc/nginx/sites-enabled/$selected_block 2>/dev/null
                                    else
                                        echo -e "\033[1;31mServer block for $selected_block does not exist.\033[0m"
                                    fi
                                    ;;
                                0)
                                    echo -e "\033[1;34mCancelling...\033[0m"
                                    ;;
                                *)
                                    echo -e "\033[1;31mError: Invalid action selected.\033[0m"
                                    ;;
                            esac
                        else
                            echo -e "\033[1;31mError: Invalid server block number.\033[0m"
                        fi
                    fi
                done
                ;;
            10)
                echo -e "\033[1;33mAvailable server blocks:\033[0m"

# List the server blocks in /etc/nginx/sites-available/
server_blocks=($(ls /etc/nginx/sites-available))

if [[ ${#server_blocks[@]} -eq 0 ]]; then
    echo -e "\033[1;31mNo server blocks available in /etc/nginx/sites-available/.\033[0m"
    exit 1
fi

# Display the list of server blocks
for i in "${!server_blocks[@]}"; do
    echo -e "\033[1;32m$((i+1)).\033[0m ${server_blocks[$i]}"
done

# Prompt the user to select a server block by number
read -p "Enter the number of the server block to edit: " server_block_number

# Check if the input is a valid number and corresponds to a server block
if [[ $server_block_number =~ ^[0-9]+$ ]] && ((server_block_number > 0 && server_block_number <= ${#server_blocks[@]})); then
    server_block_name=${server_blocks[$((server_block_number-1))]}
    echo -e "\033[1;33mEditing server block: $server_block_name\033[0m"
    sudo nano /etc/nginx/sites-available/$server_block_name
    echo -e "\033[1;32mServer block $server_block_name edited successfully.\033[0m"
else
    echo -e "\033[1;31mError: Invalid selection. Please choose a valid server block number.\033[0m"
fi

                ;;
            11)
                echo -e "\033[1;33mNginx access logs:\033[0m"
                sudo tail -f /var/log/nginx/access.log
                ;;
           
12)
#!/bin/bash

# Function to remove http/https from the input
strip_scheme() {
    echo "$1" | sed -e 's|^http://||' -e 's|^https://||'
}

# Read user inputs for the target site
read -p "Enter the target site to proxy (e.g., google.com): " target_site
echo "Is the target site using http or https?"
echo "1) http"
echo "2) https"
read -p "Enter 1 or 2: " scheme_choice

# Map user's choice to the correct scheme
if [[ "$scheme_choice" == "1" ]]; then
    scheme="http"
elif [[ "$scheme_choice" == "2" ]]; then
    scheme="https"
else
    echo -e "\033[1;31mInvalid option selected. Please run the script again and choose 1 for http or 2 for https.\033[0m"
    exit 1
fi

# Ask for the domain and its scheme
read -p "Enter your domain for replacements (e.g., domain.com): " your_domain
echo "Is your domain using http or https?"
echo "1) http"
echo "2) https"
read -p "Enter 1 or 2: " domain_scheme_choice

# Map user's choice for the domain to the correct scheme
if [[ "$domain_scheme_choice" == "1" ]]; then
    domain_scheme="http"
    ssl_config=""
elif [[ "$domain_scheme_choice" == "2" ]]; then
    domain_scheme="https"
    ssl_config=""
else
    echo -e "\033[1;31mInvalid option selected. Please run the script again and choose 1 for http or 2 for https.\033[0m"
    exit 1
fi

# Ask for ports for both HTTP and HTTPS based on domain scheme
if [[ "$domain_scheme" == "http" ]]; then
    read -p "Enter the port for HTTP (default: 80): " http_port
    http_port=${http_port:-80}
else
    read -p "Enter the port for HTTP (default: 80): " http_port
    http_port=${http_port:-80}

    read -p "Enter the port for HTTPS (default: 443): " https_port
    https_port=${https_port:-443}
fi

# Ask for SSL certificate locations if domain uses HTTPS
if [[ "$domain_scheme" == "https" ]]; then
    read -p "Enter the path to your SSL certificate (e.g., /etc/ssl/certs/your_certificate.crt): " ssl_cert
    read -p "Enter the path to your SSL certificate key (e.g., /etc/ssl/private/your_key.key): " ssl_key
fi

# Set default config name if not provided
read -p "Enter a name for the Nginx configuration file (default: reverse_proxy): " config_name
config_name=${config_name:-reverse_proxy}

# Strip the scheme from the target site and your domain
target_site=$(strip_scheme "$target_site")
your_domain=$(strip_scheme "$your_domain")

# Create the Nginx configuration content in a variable
nginx_config=$(cat <<EOF
server {
    listen $http_port; # Listen on the specified HTTP port

    server_name _;

    location / {
        proxy_pass $scheme://$target_site;
        proxy_set_header Host $target_site;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_server_name on;

        # Disable compression to make sub_filter work effectively
        proxy_set_header Accept-Encoding "";

        # Prevent redirects to the target site from changing the URL in the browser
        proxy_redirect $scheme://$target_site /;

        # Replace the target site URLs with your domain's URLs
        sub_filter '$scheme://$target_site' 'http://$your_domain:$http_port'; # Include the HTTP port

        # Ensure sub_filter works with multiple content types
        sub_filter_types text/html application/xhtml+xml;
        sub_filter_once off;
    }
}
EOF
)

# If the domain uses HTTPS, create an additional server block for it
if [[ "$domain_scheme" == "https" ]]; then
    nginx_config+=$(cat <<EOF
server {
    listen $https_port ssl; # Listen on the specified HTTPS port
    ssl_certificate $ssl_cert; # Path to your SSL certificate
    ssl_certificate_key $ssl_key; # Path to your SSL certificate key

    server_name _;

    location / {
        proxy_pass $scheme://$target_site;
        proxy_set_header Host $target_site;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_server_name on;

        # Disable compression to make sub_filter work effectively
        proxy_set_header Accept-Encoding "";

        # Prevent redirects to the target site from changing the URL in the browser
        proxy_redirect $scheme://$target_site /;

        # Replace the target site URLs with your domain's URLs
        sub_filter '$scheme://$target_site' 'https://$your_domain:$https_port'; # Include the HTTPS port

        # Ensure sub_filter works with multiple content types
        sub_filter_types text/html application/xhtml+xml;
        sub_filter_once off;
    }
}
EOF
)
fi

# Write the Nginx configuration to the file
echo "$nginx_config" | sudo tee /etc/nginx/sites-available/$config_name > /dev/null

# Check if the symbolic link already exists; if not, create it
if [ ! -L /etc/nginx/sites-enabled/$config_name ]; then
    sudo ln -s /etc/nginx/sites-available/$config_name /etc/nginx/sites-enabled/
    echo -e "\033[1;32mSymbolic link created for $config_name in sites-enabled.\033[0m"
else
    echo -e "\033[1;33mSymbolic link for $config_name already exists in sites-enabled.\033[0m"
fi

# Test Nginx configuration
if sudo nginx -t; then
    echo -e "\033[1;32mNginx configuration is valid.\033[0m"
    # Reload Nginx to apply the new configuration
    sudo systemctl reload nginx
    echo -e "\033[1;34mFull proxy set up for $your_domain.\033[0m"
else
    echo -e "\033[1;31mNginx configuration test failed. Please check the configuration.\033[0m"
fi



;;

13)
# Function to strip the scheme from a URL
strip_scheme() {
    echo "$1" | sed -e 's|^http://||' -e 's|^https://||'
}

# Fetch the public IP address
public_ip=$(curl -s icanhazip.com)

# Read user input for the target site
read -p "Enter the target (default: 127.0.0.1:8000): " target_site
target_site=${target_site:-127.0.0.1:8000}

# Set the scheme to HTTP by default
scheme="http"

# Ask for the port for HTTP
read -p "Enter the HTTP port to listen (default: 8001): " http_port
http_port=${http_port:-8001}

# Set default config name if not provided
read -p "Enter a name for the Nginx configuration file (default: default): " config_name
config_name=${config_name:-default}

# Strip the scheme from the target site
target_site=$(strip_scheme "$target_site")

# Create the Nginx configuration content in a variable
nginx_config=$(cat <<EOF
server {
    listen $http_port; # Listen on the specified HTTP port

    server_name _;

    location / {
        proxy_pass $scheme://$target_site;
        proxy_set_header Host $target_site;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_server_name on;

        # Disable compression to make proxy behavior more predictable
        proxy_set_header Accept-Encoding "";

        # Prevent redirects to the target site from changing the URL in the browser
        proxy_redirect $scheme://$target_site /;
    }
}
EOF
)

# Write the Nginx configuration to the file
echo "$nginx_config" | sudo tee /etc/nginx/sites-available/$config_name > /dev/null

# Check if the symbolic link already exists; if not, create it
if [ ! -L /etc/nginx/sites-enabled/$config_name ]; then
    sudo ln -s /etc/nginx/sites-available/$config_name /etc/nginx/sites-enabled/
    echo -e "\033[1;32mSymbolic link created for $config_name in sites-enabled.\033[0m"
else
    echo -e "\033[1;33mSymbolic link for $config_name already exists in sites-enabled.\033[0m"
fi

# Test Nginx configuration
if sudo nginx -t; then
    echo -e "\033[1;32mNginx configuration is valid.\033[0m"
    # Reload Nginx to apply the new configuration
    sudo systemctl reload nginx
    echo -e "\033[1;34mProxy setup complete on port $http_port.\033[0m"

    # Display Marzban URL with the public IP
    echo -e "\033[1;32mhttp://$public_ip:$http_port/dashboard/\033[0m"
    read -p "Press Enter to continue..."
else
    echo -e "\033[1;31mNginx configuration test failed. Please check the configuration.\033[0m"
    read -p "Press Enter to continue..."
fi

;;
            14)
                echo -e "\033[1;33mRemoving Nginx...\033[0m"
                if sudo apt remove --purge -y nginx nginx-common; then
                    echo -e "\033[1;32mNginx removed successfully.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to remove Nginx.\033[0m"
                fi
                ;;
            0)
                echo -e "\033[1;34mExiting Nginx management menu...\033[0m"
                break
                ;;
            *)
                echo -e "\033[1;31mError: Invalid option selected.\033[0m"
                ;;
        esac
    done
}

#!/bin/bash

# Define paths to configuration files
SYSCTL_CONF="/etc/sysctl.conf"
LIMITS_CONF="/etc/security/limits.conf"

# Function to back up existing configurations
backup_configs() {
    echo -e "\033[1;32mBacking up configuration files...\033[0m"
    cp "$SYSCTL_CONF" "${SYSCTL_CONF}.bak"
    cp "$LIMITS_CONF" "${LIMITS_CONF}.bak"
    echo -e "\033[1;32mBackup completed.\033[0m"
}

# Function to reload sysctl configurations
reload_sysctl() {
    echo -e "\033[1;32mReloading sysctl settings...\033[0m"
    sysctl -p
}

# Function to apply optimizations (overwrite existing values only)
apply_optimizations() {
    echo -e "\033[1;32mApplying optimizations...\033[0m"

    # Update /etc/sysctl.conf with new configurations (overwrite existing values or add if missing)
    declare -A sysctl_settings=(
        ["vm.swappiness"]="1"
        ["vm.dirty_ratio"]="60"
        ["vm.dirty_background_ratio"]="5"
        ["fs.file-max"]="2097152"
        ["net.core.somaxconn"]="4096"
        ["net.core.netdev_max_backlog"]="16384"
        ["net.ipv4.ip_local_port_range"]="1024 65535"
        ["net.ipv4.ip_nonlocal_bind"]="1"
        ["net.ipv4.tcp_keepalive_time"]="300"
        ["net.ipv4.tcp_keepalive_intvl"]="30"
        ["net.ipv4.tcp_keepalive_probes"]="5"
        ["net.ipv4.tcp_syncookies"]="0"
        ["net.ipv4.tcp_max_orphans"]="262144"
        ["net.ipv4.tcp_max_syn_backlog"]="8192"
        ["net.ipv4.tcp_max_tw_buckets"]="262144"
        ["net.ipv4.tcp_reordering"]="3"
        ["net.ipv4.tcp_mem"]="786432 1697152 1945728"
        ["net.ipv4.tcp_rmem"]="4096 87380 16777216"
        ["net.ipv4.tcp_wmem"]="4096 65536 16777216"
        ["net.ipv4.tcp_syn_retries"]="5"
        ["net.ipv4.tcp_tw_reuse"]="1"
        ["net.ipv4.tcp_mtu_probing"]="1"
        ["net.ipv4.tcp_congestion_control"]="bbr"
        ["net.ipv4.tcp_sack"]="1"
        ["net.ipv4.conf.all.rp_filter"]="1"
        ["net.ipv4.conf.default.rp_filter"]="1"
        ["net.ipv4.ip_no_pmtu_disc"]="1"
        ["vm.vfs_cache_pressure"]="10"
        ["net.ipv4.tcp_fastopen"]="3"
        ["net.ipv4.tcp_ecn"]="1"
        ["net.ipv4.tcp_retries2"]="10"
        ["net.ipv6.conf.all.forwarding"]="1"
        ["net.ipv4.conf.all.forwarding"]="1"
        ["net.ipv4.tcp_low_latency"]="1"
        ["net.ipv4.tcp_window_scaling"]="1"
        ["net.core.default_qdisc"]="fq_codel"
    )

    for key in "${!sysctl_settings[@]}"; do
        if grep -q "^$key" "$SYSCTL_CONF"; then
            sed -i "s|^$key.*|$key = ${sysctl_settings[$key]}|" "$SYSCTL_CONF"
        else
            echo "$key = ${sysctl_settings[$key]}" >> "$SYSCTL_CONF"
        fi
    done

    # Update /etc/security/limits.conf with new limits
    declare -A limits_settings=(
        ["* soft nproc"]="65535"
        ["* hard nproc"]="65535"
        ["* soft nofile"]="1048576"
        ["* hard nofile"]="1048576"
        ["root soft nproc"]="65535"
        ["root hard nproc"]="65535"
        ["root soft nofile"]="1048576"
        ["root hard nofile"]="1048576"
    )

    for key in "${!limits_settings[@]}"; do
        if grep -q "^$key" "$LIMITS_CONF"; then
            sed -i "s|^$key.*|$key ${limits_settings[$key]}|" "$LIMITS_CONF"
        else
            echo "$key ${limits_settings[$key]}" >> "$LIMITS_CONF"
        fi
    done

    reload_sysctl
    echo -e "\033[1;32mOptimization Complete!\033[0m"
}

# Function to disable all optimizations (remove specific entries)
disable_optimizations() {
    echo -e "\033[1;32mDisabling all optimizations...\033[0m"

    # Remove specific optimization settings from /etc/sysctl.conf
    for setting in "${!sysctl_settings[@]}"; do
        sed -i "/^$setting/d" "$SYSCTL_CONF"
    done

    # Remove specific limits from /etc/security/limits.conf
    for limit in "${!limits_settings[@]}"; do
        sed -i "/^$limit/d" "$LIMITS_CONF"
    done

    reload_sysctl
    echo -e "\033[1;32mAll Optimizations Disabled!\033[0m"
}

# Function to disable all optimizations (remove specific entries)
disable_optimizations() {
    echo -e "\033[1;32mDisabling all optimizations...\033[0m"

    # Directly remove specific optimization settings from /etc/sysctl.conf
    sed -i '/^vm.swappiness/d' "$SYSCTL_CONF"
    sed -i '/^vm.dirty_ratio/d' "$SYSCTL_CONF"
    sed -i '/^vm.dirty_background_ratio/d' "$SYSCTL_CONF"
    sed -i '/^fs.file-max/d' "$SYSCTL_CONF"
    sed -i '/^net.core.somaxconn/d' "$SYSCTL_CONF"
    sed -i '/^net.core.netdev_max_backlog/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.ip_local_port_range/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.ip_nonlocal_bind/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_fin_timeout/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_keepalive_time/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_syncookies/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_max_orphans/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_max_syn_backlog/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_max_tw_buckets/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_reordering/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_mem/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_rmem/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_wmem/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_syn_retries/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_tw_reuse/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_keepalive_intvl/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_keepalive_probes/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_mtu_probing/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_sack/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.conf.all.rp_filter/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.conf.default.rp_filter/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.ip_no_pmtu_disc/d' "$SYSCTL_CONF"
    sed -i '/^vm.vfs_cache_pressure/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_fastopen/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_ecn/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_retries2/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv6.conf.all.forwarding/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.conf.all.forwarding/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_low_latency/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_window_scaling/d' "$SYSCTL_CONF"
    sed -i '/^net.ipv4.tcp_congestion_control/d' "$SYSCTL_CONF"
    sed -i '/^net.core.default_qdisc/d' "$SYSCTL_CONF"

    # Directly remove specific limits from /etc/security/limits.conf
    sed -i '/^\* soft nproc/d' "$LIMITS_CONF"
    sed -i '/^\* hard nproc/d' "$LIMITS_CONF"
    sed -i '/^\* soft nofile/d' "$LIMITS_CONF"
    sed -i '/^\* hard nofile/d' "$LIMITS_CONF"
    sed -i '/^root soft nproc/d' "$LIMITS_CONF"
    sed -i '/^root hard nproc/d' "$LIMITS_CONF"
    sed -i '/^root soft nofile/d' "$LIMITS_CONF"
    sed -i '/^root hard nofile/d' "$LIMITS_CONF"

    # Apply the updated sysctl settings
    echo -e "\033[1;32mReloading sysctl settings...\033[0m"
    sysctl -p

    echo -e "\033[1;32mAll optimizations have been disabled!\033[0m"
}

# Function to install BBR via LightKnight
bbr_script() {
    echo -e "\033[1;32mUpdating system and installing necessary packages...\033[0m"
    sudo apt update && sudo apt install -y python3 python3-pip
    echo -e "\033[1;32mFetching and running the Python script...\033[0m"
    python3 <(curl -Ls https://raw.githubusercontent.com/kalilovers/LightKnightBBR/main/bbr.py --ipv4)

    if [ $? -eq 0 ]; then
        echo -e "\033[1;32mPython script executed successfully.\033[0m"
    else
        echo -e "\033[1;31mFailed to execute the Python script.\033[0m"
    fi
}

# Function to show contents of sysctl.conf
show_sysctl_conf() {
    echo -e "\033[1;34mContents of sysctl.conf:\033[0m"
    cat $SYSCTL_CONF
}

# Function to show contents of limits.conf
show_limits_conf() {
    echo -e "\033[1;34mContents of limits.conf:\033[0m"
    cat $LIMITS_CONF
}

# Function to edit sysctl.conf
edit_sysctl_conf() {
    echo -e "\033[1;32mOpening sysctl.conf for editing...\033[0m"
    nano $SYSCTL_CONF
     echo -e "\033[1;32mreload\033[0m"# Apply the updated sysctl settings
    sysctl -p
}

# Function to edit limits.conf
edit_limits_conf() {
    echo -e "\033[1;32mOpening limits.conf for editing...\033[0m"
    nano $LIMITS_CONF
     echo -e "\033[1;32mreload\033[0m"# Apply the updated sysctl settings
    sysctl -p

}

# Main menu for optimizer
Optimizer() {
    while true; do
        clear
        echo -e "\033[1;32m=======================\033[0m"
        echo -e "\033[1;32m Network Optimizer \033[0m"
        echo -e "\033[1;32m=======================\033[0m"
        echo -e "\033[1;32m1.\033[0m Backup (sysctl.conf & limits.conf)"
        echo -e "\033[1;32m2.\033[0m Optimize (backup and apply optimizations)"
        echo -e "\033[1;32m3.\033[0m Disable all optimizations"
        echo -e "\033[1;32m4.\033[0m Set BBR by LightKnight"
        echo -e "\033[1;32m5.\033[0m Show sysctl.conf"
        echo -e "\033[1;32m6.\033[0m Show limits.conf"
        echo -e "\033[1;32m7.\033[0m Edit sysctl.conf"
        echo -e "\033[1;32m8.\033[0m Edit limits.conf"
	echo -e "\033[1;32m9.\033[0m Apply changes"
        echo -e "\033[1;32m0.\033[0m Main menu"
        echo -e "\nSelect an option (1-8): "
        read choice

        case $choice in
            1) backup_configs ;;
            2) 
                backup_configs # Backup before applying optimizations
                apply_optimizations 
                ;;
            3) disable_optimizations ;;
            4) bbr_script ;;
            5) show_sysctl_conf ;;
            6) show_limits_conf ;;
            7) edit_sysctl_conf ;;
            8) edit_limits_conf ;;
	    9) sysctl -p ;;
            0)
                echo -e "\033[1;34mReturning to main menu...\033[0m"
                main_menu
                ;;
            *) echo -e "\033[1;31mInvalid option. Please select a valid number.\033[0m" ;;
        esac

        # Wait for user to press enter to continue
        echo -e "\n\033[1;34mPress Enter to return to the Optimizer menu...\033[0m"
        read
    done
}





change_sources_list() {
    while true; do
        # Create a timestamp for backup
        timestamp=$(date +"%Y%m%d_%H%M%S")

        # Backup the existing sources list with timestamp
        sudo cp /etc/apt/sources.list "/etc/apt/sources.list.bak.$timestamp"
        echo -e "\033[1;32mBackup of sources.list created at /etc/apt/sources.list.bak.$timestamp\033[0m"

        # Define the list of mirrors with the default one first
        mirrors=(
            "http://mirror.arvancloud.ir/ubuntu"  # Default mirror
            "https://ir.ubuntu.sindad.cloud/ubuntu"
            "https://ir.archive.ubuntu.com/ubuntu"
            "http://ubuntu.byteiran.com/ubuntu"
            "http://mirror.faraso.org/ubuntu"
            "http://mirror.aminidc.com/ubuntu"
            "https://mirror.iranserver.com/ubuntu"
            "https://ubuntu.pars.host"
            "http://linuxmirrors.ir/pub/ubuntu"
            "http://repo.iut.ac.ir/repo/Ubuntu"
            "https://mirror.0-1.cloud/ubuntu"
            "https://ubuntu.hostiran.ir/ubuntuarchive"
            "http://archive.ubuntu.com/ubuntu"
            "https://archive.ubuntu.petiak.ir/ubuntu"
            "https://mirrors.pardisco.co/ubuntu"
            "https://ubuntu.shatel.ir/ubuntu"
        )

        # Determine the Ubuntu release codename with a fallback for "noble"
        ubuntu_codename=$(lsb_release -cs 2>/dev/null || echo "noble")

        # Display the menu options
        echo -e "\n\033[1;34mSelect an option:\033[0m"
        echo -e "\033[1;32m1.\033[0m Change sources list"
        echo -e "\033[1;32m2.\033[0m Restore sources list from backup"
        echo -e "\033[1;32m3.\033[0m Edit sources list with nano"
        echo -e "\033[1;32m4.\033[0m Start update"
	echo -e "\033[1;32m5.\033[0m Fix update issues (broken apt or dependencies)"
        echo -e "\033[1;32m0.\033[0m Return to main menu"

        read -p "Enter your choice (1-5): " option

        case $option in
            1)
                # Display the mirror options
                echo -e "\n\033[1;34mSelect a new source for updates (0 to return):\033[0m"
                for i in "${!mirrors[@]}"; do
                    echo -e "\033[1;32m$((i + 1)).\033[0m ${mirrors[i]}"
                done

                read -p "Enter your choice (0-${#mirrors[@]}) [default: 1]: " choice

                # Set default choice if no input is provided
                if [[ -z "$choice" ]]; then
                    choice=1
                fi

                # Validate the choice
                if [[ $choice -eq 0 ]]; then
                    echo -e "\033[1;33mReturning to the previous menu...\033[0m"
                    continue
                elif [[ $choice -ge 1 && $choice -le ${#mirrors[@]} ]]; then
                    selected_mirror="${mirrors[$((choice - 1))]}"
                    echo -e "\033[1;32mYou selected: $selected_mirror\033[0m"

                    # Update sources.list with the selected mirror (clearing previous entries)
sudo bash -c "cat > /etc/apt/sources.list <<EOF
deb ${selected_mirror} $(lsb_release -cs) main restricted universe multiverse
deb ${selected_mirror} $(lsb_release -cs)-updates main restricted universe multiverse
deb ${selected_mirror} $(lsb_release -cs)-security main restricted universe multiverse
deb ${selected_mirror} $(lsb_release -cs)-backports main restricted universe multiverse
EOF"
echo -e "\033[1;32mSources updated to: ${selected_mirror}\033[0m"

                else
                    echo -e "\033[1;31mInvalid option. No changes were made.\033[0m"
                fi
                ;;

            2)
                # Restore sources.list from backup
                echo -e "\033[1;34mAvailable backups:\033[0m"
                backups=($(ls /etc/apt/sources.list.bak.* 2>/dev/null))

                if [ ${#backups[@]} -eq 0 ]; then
                    echo -e "\033[1;31mNo backup files found.\033[0m"
                    continue
                fi

                # Display backups with numbers
                for i in "${!backups[@]}"; do
                    echo -e "\033[1;32m$((i + 1)).\033[0m ${backups[i]}"
                done
                echo -e "\033[1;32m0.\033[0m Return"

                read -p "Enter the backup number to restore (1-${#backups[@]}) [default: 1]: " backup_choice

                # Set default choice if no input is provided
                if [[ -z "$backup_choice" ]]; then
                    backup_choice=1
                fi

                # Validate the choice
                if [[ $backup_choice -eq 0 ]]; then
                    echo -e "\033[1;33mReturning to the previous menu...\033[0m"
                    continue
                elif [[ $backup_choice -ge 1 && $backup_choice -le ${#backups[@]} ]]; then
                    selected_backup="${backups[$((backup_choice - 1))]}"
                    sudo cp "$selected_backup" /etc/apt/sources.list
                    echo -e "\033[1;32mRestored sources.list from $selected_backup\033[0m"
                else
                    echo -e "\033[1;31mInvalid option. No changes were made.\033[0m"
                fi
                ;;

            3)
                # Edit sources.list with nano
                echo -e "\033[1;34mOpening sources.list in nano...\033[0m"
                sudo nano /etc/apt/sources.list
                echo -e "\033[1;32mPlease review your changes.\033[0m"
                ;;

            4)
                # Start update manually
                echo -e "\033[1;34mStarting manual update...\033[0m"
                sudo apt update && sudo apt upgrade -y
                echo -e "\033[1;32mUpdate completed.\033[0m"
                ;;

            0)
                echo -e "\033[1;33mReturning to the main menu...\033[0m"
                main_menu
                ;;
            5)
                # Fix update issues (fix broken apt and dependencies)
                echo -e "\033[1;34mFixing broken packages and apt issues...\033[0m"

                # Fix broken packages
                sudo apt --fix-broken install -y

                # Clean up partial installations and dependencies
                sudo apt-get autoremove -y
                sudo apt-get autoclean -y

                # Try fixing any other package issues
                sudo dpkg --configure -a

                echo -e "\033[1;32mUpdate issues fixed.\033[0m"
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please select 1, 2, 3, 4, or 5.\033[0m"
                ;;
        esac
    done
}


manage_ipv6() {
    while true; do
        echo -e "\n\033[1;34mManage IPv6 Configuration:\033[0m"
        echo -e "\033[1;32m1.\033[0m Enable IPv6"
        echo -e "\033[1;32m2.\033[0m Disable IPv6"
        echo -e "\033[1;32m3.\033[0m Make changes permanent"
	echo -e "\033[1;32m4.\033[0m Apply changes"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        read -p "Enter your choice: " choice

        case $choice in
            1)
                # Enable IPv6
                echo -e "\033[1;34mEnabling IPv6...\033[0m"
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0
                echo -e "\033[1;32mIPv6 has been enabled.\033[0m"
                ;;
            2)
                # Disable IPv6
                echo -e "\033[1;34mDisabling IPv6...\033[0m"
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
                echo -e "\033[1;32mIPv6 has been disabled.\033[0m"
                ;;
            3)
                # Make changes permanent
                read -p "Do you want to make the current setting permanent? (y/n): " permanent_choice
                if [[ "$permanent_choice" =~ ^[Yy]$ ]]; then
                    if [[ $(sysctl -n net.ipv6.conf.all.disable_ipv6) -eq 1 ]]; then
                        # Disable IPv6 permanently
                        echo -e "\033[1;34mMaking IPv6 disable permanent...\033[0m"
                        echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
                        echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
                        echo -e "\033[1;32mIPv6 has been set to disable permanently.\033[0m"
                    else
                        # Enable IPv6 permanently
                        echo -e "\033[1;34mMaking IPv6 enable permanent...\033[0m"
                        echo "net.ipv6.conf.all.disable_ipv6 = 0" | sudo tee -a /etc/sysctl.conf
                        echo "net.ipv6.conf.default.disable_ipv6 = 0" | sudo tee -a /etc/sysctl.conf
                        echo -e "\033[1;32mIPv6 has been set to enable permanently.\033[0m"
                    fi
                else
                    echo -e "\033[1;33mChanges not made permanent.\033[0m"
                fi
                ;;
		4) sysctl -p ;;
            0)
                echo -e "\033[1;33mReturning to the main menu...\033[0m"
                main_menu
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please select 1, 2, 3, or 4.\033[0m"
                ;;
        esac
    done
}



#!/bin/bash

# Function to check and disable swap files
check_and_disable_swap() {
    # Check if any swap is currently enabled
    if sudo swapon --show | grep -q -i swap; then
        echo -e "\033[1;33mWARNING: It is recommended to disable any enabled swap files when using ZRAM.\033[0m"
        read -p "Do you want to disable all swap files? (yes/no): " user_input
        
        if [[ "$user_input" =~ ^[Yy][Ee][Ss]$ ]]; then
            # Disable all swap
            echo -e "\033[1;34mDisabling all swap files...\033[0m"
            sudo swapoff -a
            echo -e "\033[1;32mAll swap files have been disabled.\033[0m"

            # Check and remove swap entry from /etc/fstab
            if grep -q swap /etc/fstab; then
                echo -e "\033[1;34mRemoving swap entry from /etc/fstab...\033[0m"
                sudo sed -i.bak '/swap/d' /etc/fstab
                echo -e "\033[1;32mSwap entry removed from /etc/fstab.\033[0m"
            else
                echo -e "\033[1;32mNo swap entry found in /etc/fstab.\033[0m"
            fi
        else
            echo -e "\033[1;32mNo changes made. You can continue using the current swap settings.\033[0m"
        fi
    else
        echo -e "\033[1;32mNo swap files are currently enabled.\033[0m"
    fi
}

manage_zram() {
    while true; do
        echo -e "\n\033[1;34mManaging ZRAM Configuration:\033[0m"
        echo -e "\033[1;32m1.\033[0m Setup ZRAM"
        echo -e "\033[1;32m2.\033[0m Install zram-tools"
        echo -e "\033[1;32m3.\033[0m Configure ZRAM"
        echo -e "\033[1;32m4.\033[0m Enable ZRAM service"
        echo -e "\033[1;32m5.\033[0m Start ZRAM service"
        echo -e "\033[1;32m6.\033[0m Create and Enable ZRAM Swap"
        echo -e "\033[1;32m7.\033[0m Check ZRAM status"
        echo -e "\033[1;32m8.\033[0m Restart ZRAM service"
        echo -e "\033[1;32m9.\033[0m Check and Disable Swap Files"
        echo -e "\033[1;32m10.\033[0m Edit ZRAM Configuration (/etc/default/zramswap)"
        echo -e "\033[1;32m11.\033[0m Stop ZRAM"
        echo -e "\033[1;32m12.\033[0m Disable ZRAM"
        echo -e "\033[1;32m13.\033[0m Remove ZRAM"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        read -p "Enter your choice (0-13): " choice

        case $choice in
            1)
                echo -e "\033[1;34mSetting up Full ZRAM...\033[0m"
                check_and_disable_swap  # Ensure any existing swap is disabled

                echo -e "\033[1;34mInstalling zram-tools...\033[0m"
                sudo apt update && sudo apt install -y zram-tools
                echo -e "\033[1;32mzram-tools installed successfully.\033[0m"

                echo -e "\033[1;34mConfiguring ZRAM...\033[0m"
                sudo bash -c 'cat << EOF > /etc/default/zramswap
ENABLED=true
ALGO=zstd
PERCENTAGE=50
PRIORITY=100
EOF'
                echo -e "\033[1;32mZRAM configuration updated.\033[0m"

                echo -e "\033[1;34mEnabling ZRAM service...\033[0m"
                sudo systemctl enable zramswap
                echo -e "\033[1;32mZRAM service enabled.\033[0m"

                echo -e "\033[1;34mStarting ZRAM service...\033[0m"
                sudo systemctl start zramswap
                echo -e "\033[1;32mZRAM service started.\033[0m"

                # Check if /dev/zram0 is already active
                if swapon --show | grep -q "/dev/zram0"; then
                    echo -e "\033[1;33mZRAM swap area is already enabled.\033[0m"
                else
                    echo -e "\033[1;34mCreating ZRAM swap area...\033[0m"
                    sudo mkswap /dev/zram0
                    sudo swapon /dev/zram0
                    echo -e "\033[1;32mZRAM swap enabled.\033[0m"
                fi

                read -p "Press Enter to continue..."
                ;;
            2)
                echo -e "\033[1;34mInstalling zram-tools...\033[0m"
                sudo apt update && sudo apt install -y zram-tools
                echo -e "\033[1;32mzram-tools installed successfully.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            3)
                echo -e "\033[1;34mConfiguring ZRAM...\033[0m"
                sudo bash -c 'cat << EOF > /etc/default/zramswap
ENABLED=true
ALGO=zstd
PERCENTAGE=50
PRIORITY=100
EOF'
                echo -e "\033[1;32mZRAM configuration updated in /etc/default/zramswap.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            4)
                echo -e "\033[1;34mEnabling ZRAM service...\033[0m"
                sudo systemctl enable zramswap
                echo -e "\033[1;32mZRAM service enabled.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            5)
                echo -e "\033[1;34mStarting ZRAM service...\033[0m"
                sudo systemctl start zramswap
                echo -e "\033[1;32mZRAM service started.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            6)
                echo -e "\033[1;34mCreating ZRAM swap area...\033[0m"
                sudo mkswap /dev/zram0
                sudo swapon /dev/zram0
                echo -e "\033[1;32mZRAM swap enabled.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            7)
                echo -e "\033[1;34mChecking ZRAM status...\033[0m"
                sudo zramctl
                read -p "Press Enter to continue..."
                ;;
            8)
                echo -e "\033[1;34mRestarting ZRAM service...\033[0m"
                sudo systemctl restart zramswap
                echo -e "\033[1;32mZRAM service restarted.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            9)
                check_and_disable_swap
                read -p "Press Enter to continue..."
                ;;
            10)
                echo -e "\033[1;34mOpening /etc/default/zramswap for editing...\033[0m"
                sudo nano /etc/default/zramswap
                read -p "Press Enter to continue..."
                ;;
            11)
                echo -e "\033[1;34mStopping ZRAM service...\033[0m"
                sudo systemctl stop zramswap
                echo -e "\033[1;32mZRAM service stopped.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            12)
                echo -e "\033[1;34mDisabling ZRAM service...\033[0m"
                sudo systemctl disable zramswap
                echo -e "\033[1;32mZRAM service disabled.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            13)
                echo -e "\033[1;34mRemoving ZRAM swap area...\033[0m"
                sudo swapoff /dev/zram0
                sudo zramctl --destroy /dev/zram0
                echo -e "\033[1;32mZRAM swap area removed.\033[0m"
                read -p "Press Enter to continue..."
                ;;
            0)
                echo -e "\033[1;33mReturning to the main menu...\033[0m"
                main_menu
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please select a number between 0 and 13.\033[0m"
                read -p "Press Enter to continue..."
                ;;
        esac
    done
}

download_and_run_ssh_assistance() {
    local url="https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/ssh.sh"
    local script_path="/root/ssh.sh"

    echo -e "\033[1;34mDownloading the SSH assistance script...\033[0m"
    curl -o "$script_path" -s "$url"

    if [[ -f "$script_path" ]]; then
        echo -e "\033[1;32mDownload successful. Running the script...\033[0m"
        chmod +x "$script_path"
        bash "$script_path"
    else
        echo -e "\033[1;31mFailed to download the script.\033[0m"
    fi
}

fix_update_issues() {
    echo -e "\033[1;34mFixing broken packages and apt issues...\033[0m"

    # Fix broken packages
    sudo apt --fix-broken install -y

    # Clean up partial installations and dependencies
    sudo apt-get autoremove -y
    sudo apt-get autoclean -y

    # Try fixing any other package issues
    sudo dpkg --configure -a

    echo -e "\033[1;32mUpdate issues fixed successfully.\033[0m"
}

#!/bin/bash

# Function to run selected scripts
run_6to4_scripts() {
clear
    echo -e "\033[1;34mSelect a method to run:\033[0m"
    echo "1. Services (recommendation)"
    echo "2. Netplan"
    echo "0. Return"

    read -p "Enter your choice: " choice

    case $choice in
        1)
            echo -e "\033[1;32m6to4-service-method.sh\033[0m"
            # Command to run Script 1
            curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/6to4-service-method.sh -o 6to4-service-method.sh
		sudo bash 6to4-service-method.sh
            ;;
        2)
            echo -e "\033[1;32mRunning 6to4.sh\033[0m"
            # Command to run Script 2
            curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/6to4.sh -o 6to4.sh
		sudo bash 6to4.sh
            ;;
       
        0)
            echo -e "\033[1;31mExiting...\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid choice, please try again.\033[0m"
            ;;
    esac
}

display_system_info() {
SERVER_IP=$(curl -4 -s https://icanhazip.com)
    echo -e "\n\033[1;31mOS info:\033[0m"
    echo -e "\033[1;32mOS:\033[0m $(lsb_release -d | cut -f2)"
    echo -e "\033[1;32mISP:\033[0m $(curl -sS "http://ipwhois.app/json/$SERVER_IP" | jq -r '.isp')"
    echo -e "\033[1;32mCOUNTRY:\033[0m $(curl -sS "http://ipwhois.app/json/$SERVER_IP" | jq -r '.country')"
    echo -e "\033[1;32mPublic IPv4:\033[0m $(curl -4 -s https://icanhazip.com)"
    echo -e "\033[1;32mPublic IPv6:\033[0m $(curl -6 -s https://icanhazip.com)"
    echo -e "\033[1;32mUptime:\033[0m $(uptime -p)"
    echo -e "\033[1;32mCPU Cores:\033[0m $(lscpu | grep '^CPU(s):' | awk '{print $2}')"
    echo -e "\033[1;32mCPU Frequency:\033[0m $(grep 'MHz' /proc/cpuinfo | awk '{print $4 " MHz"}' | head -n 1)"
    echo -e "\033[1;32mRAM:\033[0m $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
    echo -e "\033[1;32mTime:\033[0m $(date +"%T %Z")"
    show_usage
    
}
fix_timezone() {
    sudo timedatectl set-timezone UTC
    echo -e "\033[1;32mTimezone set to UTC.\033[0m"
    read -p "Press Enter to continue..."
}

#!/bin/bash

run_haproxy_script() {
    echo -e "\033[1;34mSelect HAproxy port forwarding mode\033[0m"
    echo -e "\033[1;32m1.\033[0m SNI routing (one listening port to multi port)"
    echo -e "\033[1;32m2.\033[0m port forwarding by Musixal"
    echo -e "\033[1;31m0.\033[0m Return to Main Menu"

    read -p "Enter your choice (0-2): " choice
    case $choice in
        1)
            echo -e "\033[1;34mRunning sni mode Script...\033[0m"
            curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/HAproxy.sh -o HAproxy.sh
	    sudo bash HAproxy.sh
            ;;
        2)
            echo -e "\033[1;34mRunning Musixal Script...\033[0m"
            bash <(curl -Ls --ipv4 https://github.com/Musixal/haproxy/raw/main/haproxy.sh)
            ;;
        0)
            echo -e "\033[1;33mReturning to Main Menu...\033[0m"
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Please select a valid option.\033[0m"
            ;;
    esac
}

# Main menu function
main_menu() {
    while true; do
    clear
	echo -e "\033[1;31m+-----------------------------------------+\033[0m"
        echo -e "\033[1;32m       |   v2ray-assistant  |\033[0m"
 	echo -e "\033[1;32m       | Telegram: @tlgrmv2 |\033[0m"
	echo -e "\033[1;31m+-----------------------------------------+\033[0m"
        echo -e "\n\033[1;31mUpdate and upgrade:\033[0m"
        echo -e "\033[1;32m 1.\033[0m Update and upgrade system and install necessary packages"
	echo -e "\033[1;32m34.\033[0m Fix update issues (broken apt or dependencies)"
	 echo -e "\033[1;32m36.\033[0m System info"
	echo -e "\033[1;32m28.\033[0m Change Update sources to Iran"
        echo -e "\033[1;32m 2.\033[0m Install Docker and Docker Compose"
        echo -e "\033[1;32m20.\033[0m Install Docker on Iran servers"
	
        echo -e "\n\033[1;31mTools:\033[0m"
        echo -e "\033[1;32m 3.\033[0m ISP blocker"
        echo -e "\033[1;32m 4.\033[0m Network Optimizer + BBR"
        echo -e "\033[1;32m 5.\033[0m Speed test + system benchmark"
        echo -e "\033[1;32m 6.\033[0m Port (Check used ports by services)"
        echo -e "\033[1;32m 7.\033[0m Auto Clear cache + server reboot"
        echo -e "\033[1;32m 8.\033[0m Ping (Disable/enable) "
        echo -e "\033[1;32m 9.\033[0m DNS (Change server DNS)"
        echo -e "\033[1;32m18.\033[0m DNS (Create your DNS)"
        echo -e "\033[1;32m10.\033[0m Get SSL"
        echo -e "\033[1;32m15.\033[0m SWAP"
        echo -e "\033[1;32m16.\033[0m Desktop + firefox on ubuntu server"
        echo -e "\033[1;32m21.\033[0m Server monthly traffic limit"
        echo -e "\033[1;32m22.\033[0m CPU/RAM MONITORING"
        echo -e "\033[1;32m23.\033[0m UFW "
        echo -e "\033[1;32m24.\033[0m Cloudflare auto ip changer "
	echo -e "\033[1;32m26.\033[0m IP quality checks "
 	echo -e "\033[1;32m27.\033[0m Nginx "
        echo -e "\033[1;32m29.\033[0m IPV6 (Enable/Disable) "
	echo -e "\033[1;32m30.\033[0m ZRAM (Optimize RAM) "
        echo -e "\033[1;32m31.\033[0m Tunnel 6to4 SIT "
	echo -e "\033[1;32m32.\033[0m Send File to Remote Server & Forward to Telegram "
 	echo -e "\033[1;32m33.\033[0m Check URLs "
	echo -e "\033[1;32m35.\033[0m HAProxy "
 	echo -e "\033[1;32m37.\033[0m Fix WhatsApp Time (set timezone to UTC) "
  
        echo -e "\n\033[1;31mXray panel:\033[0m"
        echo -e "\033[1;32m11.\033[0m XUI panel"
        echo -e "\033[1;32m12.\033[0m Marzban panel"
        echo -e "\033[1;32m13.\033[0m Marzban node"
        echo -e "\033[1;32m17.\033[0m Backup + transfer"
        echo -e "\033[1;32m19.\033[0m Auto panel restart "
        echo -e "\033[1;31m0.\033[0m Exit"
	 echo -e "\n\033[1;31m\033[0m"
        choice=$(prompt_input "Enter your choice" "")
        
        case $choice in
            1) update_system
               install_packages ;;
            2) install_docker
		check_docker_compose ;;
            3) isp_blocker_script ;;
	    28)change_sources_list ;;
            4) Optimizer ;;
            5) run_system_benchmark ;;
            6) used_ports ;;
            7) setup_cache_and_reboot ;;
            8) manage_ping ;;
            9) change_dns ;;
            15) swap ;;
            16) webtop ;;
            11) xui ;;
            10) ssl;;
            12) marzban_commands;;
            13) manage_marzban_node ;;
            17) backup_menu ;;
            18) create_dns ;;
            19) panels_restart_cron ;;
            20) setup_docker ;;
            21) traffic ;;
            22) usage ;;
            23) ufw_menu ;;
            24) download_and_start_api ;;
            26) ip_quality_check ;;
            27) manage_nginx ;;
	    29) manage_ipv6 ;;
            30) manage_zram ;;
	    31) run_6to4_scripts  ;;
	    32) download_and_run_ssh_assistance ;;
            33) curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/setup_URLs_check.sh -o setup_URLs_check.sh
		sudo bash setup_URLs_check.sh ;;
	    34) fix_update_issues ;;
	    35) run_haproxy_script ;;
	    36) display_system_info ;; 
            37) fix_timezone ;; 
            0) exit 1
            echo "Exiting..." exit 0 ;;
            
            *) echo "Invalid choice. Please try again." ;;
        esac
    done
}
# Start the main menu
main_menu
