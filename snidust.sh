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


    echo -e "\033[1;32m1. \033[0m \033[1;37mDefault [Your IP: $default_ip]\033[0m"
    echo -e "\033[1;32m2. \033[0m \033[1;37mUse 0.0.0.0/0 for all clients\033[0m"
    echo -e "\033[1;32m3. \033[0m \033[1;37mEnter allowed clients (comma-separated) [Default: $default_ip]\033[0m"
    echo -e "\033[1;32m4. \033[0m \033[1;37mLoad allowed clients from /root/allowed.txt\033[0m"

    echo -e "\033[1;36m--------------------------------------------\033[0m"
    read -p "$(echo -e "\033[1;33mEnter allowed clients [defualt: all clients]: \033[0m")" option

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
                echo -e "\033[1;31mFile /root/allowed.txt not found. Defaulting to : $default_ip.\033[0m"
                ALLOWED_CLIENTS="$default_ip"
            fi
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Defaulting to all clients: "0.0.0.0/0"\033[0m"
            ALLOWED_CLIENTS="0.0.0.0/0"
            ;;
    esac

    echo -e "\033[1;32mAllowed clients set to: $ALLOWED_CLIENTS\033[0m"
}

    # Call select_allowed_clients to determine allowed clients
    select_allowed_clients

    # Prompt for external IP, with a method to find public IP
    echo -e "\033[1;33mEnter your server IP: [$(curl -4 -s https://icanhazip.com)]:\033[0m"
    read -p " > " external_ip
    external_ip=${external_ip:-$(curl -4 -s https://icanhazip.com)} # Use public IP as default

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
echo -e "\033[1;33mDo you want to use custom RAM and swap? (yes/no) [no]:\033[0m"
read -p " > " custom_ram_swap

if [[ "$custom_ram_swap" == "yes" ]]; then
    read -p $'\033[1;33mEnter RAM size (e.g., 512m, 1g) [defualt: 512m]: \033[0m' ram_size
    read -p $'\033[1;33mEnter swap size (e.g., 512m, 2g) [defualt: 512m]: \033[0m' swap_size
    ram_size=${ram_size:-512m}
    swap_size=${swap_size:-512m}
    memory_flags="--memory=\"$ram_size\" --memory-swap=\"$swap_size\""
else
    memory_flags=""
fi

echo -e "\033[1;33mDo you want to enable DOT (DNS over TLS)? (yes/no) [no]:\033[0m"
read -p " > " enable_dot

if [[ "$enable_dot" == "yes" ]]; then
    ENABLE_DOT="true"
    enable_dot="-e DNSDIST_ENABLE_DOT=\"$ENABLE_DOT\" -e DNSDIST_DOT_CERT_TYPE=\"auto-self\""
else
    enable_dot=""
fi

# Prepare the Docker command
docker_command="docker run -d \
    --name \"$container_name\" \
    -e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\" \
    -e EXTERNAL_IP=\"$external_ip\" \
    -e SPOOF_ALL_DOMAINS=\"$spoof_domains\" \
    $enable_dot \
    -p 443:8443 \
    -p 80:8080 \
    -p 53:5300/udp \
    -p 53:5300/tcp \
    $custom_domains \
    --log-driver=none \
    $memory_flags \
    ghcr.io/seji64/snidust:1.0.15"

echo -e "\033[1;32mRunning Docker with the following command:\033[0m"
echo "$docker_command"

# Execute the command
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