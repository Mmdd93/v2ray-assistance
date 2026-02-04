#!/bin/bash
# Function to prompt for input with default value
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
docker_install_menu() {
    while true; do
        echo -e "\033[1;33mSelect an option:\033[0m"
        echo "1) Install Docker (Docker official script)"
        echo "2) Install Docker Compose"
	echo "3) install Docker step-by-step"
	echo "4) Uninstall Docker"
 echo "0) Exit"
        read -p "Choose an option: " option
        
        case $option in
0)
                break  # Return to the main menu
                ;;
            1)
                install_docker
		read -p "Press Enter to continue..."
                break
                ;;
            2)
                check_docker_compose
		read -p "Press Enter to continue..."
                break
                ;;
	3)
                echo -e "\033[1;34mStarting Docker setup...\033[0m"

                # Step 1: Check if Docker is already installed
                if command -v docker &> /dev/null; then
		# Display Docker version
        echo_yellow "Docker version:"
        docker --version
                    echo -e "\033[1;33mUpdate Docker? (yes/no):\033[0m"
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
		read -p "Press Enter to continue..."
		break
                ;;
  4) uninstall_docker
  read -p "Press Enter to continue..."
  break
  ;;
            *)
                echo -e "\033[1;31mInvalid option, please choose 1 or 2.\033[0m"
                continue
                ;;
        esac
        
        read -p "Do you want to retry? (yes/no): " retry_choice
        retry_choice=${retry_choice:-yes}  # Default to "yes" if empty
        
        if [[ "$retry_choice" == "no" ]]; then
            echo "Exiting..."
            break
        fi
    done
}
set -euo pipefail

install_docker() {
    # Check if Docker is installed
    echo_yellow "Checking if Docker is installed..."
    if ! command -v docker &> /dev/stdout; then
        echo_yellow "Docker is not installed. Installing Docker..."

        sudo curl -fsSL https://get.docker.com | sh

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

        # Display Docker version
        echo_yellow "Docker version:"
        docker --version

        # Ask if the user wants to update Docker
        read -p "Do you want to update Docker? (yes/no) [default: no]: " update_choice
        update_choice=${update_choice:-no}  # Default to "no" if empty

        if [[ "$update_choice" == "yes" ]]; then
            # Ask the user for how they want to update Docker (selectable options)
            echo_yellow "Choose an option to update Docker:"
            echo "1. Update Docker using the Docker installation script"
            echo "2. Update Docker via normal apt upgrade"
            echo "3. return"
            read -p "Enter your choice: " update_method
            update_method=${update_method:-3}  # Default to "3" (skip) if empty

            case $update_method in
                1)
                    echo_yellow "Updating Docker using the Docker installation script..."
                    sudo curl -fsSL https://get.docker.com | sh

                    if [ $? -eq 0 ]; then
                        echo_green "Docker updated successfully using the script."
                    else
                        echo_red "Error updating Docker using the script."
                    fi
                    ;;
                2)
                    echo_yellow "Updating Docker via normal apt upgrade..."
                    sudo apt-get update
                    sudo apt-get upgrade -y docker-ce docker-ce-cli containerd.io

                    if [ $? -eq 0 ]; then
                        echo_green "Docker updated successfully using apt."
                    else
                        echo_red "Error updating Docker using apt."
                    fi
                    ;;
                3)
                    echo_blue "Skipping Docker update."
                    ;;
                *)
                    echo_red "Invalid choice. Skipping Docker update."
                    ;;
            esac
        else
            echo_blue "Skipping Docker update."
        fi
    fi

    # Check if Docker is running
    echo_yellow "Checking if Docker is running..."
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
uninstall_docker() {
    echo -e "\033[1;33mAre you sure you want to uninstall Docker and remove all related files? (y/n)\033[0m"
    read -r response
    if [[ "$response" == "y" || "$response" == "yes" ]]; then
        echo -e "\033[1;31mUninstalling Docker Engine and related packages...\033[0m"
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
        
        echo -e "\033[1;31mRemoving Docker data directories...\033[0m"
        sudo rm -rf /var/lib/docker
        sudo rm -rf /var/lib/containerd

        echo -e "\033[1;31mRemoving Docker source list and keyrings...\033[0m"
        sudo rm -f /etc/apt/sources.list.d/docker.list
        sudo rm -f /etc/apt/keyrings/docker.asc

        echo -e "\033[1;32mDocker has been completely removed from the system.\033[0m"
    else
        echo -e "\033[1;33mUninstallation canceled.\033[0m"
    fi
}

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
        installed_version=$(docker-compose --version)
        echo_green "Docker Compose is already installed. Current version: $installed_version"

        # Fetch the latest version of Docker Compose
        latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r '.tag_name')

        # Check if fetching the latest version was successful
        if [ -z "$latest_version" ]; then
            echo_red "Failed to fetch the latest Docker Compose version."
            return 1
        fi

        # Compare the installed version with the latest version
        if [ "$installed_version" != "$latest_version" ]; then
            echo_yellow "last version of Docker Compose is: $latest_version"

            # Ask if the user wants to update
            read -p "Do you want to update Docker Compose to $latest_version? (yes/no) [default: yes]: " update_choice
            update_choice=${update_choice:-yes}  # Default to "no" if empty

            if [[ "$update_choice" == "yes" ]]; then
                echo_yellow "Updating Docker Compose to version $latest_version..."

                # Download the latest Docker Compose binary to /usr/local/bin
                sudo curl -L "https://github.com/docker/compose/releases/download/$latest_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

                # Check if the download was successful
                if [ $? -ne 0 ]; then
                    echo_red "Failed to download Docker Compose."
                    return 1
                fi

                # Make the Docker Compose binary executable
                sudo chmod +x /usr/local/bin/docker-compose

                # Verify the update
                if ! docker-compose --version &> /dev/null; then
                    echo_red "Failed to update Docker Compose."
                    return 1
                fi

                echo_green "Docker Compose updated successfully to version $latest_version."
            else
                echo_blue "Skipping Docker Compose update."
            fi
        else
            # No update available, no need to ask
            echo_green "You are already using the latest version of Docker Compose ($installed_version)."
        fi
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
	sudo apt install -y software-properties-common

    echo_yellow "Upgrading installed packages..."
    sudo apt-get upgrade -y
 
}

install_packages() {
    # Color definitions
    local GREEN='\033[1;32m'
    local RED='\033[1;31m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[1;34m'
    local NC='\033[0m' # No Color
    
    # Helper functions for colored output
    echo_color() { echo -e "${1}${2}${NC}"; }
    echo_green() { echo_color "$GREEN" "$1"; }
    echo_red() { echo_color "$RED" "$1"; }
    echo_yellow() { echo_color "$YELLOW" "$1"; }
    echo_blue() { echo_color "$BLUE" "$1"; }

    echo_green "Advanced Package Installation Manager"
    echo "=========================================="

    # Update the package list first
    echo_yellow "Updating package list..."
    sudo apt-get update

    # Comprehensive package list with descriptions
    declare -A packages=(
        ["curl"]="Command line tool for transferring data with URL syntax"
        ["socat"]="Multipurpose relay tool for bidirectional data transfer"
        ["nano"]="Small, friendly text editor inspired by Pico"
        ["cron"]="Time-based job scheduler"
        ["dos2unix"]="Text file format converter"
        ["git"]="Distributed version control system"
        ["wget"]="Non-interactive network downloader"
        ["net-tools"]="Network administration tools (ifconfig, netstat, etc.)"
        ["iputils-ping"]="Tools to test network connectivity"
        ["traceroute"]="Tool to track the route packets take"
        ["jq"]="Lightweight and flexible command-line JSON processor"
        ["rsync"]="Fast, versatile, remote (and local) file-copying tool"
        ["build-essential"]="Informational list of build-essential packages"
        ["docker.io"]="Docker container runtime"
        ["docker-compose"]="Tool for defining and running multi-container Docker applications"
        ["btop"]="Resource monitor that shows usage and stats"
        ["htop"]="Interactive process viewer"
        ["ufw"]="Uncomplicated firewall"
        ["zip"]="Package and compress (archive) files"
        ["unzip"]="Extract compressed files in a ZIP archive"
        ["tar"]="Tape archiving program"
        ["tmux"]="Terminal multiplexer"
        ["ncdu"]="Disk usage analyzer with an ncurses interface"
        ["tree"]="Display directory tree structure"
        ["apt-transport-https"]="HTTPS transport for APT"
        ["ca-certificates"]="Common CA certificates"
        ["gnupg"]="GNU privacy guard - a free PGP replacement"
        ["software-properties-common"]="Software properties common files"
        ["python3"]="Python programming language"
        ["python3-pip"]="Python package installer"
        ["vim"]="Vi IMproved - enhanced vi editor"
    )

    # Default selections (true/false)
    declare -A selected=(
        ["curl"]=true
        ["git"]=true
        ["wget"]=true
        ["nano"]=true
        ["ufw"]=true
        ["zip"]=true
        ["unzip"]=true
        ["tar"]=true
        ["docker.io"]=false
        ["docker-compose"]=false
        ["build-essential"]=false
        ["socat"]=false
        ["cron"]=true
        ["dos2unix"]=true
        ["net-tools"]=false
        ["iputils-ping"]=false
        ["traceroute"]=false
        ["jq"]=false
        ["rsync"]=false
        ["btop"]=true
        ["htop"]=true
        ["tmux"]=false
        ["ncdu"]=false
        ["tree"]=false
        ["apt-transport-https"]=false
        ["ca-certificates"]=false
        ["gnupg"]=false
        ["software-properties-common"]=false
        ["python3"]=false
        ["python3-pip"]=false
        ["vim"]=false
    )

    # Create sorted package names array for consistent ordering
    local package_names=($(printf '%s\n' "${!packages[@]}" | sort))

    # Function to display package selection menu
    show_package_menu() {
        clear
        echo_green "Package Selection Menu"
        echo "========================"
        echo "Select packages to install (Numbers to toggle, A=all, N=none, I=install, Q=quit)"
        echo "Examples: '1' or '1,3,5' or '1-5' or '2,7-9,14'"
        echo ""

        for ((i=0; i<${#package_names[@]}; i++)); do
            local package="${package_names[$i]}"
            local status="[ ]"
            [[ "${selected[$package]}" == "true" ]] && status="[x]"
            printf "%2d. %s %-25s - %s\n" "$((i+1))" "$status" "$package" "${packages[$package]}"
        done

        echo ""
        echo_yellow "Selected packages: $(get_selected_count)/${#packages[@]}"
        echo "Commands: [1] [1,3,5] [1-5] [2,7-9,14] [A]ll [N]one [I]nstall [Q]uit"
    }

    # Function to get count of selected packages
    get_selected_count() {
        local count=0
        for package in "${!selected[@]}"; do
            [[ "${selected[$package]}" == "true" ]] && ((count++))
        done
        echo "$count"
    }

    # Function to toggle package selection
    toggle_package() {
        local package_name="$1"
        if [[ "${selected[$package_name]}" == "true" ]]; then
            selected["$package_name"]=false
            echo_yellow "Unselected: $package_name"
        else
            selected["$package_name"]=true
            echo_green "Selected: $package_name"
        fi
    }

    # Function to process number ranges (e.g., 1-5, 2,4,6)
    process_number_input() {
        local input="$1"
        local numbers=()
        
        # Remove spaces and split by comma
        input=$(echo "$input" | tr -d ' ')
        IFS=',' read -ra parts <<< "$input"
        
        for part in "${parts[@]}"; do
            if [[ "$part" =~ ^[0-9]+-[0-9]+$ ]]; then
                # Handle range (e.g., 1-5)
                local start=${part%-*}
                local end=${part#*-}
                for ((i=start; i<=end; i++)); do
                    numbers+=("$i")
                done
            elif [[ "$part" =~ ^[0-9]+$ ]]; then
                # Handle single number
                numbers+=("$part")
            fi
        done
        
        printf '%s\n' "${numbers[@]}"
    }

    # Function to select all packages
    select_all_packages() {
        for package in "${!selected[@]}"; do
            selected["$package"]=true
        done
        echo_green "All packages selected"
    }

    # Function to select no packages
    select_no_packages() {
        for package in "${!selected[@]}"; do
            selected["$package"]=false
        done
        echo_yellow "All packages unselected"
    }

    # Function to get selected packages array
    get_selected_packages() {
        local selected_list=()
        for package in "${!selected[@]}"; do
            [[ "${selected[$package]}" == "true" ]] && selected_list+=("$package")
        done
        printf '%s\n' "${selected_list[@]}"
    }

    # Main menu loop
    while true; do
        show_package_menu
        
        echo ""
        echo -n "Enter your choice default[i]: "
        read -r input
        input=${input:-i}
        
        case "$input" in
            "a"|"A")  # Select all
                select_all_packages

                ;;
            "n"|"N")  # Select none
                select_no_packages

                ;;
            "i"|"I")  # Install
                break
                ;;
            "q"|"Q")  # Quit
                echo_red "Installation cancelled."
                return 1
                ;;
            *)  # Number input (single, multiple, or ranges)
                if [[ -n "$input" ]]; then
                    local numbers=($(process_number_input "$input"))
                    if [ ${#numbers[@]} -eq 0 ]; then
                        echo_red "Invalid input: $input"
                        sleep 2

                    else
                        local valid_selection=false
                        for num in "${numbers[@]}"; do
                            if [ "$num" -ge 1 ] && [ "$num" -le "${#package_names[@]}" ]; then
                                local selected_package="${package_names[$((num-1))]}"
                                toggle_package "$selected_package"
                                valid_selection=true
                            else
                                echo_red "Invalid package number: $num"
                                sleep 2
                            fi
                        done
                        if [ "$valid_selection" = true ]; then
                            
                            sleep 2
                        fi
                    fi
                else
                    echo_red "Please enter a valid option"
                    echo "Press any key to continue..."
                    sleep 2
                fi
                ;;
        esac
    done

    # Get final selected packages
    local packages_to_install=($(get_selected_packages))
    
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo_red "No packages selected for installation."
        return 1
    fi

    # Show final selection and confirm
    clear
    echo_green "Final Package Selection"
    echo "========================"
    echo "The following packages will be installed:"
    for package in "${packages_to_install[@]}"; do
        echo "$package - ${packages[$package]}"
    done
    echo ""
    
read -p "Proceed with installation? (Y/n)  [Y]: " confirm
confirm=${confirm:-y}
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo_red "Installation cancelled."
    return 1
fi

    # Install selected packages with check for existing installation
    echo_green "Installing selected packages..."
    
    for package in "${packages_to_install[@]}"; do
        # Check if package is already installed
        if dpkg -l | grep -q "^ii  $package "; then
            echo_yellow "$package is already installed."
        else
            echo_blue "Installing $package..."
            if sudo apt-get install "$package" -y; then
                echo_green "✓ $package installed successfully"
            else
                echo_red "✗ Failed to install $package"
            fi
        fi
        echo ""
    done

    echo_green "Package installation completed!"
    echo "Processed ${#packages_to_install[@]} packages."




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
run_system_benchmark() {
    while true; do
        echo -e "\n\033[1;34m=========================\033[0m"
        echo -e "\033[1;34m    Speedtest CLI Menu   \033[0m"
        echo -e "\033[1;34m=========================\033[0m"
        echo -e "\033[1;32m1. \033[0mSystem Benchmark + Speed Test"
        echo -e "\033[1;32m2. \033[0mSpeedtest CLI"
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
          
              
              2) curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/speedtest.sh -o speedtest.sh
		sudo bash speedtest.sh   ;;
              
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

    echo -e "\n\033[1;33mListening Ports:\033[0m"
    echo -e ""

    
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
    default_cache_clear_hours="6"
    default_reboot_hour="1"
    default_reboot_days="3"

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
                clear_cache_command="sudo /usr/bin/sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null 2>&1"

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



xui() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m         Select panel\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
	echo -e "\033[1;32m1.\033[0m Sanaei 3x-ui"
    echo -e "\033[1;32m2.\033[0m Alireza x-ui"
    
    echo -e "\033[1;32m3.\033[0m AghayeCoder tx-ui"
    echo -e "\033[1;32m4.\033[0m X-UI command"
    echo -e "\033[1;32m0.\033[0m Return to the main menu"
    
    read -p "Select an option: " option

    case "$option" in
        2) repo="alireza0/x-ui" ;;
        1) repo="mhsanaei/3x-ui" ;;
        3) repo="AghayeCoder/tx-ui" ;;
        4) x-ui; return ;;
        0) return ;;
        *)
            echo -e "\033[1;31mInvalid option. Please choose 1-4.\033[0m"
            return
            ;;
    esac

    echo -e "\033[1;33mSelect installation type:\033[0m"
    echo -e "\033[1;32m1.\033[0m Latest version (default)"
    echo -e "\033[1;32m2.\033[0m Select a specific version"
    
    read -p "Select an option [1]: " install_option
    install_option=${install_option:-1}  # Set default to 1 if empty

    if [[ "$install_option" == "2" ]]; then
        echo -e "\033[1;33mFetching the list of available versions...\033[0m"

        # Fetch latest 30 versions from GitHub API
        versions_file=$(mktemp)
        curl -s "https://api.github.com/repos/$repo/releases?per_page=30" | grep -oP '"tag_name": "\K(.*?)(?=")' > "$versions_file"

        if [ ! -s "$versions_file" ]; then
            echo -e "\033[1;31mFailed to fetch available versions.\033[0m"
            return 1
        fi

        # Display the list of versions
        echo -e "\n\033[1;36mAvailable Versions:\033[0m"
        echo -e "\033[1;34m========================\033[0m"

        cat -n "$versions_file" | while read -r line_number line_content; do
            if (( line_number % 2 == 0 )); then
                echo -e "\033[1;32m$line_number: $line_content\033[0m"
            else
                echo -e "$line_number: $line_content"
            fi
        done

        echo -e "\033[1;34m========================\033[0m\n"

        local version_choice
        read -p "Enter the number of the version you want to install: " version_choice

        local selected_version
        selected_version=$(sed -n "${version_choice}p" "$versions_file")

        if [ -z "$selected_version" ]; then
            echo -e "\033[1;31mInvalid selection. Using latest version instead.\033[0m"
            script="bash <(curl -Ls https://raw.githubusercontent.com/$repo/master/install.sh)"
        else
            script="VERSION=$selected_version && bash <(curl -Ls \"https://raw.githubusercontent.com/$repo/\$VERSION/install.sh\") \$VERSION"
        fi
        
        # Clean up
        rm -f "$versions_file"
    else
        script="bash <(curl -Ls https://raw.githubusercontent.com/$repo/master/install.sh)"
    fi

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
backup_menu() {
    echo -e "\033[1;34mXray Panel Backup Menu:\033[0m"
    
    echo -e "\033[1;32m1.\033[0m Backup by Erfan (Marzban, X-ui, Hiddify, Marzneshin, Custom data)"
    echo -e "\033[1;32m2.\033[0m Backup by AC-Lover (Marzban, X-ui, Hiddify)"
    echo -e "\033[1;32m3.\033[0m Transfer panel data (Marzban, X-UI, Hiddify) to another server"
    echo -e "\033[1;32m0.\033[0m Return to Main Menu"

    read -p "Choose an option [0-3]: " choice

    case $choice in
        1)
            echo -e "\033[1;32mRunning Backup Script 1 (Backuper)...\033[0m"
            curl -Ls https://github.com/erfjab/Backuper/raw/refs/heads/master/backuper.sh -o backuperErfan.sh
            sudo bash backuperErfan.sh
            ;;
        2)
            echo -e "\033[1;32mRunning Backup Script 2 (AC-Lover)...\033[0m"
            curl -Ls https://github.com/AC-Lover/backup/raw/main/backup.sh -o AcLoverBackup.sh
            sudo bash AcLoverBackup.sh
            ;;
        3)
            echo -e "\033[1;32mRunning Script 3 (Transfer-me)...\033[0m"
            curl -Ls https://github.com/iamtheted/transfer-me/raw/main/install.sh -o Transfer-me.sh
            sudo bash Transfer-me.sh
            ;;
        0)
            echo -e "\033[1;32mReturning to the Main Menu...\033[0m"
            main_menu  # Ensure `main_menu` is defined elsewhere in your script
            ;;
        *)
            echo -e "\033[1;31mInvalid option, please choose a valid option [0-3].\033[0m"
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
        cat << 'EOL' > "$compose_file"
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
cf-auto-ip() {
    	echo -e "\033[1;34mSelect an option:\033[0m"
	echo -e "\033[1;32m1.\033[0m Set a listed IP on a subdomain using the Cloudflare API"
	echo -e "\033[1;32m2.\033[0m Set the server's public IP on a subdomain using the Cloudflare API"
	echo -e "\033[1;32m3.\033[0m Set a random IP on a subdomain using the Cloudflare API"
	echo -e "\033[1;31m0.\033[0m Return"
	read -p "Enter your choice): " choice

    case $choice in
        1)
            download_and_start_api
            ;;
        2)
            download_and_start_ip
            ;;
	3)
            download_and_start_random_ip
            ;;
        0)
            echo "Return..."
            main_menu
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
            select_function
            ;;
    esac
}
download_and_start_random_ip() {
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
                echo "Downloading api-random.sh to /root..."
                if curl -o /root/api-random.sh https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/api-random.sh; then
                    chmod +x /root/api-random.sh
                    echo -e "\033[1;32mDownload complete and permissions set.\033[0m"
                else
                    echo -e "\033[1;31mDownload failed. Please try again.\033[0m"
                fi
                ;;
            2)
                existing_folder=$(grep -oP '(?<=CONFIG_FILE="/root/)[^/]*' /root/api-random.sh | head -n 1)

                if [ -z "$existing_folder" ]; then
                    echo -e "\033[1;31mNo folder name found in api-random.sh.\033[0m"
                    continue
                fi
                
                echo "Current folder name is: '$existing_folder'"
                read -p "Enter the new name to replace '$existing_folder' in api-random.sh: " user_name
                
                sed -i "s|/root/${existing_folder}/|/root/${user_name}/|g" /root/api-random.sh
                echo -e "\033[1;32mReplacement complete: '$existing_folder' replaced with '${user_name}' in api-random.sh.\033[0m"
                ;;
            3)
                echo "Starting api-random.sh..."
                if /root/api-random.sh; then
                    echo -e "\033[1;32mapi-random.sh started successfully.\033[0m"
                else
                    echo -e "\033[1;31mFailed to start api-random.sh. Please check for errors.\033[0m"
                fi
                ;;
            4) 
    echo "Setting up cron jobs..."
    
    # Ask for hours to run api-random.sh, default is 3
    read -p "Enter the hours to run api-random.sh (default is 3): " hours
    hours=${hours:-3}  # Default to 3 if no input is provided
    
    # Create or update the cron job
    cron_expression="0 */$hours * * * /root/api-random.sh"
    echo "Adding/overwriting cron job: $cron_expression"
    
    # Overwrite the existing cron job
    (crontab -l 2>/dev/null | grep -v '/root/api-random.sh'; echo "$cron_expression") | crontab -
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
download_and_start_ip() {
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
                echo "Downloading ip.sh to /root..."
                if curl -o /root/ip.sh https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/ip.sh; then
                    chmod +x /root/ip.sh
                    echo -e "\033[1;32mDownload complete and permissions set.\033[0m"
                else
                    echo -e "\033[1;31mDownload failed. Please try again.\033[0m"
                fi
                ;;
            2)
                existing_folder=$(grep -oP '(?<=CONFIG_FILE="/root/)[^/]*' /root/ip.sh | head -n 1)

                if [ -z "$existing_folder" ]; then
                    echo -e "\033[1;31mNo folder name found in ip.sh.\033[0m"
                    continue
                fi
                
                echo "Current folder name is: '$existing_folder'"
                read -p "Enter the new name to replace '$existing_folder' in ip.sh: " user_name
                
                sed -i "s|/root/${existing_folder}/|/root/${user_name}/|g" /root/ip.sh
                echo -e "\033[1;32mReplacement complete: '$existing_folder' replaced with '${user_name}' in ip.sh.\033[0m"
                ;;
            3)
                echo "Starting ip.sh..."
                if /root/ip.sh; then
                    echo -e "\033[1;32mip.sh started successfully.\033[0m"
                else
                    echo -e "\033[1;31mFailed to start ip.sh. Please check for errors.\033[0m"
                fi
                ;;
            4) 
    echo "Setting up cron jobs..."
    
    # Ask for hours to run ip.sh, default is 3
    read -p "Enter the hours to run ip.sh (default is 3): " hours
    hours=${hours:-3}  # Default to 3 if no input is provided
    
    # Create or update the cron job
    cron_expression="0 */$hours * * * /root/ip.sh"
    echo "Adding/overwriting cron job: $cron_expression"
    
    # Overwrite the existing cron job
    (crontab -l 2>/dev/null | grep -v '/root/ip.sh'; echo "$cron_expression") | crontab -
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


manage_ipv6() {
    while true; do
        echo -e "\n\033[1;34mManage IPv6 Configuration:\033[0m"
        echo -e "\033[1;32m1.\033[0m Enable IPv6 (Permanent)"
        echo -e "\033[1;32m2.\033[0m Disable IPv6 (Permanent)"
        echo -e "\033[1;32m3.\033[0m Apply changes"
        echo -e "\033[1;32m4.\033[0m Remove IPv6 rules from /etc/sysctl.conf"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        read -p "Enter your choice: " choice

        case $choice in
            1)
                # Enable IPv6 (Permanent)
                echo -e "\033[1;34mEnabling IPv6 permanently...\033[0m"
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=0

                # Remove existing entries to prevent duplicates
                sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf

                # Append new rules
                echo "net.ipv6.conf.all.disable_ipv6 = 0" | sudo tee -a /etc/sysctl.conf > /dev/null
                echo "net.ipv6.conf.default.disable_ipv6 = 0" | sudo tee -a /etc/sysctl.conf > /dev/null

                echo -e "\033[1;32mIPv6 has been enabled permanently.\033[0m"
                ;;
            2)
                # Disable IPv6 (Permanent)
                echo -e "\033[1;34mDisabling IPv6 permanently...\033[0m"
                sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
                sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1

                # Remove existing entries to prevent duplicates
                sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf

                # Append new rules
                echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null
                echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf > /dev/null

                echo -e "\033[1;32mIPv6 has been disabled permanently.\033[0m"
                ;;
            3)
                # Apply changes
                echo -e "\033[1;34mApplying changes...\033[0m"
                sudo sysctl -p && \
                echo -e "\033[1;32mChanges applied successfully.\033[0m" || \
                echo -e "\033[1;31mFailed to apply changes.\033[0m"
                ;;
            4)
                # Remove IPv6 rules from /etc/sysctl.conf
                echo -e "\033[1;34mRemoving IPv6 rules from /etc/sysctl.conf...\033[0m"
                sudo sed -i '/net.ipv6.conf.all.disable_ipv6/d' /etc/sysctl.conf
                sudo sed -i '/net.ipv6.conf.default.disable_ipv6/d' /etc/sysctl.conf
                echo -e "\033[1;32mIPv6 rules have been removed from /etc/sysctl.conf.\033[0m"
                ;;
            0)
                echo -e "\033[1;33mReturning to the main menu...\033[0m"
                main_menu
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please select 1, 2, 3, 4, or 0.\033[0m"
                ;;
        esac
    done
}

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
PERCENTAGE=100
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





display_system_info() {
    local SERVER_IP
    SERVER_IP=$(timeout 2 curl -4 -s https://icanhazip.com 2>/dev/null)
    
    echo -e "\n\033[1;31mOS info:\033[0m"
    
    # OS info with timeout
    if OS_INFO=$(timeout 2 lsb_release -d 2>/dev/null | cut -f2 2>/dev/null); then
        echo -e "\033[1;32mOS:\033[0m $OS_INFO"
    else
        echo -e "\033[1;32mOS:\033[0m Unknown"
    fi
    
    # ISP and location info with timeout
    if [[ -n "$SERVER_IP" ]]; then
        if GEO_INFO=$(timeout 2 curl -sS "http://ipwhois.app/json/$SERVER_IP" 2>/dev/null); then
            echo -e "\033[1;32mISP:\033[0m $(echo "$GEO_INFO" | jq -r '.isp // "Unknown"')"
            echo -e "\033[1;32mCOUNTRY:\033[0m $(echo "$GEO_INFO" | jq -r '.country // "Unknown"')"
        else
            echo -e "\033[1;32mISP:\033[0m Unknown"
            echo -e "\033[1;32mCOUNTRY:\033[0m Unknown"
        fi
    else
        echo -e "\033[1;32mISP:\033[0m Unknown"
        echo -e "\033[1;32mCOUNTRY:\033[0m Unknown"
    fi
    
    # IPv4 with timeout
    if IPV4=$(timeout 2 curl -4 -s https://icanhazip.com 2>/dev/null); then
        echo -e "\033[1;32mPublic IPv4:\033[0m $IPV4"
    else
        echo -e "\033[1;32mPublic IPv4:\033[0m Unknown"
    fi
    
    # IPv6 with timeout
    if IPV6=$(timeout 2 curl -6 -s https://icanhazip.com 2>/dev/null); then
        echo -e "\033[1;32mPublic IPv6:\033[0m $IPV6"
    else
        echo -e "\033[1;32mPublic IPv6:\033[0m Unknown"
    fi
    
    # Uptime
    if UPTIME=$(timeout 2 uptime -p 2>/dev/null); then
        echo -e "\033[1;32mUptime:\033[0m $UPTIME"
    else
        echo -e "\033[1;32mUptime:\033[0m Unknown"
    fi
    
    # CPU Cores
    if CPU_CORES=$(timeout 2 lscpu 2>/dev/null | grep '^CPU(s):' | awk '{print $2}'); then
        echo -e "\033[1;32mCPU Cores:\033[0m $CPU_CORES"
    else
        echo -e "\033[1;32mCPU Cores:\033[0m Unknown"
    fi
    
    # CPU Frequency
    if CPU_FREQ=$(timeout 2 grep 'MHz' /proc/cpuinfo 2>/dev/null | awk '{print $4 " MHz"}' | head -n 1); then
        echo -e "\033[1;32mCPU Frequency:\033[0m $CPU_FREQ"
    else
        echo -e "\033[1;32mCPU Frequency:\033[0m Unknown"
    fi
    
    # RAM
    if RAM_INFO=$(timeout 2 free -h 2>/dev/null | awk '/^Mem:/ {print $3 "/" $2}'); then
        echo -e "\033[1;32mRAM:\033[0m $RAM_INFO"
    else
        echo -e "\033[1;32mRAM:\033[0m Unknown"
    fi
    
    # Time (local command, no timeout needed)
    echo -e "\033[1;32mTime:\033[0m $(date +"%T %Z")"
    
    # System Status (assuming netspeed is a custom function)
    echo -e "${CYAN}System Status:${NC} $(netspeed)"
}
fix_timezone() {
    sudo timedatectl set-timezone UTC
    echo -e "\033[1;32mTimezone set to UTC.\033[0m"
    read -p "Press Enter to continue..."
}



run_haproxy_script() {
    echo -e "\033[1;34mSelect HAproxy port forwarding mode\033[0m"
    echo -e "\033[1;32m1.\033[0m SNI routing (one listening port to multi port)"
    echo -e "\033[1;32m2.\033[0m port forwarding by Musixal"
    echo -e "\033[1;31m0.\033[0m Return to Main Menu"

    read -p "Enter your choice: " choice
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

isp_blocker() {
    echo -e "\033[1;34mSelect a firewall:\033[0m"
    echo -e "\033[1;32m1.\033[0m UFW (recommended)"
    echo -e "\033[1;32m2.\033[0m IPTables"
    echo -e "\033[1;31m0.\033[0m Return"

    read -p "Enter your choice: " choice
    case $choice in
        1)
            curl -Ls https://raw.githubusercontent.com/Mmdd93/IR-ISP-Blocker/main/ufw-isp-blocker.sh -o ufw-isp-blocker.sh
            sudo bash ufw-isp-blocker.sh
            ;;
        2)
            curl -Ls https://raw.githubusercontent.com/Mmdd93/IR-ISP-Blocker/main/ir-isp-blocker.sh -o ir-isp-blocker.sh
            sudo bash ir-isp-blocker.sh
            ;;
        0)
            echo -e "\033[1;33mReturning to the Main Menu...\033[0m"
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Please select a valid option.\033[0m"
            ;;
    esac
}


# Function to check if netstat is installed, and install if not
check_and_install_netstat() {
    # Function to check and install required tools: netstat and lsof
    for tool in netstat lsof; do
        if ! command -v $tool &> /dev/null; then
            echo -e "\033[1;31m$tool is not installed. Installing...\033[0m"
            # Check for the package manager and install the tool
            if [ -f /etc/debian_version ]; then
                sudo apt update && sudo apt install -y net-tools lsof
            elif [ -f /etc/redhat-release ]; then
                sudo yum install -y net-tools lsof
            else
                echo -e "\033[1;31mUnsupported system. Please install $tool manually.\033[0m"
                exit 1
            fi
            echo -e "\033[1;32m$tool installed successfully.\033[0m"
        else
            echo -e "\033[1;32m$tool is already installed.\033[0m"
        fi
    done
}

# Function to kill the process associated with a selected port
kill_process() {
    read -p "Enter the port number to kill the process: " PORT
    PID=$(sudo lsof -i :$PORT -t)
    if [ -n "$PID" ]; then
        sudo kill -9 $PID
        echo -e "\033[1;32mProcess using port $PORT has been killed.\033[0m"
    else
        echo -e "\033[1;31mNo process found using port $PORT.\033[0m"
    fi
}
show_tcp_udp_count() {
    # Count the number of TCP connections
    tcp_count=$(sudo netstat -ant | wc -l)
    
    # Count the number of UDP connections
    udp_count=$(sudo netstat -anu | wc -l)
    
    # Display the counts, subtracting 2 to exclude the header lines
    echo -e "\033[1;32mTCP Connections:\033[0m $((tcp_count - 2))"
    echo -e "\033[1;32mUDP Connections:\033[0m $((udp_count - 2))"
}


# Function to list in-use ports in a detailed format and allow selection
used_ports_and_select() {

    while true; do
    show_tcp_udp_count
        echo -e "\033[1;34mScanning for in-use ports...\033[0m"
        PORTS=$(sudo ss -tunlp | awk '/LISTEN/ {split($5, a, ":"); print a[length(a)]}' | sort -n | uniq)
        
        if [ -z "$PORTS" ]; then
            echo -e "\033[1;31mNo active ports found.\033[0m"
            exit 1
        fi

        echo -e "\033[1;32mPlease enter a port from the list:\033[0m"
        echo "$PORTS"  # Display the list of available ports
        read -p "Enter port: " PORT

        # Validate the selected port
        if [[ ! "$PORT" =~ ^[0-9]+$ ]] || ! echo "$PORTS" | grep -q "^$PORT$"; then
            echo -e "\033[1;31mInvalid port selection. Please try again.\033[0m"
            continue
        fi

        echo -e "\033[1;32mYou selected port $PORT.\033[0m"
        echo "$PORT" > /tmp/selected_port.txt  # Save selected port to a temporary file

        # Display established connections to the selected port
        echo -e "\033[1;32mEstablished IP Connections to Port $PORT:\033[0m"
        sudo netstat -tan | grep ":$PORT " | grep ESTABLISHED | awk '{print $5}' | cut -d: -f1 | sort | uniq | nl

        read -p "Press Enter to return or 'q' to quit: " user_input
        if [ "$user_input" == "q" ]; then
            echo -e "\033[1;32mReturning...\033[0m"
            return
        fi
    done
}

# Function to show initial menu options with improved echo formatting
initial_menu() {
    while true; do
        # Check if netstat is installed and install if necessary
        check_and_install_netstat

        echo -e "\n\033[1;33mListening Ports:\033[0m"
        echo -e ""

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

        echo -e "\033[1;36m===========================\033[0m"
        echo -e "\033[1;32mSelect an option from the menu below:\033[0m"
        echo -e "\033[1;36m===========================\033[0m"
		echo -e "\033[1;34m1)\033[0m \033[1;33mRefresh\033[0m"
        echo -e "\033[1;34m2)\033[0m \033[1;33mKill process\033[0m"
        echo -e "\033[1;34m3)\033[0m \033[1;33mView established IP connections\033[0m"
        echo -e "\033[1;34m0)\033[0m \033[1;33mReturn\033[0m"
        echo -e "\033[1;36m===========================\033[0m"
        read -p "Your choice: " choice

        case $choice in
            1)
                echo -e "\n\033[1;32mRefresh...\033[0m"
                initial_menu
                ;;

			2)
                echo -e "\n\033[1;32mYou selected to kill a process using a port.\033[0m"
                kill_process
                ;;
            3)
                echo -e "\n\033[1;32mYou selected to view established IP connections.\033[0m"
                used_ports_and_select
                ;;
            0)
                echo -e "\n\033[1;32mReturningu...\033[0m"
                return  # Exit the menu and return to port selection
                ;;
            *)
                echo -e "\n\033[1;31mInvalid choice. Please try again.\033[0m"
                ;;
        esac
    done
}
run_backhaul_script() {
    while true; do
        echo -e "\033[1;36m====Backhaul tunnel Menu====\033[0m"
	echo -e "\033[1;32mTips:! use Backhaul Premium in kharej and Backhaul free in Iran !\033[0m"
        echo -e "\033[1;33m1. Backhaul Free\033[0m"
        echo -e "\033[1;33m2. Backhaul Premium (just free use in kharej server)\033[0m"
        echo -e "\033[1;31m3. Exit\033[0m"
        echo -e "\033[1;36m--------------------------\033[0m"
        read -p "Enter your choice: " choice

        case $choice in
            1)
                echo -e "\033[1;32mDownloading and running Backhaul Free script...\033[0m"
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/backhaul-free.sh -o backhaul-free.sh
                sudo bash backhaul-free.sh
                echo -e "\033[1;32mBackhaul Free script executed successfully.\033[0m"
                ;;
            2)
                echo -e "\033[1;32mDownloading and running Backhaul Premium script...\033[0m"
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/backhaul_premium.sh -o backhaul_premium.sh
                sudo bash backhaul_premium.sh
                echo -e "\033[1;32mBackhaul Premium script executed successfully.\033[0m"
                ;;
            3)
                echo -e "\033[1;31mExiting the Backhaul Script Menu. Goodbye!\033[0m"
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid choice! Please enter a valid option (1-3).\033[0m"
                ;;
        esac

        echo -e "\033[1;36m--------------------------\033[0m"
    done
}

manage_marzban_node() {
    while true; do
    clear
        echo -e "\033[1;34mMarzban Node Management\033[0m"
        echo -e "\033[1;32m1. Install/Reinstall Marzban-node\033[0m"
        echo -e "\033[1;32m2. Start services\033[0m"
        echo -e "\033[1;32m3. Stop services\033[0m"
        echo -e "\033[1;32m4. Restart services\033[0m"
        echo -e "\033[1;32m5. Show status\033[0m"
        echo -e "\033[1;32m6. Show logs\033[0m"
        echo -e "\033[1;32m7. Update to latest version\033[0m"
        echo -e "\033[1;32m8. Uninstall Marzban-node\033[0m"
        echo -e "\033[1;32m9. Install Marzban-node script\033[0m"
        echo -e "\033[1;32m10. Uninstall Marzban-node script\033[0m"
        echo -e "\033[1;32m11. Edit docker-compose.yml\033[0m"
        echo -e "\033[1;32m12. Update/Change Xray core\033[0m"
        echo -e "\033[1;32m0. Exit\033[0m"
        read -rp "Select an option: " choice

        case "$choice" in
            1) sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban-node.sh)" @ install || { echo "Error: Command failed"; continue; } ;;
            2) marzban-node up || { echo "Error: Command failed"; continue; } ;;
            3) marzban-node down || { echo "Error: Command failed"; continue; } ;;
            4) marzban-node restart || { echo "Error: Command failed"; continue; } ;;
            5) marzban-node status || { echo "Error: Command failed"; continue; } ;;
            6) marzban-node logs || { echo "Error: Command failed"; continue; } ;;
            7) marzban-node update || { echo "Error: Command failed"; continue; } ;;
            8) marzban-node uninstall || { echo "Error: Command failed"; continue; } ;;
            9) marzban-node install-script || { echo "Error: Command failed"; continue; } ;;
            10) marzban-node uninstall-script || { echo "Error: Command failed"; continue; } ;;
            11) marzban-node edit || { echo "Error: Command failed"; continue; } ;;
            12) marzban-node core-update || { echo "Error: Command failed"; continue; } ;;
            0) echo "Exiting..."; break ;;
            *) echo -e "\033[1;31mInvalid option!\033[0m"; continue ;;
        esac
        read -rp "Press Enter to continue..."
    done
}


change_timezone() {
    while true; do
        clear
        echo -e "\033[1;34m=== Server Timezone Configuration ===\033[0m"
        echo -e "\033[1;32mCurrent Timezone:\033[0m $(timedatectl | grep "Time zone" | cut -d':' -f2 | xargs)"
        echo -e "\033[1;32mCurrent Time:\033[0m $(date)"
        echo ""
        echo -e "\033[1;36m1. UTC (Default)\033[0m"
        echo -e "\033[1;36m2. Asia/Tehran\033[0m"
        echo -e "\033[1;36m3. America/New_York\033[0m"
        echo -e "\033[1;36m4. Europe/London\033[0m"
        echo -e "\033[1;36m5. Asia/Tokyo\033[0m"
        echo -e "\033[1;36m6. Australia/Sydney\033[0m"
        echo -e "\033[1;36m7. List all available timezones\033[0m"
        echo -e "\033[1;36m8. Enter custom timezone\033[0m"
        echo -e "\033[1;31m0. Return to main menu\033[0m"
        echo ""
        read -p "Select an option [0-8]: " tz_option

        case $tz_option in
            1)
                sudo timedatectl set-timezone UTC
                echo -e "\033[1;32mTimezone set to UTC\033[0m"
                ;;
            2)
                sudo timedatectl set-timezone Asia/Tehran
                echo -e "\033[1;32mTimezone set to Asia/Tehran\033[0m"
                ;;
            3)
                sudo timedatectl set-timezone America/New_York
                echo -e "\033[1;32mTimezone set to America/New_York\033[0m"
                ;;
            4)
                sudo timedatectl set-timezone Europe/London
                echo -e "\033[1;32mTimezone set to Europe/London\033[0m"
                ;;
            5)
                sudo timedatectl set-timezone Asia/Tokyo
                echo -e "\033[1;32mTimezone set to Asia/Tokyo\033[0m"
                ;;
            6)
                sudo timedatectl set-timezone Australia/Sydney
                echo -e "\033[1;32mTimezone set to Australia/Sydney\033[0m"
                ;;
            7)
    echo -e "\033[1;33mAvailable timezones:\033[0m"
    # Create a temporary file with timezones
    TZ_TEMP_FILE=$(mktemp)
    timedatectl list-timezones > "$TZ_TEMP_FILE"
    
    # Display with line numbers and pagination
    less -N -M --prompt="Use arrows to navigate, enter number to select, Q to quit: " "$TZ_TEMP_FILE"
    
    # Get selection
    read -p $'\n\033[1;36mEnter line number of timezone to select (or 0 to cancel): \033[0m' tz_line
    
    if [[ "$tz_line" -gt 0 ]]; then
        selected_tz=$(sed -n "${tz_line}p" "$TZ_TEMP_FILE")
        if [[ -n "$selected_tz" ]]; then
            sudo timedatectl set-timezone "$selected_tz"
            echo -e "\033[1;32mTimezone set to: $selected_tz\033[0m"
        else
            echo -e "\033[1;31mInvalid selection!\033[0m"
        fi
    fi
    
    # Clean up
    rm -f "$TZ_TEMP_FILE"
    ;;
            8)
                read -p "Enter the full timezone (e.g., America/Los_Angeles): " custom_tz
                if timedatectl list-timezones | grep -q "^$custom_tz$"; then
                    sudo timedatectl set-timezone "$custom_tz"
                    echo -e "\033[1;32mTimezone set to $custom_tz\033[0m"
                else
                    echo -e "\033[1;31mInvalid timezone! Use option 7 to see available timezones.\033[0m"
                fi
                ;;
            0)
                echo -e "\033[1;33mReturning to main menu...\033[0m"
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                ;;
        esac

        read -p "Press Enter to continue..."
    done
}
sui() {
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m         S-UI Panel Installation\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    repo="alireza0/s-ui"

    echo -e "\033[1;33mSelect installation type:\033[0m"
    echo -e "\033[1;32m1.\033[0m Latest version (default)"
    echo -e "\033[1;32m2.\033[0m Select a specific version"
    
    read -p "Select an option [1]: " install_option
    install_option=${install_option:-1}  # Set default to 1 if empty

    if [[ "$install_option" == "2" ]]; then
        echo -e "\033[1;33mFetching the list of available versions...\033[0m"

        # Fetch latest 30 versions from GitHub API
        versions_file=$(mktemp)
        curl -s "https://api.github.com/repos/$repo/releases?per_page=30" | grep -oP '"tag_name": "\K(.*?)(?=")' > "$versions_file"

        if [ ! -s "$versions_file" ]; then
            echo -e "\033[1;31mFailed to fetch available versions. Using latest version instead.\033[0m"
            script="bash <(curl -Ls https://raw.githubusercontent.com/$repo/master/install.sh)"
        else
            # Display the list of versions
            echo -e "\n\033[1;36mAvailable Versions:\033[0m"
            echo -e "\033[1;34m========================\033[0m"

            cat -n "$versions_file" | while read -r line_number line_content; do
                if (( line_number % 2 == 0 )); then
                    echo -e "\033[1;32m$line_number: $line_content\033[0m"
                else
                    echo -e "$line_number: $line_content"
                fi
            done

            echo -e "\033[1;34m========================\033[0m\n"

            local version_choice
            read -p "Enter the number of the version you want to install: " version_choice

            local selected_version
            selected_version=$(sed -n "${version_choice}p" "$versions_file")

            if [ -z "$selected_version" ]; then
                echo -e "\033[1;31mInvalid selection. Using latest version instead.\033[0m"
                script="bash <(curl -Ls https://raw.githubusercontent.com/$repo/master/install.sh)"
            else
                script="VERSION=$selected_version && bash <(curl -Ls \"https://raw.githubusercontent.com/$repo/\$VERSION/install.sh\") \$VERSION"
            fi
            
            # Clean up
            rm -f "$versions_file"
        fi
    else
        script="bash <(curl -Ls https://raw.githubusercontent.com/$repo/master/install.sh)"
    fi

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
update() {
    echo -e "${YELLOW}Updating v2ray Assistant scripts...${NC}"
    
    
    # Download the new version
    echo -e "${CYAN}Downloading latest version...${NC}"
    if curl -Lso /usr/bin/v2 https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/node.sh; then
        echo -e "${GREEN}Download successful!${NC}"
        
        # Make it executable
        chmod +x /usr/bin/v2
        
        # Verify the script is valid
        if head -n 5 /usr/bin/v2 | grep -q "bash"; then
            echo -e "${GREEN}Update completed successfully!${NC}"
            echo -e "${YELLOW}Restarting v2ray Assistant...${NC}"
            sleep 2
            exec /usr/bin/v2
        else
            echo -e "${RED}Downloaded file appears to be invalid. Restoring backup.${NC}"
            # Restore from backup if available
            if ls /usr/bin/v2.backup.* 1> /dev/null 2>&1; then
                cp /usr/bin/v2.backup.* /usr/bin/v2
                chmod +x /usr/bin/v2
                echo -e "${YELLOW}Previous version restored.${NC}"
            fi
            return 1
        fi
    else
        echo -e "${RED}Download failed! Check your internet connection.${NC}"
        
        # Restore from backup if available
        if ls /usr/bin/v2.backup.* 1> /dev/null 2>&1; then
            cp /usr/bin/v2.backup.* /usr/bin/v2
            chmod +x /usr/bin/v2
            echo -e "${YELLOW}Previous version restored.${NC}"
        fi
        return 1
    fi
}
# Function to validate IP addresses
validate_ip() {
    local ip=$1
    local stat=1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Function to validate domain names
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to display a confirmation prompt
confirm_action() {
    local prompt=$1
    read -p "$prompt (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Function to display a status message
show_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ ${2}${NC}"
    else
        echo -e "${RED}✗ ${2}${NC}"
    fi
}

#!/bin/bash

# Colors for better visual organization
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
WHITE='\033[1;37m'
ORANGE='\033[1;33m'
PURPLE='\033[1;95m'
LIGHT_BLUE='\033[1;94m'
LIGHT_GREEN='\033[38;5;118m'
LIGHT_CYAN='\033[1;96m'
NC='\033[0m' # No Color

# Header function
header() {
    clear
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${LIGHT_CYAN}      github.com/zZedix/Smite          ${NC}"
    echo -e "${PURPLE}========================================${NC}"
    echo ""
}

Smite() {
    while true; do
        local choice
        local return_code=0
        
        header
        echo -e "${LIGHT_GREEN}[1]${NC} ${YELLOW}Install Docker${NC}"
        echo -e "${LIGHT_GREEN}[2]${NC} ${YELLOW}Install Smite Script${NC}"
        echo -e "${LIGHT_GREEN}[3]${NC} ${YELLOW}Install Smite Node${NC}"
        echo -e "${RED}[0]${NC} ${RED}Exit / Return to shell${NC}"
        echo -e "${CYAN}========================================${NC}"
        
        echo -ne "${MAGENTA}>>${NC} ${WHITE}Enter your choice (${GREEN}0-3${WHITE}): ${NC}"
        read choice
        
        case $choice in
            0)
                echo ""
                echo -e "${BLUE}Exiting Smite installer...${NC}"
                echo -e "${GREEN}Returning to shell...${NC}"
                echo ""
                return 0
                ;;
            1)
                header
                echo ""
				curl -Ls https://raw.githubusercontent.com/manageitir/docker/main/install-ubuntu.sh -o install-ubuntu.sh
                sudo bash install-ubuntu.sh
                return_code=$?
                echo ""
                if [ $return_code -eq 0 ]; then
                    echo -e "${GREEN}[SUCCESS] Ubuntu Docker installation completed!${NC}"
                else
                    echo -e "${RED}[ERROR] Ubuntu Docker installation failed with code: $return_code${NC}"
                fi
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            2)
                header
                echo ""
				curl -Ls https://raw.githubusercontent.com/zZedix/Smite/main/scripts/install.sh -o smite.sh
                sudo bash smite.sh
                return_code=$?
                echo ""
                if [ $return_code -eq 0 ]; then
                    echo -e "${GREEN}[SUCCESS] Smite Script installation completed!${NC}"
                else
                    echo -e "${RED}[ERROR] Smite Script installation failed with code: $return_code${NC}"
                fi
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            3)
                header
                echo ""
				curl -Ls https://raw.githubusercontent.com/zZedix/Smite/main/scripts/smite-node.sh -o smite-node.sh
                sudo bash smite-node.sh
                return_code=$?
                echo ""
                if [ $return_code -eq 0 ]; then
                    echo -e "${GREEN}[SUCCESS] Smite Node installation completed!${NC}"
                else
                    echo -e "${RED}[ERROR] Smite Node installation failed with code: $return_code${NC}"
                fi
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
            *)
                header
                echo -e "${RED}========================================${NC}"
                echo -e "${RED}ERROR: Invalid choice!${NC}"
                echo -e "${YELLOW}Please select 0, 1, 2, or 3.${NC}"
                echo -e "${RED}========================================${NC}"
                echo ""
                echo -e "${YELLOW}Press Enter to continue...${NC}"
                read
                ;;
        esac
    done
}



# Main menu function
main_menu() {
    while true; do
        display_header
        
        # System section - BLUE
		echo -e "${BLUE} SYSTEM MANAGEMENT  ${NC}"
        echo -e "${BLUE}  1.${NC} ${BLUE}Update and upgrade system + install packages${NC}"
        echo -e "${BLUE}  2.${NC} ${BLUE}Fix Update Issues (broken apt/dependencies)${NC}"
        echo -e "${BLUE}  3.${NC} ${BLUE}Change update and package sources to Iran or global${NC}"
        echo -e "${BLUE}  4.${NC} ${BLUE}System Information${NC}"
        echo -e "${BLUE}  5.${NC} ${BLUE}Install Docker and Docker Compose${NC}"
        echo -e "${BLUE}  6.${NC} ${BLUE}Install Docker On Iran Servers${NC}"
		echo -e "${BLUE}  8.${NC} ${BLUE}System and Network Optimizer${NC}"
        echo -e "${BLUE} 72.${NC} ${BLUE}MTU Management${NC}"
		echo -e "${BLUE} 83.${NC} ${BLUE}Disk Cleanup [Advanced]${NC}"
        echo
        
        # Tools section - GREEN
        echo -e "${LIGHT_GREEN} TOOLS  ${NC}"
        echo -e "${LIGHT_GREEN}  7.${NC} ${LIGHT_GREEN}ISP defender (allow/block Iran ISPs)${NC}"
        echo -e "${LIGHT_GREEN}  9.${NC} ${LIGHT_GREEN}Speed test and benchmark${NC}"
        echo -e "${LIGHT_GREEN} 10.${NC} ${LIGHT_GREEN}Port management (in-use ports, connected IPs)${NC}"
        echo -e "${LIGHT_GREEN} 11.${NC} ${LIGHT_GREEN}Auto clear cache and server reboot${NC}"
        echo -e "${LIGHT_GREEN} 12.${NC} ${LIGHT_GREEN}Ping (ICMP) management (enable/disable)${NC}"
        echo -e "${LIGHT_GREEN} 13.${NC} ${LIGHT_GREEN}Change DNS${NC}"
        echo -e "${LIGHT_GREEN} 14.${NC} ${LIGHT_GREEN}Create personal DNS${NC}"
        echo -e "${LIGHT_GREEN} 15.${NC} ${LIGHT_GREEN}SSL certificate management${NC}"
        echo -e "${LIGHT_GREEN} 16.${NC} ${LIGHT_GREEN}SWAP management${NC}"
        echo -e "${LIGHT_GREEN} 17.${NC} ${LIGHT_GREEN}Desktop + Firefox on Ubuntu server${NC}"
        echo -e "${LIGHT_GREEN} 18.${NC} ${LIGHT_GREEN}Server monthly traffic limit${NC}"
        echo -e "${LIGHT_GREEN} 19.${NC} ${LIGHT_GREEN}CPU/RAM monitoring${NC}"
        echo -e "${LIGHT_GREEN} 20.${NC} ${LIGHT_GREEN}Firewall Management + Abuse Defender (UFW)${NC}"
        echo -e "${LIGHT_GREEN} 21.${NC} ${LIGHT_GREEN}Cloudflare auto IP changer${NC}"
        echo -e "${LIGHT_GREEN} 22.${NC} ${LIGHT_GREEN}IP quality checks${NC}"
        echo -e "${LIGHT_GREEN} 23.${NC} ${LIGHT_GREEN}Nginx management${NC}"
        echo -e "${LIGHT_GREEN} 24.${NC} ${LIGHT_GREEN}IPv6 management (enable/disable)${NC}"
        echo -e "${LIGHT_GREEN} 25.${NC} ${LIGHT_GREEN}ZRAM optimization${NC}"
        echo -e "${LIGHT_GREEN} 29.${NC} ${LIGHT_GREEN}Send file to remote server & Telegram${NC}"
        echo -e "${LIGHT_GREEN} 30.${NC} ${LIGHT_GREEN}Auto check URLs${NC}"
        echo -e "${LIGHT_GREEN} 32.${NC} ${LIGHT_GREEN}Change timezone (Fix WhatsApp time)${NC}"
        echo -e "${LIGHT_GREEN} 33.${NC} ${LIGHT_GREEN}Secure SSH (fail2ban)${NC}"
        echo -e "${LIGHT_GREEN} 34.${NC} ${LIGHT_GREEN}Block torrent traffic${NC}"
        echo -e "${LIGHT_GREEN} 35.${NC} ${LIGHT_GREEN}AWS CLI installation${NC}"
        echo -e "${LIGHT_GREEN} 36.${NC} ${LIGHT_GREEN}Cron job management${NC}"
        echo -e "${LIGHT_GREEN} 37.${NC} ${LIGHT_GREEN}File management tools${NC}"
        
		 
        echo
       
        # Tunnel section - CYAN
        echo -e "${CYAN} TUNNEL SERVICES ${NC}"
		echo -e "${RED}Use Local IP instead of public IP for enhanced stealth:${NC}"
        echo -e "${YELLOW}Local Tunnel [SIT-6TO4,GRE,GENEVE,VXLAN,IPIP,ERSPAN]:${NC}"
        echo -e "${CYAN} 26.${NC} ${CYAN}SIT tunnel 6to4 (IPv6 local)             ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 28.${NC} ${CYAN}GRE tunnel (IPv4/IPv6 local)             ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 45.${NC} ${CYAN}GENEVE tunnel (IPv4 local)               ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 46.${NC} ${CYAN}VXLAN tunnel (IPv4 local)                ${WHITE}[github.com/Mmdd93]${NC}"
		echo -e "${CYAN} 85.${NC} ${CYAN}IPIP tunnel (IPv4 local)                ${WHITE}[github.com/Mmdd93]${NC}"
		echo -e "${CYAN} 86.${NC} ${CYAN}ERSPAN tunnel (IPv4 local)                ${WHITE}[github.com/Mmdd93]${NC}"
		echo -e "${YELLOW}Port-Forwarding Tunnel${NC}"
        echo -e "${CYAN} 31.${NC} ${CYAN}HAProxy tunnel                           ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 27.${NC} ${CYAN}Backhaul tunnel                          ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 44.${NC} ${CYAN}GOST tunnel by                           ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 55.${NC} ${CYAN}GOST Reverse tunnel                      ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 47.${NC} ${CYAN}WSS/WS tunnel (CDN support)              ${WHITE}[github.com/Mmdd93]${NC}"
        echo -e "${CYAN} 56.${NC} ${CYAN}WireGuard Reverse Tunnel                 ${WHITE}[github.com/eylandoo]${NC}"
        echo -e "${CYAN} 58.${NC} ${CYAN}WireGuard/Hysteria Tunnel (TAQ-BOSTAN)   ${WHITE}[github.com/ParsaKSH]${NC}"
        echo -e "${CYAN} 61.${NC} ${CYAN}Backhaul premium tunnel cracked          ${WHITE}[t.me/anony_identity]${NC}"
        echo -e "${CYAN} 62.${NC} ${CYAN}Rathole tunnel v2 by                     ${WHITE}[github.com/Musixal]${NC}"
        echo -e "${CYAN} 63.${NC} ${CYAN}Trust Tunnel (TCP/UDP over QUIC)         ${WHITE}[github.com/Erfan-XRay]${NC}"
        echo -e "${CYAN} 64.${NC} ${CYAN}HPulse Tunnel (TCP/UDP over Hysteria 2)  ${WHITE}[github.com/Erfan-XRay]${NC}"
        echo -e "${CYAN} 66.${NC} ${CYAN}DNS Tunnel (tunnel over DNS)             ${WHITE}[github.com/IRSupp]${NC}"
        echo -e "${CYAN} 67.${NC} ${CYAN}FRP Tunnel (Fast Reverse Proxy)          ${WHITE}[github.com/MmdBay]${NC}"
        echo -e "${CYAN} 68.${NC} ${CYAN}Phantom Tunnel (Reverse) by              ${WHITE}[github.com/webwizards-team]${NC}"
        echo -e "${CYAN} 69.${NC} ${CYAN}FRPulse Tunnel (Fast Reverse Proxy)      ${WHITE}[github.com/Erfan-XRay]${NC}" 
        echo -e "${CYAN} 70.${NC} ${CYAN}FRP Tunnel by Mehrad                     ${WHITE}[github.com/mikeesierrah]${NC}" 
        echo -e "${CYAN} 76.${NC} ${CYAN}ZEX Tunnel Waterwall                     ${WHITE}[github.com/izex/ZEX-Tunnel]${NC}"
        echo -e "${CYAN} 79.${NC} ${CYAN}Pingtunnel Manager                       ${WHITE}[github.com/hoseinlolready]${NC}"
		echo -e "${CYAN} 87.${NC} ${CYAN}WSS/WS Reverse tunnel                    ${WHITE}[github.com/snsinfu/reverse-tunnel]${NC}"
		echo -e "${CYAN} 88.${NC} ${CYAN}WSS/WS Reverse tunnel 69learn            ${WHITE}[github.com/69learn/wstunnel]${NC}"
		echo -e "${CYAN} 89.${NC} ${CYAN}SMITE [GOST,Backhaul,Rathole,Chisel,FRP] WEB UI           ${WHITE}[github.com/zZedix/Smite]${NC}"
		echo -e "${CYAN} 90.${NC} ${CYAN}WaterWall Reverse tunnel           ${WHITE}[github.com/Ptechgithub/WaterWall-Docs]${NC}"
		echo -e "${CYAN} 94.${NC} ${CYAN}DNS Tunnel Manager (dnstm)           ${WHITE}[github.com/Net2Share/dnstm]${NC}"
		echo -e "${CYAN} 95.${NC} ${CYAN}VortexL2 L2TPv3 Ethernet Tunnel  ${WHITE}[github.com/iliya-Developer/VortexL2]${NC}"
		echo -e "${CYAN} 96.${NC} ${CYAN}Paqet-Tunnel-Manager  ${WHITE}[github.com/behzadea12/Paqet-Tunnel-Manager]${NC}"
        echo
        # XUI section - MAGENTA
        echo -e "${MAGENTA} XUI ${NC}"
        echo -e "${MAGENTA} 38.${NC} ${MAGENTA}X-UI panels [MHSanaei,alireza,tx-ui] ${GREEN}[Single]${NC}${NC}"
        echo -e "${MAGENTA} 74.${NC} ${MAGENTA}s-ui Sing-box/SagerNet panel [alireza] ${GREEN}[Single]${NC}   ${WHITE}[github.com/alireza0]${NC}"
        echo -e "${MAGENTA} 73.${NC} ${MAGENTA}X-UI panel ${RED}[Multi]${NC}                                ${WHITE}[github.com/azavaxhuman]${NC}"
        echo -e "${MAGENTA} 80.${NC} ${MAGENTA}Hysteria2 Blitz Panel ${GREEN}[Single]${NC}                    ${WHITE}[github.com/ReturnFI]${NC}"
        echo
        
        # Telegram Bot section - WHITE
        echo -e "${WHITE} TELEGRAM BOT ${NC}"
        echo -e "${WHITE} 75.${NC} ${WHITE}Mirza Bot Pro VPN Sale ${RED}[Multi]${NC} ${WHITE}[github.com/mahdiMGF2]${NC}"
        echo -e "${WHITE} 77.${NC} ${WHITE}mtproto proxy (telegram proxy) ${WHITE}[github.com/seriyps]${NC}"
        echo
        
        # Marzban section - LIGHT_BLUE
        echo -e "${LIGHT_BLUE} MARZBAN ${RED}[Multi]${NC}${NC}"
        echo -e "${LIGHT_BLUE} 39.${NC} ${LIGHT_BLUE}Marzban ${NC}"
        echo -e "${LIGHT_BLUE} 40.${NC} ${LIGHT_BLUE}Marzban node by v2${NC}"
        echo -e "${LIGHT_BLUE} 53.${NC} ${LIGHT_BLUE}Marzban node official script${NC}"
        echo -e "${LIGHT_BLUE} 52.${NC} ${LIGHT_BLUE}Marzban node by Mehrdad${NC}"
        echo
        
        # Remnawave section - GREEN
        echo -e "${GREEN} REMNAWAVE ${RED}[Multi]${NC}${NC}"
        echo -e "${GREEN} 48.${NC} ${GREEN}Remnawave ${NC}"
        echo
        
        # Marzneshin section - ORANGE
        echo -e "${ORANGE} MARZNESHIN ${RED}[Multi]${NC}${NC}"
        echo -e "${ORANGE} 49.${NC} ${ORANGE}Marzneshin ${NC}"
        echo -e "${ORANGE} 50.${NC} ${ORANGE}Marzneshin node by ErfJab${NC}"
        echo -e "${ORANGE} 51.${NC} ${ORANGE}Marzneshin node by Mehrdad${NC}"
        echo
        
        # WireGuard/OpenVPN section - LIGHT_CYAN
        echo -e "${LIGHT_CYAN} WIREGUARD-OPENVPN-L2TP-SSTP ${NC}"
        echo -e "${LIGHT_CYAN} 60.${NC} ${LIGHT_CYAN}WireGuard Dashboard ${GREEN}[Single]${NC}  ${WHITE}[github.com/WGDashboard]${NC}"
        echo -e "${LIGHT_CYAN} 54.${NC} ${LIGHT_CYAN}SoftEther RTX-VPN ${GREEN}[Single]${NC}   ${WHITE}[github.com/Sir-MmD]${NC}"
        echo -e "${LIGHT_CYAN} 57.${NC} ${LIGHT_CYAN}OPEN VPN ${RED}[Multi]${NC}            ${WHITE}[github.com/eylandoo]${NC}"
        echo -e "${LIGHT_CYAN} 81.${NC} ${LIGHT_CYAN}OV-Panel ${RED}[Multi]${NC}            ${WHITE}[github.com/primeZdev/ov-panel]${NC}"
        echo -e "${LIGHT_CYAN} 82.${NC} ${LIGHT_CYAN}IranGate-OV ${GREEN}[Single]${NC}        ${WHITE}[github.com/amiridev-org]${NC}"
		echo -e "${LIGHT_CYAN} 84.${NC} ${LIGHT_CYAN}MikroTik (CHR/DOCKER MODE)${NC}    ${WHITE}[github.com/Mmdd93]${NC}"
		echo -e "${LIGHT_CYAN} 91.${NC} ${LIGHT_CYAN}dnstt${NC}    ${WHITE}[github.com/bugfloyd/dnstt-deploy]${NC}"
		echo -e "${LIGHT_CYAN} 92.${NC} ${LIGHT_CYAN}Shahan Panel${NC}    ${WHITE}[github.com/HamedAp/ShahanPanel]${NC}"
		echo -e "${LIGHT_CYAN} 93.${NC} ${LIGHT_CYAN}SlipStream${NC}    ${WHITE}[github.com/mirzaaghazadeh/SlipStreamGUI]${NC}"
        echo
        
        # Panel Backup section - YELLOW
        echo -e "${YELLOW} PANEL BACKUP ${NC}"
        echo -e "${YELLOW} 41.${NC} ${YELLOW}Panel Backup (Marzban, X-UI, Hiddify)${NC}"
        echo -e "${YELLOW} 42.${NC} ${YELLOW}Auto panel restart${NC}"
        echo
        
        # Monitoring section - WHITE
        echo -e "${WHITE} MONITORING ${NC}"
        echo -e "${WHITE} 59.${NC} ${WHITE}Uptime Kuma monitoring${NC}"
        echo
        
        # Footer section
        echo -e "${BLUE} 00.${NC} ${BLUE}Update scripts${NC}"
        echo -e "${BLUE}  0.${NC} ${BLUE}Exit${NC}"
		echo
        echo -e " $(netspeed)"
		echo
        read -p "$(echo -e ${GREEN}"Enter your choice: "${NC})" choice
		
		



        case $choice in
            1) 
                echo -e "${YELLOW}Updating system and installing packages...${NC}"
                update_system
                install_packages 
                ;;
            3) 
				curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/change_sources.sh -o change_sources.sh
                sudo bash change_sources.sh

                ;;
            2) 
				curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/update_issues.sh -o update_issues.sh
                sudo bash update_issues.sh
                ;;
            4) display_system_info ;;
            5) docker_install_menu ;;
            6) 
                echo -e "${YELLOW}Installing Docker on Iran servers...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/Docker.sh -o Docker.sh
                sudo bash Docker.sh 
                show_status "Docker installation completed"
                ;;
            7) isp_blocker ;;
            8) 
                echo -e "${YELLOW}Running network optimization...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/optimizations.sh -o optimizations.sh
                sudo bash optimizations.sh 
                ;;
            9) run_system_benchmark ;;
            10) initial_menu ;;
            11) setup_cache_and_reboot ;;
            12) manage_ping ;;
            13) 
                echo -e "${YELLOW}Changing DNS settings...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/ChangeDNS.sh -o ChangeDNS.sh
                sudo bash ChangeDNS.sh 
                ;;
            14) 
                echo -e "${YELLOW}Creating personal DNS...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/snidust.sh -o snidust.sh
                sudo bash snidust.sh 
                ;;
            15) 
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/ssl.sh -o ssl.sh
                sudo bash ssl.sh 
                ;;
            16) swap ;;
            17) webtop ;;
            18) traffic ;;
            19) usage ;;
            20) 
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/ufw.sh -o ufw.sh
                sudo bash ufw.sh 
                ;;
            21) cf-auto-ip ;;
            22) ip_quality_check ;;
            23) 
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/nginx.sh -o nginx.sh
                sudo bash nginx.sh 
                ;;
            24) manage_ipv6 ;;
            25) manage_zram ;;
            26) 
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/6to4-service-method.sh -o 6to4-service-method.sh
                sudo bash 6to4-service-method.sh 
                ;;
            27) run_backhaul_script ;;
            28) 
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/gre-service-method.sh -o gre-service-method.sh
                sudo bash gre-service-method.sh 
                ;;
            29) download_and_run_ssh_assistance ;;
            30) 
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/setup_URLs_check.sh -o setup_URLs_check.sh
                sudo bash setup_URLs_check.sh 
                ;;
            31) 
                echo -e "${YELLOW}Setting up HAProxy tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/HAproxy.sh -o HAproxy.sh
                sudo bash HAproxy.sh
                ;;
            32) 
                change_timezone
                sleep 2 
                ;;
            33) 
                echo -e "${YELLOW}Installing fail2ban for SSH security...${NC}"
                curl -fsSL https://raw.githubusercontent.com/MrAminiDev/NetOptix/main/scripts/fail2ban.sh -o /tmp/fail2ban.sh
                bash /tmp/fail2ban.sh
                rm /tmp/fail2ban.sh
                show_status "fail2ban installation completed"
                ;;
            34) 
                echo -e "${YELLOW}Blocking torrent traffic...${NC}"
                curl -fsSL https://raw.githubusercontent.com/MrAminiDev/NetOptix/main/scripts/blocktorrent/blocktorrent.sh -o /tmp/blocktorrent.sh
                bash /tmp/blocktorrent.sh
                rm /tmp/blocktorrent.sh
                show_status "Torrent blocking completed"
                ;;
            35) 
                echo -e "${YELLOW}Installing AWS CLI...${NC}"
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/main/aws-cli.sh -o aws-cli.sh
                sudo bash aws-cli.sh 
                ;;
            36) 
                echo -e "${YELLOW}Managing cron jobs...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/cron.sh -o cron.sh
                sudo bash cron.sh 
                ;;
            37) 
                echo -e "${YELLOW}File management tools...${NC}"
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/file_management.sh -o file_management.sh
                sudo bash file_management.sh 
                ;;
            38) xui ;;
            39) 
                echo -e "${YELLOW}Installing Marzban panel...${NC}"
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/marzban.sh -o marzban.sh
                sudo bash marzban.sh 
                ;;
            40) 
                echo -e "${YELLOW}Installing Marzban node by v2...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/marzban-node-v2.sh -o marzban-node-v2.sh
                sudo bash marzban-node-v2.sh 
                ;;
            41) backup_menu ;;
            42) panels_restart_cron ;;
            44) 
                echo -e "${YELLOW}Setting up GOST tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/gost.sh -o gost.sh
                sudo bash gost.sh 
                ;;
            45) 
                echo -e "${YELLOW}Setting up GENEVE tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/geneve-service-method.sh -o geneve-service-method.sh
                sudo bash geneve-service-method.sh 
                ;;
            46) 
                echo -e "${YELLOW}Setting up VXLAN tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/vxlan-service-method.sh -o vxlan-service-method.sh
                sudo bash vxlan-service-method.sh 
                ;;
            47) 
                echo -e "${YELLOW}Setting up WSS/WS tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/wstunnel.sh -o wstunnel.sh
                sudo bash wstunnel.sh 
                ;;
            48) 
                echo -e "${YELLOW}Installing Remnawave...${NC}"
                curl -Ls https://raw.githubusercontent.com/AsanFillter/Remnawave-AutoSetup/main/start.sh -o Remnawave.sh
                sudo bash Remnawave.sh 
                ;;
            49) 
                echo -e "${YELLOW}Installing Marzneshin...${NC}"
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/marzneshin.sh -o marzneshin.sh
                sudo bash marzneshin.sh 
                ;;
            50) 
                echo -e "${YELLOW}Installing Marzneshin node by ErfJab...${NC}"
                curl -Ls https://raw.githubusercontent.com/erfjab/marznode/main/install.sh -o marznode1.sh
                sudo bash marznode1.sh 
                ;;
            51) 
                echo -e "${YELLOW}Installing Marzneshin node by Mehrdad...${NC}"
                curl -Ls https://raw.githubusercontent.com/mikeesierrah/ez-node/main/marznode.sh -o marznode2.sh
                sudo bash marznode2.sh 
                ;;
            52) 
                echo -e "${YELLOW}Installing Marzban node by Mehrdad...${NC}"
                curl -Ls https://raw.githubusercontent.com/mikeesierrah/ez-node/main/marzban-node.sh -o marzban-node.sh
                sudo bash marzban-node.sh 
                ;;
            53) manage_marzban_node ;;
            54) 
                echo -e "${YELLOW}Installing SoftEther by RTX-VPN v2...${NC}"
                curl -Ls https://raw.githubusercontent.com/Sir-MmD/RTX-VPN/v2/rtxvpn_v2.sh -o rtxvpn_v2.sh
                sudo bash rtxvpn_v2.sh 
                ;;
            55) 
                echo -e "${YELLOW}Setting up GOST Reverse tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/Reverse-gost.sh -o Reverse-gost.sh
                sudo bash Reverse-gost.sh 
                ;;
            56) 
                echo -e "${YELLOW}Setting up WireGuard Reverse Tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/eylandoo/openvpn_webpanel_manager/main/wg-tunnel-manager.sh -o wg-tunnel-manager.sh
                sudo bash wg-tunnel-manager.sh 
                ;;
            57) 
                echo -e "${YELLOW}Setting up OpenVPN Webpanel...${NC}"
                curl -Ls https://raw.githubusercontent.com/eylandoo/openvpn_webpanel_manager/main/vpn_manager.sh -o openvpn_webpanel_manager.sh
                sudo bash openvpn_webpanel_manager.sh 
                ;;
            58) 
                echo -e "${YELLOW}Setting up Hysteria Tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/ParsaKSH/TAQ-BOSTAN/main/script.sh -o hysteria_tunnel.sh
                sudo bash hysteria_tunnel.sh 
                ;;
            59) 
                echo -e "${YELLOW}Installing Uptime Kuma...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/UptimeKuma.sh -o UptimeKuma.sh
                sudo bash UptimeKuma.sh 
                ;;
            60) 
                echo -e "${YELLOW}Installing WGDashboard...${NC}"
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/main/WGDashboard.sh -o WGDashboard.sh
                sudo bash WGDashboard.sh 
                ;;
            61) 
                echo -e "${YELLOW}Setting up Backhaul premium tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/wafflenoodle/zenith-stash/refs/heads/main/backhaul.sh -o backhaul-cracked.sh
                sudo bash backhaul-cracked.sh 
                ;;
            62) 
                echo -e "${YELLOW}Setting up Rathole tunnel v2...${NC}"
                curl -Ls https://raw.githubusercontent.com/Musixal/Rathole-Tunnel/refs/heads/main/rathole_v2.sh -o rathole_v2.sh
                sudo bash rathole_v2.sh 
                ;;
            63) 
                echo -e "${YELLOW}Setting up Trust Tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Erfan-XRay/TrustTunnel/main/main.sh -o TrustTunnel.sh
                sudo bash TrustTunnel.sh 
                ;;
            64) 
                echo -e "${YELLOW}Setting up HPulse Tunnel...${NC}"
                curl -Ls https://raw.githubusercontent.com/Erfan-XRay/HPulse/main/HPulse.sh -o HPulse.sh
                sudo bash HPulse.sh 
                ;;
            65) 
                echo -e "${YELLOW}Running DigitalVPS Toolbox...${NC}"
                curl -Ls https://github.com/Digitalvps-Ir/Digitalvps-Toolbox/blob/main/toolbox.sh -o toolbox.sh
                sudo bash toolbox.sh
                ;;
            66) 
                echo -e "${YELLOW}Setting up DNS Tunnel...${NC}"
                curl -Ls https://github.com/IRSupp/DnsTunnel/raw/main/Irsupp-DnsTunnel.sh -o Irsupp-DnsTunnel.sh
                sudo bash Irsupp-DnsTunnel.sh 
                ;;
            67) 
                echo -e "${YELLOW}Setting up FRP Tunnel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/mmdbay/frp-manager/main/frp.sh -o frp.sh
                sudo bash frp.sh 
                ;;
            68) 
                echo -e "${YELLOW}Setting up Phantom Tunnel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/webwizards-team/Phantom-Tunnel/main/install.sh -o Phantom-Tunnel.sh
                sudo bash Phantom-Tunnel.sh && phantom 
                ;;
            69) 
                echo -e "${YELLOW}Setting up FRPulse Tunnel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/Erfan-XRay/FRPulse/main/FRPulse.sh -o FRPulse.sh
                sudo bash FRPulse.sh 
                ;;
            70) 
                echo -e "${YELLOW}Setting up FRP Tunnel by Mehrad...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/mikeesierrah/frp-script/main/frp-setup.sh -o frp-setup.sh
                sudo bash frp-setup.sh 
                ;;
            71) 
                echo -e "${YELLOW}Running Abuse Defender...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/Mmdd93/Abuse-Defender/refs/heads/main/abuse-defender.sh -o abuse-defender.sh
                sudo bash abuse-defender.sh 
                ;;
            72) 
                echo -e "${YELLOW}Managing MTU settings...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/mtu.sh -o mtu.sh
                sudo bash mtu.sh 
                ;;
			73) 
                echo -e "${YELLOW}Running Nodex...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/azavaxhuman/Nodex/refs/heads/main/main.sh -o Nodex.sh
                sudo bash Nodex.sh 
                ;;
			74) 
   				echo -e "${YELLOW}Running sui...${NC}"
				sleep 1
                sui ;;
			75) 
                echo -e "${YELLOW}Running mirza.sh...${NC}"
                curl -Ls https://github.com/Mmdd93/mirza_pro/raw/refs/heads/main/install.sh -o mirza.sh
                sudo bash mirza.sh 
                ;;
			76) 
                echo -e "${YELLOW}Running ZEX-Tunnel...${NC}"
                git clone https://github.com/izex/ZEX-Tunnel.git
				cd ZEX-Tunnel
				chmod +x *
				sudo bash zex-tunnel-install.sh
                ;;
			77) 
                echo -e "${YELLOW}Running mtp_install.sh...${NC}"
                curl -L -o mtp_install.sh https://git.io/fj5ru && bash mtp_install.sh
                ;;
			78) 
                echo -e "${YELLOW}Running ovpn-admin...${NC}"
                git clone https://github.com/palark/ovpn-admin.git
				cd ovpn-admin
				./start.sh
				;;
			79)
                echo -e "${YELLOW}Running Pingtunnel Manager...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/hoseinlolready/Pingtunnel_manager/refs/heads/main/Source/bash.sh -o Pingtunnel_manager.sh
                sudo bash Pingtunnel_manager.sh
                ;;
            80)
                echo -e "${YELLOW}Running Blitz Panel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/ReturnFI/Blitz/main/install.sh -o Blitz.sh
                sudo bash Blitz.sh
                ;;
			81)
                echo -e "${YELLOW}Running OV-Panel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/primeZdev/ov-panel/refs/heads/main/install.sh -o OV-Panel.sh
                sudo bash OV-Panel.sh
                ;;
			82)
                echo -e "${YELLOW}Running OV-Panel...${NC}"
				sleep 1
				git clone https://github.com/AmiriDev-ORG/IranGate-OV.git
                curl -Ls https://raw.githubusercontent.com/AmiriDev-ORG/IranGate-OV/refs/heads/CyrusTheGreat/install.sh -o IranGate-OV.sh
                sudo bash IranGate-OV.sh
                ;;
			83)
                echo -e "${YELLOW}Cleanup...${NC}"
				sleep 1
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/Cleanup.sh -o Cleanup.sh
                sudo bash Cleanup.sh
                ;;
			84)
                echo -e "${YELLOW}MikroTik...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/MikroTik.sh -o MikroTik.sh
                sudo bash MikroTik.sh
                ;;
			85)
                echo -e "${YELLOW}ipip.sh...${NC}"
				sleep 1
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/ipip.sh -o ipip.sh
                sudo bash ipip.sh
                ;;
			86)
                echo -e "${YELLOW}erspan.sh...${NC}"
				sleep 1
                curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/erspan.sh -o erspan.sh
                sudo bash erspan.sh
                ;;
			87)
                echo -e "${YELLOW}erebe wstunnel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/wss-revers.sh -o wss-revers.sh
                sudo bash wss-revers.sh
                ;;
			88)
                echo -e "${YELLOW}69learn Websocket Tunnel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/69learn/wstunnel/main/wstunnel.sh -o ws-reverse-69learn.sh
                sudo bash ws-reverse-69learn.sh
                ;;
			89)
                echo -e "${YELLOW}Smite Tunnel...${NC}"
				sleep 1
                Smite
                ;;
			90)
                echo -e "${YELLOW}WaterWall Tunnel...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/Ptechgithub/WaterWall-Docs/main/install.sh -o WaterWall.sh
                sudo bash WaterWall.sh
                ;;
			91)
                echo -e "${YELLOW}dnstt-deploy.sh...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/bugfloyd/dnstt-deploy/main/dnstt-deploy.sh -o dnstt-deploy.sh
                sudo bash dnstt-deploy.sh
                ;;
			92)
                echo -e "${YELLOW}shahan.sh...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/HamedAp/Ssh-User-management/master/install.sh -o shahan.sh
                sudo bash shahan.sh
                ;;
			93)
                echo -e "${YELLOW}slipstream-rust...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/AliRezaBeigy/slipstream-rust-deploy/master/slipstream-rust-deploy.sh -o slipstream-rust-deploy.sh
                sudo bash slipstream-rust-deploy.sh
                ;;
				94)
                echo -e "${YELLOW}DNS Tunnel Manager (dnstm)...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/net2share/dnstm/main/install.sh -o dnstm.sh
                sudo bash dnstm.sh
                ;;
			95)
                echo -e "${YELLOW} VortexL2 L2TPv3 Ethernet Tunnel Manager...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/iliya-Developer/VortexL2/main/install.sh -o VortexL2.sh
                sudo bash VortexL2.sh
				sudo vortexl2
                ;;
			96)
                echo -e "${YELLOW} Paqet-Tunnel-Manager...${NC}"
				sleep 1
                curl -Ls https://raw.githubusercontent.com/behzadea12/Paqet-Tunnel-Manager/main/paqet-manager.sh -o paqet-manager.sh
                sudo bash paqet-manager.sh
                ;;
            00) 
                echo -e "${YELLOW}Updating scripts...${NC}"
                update 
                ;;
            0) 
                echo -e "${GREEN}Exiting... Thank you for using v2ray Assistant!${NC}"
                exit 0
                ;;
            *) 
                echo -e "${RED}Invalid choice. Please try again.${NC}"
                sleep 2
                ;;
        esac
        
        echo ""
        read -p "$(echo -e ${GREEN}"Press Enter to continue..."${NC})" dummy
    done
}

netspeed() {
    local iface rx1 tx1 rx2 tx2 rx_speed tx_speed
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
    disk=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    
    # Get network interface
    iface=$(ip route | grep default | awk '{print $5}')
    if [ -z "$iface" ]; then
        echo "CPU: ${cpu}% | RAM: ${mem}% | DISK: ${disk}% | NET: No interface"
        return 1
    fi
    
    # First measurement - ADD COLON to interface name
    rx1=$(grep "$iface:" /proc/net/dev | awk '{print $2}')
    tx1=$(grep "$iface:" /proc/net/dev | awk '{print $10}')
    
    # Wait 1 second
    sleep 1
    
    # Second measurement - ADD COLON to interface name
    rx2=$(grep "$iface:" /proc/net/dev | awk '{print $2}')
    tx2=$(grep "$iface:" /proc/net/dev | awk '{print $10}')
    
    # Calculate speeds
    rx_speed=$(echo "scale=1; ($rx2 - $rx1) / 1048576" | bc 2>/dev/null || echo "0")
    tx_speed=$(echo "scale=1; ($tx2 - $tx1) / 1048576" | bc 2>/dev/null || echo "0")
    
   echo -e "${GREEN}CPU: ${cpu}%${NC} ${YELLOW}RAM: ${mem}%${NC} ${RED}DISK: ${disk}%${NC} ${CYAN}NET: ↓${rx_speed}MB/s ↑${tx_speed}MB/s${NC}"
}
# Start the main menu
display_header() {
    clear
    echo -e "${BLUE}github.com/Mmdd93/v2ray-assistance${NC}"
    echo -e "${YELLOW}Telegram: @tlgrmv2 | Version: 25.11.24${NC}"
	echo
}
main_menu


