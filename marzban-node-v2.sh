#!/bin/bash

echo_red() {
    echo -e "\033[1;31m$1\033[0m"
}

echo_green() {
    echo -e "\033[1;32m$1\033[0m"
}

echo_yellow() {
    echo -e "\033[1;33m$1\033[0m"
}

echo_blue() {
    echo -e "\033[1;34m$1\033[0m"
}

echo_magenta() {
    echo -e "\033[1;35m$1\033[0m"
}

echo_cyan() {
    echo -e "\033[1;36m$1\033[0m"
}

echo_white() {
    echo -e "\033[1;37m$1\033[0m"
}
# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'  # Reset color
NC="\033[0m" # No Color
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
#manage_marzban_node
manage_marzban_node() {
clear
set -euo pipefail
# Detect Marzban node core directory
if [ -d "/opt/marzban-node" ]; then
    MARZBAN_NODE_DIR="/opt/marzban-node"
elif [ -d "/root/Marzban-node" ]; then
    MARZBAN_NODE_DIR="/root/Marzban-node"
elif [ -d "$HOME/Marzban-node" ]; then
    MARZBAN_NODE_DIR="$HOME/Marzban-node"
elif [ -d "/root/marzban-node" ]; then
    MARZBAN_NODE_DIR="/root/marzban-node"
else
    echo -e "\033[1;34mNo Marzban-node directory found. Skipping...\033[0m"
    # Set Marzban-node directory to default
    echo -e "\033[1;32mSetting Marzban-node directory to default: /root/Marzban-node\033[0m"
    MARZBAN_NODE_DIR="/root/Marzban-node"
fi

# Detect Marzban node data directory
if [ -d "/var/lib/marzban-node" ]; then
    MARZBAN_NODE_DATA_DIR="/var/lib/marzban-node"
elif [ -d "/var/lib/Marzban-node" ]; then
    MARZBAN_NODE_DATA_DIR="/var/lib/Marzban-node"
else
    echo -e "\033[1;34mNo Marzban-node data directory found. Skipping...\033[0m"
    # Set Marzban-node data directory to default
    echo -e "\033[1;32mSetting Marzban-node data directory to default: /var/lib/marzban-node\033[0m"
    MARZBAN_NODE_DATA_DIR="/var/lib/marzban-node"
fi

# Confirm directory detection
if [ -n "$MARZBAN_NODE_DIR" ]; then
    echo -e "\033[1;33mMarzban node core directory:\033[0m \033[1;34m$MARZBAN_NODE_DIR\033[0m"
fi

if [ -n "$MARZBAN_NODE_DATA_DIR" ]; then
    echo -e "\033[1;33mMarzban node data directory:\033[0m \033[1;34m$MARZBAN_NODE_DATA_DIR\033[0m"
fi
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m        Manage Marzban Node\033[0m"
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;32m1.\033[0m Setup Marzban-node"
	echo -e "\033[1;32m2.\033[0m Change node ports"
	echo -e "\033[1;32m3.\033[0m Edit node certificates"
	echo -e "\033[1;32m4.\033[0m Edit docker-compose.yml with nano"
	echo -e "\033[1;32m5.\033[0m Restart Docker Compose services"
	echo -e "\033[1;32m6.\033[0m Change Xray core version"
	echo -e "\033[1;32m7.\033[0m Enable/disable custom Xray core version"
	echo -e "\033[1;32m8.\033[0m Update Marzban Node"
 	echo -e "\033[1;32m9.\033[0m Setup Marzban Node traffic limit"
  echo -e "\033[1;32m10.\033[0m Stop Marzban Node"
  echo -e "\033[1;32m11.\033[0m Uninstall Marzban Node"
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
            6) list_and_download_xray_core
	    set_custom_xray_version
     		;;
            7) set_custom_xray_version ;;
            8) update_marzban_node ;;
	    9) curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/setup_node_traffic.sh -o setup_node_traffic.sh
		sudo bash setup_node_traffic.sh ;;
            10) down_docker_compose ;;
            11) uninstall_docker_compose ;;
            0) return ;;
            *) echo -e "\033[1;31mInvalid choice. Please enter a number between 1 and 10.\033[0m" ;;
        esac
        
        echo -e "\nPress Enter to continue..."
        read
    done
}

down_docker_compose() {

        local current_dir
    current_dir=$(pwd)
    cd "$MARZBAN_NODE_DIR"
    
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found in $MARZBAN_NODE_DIR"
        cd "$current_dir"
        return
    fi
    
    echo_yellow "Stopping Docker Compose services..."
    docker-compose down
    echo_green "Docker Compose services have been stopped successfully."
    
    cd "$current_dir" || return
}

uninstall_docker_compose() {

        local current_dir
    current_dir=$(pwd)
    # Check if Marzban node directory exists
    if [ ! -d "$MARZBAN_NODE_DIR" ]; then
        echo_red "Error: Marzban node directory ($MARZBAN_NODE_DIR) does not exist."
        return
    fi

    cd "$MARZBAN_NODE_DIR" || return
    
    # Check if docker-compose.yml exists before proceeding
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found in $MARZBAN_NODE_DIR"
        cd "$current_dir"
        return
    fi
    
    echo_yellow "Stopping and uninstalling Docker Compose services..."
    docker-compose down --volumes --remove-orphans
    echo_green "Docker Compose services and volumes have been uninstalled successfully."
    
   # Check and remove Marzban node directory
if [ -n "$MARZBAN_NODE_DIR" ] && [ -d "$MARZBAN_NODE_DIR" ]; then
    read -p "Do you want to remove the Marzban node directory ($MARZBAN_NODE_DIR)? (yes/no) [default: yes]: " remove_node_dir_choice
    remove_node_dir_choice=${remove_node_dir_choice:-yes}  # Default to "yes" if empty

    if [[ "$remove_node_dir_choice" == "yes" ]]; then
        echo_yellow "Removing Marzban node directory..."
        rm -rf "$MARZBAN_NODE_DIR"
        echo_green "Marzban node directory has been removed successfully."
    else
        echo_blue "Skipping the removal of Marzban node directory."
    fi
else
    echo_blue "Marzban node directory does not exist, skipping removal."
fi

# Check if MARZBAN_NODE_DATA_DIR is set
if [ -z "$MARZBAN_NODE_DATA_DIR" ]; then
    echo_red "Error: MARZBAN_NODE_DATA_DIR is not set."
    cd "$current_dir"
    return
fi

# Check and remove Marzban data directory
if [ -d "$MARZBAN_NODE_DATA_DIR" ]; then
    read -p "Do you want to remove the Marzban data directory ($MARZBAN_NODE_DATA_DIR)? (yes/no) [default: yes]: " remove_data_dir_choice
    remove_data_dir_choice=${remove_data_dir_choice:-yes}  # Default to "yes" if empty

    if [[ "$remove_data_dir_choice" == "yes" ]]; then
        echo_yellow "Removing Marzban data directory..."
        rm -rf "$MARZBAN_NODE_DATA_DIR"
        echo_green "Marzban data directory has been removed successfully."
    else
        echo_blue "Skipping the removal of Marzban data directory."
    fi
else
    echo_blue "Marzban data directory does not exist, skipping removal."
fi

    
    cd "$current_dir" || return
}



install_docker() {
    # Check if Docker is installed
    echo "Checking if Docker is installed..."
    if ! command -v docker &> /dev/stdout; then
        echo_yellow "Docker is not installed. Installing Docker..."
       
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh

        if [ $? -eq 0 ]; then
            echo_green "Docker installed successfully."

            # Add user to Docker group (only if not root)
            if [ "$EUID" -ne 0 ]; then
                sudo usermod -aG docker $USER
                echo_yellow "Please log out and log back in to apply Docker group permissions."
            fi

        else
            echo_red "Installation of Docker failed."
            return 1
        fi

        # Clean up installer file if it exists
        [ -f get-docker.sh ] && sudo rm get-docker.sh
    else
        echo_green "Docker is already installed."
    fi

    # Check if Docker is running
    echo "Checking if Docker is running..."
    if ! sudo systemctl is-active --quiet docker; then
        echo_yellow "Docker is not running. Attempting to start Docker..."
      
        sudo systemctl start docker
        if ! sudo systemctl is-active --quiet docker; then
            echo_red "Failed to start Docker. Please manually start Docker."
            return 1
        fi
    fi

    # Ensure Docker starts on boot
    sudo systemctl enable docker

    # Display the current Docker status
    echo_green "Docker is running and enabled at startup."
    sudo systemctl status docker | grep "Active:"  # Display only the 'Active' status line
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
# Function to install marzban node
setup_marzban_node() {
local current_dir
    current_dir=$(pwd)
    if [ -d "$MARZBAN_NODE_DIR" ]; then
        echo_red "! marzban node directory already exists !"
        read -p "Do you want to remove the Marzban node directory ($MARZBAN_NODE_DIR)? (Yes/no) [defualt yes]: " remove_node_dir_choice
        remove_node_dir_choice=${remove_node_dir_choice:-yes}  # Default to "yes" if empty

        if [[ "$remove_node_dir_choice" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo_red "Removing existing directory $MARZBAN_NODE_DIR..."
            rm -rf "$MARZBAN_NODE_DIR"
            echo_green "Marzban node directory has been removed."
        else
            echo_blue "Skipping the removal of Marzban node directory."
        fi
    fi

    if [ -d "$MARZBAN_NODE_DATA_DIR" ]; then
    echo_red "! marzban node data directory already exists !"
        read -p "Do you want to remove the Marzban data directory ($MARZBAN_NODE_DATA_DIR)? (Yes/no) [defualt yes]: " remove_data_dir_choice
        remove_data_dir_choice=${remove_data_dir_choice:-yes}  # Default to "yes" if empty

        if [[ "$remove_data_dir_choice" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo_red "Removing existing directory $MARZBAN_NODE_DATA_DIR..."
            sudo rm -rf "$MARZBAN_NODE_DATA_DIR"
            echo_green "Marzban data directory has been removed."
        else
            echo_blue "Skipping the removal of Marzban data directory."
        fi
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
      - /var/lib/marzban-node:/var/lib/marzban-node
    logging:
      driver: "none"  # Disable logging for this container
EOF
    done
	for ((i = 1; i <= NUM_NODES; i++)); do
    CERT_FILE="$MARZBAN_NODE_DATA_DIR/ssl_client_cert_$i.pem"

    echo -ne "\rPress Enter to edit the marzban-node-$i certificate with nano "

# Animated blinking effect while waiting for Enter key
while true; do
    for s in " " "."; do
        echo -ne "\rPress Enter to edit the marzban-node-$i certificate with nano $s"
        read -t 0.5 -n 1 key && break 2
    done
done

echo_green "\rEditing the marzban-node-$i certificate with nano...  "  # Clear blinking text
sleep 1

    # Open the certificate file with nano
    sudo nano "$CERT_FILE"

    # Confirm successful editing
    echo_green "Certificate marzban-node-$i file edited successfully."
    sleep 1
done

	# Restart Docker Compose after setup
    restart_docker_compose
    cd "$current_dir" || return
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
        read -p "Press Enter to edit the marzban-node-$selected_node certificate with nano..."

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
    local current_dir
    current_dir=$(pwd)

    cd $MARZBAN_NODE_DIR || { echo -e "\033[1;31mFailed to change directory to Marzban-node.\033[0m"; return; }

    echo -e "\033[1;32mPulling the latest images...\033[0m"
    docker compose pull

    echo -e "\033[1;32mStopping and removing orphaned containers...\033[0m"
    docker compose down --remove-orphans

    echo -e "\033[1;32mStarting services...\033[0m"
    docker compose up -d

    echo -e "\033[1;32mMarzban node update completed successfully.\033[0m"
    cd "$current_dir"
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
        sleep 1
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
        sleep 1
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
            sleep 1
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
            sleep 1
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
            sleep 1
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

    sleep 1
}
manage_marzban_node
