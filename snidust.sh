#!/bin/bash
clear
# Function to check if specific ports are busy (TCP only)
check_ports() {
    echo -e "\033[1;36m==========Check Ports Status===========\033[0m"


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
clear
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
    echo -e "\033[1;36m==========Create Your Custom DNS (snidust)========\033[0m"

    # Check if the container is already running
    container_name="snidust"
    if [ "$(docker ps -q -f name="$container_name")" ]; then
        echo -e "\033[1;31mDocker container '$container_name' is already running.\033[0m"
        echo -e "\033[1;33mPlease stop and remove the existing container before creating a new one.\033[0m"
        manage_container
    fi
      echo -e "\033[1;33mStarting Create Your Custom DNS (snidust)\033[0m"
      
select_allowed_clients() {
    default_ip=$(get_current_ssh_user_ip)

    echo -e "\033[1;32m1. \033[0m \033[1;37mDefault [Your IP: $default_ip]\033[0m"
    echo -e "\033[1;32m2. \033[0m \033[1;37mUse 0.0.0.0/0 for all clients\033[0m"
    echo -e "\033[1;32m3. \033[0m \033[1;37mEnter static allowed clients (comma-separated) [Default: $default_ip]\033[0m"
    echo -e "\033[1;32m4. \033[0m \033[1;37mEnter dynamic allowed clients (comma-separated) [Default: $default_ip]\033[0m"
    echo -e "\033[1;32m5. \033[0m \033[1;37mLoad static allowed clients from /root/myacls.acl\033[0m"
    echo -e "\033[1;32m6. \033[0m \033[1;37mLoad dynamic allowed clients from /root/myacls.acl\033[0m"
    echo -e "\033[1;36m--------------------------------------------\033[0m"

    read -p "$(echo -e "\033[1;33mEnter allowed clients [default: all clients]: \033[0m")" option

    case $option in
        1)
            ALLOWED_CLIENTS="$default_ip"
            allowed_clients_env="-e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\""
            allowed_clients_volume=""
            ;;
        2)
            ALLOWED_CLIENTS="0.0.0.0/0"
            allowed_clients_env="-e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\""
            allowed_clients_volume=""
            ;;
        3)
            read -p "Enter the allowed clients (separate with a comma): " custom_clients
            ALLOWED_CLIENTS="${custom_clients:-$default_ip}"
            allowed_clients_env="-e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\""
            allowed_clients_volume=""
            ;;
        4)
            read -p "Enter dynamic allowed clients (comma-separated): " dynamic_clients
            ALLOWED_CLIENTS="${dynamic_clients:-$default_ip}"
            echo "$ALLOWED_CLIENTS" | tr ',' '\n' > /root/myacls.acl
            echo -e "\033[1;32mDynamic allowed clients saved to /root/myacls.acl (line by line)\033[0m"
            allowed_clients_env="-e ALLOWED_CLIENTS_FILE=/tmp/myacls.acl"
            allowed_clients_volume="-v /root/myacls.acl:/tmp/myacls.acl:ro"
            ;;
        5)
            if [[ -f /root/myacls.acl ]]; then
                ALLOWED_CLIENTS=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' /root/myacls.acl | paste -sd, -)
                if [[ -z "$ALLOWED_CLIENTS" ]]; then
                    echo -e "\033[1;31mNo valid clients found in /root/myacls.acl. Defaulting to your IP: $default_ip.\033[0m"
                    ALLOWED_CLIENTS="$default_ip"
                    allowed_clients_env="-e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\""
                    allowed_clients_volume=""
                else
                    echo -e "\033[1;32mAllowed clients from /root/myacls.acl: $ALLOWED_CLIENTS\033[0m"
                    allowed_clients_env="-e ALLOWED_CLIENTS_FILE=/tmp/myacls.acl"
                    allowed_clients_volume="-v /root/myacls.acl:/tmp/myacls.acl:ro"
                fi
            else
                echo -e "\033[1;31mFile /root/myacls.acl not found. Defaulting to: $default_ip.\033[0m"
                ALLOWED_CLIENTS="$default_ip"
                allowed_clients_env="-e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\""
                allowed_clients_volume=""
            fi
            ;;
        6)
            if [[ -f /root/myacls.acl ]]; then
                ALLOWED_CLIENTS=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' /root/myacls.acl | paste -sd, -)
                if [[ -z "$ALLOWED_CLIENTS" ]]; then
                    echo -e "\033[1;31mNo valid dynamic clients found in /root/myacls.acl. Defaulting to your IP: $default_ip.\033[0m"
                    ALLOWED_CLIENTS="$default_ip"
                    allowed_clients_env="-e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\""
                    allowed_clients_volume=""
                else
                    echo -e "\033[1;32mDynamic allowed clients from /root/myacls.acl: $ALLOWED_CLIENTS\033[0m"
                    allowed_clients_env="-e ALLOWED_CLIENTS_FILE=/tmp/myacls.acl"
                    allowed_clients_volume="-v /root/myacls.acl:/tmp/myacls.acl:ro"
                fi
            else
                echo -e "\033[1;31mFile /root/myacls.acl not found. Defaulting to: $default_ip.\033[0m"
                ALLOWED_CLIENTS="$default_ip"
                allowed_clients_env="-e ALLOWED_CLIENTS_FILE=/tmp/myacls.acl"
                allowed_clients_volume="-v /root/myacls.acl:/tmp/myacls.acl:ro"
            fi
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Defaulting to all clients: 0.0.0.0/0\033[0m"
            ALLOWED_CLIENTS="0.0.0.0/0"
            allowed_clients_env="-e ALLOWED_CLIENTS=\"$ALLOWED_CLIENTS\""
            allowed_clients_volume=""
            ;;
    esac

    echo -e "\033[1;32mAllowed clients set to: $ALLOWED_CLIENTS\033[0m"
}


# Call select_allowed_clients
select_allowed_clients



    # Prompt for external IP, with a method to find public IP
    echo -e "\033[1;33mEnter your server IP: [defualt: $(curl -4 -s https://icanhazip.com)]:\033[0m"
    read -p " > " external_ip
    external_ip=${external_ip:-$(curl -4 -s https://icanhazip.com)} # Use public IP as default

        # Prompt for using custom domains with default set to 'yes'
echo -e "\033[1;33mDo you have custom domains (/root/99-custom.lst)? (yes/no) [yes]:\033[0m"
echo -e "\033[1;32mSelect no to spoof all domains (Not recommended.)\033[0m"
read -p " > " custom_domains_input
custom_domains_input=${custom_domains_input,,} # Convert to lowercase

# Default to 'yes' if no input is provided
if [[ -z "$custom_domains_input" ]]; then
    custom_domains_input="yes"
fi

if [[ "$custom_domains_input" == "yes" ]]; then
    if [[ -f /root/99-custom.lst ]]; then
        echo -e "\033[1;32mDomain list already exists at /root/99-custom.lst.\033[0m"
    else
        echo -e "\033[1;33mNo domain list found. Let's create one.\033[0m"
        echo -e "\033[1;33mEnter your domains one by one. When finished, just press Enter on an empty line.\033[0m"

        > /root/99-custom.lst
        while true; do
            read -p "Enter domain (leave blank to finish): " domain
            if [[ -z "$domain" ]]; then
                break
            fi
            echo "$domain" >> /root/99-custom.lst
        done
        echo "" >> /root/99-custom.lst
        echo -e "\033[1;32mCustom domain list created at /root/99-custom.lst.\033[0m"
    fi

    custom_domains="-v /root/99-custom.lst:/etc/snidust/domains.d/99-custom.lst:ro"
    spoof_domains="false"
else
    custom_domains=""
    spoof_domains="true"
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

echo -e "\033[1;33mDo you want to configure IP rate limiting? (yes/no) [no]:\033[0m"
read -p " > " enable_rate_limit

if [[ "$enable_rate_limit" == "yes" ]]; then
    read -p $'\033[1;33mEnter warning QPS limit (default: 800): \033[0m' rate_limit_warn
    read -p $'\033[1;33mEnter block QPS limit (default: 1000): \033[0m' rate_limit_block
    read -p $'\033[1;33mEnter block duration in seconds (default: 360): \033[0m' rate_limit_block_duration
    read -p $'\033[1;33mEnter evaluation window in seconds (default: 60): \033[0m' rate_limit_eval_window

    rate_limit_warn=${rate_limit_warn:-800}
    rate_limit_block=${rate_limit_block:-1000}
    rate_limit_block_duration=${rate_limit_block_duration:-360}
    rate_limit_eval_window=${rate_limit_eval_window:-60}

    rate_limit_flags="-e DNSDIST_RATE_LIMIT_WARN=\"$rate_limit_warn\" \
                      -e DNSDIST_RATE_LIMIT_BLOCK=\"$rate_limit_block\" \
                      -e DNSDIST_RATE_LIMIT_BLOCK_DURATION=\"$rate_limit_block_duration\" \
                      -e DNSDIST_RATE_LIMIT_EVAL_WINDOW=\"$rate_limit_eval_window\""
else
    echo -e "\033[1;33mDo you want to completly disable IP rate limiting? (yes/no) [no]:\033[0m"
    echo -e "\033[1;32m[no]= use default IP rate limit (recommended):\033[0m"
    echo -e "\033[1;32m[yes]= completly disable IP rate limit:\033[0m"
    read -p " > " disable_rate_limit

    if [[ "$disable_rate_limit" == "yes" ]]; then
        rate_limit_flags="-e DNSDIST_RATE_LIMIT_DISABLE=true"
    else
        rate_limit_flags=""
    fi
fi
# Ask if they want to enable the log driver
read -p "$(echo -e "\033[1;34mDo you want to enable the log driver (increases ram and CPU usage)? (yes/no, default: no): \033[0m")" enable_logging

# Check if the user wants to enable the log driver
if [[ "$enable_logging" =~ ^[Yy][Ee][Ss]$ || -z "$enable_logging" ]]; then
    # If 'yes', log_driver_option is an empty string
    log_driver_option=""
else
    # If 'no', set log_driver_option to '--log-driver=none'
    log_driver_option="--log-driver=none"
fi
# Ask for custom upstream configuration
read -p "Do you want to use a custom upstream pool? (yes/no) [no]: " use_custom_upstream
use_custom_upstream=${use_custom_upstream:-no}

custom_upstream_env=""
custom_upstream_volume=""

if [[ "$use_custom_upstream" == "yes" ]]; then
    read -p "Enter the name of your custom upstream pool [myUpstream]: " custom_upstream_name
    custom_upstream_name=${custom_upstream_name:-myUpstream}

    read -p "Enter the path where you want to save the config file [/root]: " custom_upstream_dir
    custom_upstream_dir=${custom_upstream_dir:-/root}

    # Ensure directory exists
    mkdir -p "$custom_upstream_dir"

    # Set config file path
    custom_upstream_file="$custom_upstream_dir/99-customUpstream.conf"

    # Ask for upstream DNS servers
    read -p "Enter your upstream DNS servers (comma-separated) [1.1.1.1,8.8.8.8]: " upstream_servers
    upstream_servers=${upstream_servers:-1.1.1.1,8.8.8.8}

    # Convert to array
    IFS=',' read -ra servers <<< "$upstream_servers"

    # Create config file
    echo "-- Auto-generated Custom Upstream config for SniDust" > "$custom_upstream_file"
    for i in "${!servers[@]}"; do
        srv="${servers[$i]}"
        echo "newServer({ address = \"$srv\", name = \"custom$i\", pool = \"$custom_upstream_name\" })" >> "$custom_upstream_file"
    done

    echo -e "\033[1;32mCustom upstream config created at: $custom_upstream_file\033[0m"

    # Add environment variable and volume mount
    custom_upstream_env="-e DNSDIST_UPSTREAM_POOL_NAME=$custom_upstream_name"
    custom_upstream_volume="-v $custom_upstream_file:/etc/dnsdist/conf.d/99-customUpstream.conf:ro"
fi
# Prepare the Docker command
docker_command="docker run -d \
    --name \"$container_name\" \
    $allowed_clients_env \
    -e EXTERNAL_IP=\"$external_ip\" \
    -e SPOOF_ALL_DOMAINS=\"$spoof_domains\" \
    $enable_dot \
    $rate_limit_flags \
    -p 443:8443 \
    -p 80:8080 \
    -p 53:5300/udp \
    -p 53:5300/tcp \
    $custom_domains \
    $log_driver_option \
    $memory_flags \
    $allowed_clients_volume \
    $custom_upstream_env \
    $custom_upstream_volume \
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
    read -p "Press Enter to continue..."
}

# Function to manage the Docker container (start, stop, restart, remove, check status)
manage_container() {

    while true; do
    clear
        echo -e "\033[1;36m=========Manage Docker Container==========\033[0m"
        echo -e "\033[1;32m1. Start Container\033[0m"
        echo -e "\033[1;32m2. Stop Container\033[0m"
        echo -e "\033[1;32m3. Restart Container\033[0m"
        echo -e "\033[1;32m4. Remove Container\033[0m"
        echo -e "\033[1;32m5. Check Status\033[0m"
        echo -e "\033[1;32m0. Return to Main Menu\033[0m"
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
                echo -e "\033[1;32mChecking status of Docker container 'snidust'...\033[0m"
                if docker ps -a --format '{{.Names}}: {{.State}}' | grep -q '^snidust: running$'; then
                    echo -e "\033[1;32mThe container 'snidust' is running.\033[0m"
                elif docker ps -a --format '{{.Names}}: {{.State}}' | grep -q '^snidust: exited$'; then
                    echo -e "\033[1;33mThe container 'snidust' is stopped.\033[0m"
                else
                    echo -e "\033[1;31mThe container 'snidust' does not exist.\033[0m"
                fi
                ;;
            0) 
                echo -e "\033[1;34mReturning to Main Menu...\033[0m"
                return
                ;;
            *) 
                echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                ;;
        esac
        read -p $'\033[1;34mPress Enter to continue...\033[0m'
    done
}


manage_custom_domains() {
    clear
    echo -e "\033[1;36m============ Edit Custom Domains ============\033[0m"
    echo -e "\033[1;33mExample entries:\033[0m"
    echo -e "\033[1;33m- check-host.net\n- xbox.com\033[0m"

    while true; do
        echo -e "\n\033[1;36m============================================\033[0m"
        echo -e "\033[1;33mOptions:\033[0m"
        echo -e "\033[1;32m1.\033[0m Edit custom domains file"
        echo -e "\033[1;32m2.\033[0m Download custom domains file"
        echo -e "\033[1;32m0.\033[0m Return to DNS menu"
        echo -e "\033[1;36m============================================\033[0m"

        read -p "Choose an option: " choice
        case $choice in
            1)
                echo -e "\033[1;33mOpening file for editing...\033[0m"
                nano /root/99-custom.lst
                ;;
            2)
                echo -e "\033[1;33mDownloading the custom domains file...\033[0m"
                wget -O /root/99-custom.lst https://sub-s3.s3.eu-central-1.amazonaws.com/99-custom.lst
                if [[ $? -eq 0 ]]; then
                    echo -e "\033[1;32mDownload successful!\033[0m"
                else
                    echo -e "\033[1;31mDownload failed. Check URL or connection.\033[0m"
                fi
                ;;
            0)
                echo -e "\033[1;31mReturning to the DNS menu...\033[0m"
                create_dns
                return
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please choose again.\033[0m"
                continue
                ;;
        esac

        # Ask about container restart after action
        while true; do
            read -p "Do you want to restart the container? (yes/no): " restart_choice
            case "$restart_choice" in
                yes)
                    echo -e "\033[1;33mRestarting the container...\033[0m"
                    docker restart snidust
                    break
                    ;;
                no)
                    echo -e "\033[1;31mContainer restart skipped.\033[0m"
                    break
                    ;;
                *)
                    echo -e "\033[1;31mInvalid input. Please enter 'yes' or 'no'.\033[0m"
                    ;;
            esac
        done
    done
}


edit_clients() {
    clear
    echo -e "\033[1;36m=========== Edit Allowed Clients ===========\033[0m"
    echo -e "\033[1;33mAdd IPs line by line.\033[0m"

    read -p "Press Enter to edit or type '0' to return: " input
    if [[ "$input" == "0" ]]; then
        echo -e "\033[1;31mExiting without changes.\033[0m"
        return
    fi

    nano /root/myacls.acl

    # Ask about restarting the container
    while true; do
        read -p "Do you want to restart the container? (yes/no): " restart_choice
        case "$restart_choice" in
            yes)
                echo -e "\033[1;33mRestarting the container...\033[0m"
                docker restart snidust
                break
                ;;
            no)
                echo -e "\033[1;31mContainer restart skipped.\033[0m"
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid input. Please enter 'yes' or 'no'.\033[0m"
                ;;
        esac
    done

    create_dns
}

auto_restart() {
    while true; do
        clear
        echo -e "\n\033[1;34mManage Service Cron Jobs:\033[0m"
        echo -e " \033[1;34m1.\033[0m Add/Update Cron Job (Includes Restart & Start at Reboot)"
        echo -e " \033[1;34m2.\033[0m Remove Cron Job"
        echo -e " \033[1;34m3.\033[0m Edit Cron Jobs with Nano"
        echo -e " \033[1;31m0.\033[0m Return"

        read -p "Select an option: " cron_option

        case $cron_option in
            1)
                read -p "Enter the interval in hours to restart the service (1-23): " restart_interval
                if [[ ! "$restart_interval" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
                    echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 23.\033[0m"
                else
                    # Define cron jobs
                    restart_cron="0 */$restart_interval * * * /usr/bin/docker restart snidust"
                    reboot_cron="@reboot /usr/bin/docker start snidust"

                    # Remove any existing cron jobs for this service
                    (crontab -l 2>/dev/null | grep -v "/usr/bin/docker restart snidust" | grep -v "/usr/bin/docker start snidust") | crontab -

                    # Add the new cron jobs
                    (crontab -l 2>/dev/null; echo "$restart_cron"; echo "$reboot_cron") | crontab -

                    echo -e "\033[1;32mCron job updated:\033[0m"
                    echo -e "\033[1;32m- Restart snidust every $restart_interval hour(s).\033[0m"
                    echo -e "\033[1;32m- Start snidust at system boot.\033[0m"
                fi
                ;;
            2)
                # Remove both the restart and reboot cron jobs
                crontab -l 2>/dev/null | grep -v "/usr/bin/docker restart snidust" | grep -v "/usr/bin/docker start snidust" | crontab -
                echo -e "\033[1;32mCron jobs for snidust removed.\033[0m"
                ;;
            3)
                echo -e "\033[1;33mOpening crontab for manual editing...\033[0m"
                sleep 1
                crontab -e
                ;;
            0)
                echo -e "\033[1;33mReturning to previous menu...\033[0m"
                sleep 1
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid option! Please try again.\033[0m"
                sleep 2
                ;;
        esac
        read -p "Press Enter to continue..."
    done
}

manage_snidust_service() {
    # Define the path to the systemd service file
    local service_file="/etc/systemd/system/snidust.service"

    # Ask the user for an option
    echo -e "\033[1;32mPlease select an option:\033[0m"
    echo -e "\033[1;32m1. \033[0m Add Snidust service"
    echo -e "\033[1;32m2. \033[0m Remove Snidust service"
    echo -e "\033[1;32m3. \033[0m Check Snidust service status"
    echo -e "\033[1;32m0. \033[0m return"
    read -p "$(echo -e "\033[1;33mEnter your choice [1-3]: \033[0m")" option

    case $option in
        1)
            # Add Snidust service
            echo -e "[Unit]
Description=Snidust Docker Service
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/usr/bin/docker start snidust
ExecStop=/usr/bin/docker stop snidust
ExecReload=/usr/bin/docker restart snidust

[Install]
WantedBy=multi-user.target" | sudo tee $service_file > /dev/null

            # Reload systemd to recognize the new service
            sudo systemctl daemon-reload

            # Enable the service to start on boot
            sudo systemctl enable snidust.service

            # Start the snidust service
            sudo systemctl start snidust.service

            echo -e "\033[1;32mSnidust service has been added and started.\033[0m"
            ;;
        2)
            # Remove Snidust service
            if [[ -f $service_file ]]; then
                sudo systemctl stop snidust.service
                sudo systemctl disable snidust.service
                sudo rm -f $service_file
                sudo systemctl daemon-reload
                echo -e "\033[1;32mSnidust service has been removed.\033[0m"
            else
                echo -e "\033[1;31mSnidust service does not exist.\033[0m"
            fi
            ;;
        3)
    # Check Snidust service status
    systemctl status snidust.service
    if systemctl status snidust.service > /dev/null 2>&1; then
        echo -e "\033[1;32mSnidust service is running.\033[0m"
    else
        echo -e "\033[1;31mSnidust service is not running.\033[0m"
    fi
    ;;

        *)
            echo -e "\033[1;31mInvalid option. Please choose between 1-3.\033[0m"
            ;;
        0) create_dns ;;
    esac
}

reload_acls() {
    # Get the external IP dynamically
    external_ip=${external_ip:-$(curl -4 -s https://icanhazip.com)}  # Use public IP as default
    local dns_query="reload.acl.snidust.local"

    echo -e "\033[1;32mReloading ACLs from $external_ip...\033[0m"
    
    # Send a DNS query to trigger ACL reload
    dig @$external_ip $dns_query

    # Optionally, you can check the logs to ensure the reload was successful
    echo -e "\033[1;36mCheck logs for reload confirmation:\033[0m"
    echo "docker logs snidust"
}
reload_domains() {
    # Get the external IP dynamically
    external_ip=${external_ip:-$(curl -4 -s https://icanhazip.com)}  # Use public IP as default
    local dns_query="reload.domainlist.snidust.local"

    echo -e "\033[1;32mReloading domain lists from $external_ip...\033[0m"
    
    # Send a DNS query to trigger domain list reload
    dig @$external_ip $dns_query

    # Optionally, you can check the logs to ensure the reload was successful
    echo -e "\033[1;36mCheck logs for reload confirmation:\033[0m"
    echo "docker logs snidust"
}

# create_dns
create_dns() {

    while true; do
    clear
        echo -e "\033[1;36m===========create custom dns==============\033[0m"
        echo -e "\033[1;31mPort 80 443 53 must be free \033[0m"
        echo -e "\033[1;34mTips: use (Change server DNS) from main menu to free up port 53 \033[0m"
        echo -e "\033[1;32m1. Create DNS\033[0m"
        echo -e "\033[1;32m2. Edit Custom Domains\033[0m"
        echo -e "\033[1;32m3. Manage Docker Container (start, stop, remove) \033[0m"
        echo -e "\033[1;32m4. Check Ports Status\033[0m"
        echo -e "\033[1;32m5. Edit Allowed clients\033[0m"
        echo -e "\033[1;32m6. Auto Restart Service (Cron)\033[0m"
        echo -e "\033[1;32m7. Auto start Service after reboot (systemd)\033[0m"
        echo -e "\033[1;32m8. reload clients IPS \033[0m"
        echo -e "\033[1;32m9. reload custom domains \033[0m"
        echo -e "\033[1;32m0. Main menu\033[0m"
        read -p "> " choice

        case $choice in
            1) create_custom_dns ;;
            2) manage_custom_domains ;;
            3) manage_container ;;
            4) check_ports ;;
            5) edit_clients ;;
            6) auto_restart ;;
            7) manage_snidust_service
            read -p "Press Enter to continue..."
            ;;
            8) reload_acls
            read -p "Press Enter to continue..."
            ;;
            9) reload_domains
            read -p "Press Enter to continue..."
            ;;
            0) return ;;
            *) echo -e "\033[1;31mInvalid option. Please try again.\033[0m" ;;
        esac
    done
}

create_dns
