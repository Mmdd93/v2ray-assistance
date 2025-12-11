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

    # Function to select allowed clients
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
                ALLOWED_CLIENTS_TYPE="static"
                ;;
            2)
                ALLOWED_CLIENTS="0.0.0.0/0"
                ALLOWED_CLIENTS_TYPE="static"
                ;;
            3)
                read -p "Enter the allowed clients (separate with a comma): " custom_clients
                ALLOWED_CLIENTS="${custom_clients:-$default_ip}"
                ALLOWED_CLIENTS_TYPE="static"
                ;;
            4)
                read -p "Enter dynamic allowed clients (comma-separated): " dynamic_clients
                ALLOWED_CLIENTS="${dynamic_clients:-$default_ip}"
                echo "$ALLOWED_CLIENTS" | tr ',' '\n' > /root/myacls.acl
                echo -e "\033[1;32mDynamic allowed clients saved to /root/myacls.acl (line by line)\033[0m"
                ALLOWED_CLIENTS_TYPE="file"
                ;;
            5)
                if [[ -f /root/myacls.acl ]]; then
                    ALLOWED_CLIENTS=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' /root/myacls.acl | paste -sd, -)
                    if [[ -z "$ALLOWED_CLIENTS" ]]; then
                        echo -e "\033[1;31mNo valid clients found in /root/myacls.acl. Defaulting to your IP: $default_ip.\033[0m"
                        ALLOWED_CLIENTS="$default_ip"
                        ALLOWED_CLIENTS_TYPE="static"
                    else
                        echo -e "\033[1;32mAllowed clients from /root/myacls.acl: $ALLOWED_CLIENTS\033[0m"
                        ALLOWED_CLIENTS_TYPE="file"
                    fi
                else
                    echo -e "\033[1;31mFile /root/myacls.acl not found. Defaulting to: $default_ip.\033[0m"
                    ALLOWED_CLIENTS="$default_ip"
                    ALLOWED_CLIENTS_TYPE="static"
                fi
                ;;
            6)
                if [[ -f /root/myacls.acl ]]; then
                    ALLOWED_CLIENTS=$(grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}|[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' /root/myacls.acl | paste -sd, -)
                    if [[ -z "$ALLOWED_CLIENTS" ]]; then
                        echo -e "\033[1;31mNo valid dynamic clients found in /root/myacls.acl. Defaulting to your IP: $default_ip.\033[0m"
                        ALLOWED_CLIENTS="$default_ip"
                        ALLOWED_CLIENTS_TYPE="static"
                    else
                        echo -e "\033[1;32mDynamic allowed clients from /root/myacls.acl: $ALLOWED_CLIENTS\033[0m"
                        ALLOWED_CLIENTS_TYPE="file"
                    fi
                else
                    echo -e "\033[1;31mFile /root/myacls.acl not found. Defaulting to: $default_ip.\033[0m"
                    ALLOWED_CLIENTS="$default_ip"
                    ALLOWED_CLIENTS_TYPE="file"
                fi
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Defaulting to all clients: 0.0.0.0/0\033[0m"
                ALLOWED_CLIENTS="0.0.0.0/0"
                ALLOWED_CLIENTS_TYPE="static"
                ;;
        esac

        echo -e "\033[1;32mAllowed clients set to: $ALLOWED_CLIENTS\033[0m"
    }

    # Call select_allowed_clients
    select_allowed_clients

    # Prompt for external IP
    echo -e "\033[1;33mEnter your server IP: [default: $(curl -4 -s https://icanhazip.com)]:\033[0m"
    read -p " > " external_ip
    external_ip=${external_ip:-$(curl -4 -s https://icanhazip.com)}

    # Prompt for using custom domains
    echo -e "\033[1;33mDo you have custom domains (/root/99-custom.lst)? (yes/no) [yes]:\033[0m"
    echo -e "\033[1;32mSelect no to spoof all domains (Not recommended.)\033[0m"
    read -p " > " custom_domains_input
    custom_domains_input=${custom_domains_input,,}

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
        spoof_domains="false"
    else
        spoof_domains="true"
        echo -e "\033[1;32mSelected all domains for spoofing.\033[0m"
    fi

    # RAM and swap configuration
    echo -e "\033[1;33mDo you want to use custom RAM and swap? (yes/no) [no]:\033[0m"
    read -p " > " custom_ram_swap

    if [[ "$custom_ram_swap" == "yes" ]]; then
        read -p $'\033[1;33mEnter RAM size (e.g., 512m, 1g) [default: 512m]: \033[0m' ram_size
        read -p $'\033[1;33mEnter swap size (e.g., 512m, 2g) [default: 512m]: \033[0m' swap_size
        ram_size=${ram_size:-512m}
        swap_size=${swap_size:-512m}
    else
        ram_size=""
        swap_size=""
    fi

    # DOT configuration
    echo -e "\033[1;33mDo you want to enable DOT (DNS over TLS)? (yes/no) [no]:\033[0m"
    read -p " > " enable_dot

    if [[ "$enable_dot" == "yes" ]]; then
        ENABLE_DOT="true"
    else
        ENABLE_DOT="false"
    fi

    # Rate limiting configuration
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
        rate_limit_disable="false"
    else
        echo -e "\033[1;33mDo you want to completely disable IP rate limiting? (yes/no) [no]:\033[0m"
        echo -e "\033[1;32m[no]= use default IP rate limit (recommended):\033[0m"
        echo -e "\033[1;32m[yes]= completely disable IP rate limit:\033[0m"
        read -p " > " disable_rate_limit

        if [[ "$disable_rate_limit" == "yes" ]]; then
            rate_limit_disable="true"
            rate_limit_warn=""
            rate_limit_block=""
            rate_limit_block_duration=""
            rate_limit_eval_window=""
        else
            rate_limit_disable="false"
            rate_limit_warn=""
            rate_limit_block=""
            rate_limit_block_duration=""
            rate_limit_eval_window=""
        fi
    fi
    # Logging configuration
    echo -e "\033[1;34mDo you want to enable the log driver (increases ram and CPU usage)? (yes/no, default: no): \033[0m"
    read -p "" enable_logging

    if [[ "$enable_logging" =~ ^[Yy][Ee][Ss]$ ]]; then
        logging_enabled="true"
    else
        logging_enabled="false"
    fi

    # Custom upstream configuration
    read -p "Do you want to use a custom upstream pool? (yes/no) [no]: " use_custom_upstream
    use_custom_upstream=${use_custom_upstream:-no}

    if [[ "$use_custom_upstream" == "yes" ]]; then
        read -p "Enter the name of your custom upstream pool [myUpstream]: " custom_upstream_name
        custom_upstream_name=${custom_upstream_name:-myUpstream}

        read -p "Enter the path where you want to save the config file [/root]: " custom_upstream_dir
        custom_upstream_dir=${custom_upstream_dir:-/root}

        mkdir -p "$custom_upstream_dir"
        custom_upstream_file="$custom_upstream_dir/99-customUpstream.conf"

        read -p "Enter your upstream DNS servers (comma-separated) [1.1.1.1,8.8.8.8]: " upstream_servers
        upstream_servers=${upstream_servers:-1.1.1.1,8.8.8.8}

        IFS=',' read -ra servers <<< "$upstream_servers"

        echo "-- Auto-generated Custom Upstream config for SniDust" > "$custom_upstream_file"
        for i in "${!servers[@]}"; do
            srv="${servers[$i]}"
            echo "newServer({ address = \"$srv\", name = \"custom$i\", pool = \"$custom_upstream_name\" })" >> "$custom_upstream_file"
        done

        echo -e "\033[1;32mCustom upstream config created at: $custom_upstream_file\033[0m"
    else
        custom_upstream_name=""
        custom_upstream_file=""
    fi

    # Create docker-compose.yml with proper YAML structure
    {
    cat << EOF
services:
  snidust:
    image: ghcr.io/seji64/snidust:1.0.15
    container_name: ${container_name}
    restart: unless-stopped
    ports:
      - "443:8443"
      - "80:8080"
      - "53:5300/tcp"
      - "53:5300/udp"
    environment:
      - EXTERNAL_IP=${external_ip}
      - SPOOF_ALL_DOMAINS=${spoof_domains}
EOF

    # Add allowed clients based on type
    if [[ "$ALLOWED_CLIENTS_TYPE" == "static" ]]; then
        echo "      - ALLOWED_CLIENTS=${ALLOWED_CLIENTS}"
    elif [[ "$ALLOWED_CLIENTS_TYPE" == "file" ]]; then
        echo "      - ALLOWED_CLIENTS_FILE=/tmp/myacls.acl"
    fi

    # Add DOT configuration
    if [[ "$ENABLE_DOT" == "true" ]]; then
        echo "      - DNSDIST_ENABLE_DOT=true"
        echo "      - DNSDIST_DOT_CERT_TYPE=auto-self"
    fi

    # Add rate limiting configuration
    if [[ "$rate_limit_disable" == "true" ]]; then
        echo "      - DNSDIST_RATE_LIMIT_DISABLE=true"
    elif [[ -n "$rate_limit_warn" ]]; then
        echo "      - DNSDIST_RATE_LIMIT_WARN=${rate_limit_warn}"
        echo "      - DNSDIST_RATE_LIMIT_BLOCK=${rate_limit_block}"
        echo "      - DNSDIST_RATE_LIMIT_BLOCK_DURATION=${rate_limit_block_duration}"
        echo "      - DNSDIST_RATE_LIMIT_EVAL_WINDOW=${rate_limit_eval_window}"
    fi

    # Add custom upstream configuration
    if [[ -n "$custom_upstream_name" ]]; then
        echo "      - DNSDIST_UPSTREAM_POOL_NAME=${custom_upstream_name}"
    fi

    # Close environment section and start volumes
    echo "    volumes:"
    
    if [[ "$custom_domains_input" == "yes" ]]; then
        echo "      - /root/99-custom.lst:/etc/snidust/domains.d/99-custom.lst:ro"
    fi
    
    if [[ "$ALLOWED_CLIENTS_TYPE" == "file" ]]; then
        echo "      - /root/myacls.acl:/tmp/myacls.acl:ro"
    fi
    
    if [[ -n "$custom_upstream_file" ]]; then
        echo "      - ${custom_upstream_file}:/etc/dnsdist/conf.d/99-customUpstream.conf:ro"
    fi

    # Add logging configuration
    if [[ "$logging_enabled" == "false" ]]; then
        echo "    logging:"
        echo "      driver: none"
    fi

    # Add resource limits (deploy section)
    if [[ -n "$ram_size" ]]; then
        echo "    deploy:"
        echo "      resources:"
        echo "        limits:"
        echo "          memory: ${ram_size}"
        if [[ -n "$swap_size" ]]; then
            echo "          memory_swap: ${swap_size}"
        fi
    fi
    } > /root/snidust-docker-compose.yml

    echo -e "\033[1;32mDocker Compose file created at: /root/snidust-docker-compose.yml\033[0m"
    echo ""
    echo -e "\033[1;33mDocker Compose configuration:\033[0m"
    echo "----------------------------------------"
    cat /root/snidust-docker-compose.yml
    echo "----------------------------------------"
    echo ""

    # Ask if user wants to start the container
    read -p "$(echo -e "\033[1;33mDo you want to start the container now? (yes/no) [yes]: \033[0m")" start_now
    start_now=${start_now:-yes}

    if [[ "$start_now" == "yes" ]]; then
        echo -e "\033[1;32mStarting snidust container...\033[0m"
        cd /root
        
        # Try docker compose (new) first, then docker-compose (old)
        if command -v docker-compose &> /dev/null; then
            docker-compose -f snidust-docker-compose.yml up -d
        elif command -v docker &> /dev/null && docker compose version &> /dev/null; then
            docker compose -f snidust-docker-compose.yml up -d
        else
            echo -e "\033[1;31mError: Neither docker-compose nor docker compose command found!\033[0m"
            echo -e "\033[1;33mPlease install docker-compose or update Docker to use 'docker compose'\033[0m"
            read -p "Press Enter to continue..."
            return 1
        fi
        
        # Verify that the container is running
        sleep 2
        if [ "$(docker ps -q -f name="$container_name")" ]; then
            echo -e "\033[1;32m✓ Docker container '$container_name' is up and running with snidust DNS settings.\033[0m"
            echo ""
            echo -e "\033[1;33mConfiguration Summary:\033[0m"
            echo -e "  Server IP: \033[1;37m$external_ip\033[0m"
            echo -e "  Spoof domains: \033[1;37m$spoof_domains\033[0m"
            echo -e "  DOT enabled: \033[1;37m$ENABLE_DOT\033[0m"
            echo -e "  Logging enabled: \033[1;37m$logging_enabled\033[0m"
            echo -e "  Allowed clients: \033[1;37m$ALLOWED_CLIENTS\033[0m"
            echo ""
            echo -e "\033[1;32mAccess your DNS server at:\033[0m"
            echo -e "  - HTTPS: \033[1;37mhttps://$external_ip\033[0m"
            echo -e "  - HTTP: \033[1;37mhttp://$external_ip\033[0m"
            echo -e "  - DNS: \033[1;37m$external_ip:53\033[0m"
        else
            echo -e "\033[1;31m✗ Failed to start the Docker container.\033[0m"
            echo -e "\033[1;33mChecking logs for errors...\033[0m"
            if command -v docker-compose &> /dev/null; then
                docker-compose -f snidust-docker-compose.yml logs
            elif command -v docker &> /dev/null; then
                docker compose -f snidust-docker-compose.yml logs
            fi
        fi
    else
        echo -e "\033[1;33mDocker Compose file saved to /root/snidust-docker-compose.yml\033[0m"
        echo -e "\033[1;33mYou can start it later with:\033[0m"
        echo -e "  \033[1;37mdocker-compose -f /root/snidust-docker-compose.yml up -d\033[0m"
        echo -e "  \033[1;37mor\033[0m"
        echo -e "  \033[1;37mdocker compose -f /root/snidust-docker-compose.yml up -d\033[0m"
    fi

    read -p "Press Enter to continue..."
}
# Function to manage the Docker container (start, stop, restart, remove, check status)
manage_container() {
    local compose_file="/root/snidust-docker-compose.yml"
    local use_compose=false
    
    # Check if we should use docker-compose
    if [[ -f "$compose_file" ]] && (command -v docker-compose &> /dev/null || docker compose version &> /dev/null); then
        use_compose=true
    fi
    
    # Function to execute compose command
    docker_compose_cmd() {
        local cmd="$1"
        if command -v docker-compose &> /dev/null; then
            docker-compose -f "$compose_file" $cmd
        elif docker compose version &> /dev/null; then
            docker compose -f "$compose_file" $cmd
        else
            echo -e "\033[1;31mError: Neither docker-compose nor docker compose found!\033[0m"
            return 1
        fi
    }
    
    # Function to edit docker-compose.yml
    edit_docker_compose() {
        local editor="${EDITOR:-nano}"
        
        echo -e "\033[1;36m===== Edit Docker Compose Configuration =====\033[0m"
        echo ""
        echo -e "\033[1;33mCurrent docker-compose.yml:\033[0m"
        echo "----------------------------------------"
        cat "$compose_file" 2>/dev/null || echo -e "\033[1;31mFile not found: $compose_file\033[0m"
        echo "----------------------------------------"
        echo ""
        
        echo -e "\033[1;34mSelect editor:\033[0m"
        echo -e "\033[1;32m1. nano (recommended for beginners)\033[0m"
        echo -e "\033[1;32m2. vim\033[0m"
        echo -e "\033[1;32m3. vi\033[0m"
        echo -e "\033[1;32m4. Custom editor command\033[0m"
        echo -e "\033[1;32m5. View only (no edit)\033[0m"
        read -p "Select option [1]: " editor_choice
        
        case $editor_choice in
            2) editor="vim" ;;
            3) editor="vi" ;;
            4) 
                read -p "Enter editor command (e.g., 'emacs', 'code'): " custom_editor
                editor="$custom_editor"
                ;;
            5)
                echo -e "\033[1;33mViewing file only. No changes will be made.\033[0m"
                read -p "Press Enter to continue..."
                return
                ;;
            *) editor="nano" ;;
        esac
        
        if command -v "$editor" &> /dev/null; then
            echo -e "\033[1;32mOpening $compose_file with $editor...\033[0m"
            "$editor" "$compose_file"
            
            # Ask if user wants to restart container after edit
            read -p "Do you want to restart the container with new configuration? (yes/no) [yes]: " restart_after
            restart_after=${restart_after:-yes}
            
            if [[ "$restart_after" == "yes" ]]; then
                echo -e "\033[1;32mRestarting container with new configuration...\033[0m"
                docker_compose_cmd "down" 2>/dev/null
                docker_compose_cmd "up -d"
                
                if [ "$(docker ps -q -f name=snidust)" ]; then
                    echo -e "\033[1;32m✓ Container restarted successfully with new configuration\033[0m"
                else
                    echo -e "\033[1;31m✗ Failed to restart container. Check configuration.\033[0m"
                fi
            fi
        else
            echo -e "\033[1;31mEditor '$editor' not found. Available editors:\033[0m"
            echo -e "\033[1;33mTrying to use vi as fallback...\033[0m"
            if command -v vi &> /dev/null; then
                vi "$compose_file"
            else
                echo -e "\033[1;31mNo suitable editor found. File location: $compose_file\033[0m"
            fi
        fi
    }
    
    # Function to edit specific section
    edit_specific_section() {
        clear
        echo -e "\033[1;36m===== Edit Specific Docker Compose Section =====\033[0m"
        echo ""
        
        # Create a temporary file with the current config
        local temp_file=$(mktemp)
        cp "$compose_file" "$temp_file"
        
        echo -e "\033[1;34mSelect section to edit:\033[0m"
        echo -e "\033[1;32m1. Environment variables\033[0m"
        echo -e "\033[1;32m2. Port mappings\033[0m"
        echo -e "\033[1;32m3. Volumes\033[0m"
        echo -e "\033[1;32m4. Resource limits (memory/swap)\033[0m"
        echo -e "\033[1;32m5. Logging configuration\033[0m"
        echo -e "\033[1;32m6. Container name\033[0m"
        echo -e "\033[1;32m7. Restart policy\033[0m"
        echo -e "\033[1;32m8. Back to main menu\033[0m"
        read -p "Select option: " section_choice
        
        case $section_choice in
            1)
                echo -e "\033[1;33mCurrent environment variables:\033[0m"
                grep -A 20 "environment:" "$temp_file" | grep -E "^\s+-\s"
                echo ""
                echo -e "\033[1;34mOptions:\033[0m"
                echo -e "\033[1;32m1. Add new environment variable\033[0m"
                echo -e "\033[1;32m2. Remove environment variable\033[0m"
                echo -e "\033[1;32m3. Edit existing variable\033[0m"
                read -p "Select option: " env_choice
                
                if [[ "$env_choice" == "1" ]]; then
                    read -p "Enter variable name: " var_name
                    read -p "Enter variable value: " var_value
                    # Add to environment section
                    sed -i "/environment:/a\      - ${var_name}=${var_value}" "$temp_file"
                fi
                ;;
            2)
                echo -e "\033[1;33mCurrent port mappings:\033[0m"
                grep -A 10 "ports:" "$temp_file" | grep -E "^\s+-\s"
                echo ""
                read -p "Enter new port mapping (e.g., '443:8443'): " new_port
                read -p "Remove existing port? (yes/no): " remove_port
                if [[ "$remove_port" == "yes" ]]; then
                    read -p "Enter port to remove (e.g., '443:8443'): " remove_which
                    sed -i "/^\s\+-\s\"$remove_which\"/d" "$temp_file"
                fi
                sed -i "/ports:/a\      - \"$new_port\"" "$temp_file"
                ;;
            3)
                echo -e "\033[1;33mCurrent volumes:\033[0m"
                grep -A 10 "volumes:" "$temp_file" | grep -E "^\s+-\s"
                ;;
            4)
                echo -e "\033[1;33mCurrent resource limits:\033[0m"
                grep -A 10 "deploy:" "$temp_file" || echo "No resource limits set"
                ;;
            # ... other sections
            8)
                rm "$temp_file"
                return
                ;;
        esac
        
        # Show diff and ask for confirmation
        echo ""
        echo -e "\033[1;33mChanges to be made:\033[0m"
        diff -u "$compose_file" "$temp_file" || echo "No changes"
        echo ""
        
        read -p "Apply these changes? (yes/no): " apply_changes
        if [[ "$apply_changes" == "yes" ]]; then
            cp "$temp_file" "$compose_file"
            echo -e "\033[1;32m✓ Changes applied to $compose_file\033[0m"
            
            read -p "Restart container with new configuration? (yes/no) [yes]: " restart_now
            restart_now=${restart_now:-yes}
            if [[ "$restart_now" == "yes" ]]; then
                docker_compose_cmd "restart"
            fi
        else
            echo -e "\033[1;33mChanges discarded\033[0m"
        fi
        
        rm "$temp_file"
    }
    
    # Function to create backup of docker-compose
    backup_docker_compose() {
        local backup_dir="/root/docker-compose-backups"
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="$backup_dir/snidust-docker-compose_$timestamp.yml"
        
        mkdir -p "$backup_dir"
        cp "$compose_file" "$backup_file"
        echo -e "\033[1;32m✓ Backup created: $backup_file\033[0m"
        
        # List recent backups
        echo -e "\033[1;33mRecent backups:\033[0m"
        ls -lt "$backup_dir"/*.yml 2>/dev/null | head -5 || echo "No backups found"
    }
    
    # Function to restore from backup
    restore_docker_compose() {
        local backup_dir="/root/docker-compose-backups"
        
        if [[ ! -d "$backup_dir" ]]; then
            echo -e "\033[1;31mNo backup directory found\033[0m"
            return
        fi
        
        echo -e "\033[1;33mAvailable backups:\033[0m"
        select backup_file in "$backup_dir"/*.yml "Cancel"; do
            if [[ "$backup_file" == "Cancel" ]]; then
                echo -e "\033[1;33mRestore cancelled\033[0m"
                return
            elif [[ -f "$backup_file" ]]; then
                echo -e "\033[1;33mRestoring from: $backup_file\033[0m"
                cp "$backup_file" "$compose_file"
                echo -e "\033[1;32m✓ Restored successfully\033[0m"
                
                read -p "Restart container with restored configuration? (yes/no) [yes]: " restart_after
                restart_after=${restart_after:-yes}
                if [[ "$restart_after" == "yes" ]]; then
                    docker_compose_cmd "restart"
                fi
                break
            else
                echo -e "\033[1;31mInvalid selection\033[0m"
            fi
        done
    }
    
    while true; do
        clear
        echo -e "\033[1;36m=========Manage Docker Container==========\033[0m"
        if [[ "$use_compose" == "true" ]]; then
            echo -e "\033[1;35mMode: Docker Compose\033[0m"
            echo -e "\033[1;37mFile: $compose_file\033[0m"
        else
            echo -e "\033[1;35mMode: Direct Docker\033[0m"
        fi
        echo -e "\033[1;36m==========================================\033[0m"
        echo -e "\033[1;32m1. Start Container\033[0m"
        echo -e "\033[1;32m2. Stop Container\033[0m"
        echo -e "\033[1;32m3. Restart Container\033[0m"
        echo -e "\033[1;32m4. Remove Container\033[0m"
        echo -e "\033[1;32m5. Check Status\033[0m"
        echo -e "\033[1;32m6. Show Environment Variables\033[0m"
        echo -e "\033[1;32m7. Show Volumes\033[0m"
        echo -e "\033[1;32m8. Show Logs\033[0m"
        echo -e "\033[1;32m9. Execute Shell in Container\033[0m"
        echo -e "\033[1;32m10. Inspect Container Info\033[0m"
        
        if [[ "$use_compose" == "true" ]]; then
            echo -e "\033[1;36m--- Docker Compose Options ---\033[0m"
            echo -e "\033[1;32m11. View Docker Compose Config\033[0m"
            echo -e "\033[1;32m12. Rebuild Container\033[0m"
            echo -e "\033[1;32m13. Edit Docker Compose File\033[0m"
            echo -e "\033[1;32m14. Edit Specific Section\033[0m"
            echo -e "\033[1;32m15. Backup Configuration\033[0m"
            echo -e "\033[1;32m16. Restore from Backup\033[0m"
            echo -e "\033[1;32m17. Validate Configuration\033[0m"
            echo -e "\033[1;32m18. Pull Latest Image\033[0m"
        fi
        
        echo -e "\033[1;36m------------------------------------------\033[0m"
        echo -e "\033[1;32m0. Return to Main Menu\033[0m"
        read -p "> " choice

        case $choice in
            1)
                echo -e "\033[1;32mStarting container 'snidust'...\033[0m"
                if [[ "$use_compose" == "true" ]]; then
                    docker_compose_cmd "up -d"
                else
                    docker start snidust 2>/dev/null || \
                    echo -e "\033[1;31mContainer not found\033[0m"
                fi
                ;;
            2)
                echo -e "\033[1;32mStopping container 'snidust'...\033[0m"
                if [[ "$use_compose" == "true" ]]; then
                    docker_compose_cmd "stop"
                else
                    docker stop snidust
                fi
                ;;
            3)
                echo -e "\033[1;32mRestarting container 'snidust'...\033[0m"
                if [[ "$use_compose" == "true" ]]; then
                    docker_compose_cmd "restart"
                else
                    docker restart snidust
                fi
                ;;
            4)
                echo -e "\033[1;31mWARNING: This will remove the container!\033[0m"
                read -p "Are you sure? (yes/no): " confirm
                if [[ "$confirm" == "yes" ]]; then
                    echo -e "\033[1;32mRemoving container 'snidust'...\033[0m"
                    if [[ "$use_compose" == "true" ]]; then
                        docker_compose_cmd "down"
                    else
                        docker rm -f snidust
                    fi
                else
                    echo -e "\033[1;33mOperation cancelled\033[0m"
                fi
                ;;
            5)
                echo -e "\033[1;32mChecking status...\033[0m"
                if [[ "$use_compose" == "true" ]]; then
                    docker_compose_cmd "ps"
                fi
                echo ""
                if docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -q snidust; then
                    docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E "(snidust|NAMES)"
                else
                    echo -e "\033[1;31mContainer 'snidust' does not exist\033[0m"
                fi
                ;;
            6)
                echo -e "\033[1;32mEnvironment variables:\033[0m"
                docker exec snidust printenv 2>/dev/null | sort || \
                echo -e "\033[1;31mContainer not running or doesn't exist\033[0m"
                ;;
            7)
                echo -e "\033[1;32mVolumes:\033[0m"
                docker inspect -f '{{range .Mounts}}{{printf "• Source: %s\n  Destination: %s\n  Mode: %s\n" .Source .Destination .Mode}}{{end}}' snidust 2>/dev/null || \
                echo -e "\033[1;31mContainer doesn't exist\033[0m"
                ;;
            8)
                echo -e "\033[1;32mLogs:\033[0m"
                read -p "Number of lines to show (default: 50): " lines
                lines=${lines:-50}
                docker logs --tail=$lines snidust 2>/dev/null || \
                echo -e "\033[1;31mContainer doesn't exist\033[0m"
                ;;
            9)
                echo -e "\033[1;32mStarting shell...\033[0m"
                docker exec -it snidust /bin/bash 2>/dev/null || \
                docker exec -it snidust /bin/sh 2>/dev/null || \
                echo -e "\033[1;31mContainer not running or doesn't exist\033[0m"
                ;;
            10)
                echo -e "\033[1;32mInspecting container:\033[0m"
                docker inspect snidust 2>/dev/null | head -100 || \
                echo -e "\033[1;31mContainer doesn't exist\033[0m"
                ;;
            
            # Docker Compose specific options
            11)
                if [[ "$use_compose" == "true" ]]; then
                    echo -e "\033[1;32mDocker Compose configuration:\033[0m"
                    echo "----------------------------------------"
                    cat "$compose_file"
                    echo "----------------------------------------"
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            12)
                if [[ "$use_compose" == "true" ]]; then
                    echo -e "\033[1;32mRebuilding container...\033[0m"
                    docker_compose_cmd "up -d --build"
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            13)
                if [[ "$use_compose" == "true" ]]; then
                    edit_docker_compose
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            14)
                if [[ "$use_compose" == "true" ]]; then
                    edit_specific_section
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            15)
                if [[ "$use_compose" == "true" ]]; then
                    backup_docker_compose
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            16)
                if [[ "$use_compose" == "true" ]]; then
                    restore_docker_compose
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            17)
                if [[ "$use_compose" == "true" ]]; then
                    echo -e "\033[1;32mValidating Docker Compose configuration...\033[0m"
                    docker_compose_cmd "config" || \
                    echo -e "\033[1;31mConfiguration validation failed\033[0m"
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            18)
                if [[ "$use_compose" == "true" ]]; then
                    echo -e "\033[1;32mPulling latest image...\033[0m"
                    docker_compose_cmd "pull"
                    read -p "Restart container with new image? (yes/no) [yes]: " restart_with_new
                    restart_with_new=${restart_with_new:-yes}
                    if [[ "$restart_with_new" == "yes" ]]; then
                        docker_compose_cmd "up -d"
                    fi
                else
                    echo -e "\033[1;31mOption only available with Docker Compose\033[0m"
                fi
                ;;
            0)
                echo -e "\033[1;34mReturning to Main Menu...\033[0m"
                return
                ;;
            *)
                echo -e "\033[1;31mInvalid option\033[0m"
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
    local compose_file="/root/snidust-docker-compose.yml"
    
    while true; do
        clear
        echo -e "\n\033[1;34mManage Service Cron Jobs:\033[0m"
        echo -e "\033[1;36m=================================\033[0m"
        echo -e " \033[1;34m1.\033[0m Add/Update Cron Job (Includes Restart & Start at Reboot)"
        echo -e " \033[1;34m2.\033[0m Remove Cron Job"
        echo -e " \033[1;34m3.\033[0m Edit Cron Jobs with Nano"
        echo -e " \033[1;34m4.\033[0m View Current Cron Jobs"
        echo -e " \033[1;34m5.\033[0m Test Cron Job Command"
        echo -e "\033[1;36m=================================\033[0m"
        echo -e " \033[1;31m0.\033[0m Return"

        read -p "Select an option: " cron_option

        case $cron_option in
            1)
                read -p "Enter the interval in hours to restart the service (1-23): " restart_interval
                if [[ ! "$restart_interval" =~ ^[1-9]$|^1[0-9]$|^2[0-3]$ ]]; then
                    echo -e "\033[1;31mInvalid input! Please enter a number between 1 and 23.\033[0m"
                else
                    # Check if docker-compose exists
                    local docker_cmd
                    if command -v docker-compose &> /dev/null; then
                        docker_cmd="docker-compose -f $compose_file"
                    elif docker compose version &> /dev/null; then
                        docker_cmd="docker compose -f $compose_file"
                    else
                        docker_cmd="docker"
                        echo -e "\033[1;33mWarning: Using regular docker commands (docker-compose not found)\033[0m"
                    fi
                    
                    # Define cron jobs - UPDATED FOR DOCKER COMPOSE
                    restart_cron="0 */$restart_interval * * * cd /root && $docker_cmd restart"
                    reboot_cron="@reboot sleep 30 && cd /root && $docker_cmd up -d"

                    # Remove any existing cron jobs for this service
                    (crontab -l 2>/dev/null | grep -v "docker.*snidust" | grep -v "docker-compose.*snidust") | crontab -

                    # Add the new cron jobs
                    (crontab -l 2>/dev/null; echo "# SniDust Auto Restart - Every $restart_interval hours"; echo "$restart_cron"; echo ""; echo "# SniDust Auto Start on Boot"; echo "$reboot_cron") | crontab -

                    echo -e "\033[1;32m✓ Cron job updated:\033[0m"
                    echo -e "\033[1;32m  • Restart snidust every $restart_interval hour(s)\033[0m"
                    echo -e "\033[1;32m  • Start snidust at system boot\033[0m"
                    echo ""
                    echo -e "\033[1;33mCommands used:\033[0m"
                    echo -e "\033[1;37m  $restart_cron\033[0m"
                    echo -e "\033[1;37m  $reboot_cron\033[0m"
                fi
                ;;
            2)
                echo -e "\033[1;31mAre you sure you want to remove all SniDust cron jobs?\033[0m"
                read -p "Type 'yes' to confirm: " confirm
                if [[ "$confirm" == "yes" ]]; then
                    # Remove all cron jobs related to snidust
                    (crontab -l 2>/dev/null | grep -v -E "(docker.*snidust|docker-compose.*snidust|SniDust)") | crontab -
                    echo -e "\033[1;32m✓ All SniDust cron jobs removed.\033[0m"
                else
                    echo -e "\033[1;33mOperation cancelled.\033[0m"
                fi
                ;;
            3)
                echo -e "\033[1;33mOpening crontab for manual editing...\033[0m"
                sleep 1
                crontab -e
                ;;
            4)
                echo -e "\033[1;33mCurrent cron jobs for SniDust:\033[0m"
                echo "----------------------------------------"
                crontab -l 2>/dev/null | grep -E -A1 -B1 "(docker.*snidust|docker-compose.*snidust|SniDust)" || \
                echo -e "\033[1;31mNo SniDust cron jobs found.\033[0m"
                echo "----------------------------------------"
                ;;
            5)
                echo -e "\033[1;33mTesting cron job command...\033[0m"
                if [[ -f "$compose_file" ]]; then
                    if command -v docker-compose &> /dev/null; then
                        echo -e "\033[1;32mTesting: docker-compose -f $compose_file restart\033[0m"
                        docker-compose -f "$compose_file" restart
                    elif docker compose version &> /dev/null; then
                        echo -e "\033[1;32mTesting: docker compose -f $compose_file restart\033[0m"
                        docker compose -f "$compose_file" restart
                    else
                        echo -e "\033[1;32mTesting: docker restart snidust\033[0m"
                        docker restart snidust
                    fi
                    echo -e "\033[1;32m✓ Test completed.\033[0m"
                else
                    echo -e "\033[1;31mDocker Compose file not found: $compose_file\033[0m"
                    echo -e "\033[1;33mTesting with regular docker command...\033[0m"
                    docker restart snidust
                fi
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
    local service_file="/etc/systemd/system/snidust.service"
    local compose_file="/root/snidust-docker-compose.yml"

    while true; do
        clear
        echo -e "\033[1;36m===== Manage SniDust Systemd Service =====\033[0m"
        echo ""
        echo -e "\033[1;32mPlease select an option:\033[0m"
        echo -e "\033[1;32m1. \033[0m Add/Enable SniDust service (Start on boot)"
        echo -e "\033[1;32m2. \033[0m Remove/Disable SniDust service"
        echo -e "\033[1;32m3. \033[0m Check SniDust service status"
        echo -e "\033[1;32m4. \033[0m Start SniDust service now"
        echo -e "\033[1;32m5. \033[0m Stop SniDust service now"
        echo -e "\033[1;32m6. \033[0m Restart SniDust service"
        echo -e "\033[1;32m7. \033[0m View service file"
        echo -e "\033[1;36m=========================================\033[0m"
        echo -e "\033[1;31m0. \033[0m Return to Main Menu"
        echo ""
        read -p "$(echo -e "\033[1;33mEnter your choice [0-7]: \033[0m")" option

        case $option in
            1)
                # Add/Enable Snidust service
                echo -e "\033[1;33mCreating systemd service for SniDust...\033[0m"
                
                # Determine which command to use
                local start_cmd="docker start snidust"
                local stop_cmd="docker stop snidust"
                local restart_cmd="docker restart snidust"
                
                if [[ -f "$compose_file" ]]; then
                    if command -v docker-compose &> /dev/null; then
                        start_cmd="cd /root && docker-compose -f $compose_file up -d"
                        stop_cmd="cd /root && docker-compose -f $compose_file down"
                        restart_cmd="cd /root && docker-compose -f $compose_file restart"
                    elif docker compose version &> /dev/null; then
                        start_cmd="cd /root && docker compose -f $compose_file up -d"
                        stop_cmd="cd /root && docker compose -f $compose_file down"
                        restart_cmd="cd /root && docker compose -f $compose_file restart"
                    fi
                fi
                
                # Create the service file
                sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=SniDust DNS Service
Requires=docker.service
After=docker.service network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/root
ExecStart=${start_cmd}
ExecStop=${stop_cmd}
ExecReload=${restart_cmd}
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

                # Reload systemd and enable service
                sudo systemctl daemon-reload
                sudo systemctl enable snidust.service
                
                # Ask if user wants to start now
                read -p "Start SniDust service now? (yes/no) [yes]: " start_now
                start_now=${start_now:-yes}
                
                if [[ "$start_now" == "yes" ]]; then
                    sudo systemctl start snidust.service
                    sleep 2
                fi
                
                # Show status
                echo ""
                echo -e "\033[1;32m✓ SniDust service has been configured:\033[0m"
                echo -e "\033[1;37m  • Service file: $service_file\033[0m"
                echo -e "\033[1;37m  • Start command: $start_cmd\033[0m"
                echo -e "\033[1;37m  • Auto-start on boot: Enabled\033[0m"
                
                if systemctl is-active snidust.service &>/dev/null; then
                    echo -e "\033[1;32m  • Current status: Running\033[0m"
                else
                    echo -e "\033[1;33m  • Current status: Stopped\033[0m"
                fi
                ;;
            2)
                # Remove/Disable Snidust service
                echo -e "\033[1;31mAre you sure you want to remove the SniDust service?\033[0m"
                read -p "Type 'yes' to confirm: " confirm
                
                if [[ "$confirm" == "yes" ]]; then
                    if [[ -f "$service_file" ]]; then
                        sudo systemctl stop snidust.service 2>/dev/null
                        sudo systemctl disable snidust.service 2>/dev/null
                        sudo rm -f "$service_file"
                        sudo systemctl daemon-reload
                        sudo systemctl reset-failed
                        echo -e "\033[1;32m✓ SniDust service has been removed.\033[0m"
                    else
                        echo -e "\033[1;31m✗ SniDust service file does not exist.\033[0m"
                    fi
                else
                    echo -e "\033[1;33mOperation cancelled.\033[0m"
                fi
                ;;
            3)
                # Check Snidust service status
                echo -e "\033[1;33mSniDust Service Status:\033[0m"
                echo "----------------------------------------"
                sudo systemctl status snidust.service --no-pager
                echo "----------------------------------------"
                
                # Show simple status
                if systemctl is-active snidust.service &>/dev/null; then
                    echo -e "\033[1;32m✓ Service is: ACTIVE\033[0m"
                elif systemctl is-enabled snidust.service &>/dev/null; then
                    echo -e "\033[1;33m✓ Service is: ENABLED but not running\033[0m"
                else
                    echo -e "\033[1;31m✗ Service is: NOT ACTIVE\033[0m"
                fi
                
                # Show if enabled on boot
                if systemctl is-enabled snidust.service &>/dev/null; then
                    echo -e "\033[1;32m✓ Auto-start on boot: ENABLED\033[0m"
                else
                    echo -e "\033[1;33m✗ Auto-start on boot: DISABLED\033[0m"
                fi
                ;;
            4)
                # Start service now
                echo -e "\033[1;32mStarting SniDust service...\033[0m"
                sudo systemctl start snidust.service
                sleep 2
                
                if systemctl is-active snidust.service &>/dev/null; then
                    echo -e "\033[1;32m✓ Service started successfully.\033[0m"
                else
                    echo -e "\033[1;31m✗ Failed to start service.\033[0m"
                    sudo systemctl status snidust.service --no-pager | tail -20
                fi
                ;;
            5)
                # Stop service now
                echo -e "\033[1;33mStopping SniDust service...\033[0m"
                sudo systemctl stop snidust.service
                sleep 2
                
                if systemctl is-active snidust.service &>/dev/null; then
                    echo -e "\033[1;31m✗ Failed to stop service.\033[0m"
                else
                    echo -e "\033[1;32m✓ Service stopped successfully.\033[0m"
                fi
                ;;
            6)
                # Restart service
                echo -e "\033[1;32mRestarting SniDust service...\033[0m"
                sudo systemctl restart snidust.service
                sleep 2
                
                if systemctl is-active snidust.service &>/dev/null; then
                    echo -e "\033[1;32m✓ Service restarted successfully.\033[0m"
                else
                    echo -e "\033[1;31m✗ Failed to restart service.\033[0m"
                fi
                ;;
            7)
                # View service file
                if [[ -f "$service_file" ]]; then
                    echo -e "\033[1;33mSniDust Service File: $service_file\033[0m"
                    echo "----------------------------------------"
                    cat "$service_file"
                    echo "----------------------------------------"
                else
                    echo -e "\033[1;31mService file does not exist: $service_file\033[0m"
                fi
                ;;
            0)
                echo -e "\033[1;34mReturning to Main Menu...\033[0m"
                return
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please choose between 0-7.\033[0m"
                ;;
        esac
        read -p "Press Enter to continue..."
    done
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
    local container_name="snidust"
    
    # Function to check container status with ASCII icons
    check_container_status() {
        if docker ps -q -f name="$container_name" > /dev/null 2>&1; then
            echo -e "\033[1;32m[RUNNING]\033[0m"
        elif docker ps -a -q -f name="$container_name" > /dev/null 2>&1; then
            echo -e "\033[1;33m[STOPPED]\033[0m"
        else
            echo -e "\033[1;31m[NOT CREATED]\033[0m"
        fi
    }
    
    # Function to check if file exists with ASCII icons
    check_file_status() {
        if [[ -f "$1" ]]; then
            echo -e "\033[1;32m[OK]\033[0m"
        else
            echo -e "\033[1;31m[MISSING]\033[0m"
        fi
    }
    
    # Function to check if port is in use with process info
    check_port_status() {
        local port=$1
        
        # First check with lsof
        local process_info=$(lsof -iTCP:$port -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==2')
        
        if [[ -n "$process_info" ]]; then
            local pid=$(echo "$process_info" | awk '{print $2}')
            local process_name=$(echo "$process_info" | awk '{print $1}')
            
            # Check if it's docker proxy (docker-pr)
            if [[ "$process_name" == "docker-pr" ]]; then
                # Try to find which container is using this port
                local container_info=$(docker ps --format "{{.Names}} {{.Ports}}" | grep ":$port->" | head -1)
                if [[ -n "$container_info" ]]; then
                    local container=$(echo "$container_info" | awk '{print $1}')
                    if [[ "$container" == "$container_name" ]]; then
                        echo -e "\033[1;32m[OK - Used by $container_name]\033[0m"
                    else
                        echo -e "\033[1;31m[BLOCKED - Used by: $container]\033[0m"
                    fi
                else
                    echo -e "\033[1;31m[BLOCKED - Docker proxy (PID: $pid)]\033[0m"
                fi
            else
                # Not docker, show process info
                local user=$(echo "$process_info" | awk '{print $3}')
                echo -e "\033[1;31m[BLOCKED - $process_name (PID: $pid)]\033[0m"
            fi
        else
            # Also check with ss (socket statistics) as fallback
            if ss -tulpn | grep -q ":$port "; then
                echo -e "\033[1;31m[BLOCKED - Unknown process]\033[0m"
            else
                echo -e "\033[1;32m[FREE]\033[0m"
            fi
        fi
    }
    
    # Function to get detailed port info for warning message
    get_port_warnings() {
        local warnings=""
        local ports=(53 80 443)
        local has_warnings=false
        
        for port in "${ports[@]}"; do
            local process_info=$(lsof -iTCP:$port -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==2')
            if [[ -n "$process_info" ]]; then
                local pid=$(echo "$process_info" | awk '{print $2}')
                local process_name=$(echo "$process_info" | awk '{print $1}')
                
                # Check if it's our own container
                local is_our_container=false
                if [[ "$process_name" == "docker-pr" ]]; then
                    local container_info=$(docker ps --format "{{.Names}} {{.Ports}}" | grep ":$port->" | head -1)
                    if [[ -n "$container_info" ]]; then
                        local container=$(echo "$container_info" | awk '{print $1}')
                        [[ "$container" == "$container_name" ]] && is_our_container=true
                    fi
                fi
                
                if [[ "$is_our_container" == false ]]; then
                    has_warnings=true
                    warnings+="Port $port: $process_name (PID: $pid) "
                fi
            fi
        done
        
        if [[ "$has_warnings" == true ]]; then
            echo "$warnings"
        fi
    }

    while true; do
        clear
        
        # Header with ASCII border
        echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
        echo -e "\033[1;36m|                 CREATE CUSTOM DNS                           |\033[0m"
        echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
        
        # Status bar
        echo -e "\033[1;37m|  Status: Container $(check_container_status)\033[0m"
        echo -e "\033[1;37m|  Config Files:\033[0m"
        echo -e "\033[1;37m|    Domains: $(check_file_status "/root/99-custom.lst")  Clients: $(check_file_status "/root/myacls.acl")"
        echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
        
        # REAL-TIME PORT STATUS
        echo -e "\033[1;37m|  Port Status (Real-time):\033[0m"
        echo -e "\033[1;37m|    Port 53  (DNS):   $(check_port_status 53)\033[0m"
        echo -e "\033[1;37m|    Port 80  (HTTP):  $(check_port_status 80)\033[0m"
        echo -e "\033[1;37m|    Port 443 (HTTPS): $(check_port_status 443)\033[0m"
        echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
        
        # Show warnings only if ports are used by other processes
        local port_warnings=$(get_port_warnings)
        if [[ -n "$port_warnings" ]]; then
            echo -e "\033[1;37m|  [!] Warning: $port_warnings\033[0m"
            echo -e "\033[1;37m|  [i] Use 'Change server DNS' from main menu to free port 53\033[0m"
            echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
        fi
        
        # Menu options
        echo -e "\033[1;37m|  \033[1;32m1.\033[0m Create DNS Server\033[0m"
        echo -e "\033[1;37m|  \033[1;32m2.\033[0m Edit Custom Domains\033[0m"
        echo -e "\033[1;37m|  \033[1;32m3.\033[0m Manage Docker Container\033[0m"
        echo -e "\033[1;37m|  \033[1;32m4.\033[0m Check Ports Status (Detailed)\033[0m"
        echo -e "\033[1;37m|  \033[1;32m5.\033[0m Edit Allowed Clients\033[0m"
        echo -e "\033[1;36m+-- Auto Management --------------------------------------------+\033[0m"
        echo -e "\033[1;37m|  \033[1;32m6.\033[0m Auto Start/Restart (Cron)\033[0m"
        echo -e "\033[1;37m|  \033[1;32m7.\033[0m Auto Start on Reboot (Systemd)\033[0m"
        echo -e "\033[1;36m+-- Quick Actions ----------------------------------------------+\033[0m"
        echo -e "\033[1;37m|  \033[1;32m8.\033[0m Reload Clients IPs\033[0m"
        echo -e "\033[1;37m|  \033[1;32m9.\033[0m Reload Custom Domains\033[0m"
        echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
        echo -e "\033[1;37m|  \033[1;31m0.\033[0m Return to Main Menu\033[0m"
        echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
        
        echo ""
        echo -en "\033[1;33m> Select option [0-9]: \033[0m"
        read -p "" choice
        echo ""

        case $choice in
            1) 
                # Check if ports are free before creating DNS
                local can_create=true
                local ports=(53 80 443)
                local blocked_ports=""
                
                for port in "${ports[@]}"; do
                    local process_info=$(lsof -iTCP:$port -sTCP:LISTEN -P -n 2>/dev/null | awk 'NR==2')
                    if [[ -n "$process_info" ]]; then
                        local process_name=$(echo "$process_info" | awk '{print $1}')
                        local pid=$(echo "$process_info" | awk '{print $2}')
                        
                        # Check if it's our own container
                        local is_our_container=false
                        if [[ "$process_name" == "docker-pr" ]]; then
                            local container_info=$(docker ps --format "{{.Names}} {{.Ports}}" | grep ":$port->" | head -1)
                            if [[ -n "$container_info" ]]; then
                                local container=$(echo "$container_info" | awk '{print $1}')
                                [[ "$container" == "$container_name" ]] && is_our_container=true
                            fi
                        fi
                        
                        if [[ "$is_our_container" == false ]]; then
                            can_create=false
                            blocked_ports+="  - Port $port: $process_name (PID: $pid)\n"
                        fi
                    fi
                done
                
                if [[ "$can_create" == false ]]; then
                    echo -e "\033[1;31m+-------------------------------------------------------------+\033[0m"
                    echo -e "\033[1;31m|                 PORT CONFLICT DETECTED                      |\033[0m"
                    echo -e "\033[1;31m+-------------------------------------------------------------+\033[0m"
                    echo ""
                    echo -e "\033[1;31mCannot create DNS server. The following ports are in use:\033[0m"
                    echo -e "$blocked_ports"
                    echo -e "\033[1;33mPlease free these ports before creating the DNS server.\033[0m"
                    echo -e "\033[1;34mYou can use option 4 to see detailed port information.\033[0m"
                    read -p "Press Enter to continue..."
                else
                    echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                    echo -e "\033[1;36m|                     CREATE DNS SERVER                       |\033[0m"
                    echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                    echo ""
                    create_custom_dns 
                fi
                ;;
            2) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|                   EDIT CUSTOM DOMAINS                       |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                manage_custom_domains 
                ;;
            3) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|                MANAGE DOCKER CONTAINER                      |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                manage_container 
                ;;
            4) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|                   CHECK PORTS STATUS                        |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                check_ports 
                read -p "Press Enter to continue..."
                ;;
            5) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|                  EDIT ALLOWED CLIENTS                       |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                edit_clients 
                ;;
            6) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|                AUTO START/RESTART (CRON)                    |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                auto_restart 
                ;;
            7) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|              AUTO START ON REBOOT (SYSTEMD)                 |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                manage_snidust_service
                read -p "Press Enter to continue..."
                ;;
            8) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|                    RELOAD CLIENTS IPS                       |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                reload_acls
                read -p "Press Enter to continue..."
                ;;
            9) 
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo -e "\033[1;36m|                  RELOAD CUSTOM DOMAINS                      |\033[0m"
                echo -e "\033[1;36m+-------------------------------------------------------------+\033[0m"
                echo ""
                reload_domains
                read -p "Press Enter to continue..."
                ;;
            0) 
                echo -e "\033[1;33mReturning to Main Menu...\033[0m"
                sleep 1
                return 
                ;;
            *) 
                echo -e "\033[1;31mInvalid option! Please select 0-9.\033[0m"
                sleep 1
                ;;
        esac
    done
}

create_dns
