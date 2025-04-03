#!/bin/bash

# Path to HAProxy config file (update this as per your setup)
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
BACKUP_DIR="/etc/haproxy/backups"  # Backup directory
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
}
# Ensure backup directory exists
mkdir -p $BACKUP_DIR

install_haproxy() {
  echo -e "\033[1;34m--- Checking HAProxy Installation ---\033[0m"
  
  # Check if HAProxy is already installed
  if command -v haproxy &> /dev/null; then
    echo -e "\033[1;32mHAProxy is already installed.\033[0m"
    echo -e "Version: \033[1;36m$(haproxy -v | head -n 1)\033[0m"
    sleep 1

  fi

  # If not installed, proceed with installation
  echo -e "\033[1;33mHAProxy not found. Installing now...\033[0m"
  if sudo apt install -y haproxy; then
    echo -e "\033[1;32mHAProxy installed successfully!\033[0m"
    echo -e "Version: \033[1;36m$(haproxy -v | head -n 1)\033[0m"
    sleep 1
  else
    echo -e "\033[1;31mFailed to install HAProxy!\033[0m"
    sleep 1
    return 1
  fi
  

}

# Function to remove HAProxy
remove_haproxy() {
  echo -e "\033[1;34m--- Removing HAProxy ---\033[0m"
  sudo apt remove --purge -y haproxy
  sudo apt autoremove -y
  sudo rm -f $HAPROXY_CONFIG
  echo -e "\033[1;32mHAProxy removed successfully!\033[0m"
  read -p "Press Enter to continue..."
}

create_backend() {
  echo -e "\033[1;34m--- Create Frontend with Multiple Backends (SNI Routing) ---\033[0m"

  # Ensure global/defaults sections exist
  if ! grep -q "^global" "$HAPROXY_CONFIG"; then
    {
      echo "global"
      echo "    chroot /var/lib/haproxy"
      echo "    stats socket /run/haproxy/admin.sock mode 660 level admin"
      echo "    stats timeout 30s"
      echo "    user haproxy"
      echo "    group haproxy"
      echo "    daemon"
      echo -e "\ndefaults"
      echo "    option dontlognull"
      echo "    option dontlog-normal"
      echo "    no log"
      echo "    timeout connect 5000"
      echo "    timeout client 50000"
      echo "    timeout server 50000"
    } >> "$HAPROXY_CONFIG"
  fi

  # Frontend configuration
  while true; do
    # Get frontend details
    while true; do
      read -p "Enter Bind Port (listen port) [default: 443]: " frontend_port
      frontend_port=${frontend_port:-443}
      
      if grep -q "bind \*:$frontend_port" "$HAPROXY_CONFIG"; then
        echo -e "\033[1;31mError: Port $frontend_port already used in HAProxy!\033[0m"
        grep -n "bind \*:$frontend_port" "$HAPROXY_CONFIG"
        continue
      fi
      
      if lsof -i :$frontend_port >/dev/null 2>&1 || ss -tuln | grep -q ":$frontend_port"; then
        echo -e "\033[1;31mError: Port $frontend_port already in use by system!\033[0m"
        lsof -i :$frontend_port || ss -tulp | grep ":$frontend_port"
        continue
      fi
      break
    done

    frontend_name="frontend_${frontend_port}"
    {
      echo -e "\nfrontend $frontend_name"
      echo "  mode tcp"
      echo "  bind *:$frontend_port"
      echo "  tcp-request inspect-delay 5s"
      echo "  tcp-request content accept if { req_ssl_hello_type 1 }"
    } >> "$HAPROXY_CONFIG"

    # Backend configuration loop
    backend_count=0
    while true; do
      ((backend_count++))
      echo -e "\n\033[1;36m--- Configuring Backend #$backend_count for $frontend_name ---\033[0m"
      
      # Generate backend name
      backend_name="${frontend_name}_backend_${backend_count}"
      read -p "Enter backend name (default: $backend_name): " user_backend_name
      backend_name=${user_backend_name:-$backend_name}

      # Remove existing config
      sed -i "/^backend $backend_name/,/^$/d" "$HAPROXY_CONFIG"

      # Backend mode
      echo "Select backend mode:"
      echo "1) TCP"
      echo "2) UDP"
      read -p "Enter choice (default: TCP): " backend_mode_choice
      case $backend_mode_choice in
        1) backend_mode="tcp" ;;
        2) backend_mode="udp" ;;
        *) backend_mode="tcp" ;;
      esac

      # Multiple servers input with port for each IP
      server_entries=()
      while true; do
        echo -e "\n\033[1;36m--- Adding Server #$((${#server_entries[@]}+1)) ---\033[0m"
        
        # Get IP
        while true; do
          read -p "Enter Server IP (leave empty when done): " ip
          [ -z "$ip" ] && break
          
          ip=$(echo "$ip" | xargs) # Trim whitespace
          if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            : # Valid IPv4
          elif [[ $ip =~ .*:.* ]]; then
            ip="[$ip]" # Wrap IPv6
          else
            echo -e "\033[1;31mInvalid IP address format. Please try again.\033[0m"
            continue
          fi
          
          # Get Port for this IP
          while true; do
            read -p "Enter Port for $ip: " port
            
            
            if [[ $port =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
              server_entries+=("$ip:$port")
              break
            else
              echo -e "\033[1;31mInvalid port number (1-65535). Please try again.\033[0m"
            fi
          done
          
          break
        done
        
        # Break if no IP entered or user doesn't want to add more
        [ -z "$ip" ] && break
        [ ${#server_entries[@]} -ge 1 ] && {
          read -p "Add another server? (y/n) [default: n]: " add_more
          [[ "$add_more" != "y" ]] && break
        }
      done

      # Check if we have any servers
      if [ ${#server_entries[@]} -eq 0 ]; then
        echo -e "\033[1;31mNo servers added. Skipping configuration.\033[0m"
        continue 2
      fi

      # Display the collected servers
      echo -e "\n\033[1;32mConfigured Servers:\033[0m"
      for entry in "${server_entries[@]}"; do
        echo -e "  - \033[1;36m$entry\033[0m"
      done

      # Load balancing configuration for multiple IPs
      if [ ${#server_entries[@]} -gt 1 ]; then
        echo -e "\n\033[1;33mMultiple servers detected. Configuring load balancing...\033[0m"
        echo "Select load balancing algorithm:"
        echo "1) roundrobin (default)"
        echo "2) leastconn"
        echo "3) source"
        echo "4) static-rr"
        read -p "Your choice [1-4]: " lb_choice
        
        case $lb_choice in
          1) lb_method="roundrobin" ;;
          2) lb_method="leastconn" ;;
          3) lb_method="source" ;;
          4) lb_method="static-rr" ;;
          *) lb_method="roundrobin" ;;
        esac
      else
        lb_method=""
      fi

      # SNI configuration
      read -p "Enter SNI value (e.g., example.com): " sni_value
      echo "SNI Match Type:"
      echo "1) Ends with (example.com matches *.example.com)"
      echo "2) Exact match"
      echo "3) Regex match"
      read -p "Choice [default: 1]: " sni_choice
      case $sni_choice in
        1) sni_condition="{ req_ssl_sni -m end $sni_value }" ;;
        2) sni_condition="{ req_ssl_sni -m str $sni_value }" ;;
        3) sni_condition="{ req_ssl_sni -m reg $sni_value }" ;;
        *) sni_condition="{ req_ssl_sni -m end $sni_value }" ;;
      esac

      # Add backend configuration
      {
        echo -e "\nbackend $backend_name"
        echo "  mode $backend_mode"
        [ -n "$lb_method" ] && echo "  balance $lb_method"
        
        server_num=1
        for entry in "${server_entries[@]}"; do
          echo "  server server${server_num} ${entry} check"
          ((server_num++))
        done
      } >> "$HAPROXY_CONFIG"

      # Add SNI rule to frontend
      sed -i "/^frontend $frontend_name/a \  use_backend $backend_name if $sni_condition" "$HAPROXY_CONFIG"

      # Add another backend?
      read -p "Add another backend to this frontend? (y/n) [default: n]: " add_another
      [[ "$add_another" != "y" ]] && break
    done

    # Add default backend if not exists
    if ! grep -q "^backend default_backend" "$HAPROXY_CONFIG"; then
      read -p "Configure fallback backend? (y/n) [default: n]: " add_fallback
      if [[ "$add_fallback" == "y" ]]; then
        read -p "Fallback IP [default: 127.0.0.1]: " fallback_ip
        fallback_ip=${fallback_ip:-127.0.0.1}
        read -p "Fallback Port [default: 443]: " fallback_port
        fallback_port=${fallback_port:-443}
        
        {
          echo -e "\nbackend default_backend"
          echo "  mode tcp"
          echo "  server fallback $fallback_ip:$fallback_port"
        } >> "$HAPROXY_CONFIG"
        
        sed -i "/^frontend $frontend_name/a \  default_backend default_backend" "$HAPROXY_CONFIG"
      fi
    else
      sed -i "/^frontend $frontend_name/a \  default_backend default_backend" "$HAPROXY_CONFIG"
    fi

    # Add another frontend?
    read -p "Create another frontend? (y/n) [default: n]: " another_frontend
    [[ "$another_frontend" != "y" ]] && break
  done

  echo -e "\033[1;32m\nConfiguration completed successfully!\033[0m"
  restart_haproxy
}
simple_port_forward() {
  echo -e "\033[1;34m--- Create Port Forwarding with Load Balancing ---\033[0m"

  # Ensure global/defaults sections exist
  if ! grep -q "^global" "$HAPROXY_CONFIG"; then
    {
      echo "global"
      echo "    chroot /var/lib/haproxy"
      echo "    stats socket /run/haproxy/admin.sock mode 660 level admin"
      echo "    stats timeout 30s"
      echo "    user haproxy"
      echo "    group haproxy"
      echo "    daemon"
      echo -e "\ndefaults"
      echo "    option dontlognull"
      echo "    option dontlog-normal"
      echo "    no log"
      echo "    timeout connect 5000"
      echo "    timeout client 50000"
      echo "    timeout server 50000"
    } >> "$HAPROXY_CONFIG"
  fi

  while true; do
    # Get frontend details
    while true; do
      read -p "Enter Listen Port [default 8080]: " listen_port
      listen_port=${listen_port:-8080}
      
      if grep -q "bind \*:$listen_port" "$HAPROXY_CONFIG"; then
        echo -e "\033[1;31mError: Port $listen_port already used in HAProxy!\033[0m"
        grep -n "bind \*:$listen_port" "$HAPROXY_CONFIG"
        continue
      fi
      
      if lsof -i :$listen_port >/dev/null 2>&1 || ss -tuln | grep -q ":$listen_port"; then
        echo -e "\033[1;31mError: Port $listen_port already in use by system!\033[0m"
        lsof -i :$listen_port || ss -tulp | grep ":$listen_port"
        continue
      fi
      break
    done

    frontend_name="pf_${listen_port}"
    
    # Get backend details
    server_entries=()
    while true; do
      echo -e "\n\033[1;36m--- Adding Server #$((${#server_entries[@]}+1)) ---\033[0m"
      
      # Get IP
      while true; do
        read -p "Enter Destination (kharej) IP: " ip
        [ -z "$ip" ] && break
        
        ip=$(echo "$ip" | xargs) # Trim whitespace
        if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
          : # Valid IPv4
        elif [[ $ip =~ .*:.* ]]; then
          ip="[$ip]" # Wrap IPv6
        else
          echo -e "\033[1;31mInvalid IP address format. Please try again.\033[0m"
          continue
        fi
        
        # Get Port for this IP
        while true; do
          read -p "Enter Destination (config) Port for $ip: " dest_port
          
          
          if [[ $dest_port =~ ^[0-9]+$ ]] && [ "$dest_port" -ge 1 ] && [ "$dest_port" -le 65535 ]; then
            break
          else
            echo -e "\033[1;31mInvalid port number (1-65535). Please try again.\033[0m"
          fi
        done
        
        server_entries+=("$ip:$dest_port")
        break
      done
      
      # Break if no IP entered or user doesn't want to add more
      [ -z "$ip" ] && break
      [ ${#server_entries[@]} -ge 1 ] && {
        read -p "Add another server? (y/n) [defualt no]: " add_more
        [[ "$add_more" != "y" ]] && break
      }
    done

    # Check if we have any servers
    if [ ${#server_entries[@]} -eq 0 ]; then
      echo -e "\033[1;31mNo servers added. Skipping this port forward.\033[0m"
      continue
    fi

    # Configure load balancing if multiple servers
    lb_method=""
    if [ ${#server_entries[@]} -gt 1 ]; then
      echo -e "\n\033[1;33mMultiple servers detected. Configuring load balancing...\033[0m"
      echo "Select load balancing algorithm:"
      echo "1) roundrobin (default)"
      echo "2) leastconn"
      echo "3) source"
      echo "4) static-rr"
      read -p "Enter choice [1-4]: " lb_choice
      
      case $lb_choice in
        1) lb_method="roundrobin" ;;
        2) lb_method="leastconn" ;;
        3) lb_method="source" ;;
        4) lb_method="static-rr" ;;
        *) lb_method="roundrobin" ;;
      esac
    fi

    # Select mode
    echo -e "\nSelect forwarding mode:"
    echo "1) TCP (default)"
    echo "2) UDP"
    read -p "Enter choice: " mode_choice
    case $mode_choice in
      2) mode="udp" ;;
      *) mode="tcp" ;;
    esac

    # Generate names
    backend_name="${frontend_name}_backend"

    # Add frontend
    {
      echo -e "\nfrontend $frontend_name"
      echo "  mode $mode"
      echo "  bind *:$listen_port"
      echo "  default_backend $backend_name"
    } >> "$HAPROXY_CONFIG"

    # Add backend with all servers
    {
      echo -e "\nbackend $backend_name"
      echo "  mode $mode"
      [ -n "$lb_method" ] && echo "  balance $lb_method"
      
      for i in "${!server_entries[@]}"; do
        echo "  server server$((i+1)) ${server_entries[i]} check"
      done
    } >> "$HAPROXY_CONFIG"

    # Display configuration summary
    echo -e "\n\033[1;32mPort forwarding configured:\033[0m"
    echo -e "  Listen Port: \033[1;36m$listen_port\033[0m"
    echo -e "  Forwarding to:"
    for entry in "${server_entries[@]}"; do
      echo -e "    - \033[1;36m$entry\033[0m"
    done
    [ -n "$lb_method" ] && echo -e "  Load Balancing: \033[1;36m$lb_method\033[0m"
    echo -e "  Mode: \033[1;36m$mode\033[0m"

    read -p "Create another port forward? (y/n) [defualt no]: " another
    [[ "$another" != "y" ]] && break
  done

  echo -e "\033[1;32m\nPort forwarding setup completed!\033[0m"
  restart_haproxy
}
clear_haproxy_config() {
    echo -e "\033[1;31m[WARNING] This will COMPLETELY CLEAR your HAProxy configuration!\033[0m"
    echo -e "\033[1;33mAll existing configuration will be removed.\033[0m"
    
    # Show current config size
    current_size=$(wc -l < "$HAPROXY_CONFIG")
    echo -e "\nCurrent configuration size: \033[1;36m$current_size lines\033[0m"
    
    # Show last modification time
    last_modified=$(stat -c "%y" "$HAPROXY_CONFIG")
    echo "Last modified: $last_modified"
    
    # Double confirmation
    read -p $'\033[1;31mAre you ABSOLUTELY sure? (type \'CLEAR\' to confirm): \033[0m' confirm
    if [[ "$confirm" != "CLEAR" ]]; then
        echo -e "\033[1;32mOperation cancelled. Configuration remains unchanged.\033[0m"
        return
    fi
    
    # Create backup
    backup_file="${HAPROXY_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$HAPROXY_CONFIG" "$backup_file"
    echo -e "\n\033[1;35mBackup created: $backup_file\033[0m"
    
    # Completely empty the file
    > "$HAPROXY_CONFIG"
    
    # Verify
    if [[ -s "$HAPROXY_CONFIG" ]]; then
        echo -e "\033[1;31mError: Failed to clear configuration!\033[0m"
        return 1
    fi
    
    echo -e "\033[1;32m\nHAProxy configuration completely cleared!\033[0m"
    echo -e "New configuration size: \033[1;36m0 lines\033[0m"
    
    # Offer to restart
    read -p $'\033[1;36mRestart HAProxy now? (y/n) [defualt no]: \033[0m' restart
    if [[ "$restart" == "y" ]]; then
        if systemctl restart haproxy; then
            echo -e "\033[1;32mHAProxy restarted successfully!\033[0m"
        else
            echo -e "\033[1;31mFailed to restart HAProxy!\033[0m"
        fi
    fi
    
    # Show warning about empty config
    echo -e "\n\033[1;33m[IMPORTANT] Your HAProxy is now running with empty configuration!"
    echo -e "You must add new configuration before it can properly route traffic.\033[0m"
    read -p "Press Enter to continue... "
}

# Function to backup HAProxy config
backup_haproxy() {
  echo -e "\033[1;34m--- Backing up HAProxy Configuration ---\033[0m"
  
  # Generate a timestamp
  timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  backup_file="$BACKUP_DIR/haproxy.cfg.backup-$timestamp"

  # Backup the config file
  sudo cp $HAPROXY_CONFIG $backup_file
  echo -e "\033[1;32mBackup created successfully: $backup_file\033[0m"
  read -p "Press Enter to continue... "

}

# Function to restore HAProxy config from a backup
restore_haproxy() {
  echo -e "\033[1;34m--- Restoring HAProxy Configuration ---\033[0m"

  # List available backups
  echo -e "\033[1;34mAvailable Backups:\033[0m"
  ls -1 $BACKUP_DIR/haproxy.cfg.backup-* | nl
  
  # Prompt user to select a backup to restore
  read -p "Enter the number of the backup to restore: " backup_number
  backup_file=$(ls -1 $BACKUP_DIR/haproxy.cfg.backup-* | sed -n "${backup_number}p")
  
  if [[ -f $backup_file ]]; then
    sudo cp $backup_file $HAPROXY_CONFIG
    echo -e "\033[1;32mConfiguration restored from: $backup_file\033[0m"
  else
    echo -e "\033[1;31mInvalid backup selection. Restoration failed.\033[0m"
    read -p "Press Enter to continue... "
  fi
  

}

# Function to restart HAProxy service
restart_haproxy() {
  echo -e "\033[1;34m--- Restarting HAProxy Service ---\033[0m"
  if sudo systemctl restart haproxy; then
    echo -e "\033[1;32mHAProxy service restarted successfully!\033[0m"
    read -p "Press Enter to continue... "
  else
    echo -e "\033[1;31mFailed to restart HAProxy service. Please check the service status or logs.\033[0m"
    read -p "Press Enter to continue... "
    return 1  # Indicate failure
  fi
  

}

# Function to restart HAProxy service
reload_haproxy() {
  echo -e "\033[1;34m--- Reloading HAProxy Service ---\033[0m"
  if sudo systemctl reload haproxy; then
    echo -e "\033[1;32mHAProxy service reloaded successfully!\033[0m"
    read -p "Press Enter to continue... "
  else
    echo -e "\033[1;31mFailed to reload HAProxy service. Please check the service status or logs.\033[0m"
    read -p "Press Enter to continue... "
    return 1  # Indicate failure
  fi
  

}

# Function to stop HAProxy service
stop_haproxy() {
  echo -e "\033[1;34m--- Stopping HAProxy Service ---\033[0m"
  if sudo systemctl stop haproxy; then
    echo -e "\033[1;32mHAProxy service stopped successfully!\033[0m"
    read -p "Press Enter to continue... "
  else
    echo -e "\033[1;31mFailed to stop HAProxy service. Please check the service status or logs.\033[0m"
    read -p "Press Enter to continue... "
    return 1  # Indicate failure
  fi
  

}

# Function to start HAProxy service
start_haproxy() {
  echo -e "\033[1;34m--- Starting HAProxy Service ---\033[0m"
  if sudo systemctl start haproxy; then
    echo -e "\033[1;32mHAProxy service started successfully!\033[0m"
    read -p "Press Enter to continue... "
  else
    echo -e "\033[1;31mFailed to start HAProxy service. Please check the service status or logs.\033[0m"
    read -p "Press Enter to continue... "
    return 1  # Indicate failure
  fi
  

}

# Function to check HAProxy service status
check_haproxy_status() {
  echo -e "\033[1;34m--- Checking HAProxy Service Status ---\033[0m"
  if systemctl is-active --quiet haproxy; then
    echo -e "\033[1;32mHAProxy is running.\033[0m"
    read -p "Press Enter to continue... "
  else
    echo -e "\033[1;31mHAProxy is not running. Please check the service or start it.\033[0m"
    read -p "Press Enter to continue... "
    return 1  # Indicate failure
  fi

}


# Function to edit HAProxy configuration
edit_haproxy() {
  echo -e "\033[1;34m--- Editing HAProxy Configuration ---\033[0m"
  sudo nano $HAPROXY_CONFIG
}

auto_restart_haproxy() {
    echo -e "\n\033[1;34mManage Service Cron Jobs:\033[0m"
    echo -e " \033[1;34m1.\033[0m Add/Update Cron Job"
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
                # Define cron job for restarting the service
                cron_job="0 */$restart_interval * * * /bin/systemctl restart haproxy"

                # Remove any existing cron job for this service
                (crontab -l 2>/dev/null | grep -v "/bin/systemctl restart haproxy") | crontab -

                # Add the new cron job
                (crontab -l 2>/dev/null; echo "$cron_job") | crontab -

                echo -e "\033[1;32mCron job updated: Restart haproxy every $restart_interval hour(s).\033[0m"
            fi
            ;;
        2)
            # Remove the cron job related to the service
            crontab -l 2>/dev/null | grep -v "/bin/systemctl restart haproxy" | crontab -
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
    }
    
haproxy_menu() {
  while true; do
    clear
    # Check if HAProxy is installed
    if command -v haproxy &> /dev/null; then
      haproxy_status="\033[1;32m(Installed)\033[0m"
      current_version=$(haproxy -v | head -n 1 | awk '{print $3}')
    else
      haproxy_status="\033[1;31m(Not Installed)\033[0m"
      current_version=""
    fi

    echo -e "\n\033[1;34m--- HAProxy Management---\033[0m"
    echo -e "\033[1;34mHAProxy: $haproxy_status\033[0m"
    [ -n "$current_version" ] && echo -e "\033[1;36mVersion: $current_version\033[0m"
    echo -e "\033[1;33mInclude Multi-port and load balancing\033[0m"
    echo -e "\n\033[1;32m1.\033[0m Install HAProxy"
    
    # Only show configuration options if installed
    if [ -n "$current_version" ]; then
      echo -e "\033[1;32m2.\033[0m Port Forwarding (simple mode) "
      echo -e "\033[1;32m3.\033[0m Port Forwarding (SNI mode)"
      echo -e "\033[1;32m4.\033[0m Check HAProxy Status"
      echo -e "\033[1;32m5.\033[0m Backup HAProxy Configuration"
      echo -e "\033[1;32m6.\033[0m Restore HAProxy Configuration"
      echo -e "\033[1;32m7.\033[0m Restart HAProxy"
      echo -e "\033[1;32m8.\033[0m Start HAProxy"
      echo -e "\033[1;32m9.\033[0m Stop HAProxy"
      echo -e "\033[1;32m10.\033[0m Edit HAProxy Configuration with nano"
      echo -e "\033[1;32m11.\033[0m Reload HAProxy"
      echo -e "\033[1;32m12.\033[0m Clear HAProxy Configuration"
      echo -e "\033[1;32m13.\033[0m Remove HAProxy"
      echo -e "\033[1;32m14.\033[0m Auto restart haproxy"
    else
      echo -e "\033[1;90m2. Port Forwarding (simple mode) [Install HAProxy first]\033[0m"
      echo -e "\033[1;90m3. Port Forwarding (SNI mode) [Install HAProxy first]\033[0m"
      echo -e "\033[1;90m4. Check HAProxy Status [Install HAProxy first]\033[0m"
      echo -e "\033[1;90m5-13. [Install HAProxy first]\033[0m"
    fi
    
    echo -e "\033[1;31m0.\033[0m Exit"
    read -p "Select an option: " option

    case $option in
      1) install_haproxy ;;
      2) 
        if [ -n "$current_version" ]; then 
          simple_port_forward 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      3) 
        if [ -n "$current_version" ]; then 
          create_backend 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      4) 
        if [ -n "$current_version" ]; then 
          check_haproxy_status 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      5) 
        if [ -n "$current_version" ]; then 
          backup_haproxy 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      6) 
        if [ -n "$current_version" ]; then 
          restore_haproxy 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      7) 
        if [ -n "$current_version" ]; then 
          restart_haproxy 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      8) 
        if [ -n "$current_version" ]; then 
          start_haproxy 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      9) 
        if [ -n "$current_version" ]; then 
          stop_haproxy 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      10) 
        if [ -n "$current_version" ]; then 
          edit_haproxy 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      11) 
        if [ -n "$current_version" ]; then 
          reload_haproxy 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      12) 
        if [ -n "$current_version" ]; then 
          clear_haproxy_config 
        else
          echo -e "\033[1;31mPlease install HAProxy first!\033[0m"
          sleep 2
        fi 
        ;;
      13) 
        if [ -n "$current_version" ]; then 
          remove_haproxy 
        else
          echo -e "\033[1;31mHAProxy is not installed!\033[0m"
          sleep 2
        fi 
        ;;
        
      14)
              if [ -n "$current_version" ]; then 
          auto_restart_haproxy 
        else
          echo -e "\033[1;31mHAProxy is not installed!\033[0m"
          sleep 2
        fi 
       ;;
      0) break ;;
      *) echo -e "\033[1;31mInvalid option!\033[0m"; sleep 1 ;;
    esac
  done
}
check_root
install_haproxy
haproxy_menu
