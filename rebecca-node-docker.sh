#!/bin/bash

# =============================================================================
# Rebecca Node Docker Management Script
# This script installs and manages Rebecca Node using Docker Compose.
# It features node discovery and a menu similar to the Rebecca binary script.
# =============================================================================

set -euo pipefail

# ------------------------------ Color Functions ------------------------------
echo_red()   { echo -e "\033[1;31m$1\033[0m"; }
echo_green() { echo -e "\033[1;32m$1\033[0m"; }
echo_yellow(){ echo -e "\033[1;33m$1\033[0m"; }
echo_blue()  { echo -e "\033[1;34m$1\033[0m"; }
echo_magenta(){ echo -e "\033[1;35m$1\033[0m"; }
echo_cyan()  { echo -e "\033[1;36m$1\033[0m"; }
echo_white() { echo -e "\033[1;37m$1\033[0m"; }

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; RESET='\033[0m'; NC="\033[0m"

# ------------------------------ Default Settings -----------------------------
REBECCA_NODE_IMAGE="${REBECCA_NODE_IMAGE:-rebeccapanel/rebecca-node:latest}"
SCRIPT_DEFAULT_APP_NAME="rebecca-node"
INSTALL_DIR="/opt"
NODE_DISCOVERY_BASE="/opt"

# ------------------------------ Global Variables -----------------------------
APP_NAME=""
APP_DIR=""
DATA_DIR=""
APP_NAME_FROM_ARG=0

declare -a DISCOVERED_NODE_PATHS=()
declare -a DISCOVERED_NODE_NAMES=()

# ------------------------------ Helper Functions -----------------------------
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

prompt_input() {
    local prompt="$1"
    local default_value="${2:-}"
    local prompt_text="$prompt"
    if [ -n "$default_value" ]; then
        prompt_text="$prompt_text [$default_value]"
    fi
    read -t 0.1 -n 10000 discard_input 2>/dev/null || true
    read -p "$prompt_text: " user_input
    echo "${user_input:-$default_value}"
}

ensure_valid_app_name() {
    local candidate="${APP_NAME:-$SCRIPT_DEFAULT_APP_NAME}"
    if [[ "$candidate" != rebecca-node* ]]; then
        candidate="rebecca-node-${candidate}"
    fi
    if ! [[ "$candidate" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        candidate="rebecca-node"
        echo "Invalid app name detected. Falling back to default: $candidate"
    fi
    APP_NAME="$candidate"
}

set_app_context() {
    if [ -z "$APP_NAME" ]; then
        APP_NAME="$SCRIPT_DEFAULT_APP_NAME"
    fi
    ensure_valid_app_name

    if [ -z "${APP_DIR:-}" ] || [ ! -d "$APP_DIR" ]; then
        if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
            APP_DIR="$INSTALL_DIR/$APP_NAME"
        else
            APP_DIR="$INSTALL_DIR/$APP_NAME"
        fi
    fi

    DATA_DIR="/var/lib/$APP_NAME"
    ENV_FILE="$APP_DIR/.env"
}

# ------------------------------ Node Discovery -------------------------------
add_discovered_node_instance() {
    local dir="$1"
    local name="$2"
    for existing in "${DISCOVERED_NODE_PATHS[@]}"; do
        if [ "$existing" = "$dir" ]; then return; fi
    done
    if [ -z "$name" ]; then name=$(basename "$dir"); fi
    DISCOVERED_NODE_PATHS+=("$dir")
    DISCOVERED_NODE_NAMES+=("$name")
}

discover_node_instances() {
    DISCOVERED_NODE_PATHS=()
    DISCOVERED_NODE_NAMES=()

    if [ -d "$NODE_DISCOVERY_BASE" ]; then
        while IFS= read -r -d '' dir; do
            local name
            name=$(basename "$dir")
            if [ -f "$dir/docker-compose.yml" ]; then
                if grep -q "rebecca-node" "$dir/docker-compose.yml" 2>/dev/null || [ -f "$dir/.env" ]; then
                    add_discovered_node_instance "$dir" "$name"
                fi
            fi
        done < <(find "$NODE_DISCOVERY_BASE" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi
}

# ------------------------------ UI Helpers (from binary script) --------------
ui_is_tty() { [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; }
ui_color() {
    local code="$1"; shift
    if ui_is_tty; then printf "\033[%sm%s\033[0m" "$code" "$*"; else printf "%s" "$*"; fi
}
ui_line() { ui_color "38;5;39" "────────────────────────────────────────────────────────────"; printf "\n"; }
ui_header() {
    local title="$1"; local subtitle="${2:-}"
    printf "\n"
    ui_color "38;5;45;1" "╭──────────────────────────────────────────────────────────╮"
    printf "\n  "
    ui_color "38;5;231;1" "$title"
    printf "\n"
    if [ -n "$subtitle" ]; then
        printf "  "
        ui_color "38;5;117" "$subtitle"
        printf "\n"
    fi
    ui_color "38;5;45;1" "╰──────────────────────────────────────────────────────────╯"
    printf "\n"
}
ui_section() { printf "\n"; ui_color "38;5;45;1" "◆ $1"; printf "\n"; ui_line; }
ui_status_row() {
    local label="$1"; local value="$2"
    printf "  "
    ui_color "38;5;245" "$(printf '%-14s' "$label")"
    ui_color "38;5;231;1" "$value"
    printf "\n"
}
ui_menu_category() { printf "\n"; ui_color "38;5;117;1" "  $1"; printf "\n"; }
ui_clear() { if ui_is_tty; then printf "\033[H\033[2J"; fi; }

# ------------------------------ Status Information ----------------------------
get_node_current_version() {
    if [ -f "$APP_DIR/.version" ]; then
        cat "$APP_DIR/.version"
    else
        local image_tag
        image_tag=$(grep -E 'image:' "$APP_DIR/docker-compose.yml" 2>/dev/null | head -n1 | awk '{print $2}' | cut -d':' -f2)
        echo "${image_tag:-latest}"
    fi
}

get_node_service_status() {
    if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
        echo "not installed"
        return
    fi
    cd "$APP_DIR" 2>/dev/null || return
    if docker-compose ps --services --filter "status=running" 2>/dev/null | grep -q .; then
        echo "running"
    else
        echo "stopped"
    fi
}

get_node_ip() {
    local ip
    ip=$(curl -s -4 ifconfig.io 2>/dev/null)
    if [ -z "$ip" ]; then
        ip=$(curl -s -6 ifconfig.io 2>/dev/null)
    fi
    echo "${ip:-unknown}"
}

get_service_port() {
    if [ -f "$ENV_FILE" ]; then
        grep -E '^SERVICE_PORT' "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' "'
    else
        grep -E 'SERVICE_PORT:' "$APP_DIR/docker-compose.yml" 2>/dev/null | head -n1 | awk '{print $2}'
    fi
}

get_xray_api_port() {
    if [ -f "$ENV_FILE" ]; then
        grep -E '^XRAY_API_PORT' "$ENV_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' "'
    else
        grep -E 'XRAY_API_PORT:' "$APP_DIR/docker-compose.yml" 2>/dev/null | head -n1 | awk '{print $2}'
    fi
}

print_node_menu_status_summary() {
    local service_port xray_api_port
    service_port=$(get_service_port)
    xray_api_port=$(get_xray_api_port)
    service_port="${service_port:-62050}"
    xray_api_port="${xray_api_port:-62051}"
    ui_status_row "Version" "$(get_node_current_version)"
    ui_status_row "Service" "$(get_node_service_status)"
    ui_status_row "Node IP" "$(get_node_ip)"
    ui_status_row "Service port" "$service_port"
    ui_status_row "Xray API" "$xray_api_port"
    local cert_file="$DATA_DIR/ssl_client_cert_1.pem"
    [ -f "$cert_file" ] && ui_status_row "Cert" "$cert_file"
}

# ------------------------------ Certificate Reader (for install) -------------
read_node_certificate_bundle() {
    local bundle_file
    bundle_file=$(mktemp)
    : > "$bundle_file"

    echo -e "Paste the Node certificate (PEM format) from the panel, press ENTER on a new line when finished: "
    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ -z "$line" ]]; then
            break
        fi
        echo "$line" >> "$bundle_file"
    done

    local cert_file="$1"
    cp "$bundle_file" "$cert_file"
    rm -f "$bundle_file"
    echo_green "Certificate saved to $cert_file"
    return 0
}

# ------------------------------ Edit Certificate (paste new content) ---------
edit_node_certificates() {
    if [ ! -f "$APP_DIR/docker-compose.yml" ]; then
        echo_red "Error: docker-compose.yml not found in $APP_DIR"
        return
    fi
    if [ ! -d "$DATA_DIR" ]; then
        echo_red "Error: Data directory $DATA_DIR does not exist."
        return
    fi
    cd "$APP_DIR"

    existing_nodes=$(grep -oE 'rebecca-node-[0-9]*:' "docker-compose.yml" | sort -u)
    NUM_NODES=$(echo "$existing_nodes" | wc -w)

    echo_yellow "Available node certificates:"
    for node in $existing_nodes; do
        node_number=$(echo "$node" | cut -d '-' -f 3)
        echo "  rebecca-node-$node_number"
    done

    selected_node=""
    while true; do
        selected_node=$(prompt_input "Enter the rebecca-node number to edit certificate: ")
        if [[ "$selected_node" =~ ^[0-9]+$ ]] && [ "$selected_node" -ge 1 ] && [ "$selected_node" -le "$NUM_NODES" ]; then
            break
        else
            echo_red "Error: Invalid node number."
        fi
    done

    CERT_FILE="$DATA_DIR/ssl_client_cert_$selected_node.pem"
    if [ ! -f "$CERT_FILE" ]; then
        echo_yellow "Certificate file does not exist. Creating new file."
        touch "$CERT_FILE"
    fi

    echo_yellow "Current certificate content for rebecca-node-$selected_node:"
    echo "----------------------------------------"
    cat "$CERT_FILE"
    echo "----------------------------------------"
    echo ""
    echo_yellow "Paste the new certificate content (PEM format) and press ENTER on a new line when finished:"

    local new_content=""
    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ -z "$line" ]]; then
            break
        fi
        new_content="$new_content$line"$'\n'
    done

    echo "$new_content" > "$CERT_FILE"
    echo_green "Certificate for rebecca-node-$selected_node updated."

    read -p "Do you want to restart the Docker container for rebecca-node-$selected_node? (yes/no) [yes]: " restart_choice
    restart_choice=${restart_choice:-yes}
    if [[ "$restart_choice" == "yes" ]]; then
        echo_green "Restarting container..."
        cd "$APP_DIR" || return
        docker-compose down --remove-orphans "rebecca-node-$selected_node"
        docker-compose up -d "rebecca-node-$selected_node"
    else
        echo_green "Container will not be restarted."
    fi
    sleep 2
}

# ------------------------------ Docker Installation --------------------------
install_docker() {
    echo "Checking if Docker is installed..."
    if ! command -v docker &> /dev/null; then
        echo_yellow "Docker is not installed. Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        if [ $? -eq 0 ]; then
            echo_green "Docker installed successfully."
            if [ "$EUID" -ne 0 ]; then
                sudo usermod -aG docker $USER
                echo_yellow "Please log out and log back in to apply Docker group permissions."
            fi
        else
            echo_red "Installation of Docker failed."
            return 1
        fi
        [ -f get-docker.sh ] && sudo rm get-docker.sh
    else
        echo_green "Docker is already installed."
    fi

    if ! sudo systemctl is-active --quiet docker; then
        echo_yellow "Docker is not running. Attempting to start Docker..."
        sudo systemctl start docker
        if ! sudo systemctl is-active --quiet docker; then
            echo_red "Failed to start Docker. Please manually start Docker."
            return 1
        fi
    fi
    sudo systemctl enable docker
    echo_green "Docker is running and enabled at startup."
    docker --version
}

check_docker_compose() {
    if ! command -v jq &> /dev/null; then
        echo_yellow "jq is not installed. Installing now..."
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
    fi

    if ! command -v docker-compose &> /dev/null; then
        echo_yellow "Docker Compose is not installed. Installing now..."
        latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')
        if [ -z "$latest_version" ]; then
            echo_red "Failed to fetch the latest Docker Compose version."
            return 1
        fi
        sudo curl -L "https://github.com/docker/compose/releases/download/$latest_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        if ! docker-compose --version &> /dev/null; then
            echo_red "Failed to install Docker Compose."
            return 1
        fi
        echo_green "Docker Compose installed successfully."
    else
        installed_version=$(docker-compose --version)
        echo_green "Docker Compose is already installed. Current version: $installed_version"
    fi
}

# ------------------------------ Setup Functions ------------------------------
setup_rebecca_node() {
    while true; do
        echo -e "${YELLOW}Select a mode to run or choose to return:${NC}"
        echo -e "${GREEN}1.${NC} Normal Mode (Host Network: Use all inbound ports)"
        echo -e "${GREEN}2.${NC} Port Mapping Mode (Use only specific inbound ports)"
        echo -e "${GREEN}3.${NC} Return"
        read -p "$(echo -e ${YELLOW}Please choose an option or press enter for Normal Mode [default]:${NC} )" choice
        choice=${choice:-1}
        case "$choice" in
            1) echo -e "${GREEN}Running Normal Mode...${NC}"; setup_rebecca_node1; return ;;
            2) echo -e "${GREEN}Running Port Mapping Mode...${NC}"; setup_rebecca_node2; return ;;
            3) echo -e "${YELLOW}Returning to the main menu...${NC}"; return ;;
            *) echo -e "${RED}Invalid option. Please choose 1, 2, or 3.${NC}" ;;
        esac
    done
}

setup_rebecca_node1() {
    local current_dir
    current_dir=$(pwd)

    if [ -d "$APP_DIR" ]; then
        echo_red "! Rebecca node directory already exists !"
        read -p "Do you want to remove the existing directory ($APP_DIR)? (Yes/no) [default yes]: " remove_choice
        remove_choice=${remove_choice:-yes}
        if [[ "$remove_choice" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo_red "Removing existing directory $APP_DIR..."
            rm -rf "$APP_DIR"
            echo_green "Directory removed."
        else
            echo_blue "Skipping removal."
        fi
    fi

    if [ -d "$DATA_DIR" ]; then
        echo_red "! Rebecca node data directory already exists !"
        read -p "Do you want to remove the data directory ($DATA_DIR)? (Yes/no) [default yes]: " remove_data_choice
        remove_data_choice=${remove_data_choice:-yes}
        if [[ "$remove_data_choice" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo_red "Removing existing data directory $DATA_DIR..."
            sudo rm -rf "$DATA_DIR"
            echo_green "Data directory removed."
        else
            echo_blue "Skipping data directory removal."
        fi
    fi

    echo_green "Creating Rebecca node directory: $APP_DIR"
    mkdir -p "$APP_DIR"
    echo_green "Creating data directory: $DATA_DIR"
    sudo mkdir -p "$DATA_DIR"

    cd "$APP_DIR"

    while true; do
        NUM_NODES=$(prompt_input "How many nodes (services) do you need in this compose? [1-3]" 1)
        if [[ "$NUM_NODES" =~ ^[1-3]$ ]]; then break; else echo_red "Enter a number between 1 and 3."; fi
    done

    echo "services:" > docker-compose.yml
    for ((i = 1; i <= NUM_NODES; i++)); do
        DEFAULT_SERVICE_PORT=5000
        DEFAULT_XRAY_API_PORT=5001
        case $i in
            2) DEFAULT_SERVICE_PORT=3000; DEFAULT_XRAY_API_PORT=3001 ;;
            3) DEFAULT_SERVICE_PORT=4000; DEFAULT_XRAY_API_PORT=4001 ;;
        esac

        SERVICE_PORT=$(prompt_input "Enter service port for rebecca-node-$i" "$DEFAULT_SERVICE_PORT")
        XRAY_API_PORT=$(prompt_input "Enter XRAY API port for rebecca-node-$i" "$DEFAULT_XRAY_API_PORT")
        validate_port "$SERVICE_PORT"
        validate_port "$XRAY_API_PORT"

        CERT_FILE="$DATA_DIR/ssl_client_cert_$i.pem"
        echo_yellow "Please provide the certificate content for rebecca-node-$i"
        if ! read_node_certificate_bundle "$CERT_FILE"; then
            echo_red "Failed to read certificate. Aborting installation for this node."
            cd "$current_dir" || return
            return 1
        fi

        cat <<EOF >> docker-compose.yml
  rebecca-node-$i:
    image: $REBECCA_NODE_IMAGE
    restart: always
    network_mode: host
    environment:
      SSL_CLIENT_CERT_FILE: "$CERT_FILE"
      SERVICE_PORT: $SERVICE_PORT
      XRAY_API_PORT: $XRAY_API_PORT
      SERVICE_PROTOCOL: "rest"
    volumes:
      - $DATA_DIR:/var/lib/rebecca-node
    logging:
      driver: "none"
EOF
    done

    echo "SERVICE_PORT=${SERVICE_PORT}" > "$APP_DIR/.env"
    echo "XRAY_API_PORT=${XRAY_API_PORT}" >> "$APP_DIR/.env"
    echo "dev" > "$APP_DIR/.version"

    restart_docker_compose
    cd "$current_dir" || return
}

setup_rebecca_node2() {
    echo_red "Port Mapping Mode is not implemented in this version. Using Normal Mode."
    setup_rebecca_node1
}

# ------------------------------ Docker Compose Management --------------------
start_docker_compose() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found."
        return 1
    fi
    echo_yellow "Starting services..."
    docker-compose up -d
    echo_green "Services started."
}

stop_docker_compose() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found."
        return 1
    fi
    echo_yellow "Stopping services..."
    docker-compose down
    echo_green "Services stopped."
}

restart_docker_compose() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found."
        return 1
    fi
    echo_yellow "Restarting services..."
    docker-compose down --remove-orphans
    docker-compose up -d
    echo_green "Services restarted."
}

show_status() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found."
        return 1
    fi
    docker-compose ps
}

show_logs() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found."
        return 1
    fi
    docker-compose logs -f
}

uninstall_rebecca_node() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "No docker-compose.yml found. Removing directory..."
        rm -rf "$APP_DIR"
        return
    fi
    echo_yellow "Stopping and removing containers and volumes..."
    docker-compose down --volumes --remove-orphans
    echo_green "Containers and volumes removed."

    read -p "Do you want to remove the node directory ($APP_DIR) and data ($DATA_DIR)? (yes/no) [default: yes]: " remove_all
    remove_all=${remove_all:-yes}
    if [[ "$remove_all" == "yes" ]]; then
        rm -rf "$APP_DIR"
        sudo rm -rf "$DATA_DIR"
        echo_green "Node directories removed."
    else
        echo_blue "Skipping directory removal."
    fi
}

update_rebecca_node() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found."
        return 1
    fi
    echo_yellow "Pulling latest image..."
    docker-compose pull
    echo_yellow "Recreating containers..."
    docker-compose down --remove-orphans
    docker-compose up -d
    echo_green "Update completed."
}

edit_compose() {
    cd "$APP_DIR" || return
    if [ ! -f docker-compose.yml ]; then
        echo_red "Error: docker-compose.yml not found."
        return 1
    fi
    sudo nano docker-compose.yml
    echo_green "docker-compose.yml edited."
}

# ------------------------------ Xray Core Management --------------------------
list_and_download_xray_core() {
    local xray_core_dir="$DATA_DIR/xray-core"
    local github_api_url="https://api.github.com/repos/XTLS/Xray-core/releases"
    local versions_file="/tmp/xray_versions.txt"

    echo_yellow "Fetching the list of available Xray core versions..."
    curl -s "$github_api_url?per_page=15" | grep -oP '"tag_name": "\K(.*?)(?=")' > "$versions_file"

    if [ ! -s "$versions_file" ]; then
        echo_red "Failed to fetch Xray core versions."
        return 1
    fi

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

    local compose_file="$APP_DIR/docker-compose.yml"
    if [ -f "$compose_file" ]; then
        if ! grep -q 'XRAY_EXECUTABLE_PATH:' "$compose_file"; then
            echo_yellow "Adding XRAY_EXECUTABLE_PATH to docker-compose.yml..."
            sed -i "/environment:/a\      XRAY_EXECUTABLE_PATH: \"$xray_core_dir/xray\"" "$compose_file"
            echo_green "Added. Restart services to apply."
        fi
    fi
}

# ------------------------------ Menu System (like binary) --------------------
menu_commands() {
    echo "up down restart status logs install update uninstall edit-cert edit-compose core-update help"
}

menu_category_for() {
    case "$1" in
        up|down|restart|status|logs) echo "Node runtime" ;;
        install|update|uninstall) echo "Install and update" ;;
        edit-cert|edit-compose|core-update) echo "Tools" ;;
        help) echo "Help" ;;
        *) echo "Other" ;;
    esac
}

menu_description_for() {
    case "$1" in
        up) echo "Start services" ;;
        down) echo "Stop services" ;;
        restart) echo "Restart services" ;;
        status) echo "Show status" ;;
        logs) echo "Show logs" ;;
        install) echo "Install/reinstall $APP_NAME" ;;
        update) echo "Update node" ;;
        uninstall) echo "Uninstall $APP_NAME" ;;
        edit-cert) echo "Edit node certificate (paste new)" ;;
        edit-compose) echo "Edit docker-compose.yml" ;;
        core-update) echo "Update/Change Xray core" ;;
        help) echo "Show this help message" ;;
        *) echo "" ;;
    esac
}

print_menu() {
    ui_header "$APP_NAME" "$APP_NAME control center"
    ui_section "Status"
    print_node_menu_status_summary
    ui_section "Actions"

    local previous_category=""
    local idx=1
    local cmd category desc

    for cmd in $(menu_commands); do
        category=$(menu_category_for "$cmd")
        if [ "$category" != "$previous_category" ]; then
            ui_menu_category "$category"
            previous_category="$category"
        fi
        desc=$(menu_description_for "$cmd")
        printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$idx" "$cmd" "$desc"
        idx=$((idx + 1))
    done
    echo
}

map_choice_to_command() {
    local commands=($(menu_commands))
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le "${#commands[@]}" ]; then
        echo "${commands[$(($1 - 1))]}"
        return
    fi
    echo "$1"
}

read_menu_command() {
    local commands=($(menu_commands))
    local total=${#commands[@]}

    while true; do
        ui_clear
        print_menu
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r user_choice

        if [[ "$user_choice" == "q" || "$user_choice" == "Q" ]]; then
            echo
            exit 0
        fi

        MENU_COMMAND=$(map_choice_to_command "$user_choice")

        if [[ " ${commands[*]} " =~ " ${MENU_COMMAND} " ]] && [ -n "$MENU_COMMAND" ]; then
            echo
            return 0
        fi

        echo_red "Invalid choice. Please enter a number between 1 and $total."
        sleep 1.5
    done
}

# ------------------------------ Dispatch -------------------------------------
dispatch_command() {
    local cmd="$1"
    shift || true
    case "$cmd" in
        up) start_docker_compose ;;
        down) stop_docker_compose ;;
        restart) restart_docker_compose ;;
        status) show_status ;;
        logs) show_logs ;;
        install) install_docker; check_docker_compose; setup_rebecca_node ;;
        update) update_rebecca_node ;;
        uninstall) uninstall_rebecca_node ;;
        edit-cert) edit_node_certificates ;;
        edit-compose) edit_compose ;;
        core-update) list_and_download_xray_core ;;
        help) print_menu ;;
        *) echo_red "Unknown command: $cmd"; print_menu ;;
    esac
}

# ------------------------------ Node Selection -------------------------------
startup_node_selection() {
    discover_node_instances

    while true; do
        ui_clear
        ui_header "Rebecca Node Selection" "Select an existing node or create a new one"

        local count=${#DISCOVERED_NODE_PATHS[@]}
        local idx=2  # start numbering from 2 for discovered nodes

        if [ "$count" -gt 0 ]; then
            echo_yellow "   Discovered Nodes:"
            for i in "${!DISCOVERED_NODE_PATHS[@]}"; do
                local name="${DISCOVERED_NODE_NAMES[$i]}"
                local path="${DISCOVERED_NODE_PATHS[$i]}"
                printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-22s\033[0m \033[38;5;245m(%s)\033[0m\n" "$idx" "$name" "$path"
                ((idx++))
            done
            echo
        else
            echo_red "   No Rebecca node installations detected."
            echo
        fi

        printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-25s\033[0m\n" "0" "Exit"
        printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-25s\033[0m\n" "1" "Create a new node"
        printf "   \033[38;5;117;1m%2s)\033[0m \033[38;5;231;1m%-25s\033[0m\n" "S" "Search custom directory"
        echo
        echo_cyan "Select an option: "
        read -r choice

        case "$choice" in
            0)
                echo
                exit 0
                ;;
            1)
                echo
                echo_cyan "Enter a suffix for the new node."
                echo_yellow "Example: typing 'newname' creates 'rebecca-node-newname'"
                read -p "Suffix (leave empty for default 'rebecca-node'): " suffix
                suffix=$(echo "$suffix" | tr -cd 'a-zA-Z0-9_-')
                if [[ -n "$suffix" ]]; then
                    APP_NAME="rebecca-node-${suffix}"
                else
                    APP_NAME="rebecca-node"
                fi
                APP_NAME_FROM_ARG=1
                set_app_context
                return 0
                ;;
            [Ss])
                echo
                echo_cyan "Enter the directory path to search for node installations (e.g., /root):"
                read -p "Path: " search_path
                if [ -d "$search_path" ]; then
                    local found_any=0
                    while IFS= read -r -d '' dir; do
                        local name
                        name=$(basename "$dir")
                        if [ -f "$dir/docker-compose.yml" ] && grep -q "rebecca-node" "$dir/docker-compose.yml" 2>/dev/null; then
                            add_discovered_node_instance "$dir" "$name"
                            found_any=1
                        fi
                    done < <(find "$search_path" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null || true)
                    if [ "$found_any" -eq 0 ]; then
                        echo_yellow "No Rebecca node installations found under $search_path."
                        sleep 2
                    else
                        echo_green "Found new nodes. Refreshing list..."
                        sleep 1
                    fi
                else
                    echo_red "Directory does not exist: $search_path"
                    sleep 2
                fi
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 2 ] && [ "$choice" -le "$((count+1))" ]; then
                    local chosen=$((choice - 2))
                    if [ "$chosen" -ge 0 ] && [ "$chosen" -lt "$count" ]; then
                        APP_NAME="${DISCOVERED_NODE_NAMES[$chosen]}"
                        APP_DIR="${DISCOVERED_NODE_PATHS[$chosen]}"
                        DATA_DIR="/var/lib/$APP_NAME"
                        set_app_context
                        return 0
                    fi
                else
                    echo_red "Invalid choice."
                    sleep 1
                fi
                ;;
        esac
    done
}

# ------------------------------ Main -----------------------------------------
if [ $# -eq 0 ]; then
    startup_node_selection
    while true; do
        read_menu_command || exit 0
        dispatch_command "$MENU_COMMAND" || true
        echo
        echo_cyan "Press Enter to return to the menu..."
        read -r
    done
else
    if [ -z "${APP_NAME:-}" ]; then
        startup_node_selection
    fi
    dispatch_command "$1"
fi