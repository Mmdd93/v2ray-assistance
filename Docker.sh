#!/bin/bash
# Color codes
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

setup_docker() {
    while true; do
	echo -e "\033[1;34mSelect an option:\033[0m"
	echo "1. Auto-install (irDocker script)"
	echo "2. Set DNS to Electro or Shecan, etc..."
	echo "3. Change Update sources to Iran"
	echo "4. Auto-install step-by-step (official Docker)"
	echo "0. Main menu"

        read -p "Enter your choice: " choice
        
        case $choice in
            1)
	    echo "Running ..."
            curl -Ls https://raw.githubusercontent.com/AlefbeMedia/irDocker/main/install.sh -o irDocker.sh
            sudo bash irDocker.sh ;;
            2)
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
	3)
                echo -e "\033[1;34mCurrent sources.list:\033[0m"
if grep -q '^deb ' /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
    cat /etc/apt/sources.list 2>/dev/null
    if [ -d /etc/apt/sources.list.d/ ] && ls /etc/apt/sources.list.d/*.list &>/dev/null; then
        cat /etc/apt/sources.list.d/*.list 2>/dev/null
    fi
    echo -e "\033[1;32m✔ Sources list found.\033[0m"
else
    echo -e "\033[1;31m✘ No sources found!\033[0m"
fi

# Ask if they want to change update sources
read -p "Do you want to change update sources to Iran? (yes/no): " change_sources_answer
if [[ "$change_sources_answer" == "yes" ]]; then
    change_sources_list  # Call the function to change sources
else
    echo -e "\033[1;34mNo update sources change requested.\033[0m"
fi

                ;;

            4)
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
                    echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


                    # Update apt package index again
                    echo -e "\033[1;32m7. Updating apt package index...\033[0m"
                    sudo apt-get update

                    # Install Docker and related components
                    echo -e "\033[1;32m8. Installing Docker CE, CLI, and related plugins...\033[0m"
                    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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

setup_docker