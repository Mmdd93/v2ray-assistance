#!/bin/bash

# Path to HAProxy config file (update this as per your setup)
HAPROXY_CONFIG="/etc/haproxy/haproxy.cfg"
BACKUP_DIR="/etc/haproxy/backups"  # Backup directory

# Ensure backup directory exists
mkdir -p $BACKUP_DIR

# Function to install HAProxy
install_haproxy() {
  echo -e "\033[1;34m--- Installing HAProxy ---\033[0m"
  sudo apt update
  sudo apt install -y haproxy
  echo -e "\033[1;32mHAProxy installed successfully!\033[0m"
  read -p "Press Enter to continue: "

}

# Function to remove HAProxy
remove_haproxy() {
  echo -e "\033[1;34m--- Removing HAProxy ---\033[0m"
  sudo apt remove --purge -y haproxy
  sudo apt autoremove -y
  sudo rm -f $HAPROXY_CONFIG
  echo -e "\033[1;32mHAProxy removed successfully!\033[0m"
  read -p "Press Enter to continue: "
}

create_backend() {
  echo -e "\033[1;34m--- Create Backend and Frontend Configuration ---\033[0m"

  while true; do
    # Generate a random backend name by default (e.g., backend_12)
  backend_name="backend_$(shuf -i 1-100 -n 1)"  # Random number between 1 and 100

  # If the user wants to specify a backend name
  read -p "Enter backend name (default: $backend_name): " user_backend_name
  backend_name=${user_backend_name:-$backend_name}  # Use user input or default

  # Remove existing backend configuration for this name
  sed -i "/^backend $backend_name/,/^$/d" $HAPROXY_CONFIG

    # Ask for backend mode (TCP or UDP)
    echo "Select backend mode (default tcp):"
    echo "1) TCP"
    echo "2) UDP"
    read -p "Enter choice: " backend_mode_choice

    case $backend_mode_choice in
      1)
        backend_mode="tcp"
        ;;
      2)
        backend_mode="udp"
        ;;
      *)
        echo "defaulting to 'tcp'."
        backend_mode="tcp"
        ;;
    esac

    # Initialize server array to store each server entered by the user
    server_array=()
    echo -e "\033[1;33mEnter each backend server+port on a new line (e.g., 127.0.0.1:8999):\033[0m"
    echo -e "\033[1;33mEnter blank to finish :\033[0m"
    while true; do
      read -p "Server address+port (enter blank to finish): " server
      [[ -z "$server" ]] && break  # Exit the loop if the input is blank
      server_array+=("$server")    # Add each entered server to the array
    done

    # Initialize SNI array to store each SNI value entered by the user for the frontend
    sni_array=()
    echo -e "\033[1;33mEnter each SNI value for frontend on a new line (e.g., anten.ir):\033[0m"
    echo -e "\033[1;33mPress Enter blank to finish :\033[0m"
    
    while true; do
      read -p "SNI: (enter blank to finish): " sni_value
      [[ -z "$sni_value" ]] && break  # Exit the loop if the input is blank
      sni_array+=("$sni_value")       # Add each entered SNI to the array
    done

    # Prompt for SNI match type (end/equal)
    echo "Select SNI match type for frontend (default end):"
    echo "1) end with SNI"
    echo "2) equal with SNI"
    read -p "Enter choice: " sni_choice

    # Set sni_type based on user choice
    case $sni_choice in
      1)
        sni_type="end"
        ;;
      2)
        sni_type="equal"
        ;;
      *)
        echo "defaulting to 'end'."
        sni_type="end"
        ;;
    esac

    # Ask for the frontend port
    read -p "Enter frontend port (default is 443): " frontend_port
    frontend_port=${frontend_port:-443}  # Default to 443 if blank

    # Adding frontend configuration first
    {
      echo -e "\nfrontend $backend_name-frontend"
      echo "  mode tcp"
      echo "  bind *:$frontend_port"  # Use user-defined port
      echo "  tcp-request inspect-delay 5s"
      echo "  tcp-request content accept if { req_ssl_hello_type 1 }"

      # Loop through each SNI value and add matching rules
      for sni_value in "${sni_array[@]}"; do
        if [[ "$sni_type" == "end" ]]; then
          echo "  use_backend $backend_name if { req_ssl_sni -m end $sni_value }"
        else
          echo "  use_backend $backend_name if { req_ssl_sni -i $sni_value }"
        fi
      done
      echo -e "\n# Frontend added for backend $backend_name"
    } >> $HAPROXY_CONFIG

    # Adding backend configuration after frontend
    {
      echo "backend $backend_name"
      echo "  mode $backend_mode"
      if [[ ${#server_array[@]} -gt 1 ]]; then
        echo "  balance roundrobin"
      fi

      i=1
      for server in "${server_array[@]}"; do
        echo "  server srv$i $server"
        ((i++))
      done
      echo -e "\n# Added backend $backend_name with servers ${server_array[*]}"
    } >> $HAPROXY_CONFIG

    # Ask if the user wants to create another backend
    read -p "Do you want to create another backend? (y/n): " create_another
    if [[ "$create_another" != "y" ]]; then
      break
    fi
  done

  echo -e "\033[1;32m--- Backend(s) and frontend(s) created successfully! ---\033[0m"
  restart_haproxy
  
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
  read -p "Press Enter to continue: "

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
    read -p "Press Enter to continue: "
  fi
  

}

# Function to restart HAProxy service
restart_haproxy() {
  echo -e "\033[1;34m--- Restarting HAProxy Service ---\033[0m"
  if sudo systemctl restart haproxy; then
    echo -e "\033[1;32mHAProxy service restarted successfully!\033[0m"
    read -p "Press Enter to continue: "
  else
    echo -e "\033[1;31mFailed to restart HAProxy service. Please check the service status or logs.\033[0m"
    read -p "Press Enter to continue: "
    return 1  # Indicate failure
  fi
  

}

# Function to stop HAProxy service
stop_haproxy() {
  echo -e "\033[1;34m--- Stopping HAProxy Service ---\033[0m"
  if sudo systemctl stop haproxy; then
    echo -e "\033[1;32mHAProxy service stopped successfully!\033[0m"
    read -p "Press Enter to continue: "
  else
    echo -e "\033[1;31mFailed to stop HAProxy service. Please check the service status or logs.\033[0m"
    read -p "Press Enter to continue: "
    return 1  # Indicate failure
  fi
  

}

# Function to start HAProxy service
start_haproxy() {
  echo -e "\033[1;34m--- Starting HAProxy Service ---\033[0m"
  if sudo systemctl start haproxy; then
    echo -e "\033[1;32mHAProxy service started successfully!\033[0m"
    read -p "Press Enter to continue: "
  else
    echo -e "\033[1;31mFailed to start HAProxy service. Please check the service status or logs.\033[0m"
    read -p "Press Enter to continue: "
    return 1  # Indicate failure
  fi
  

}

# Function to check HAProxy service status
check_haproxy_status() {
  echo -e "\033[1;34m--- Checking HAProxy Service Status ---\033[0m"
  if systemctl is-active --quiet haproxy; then
    echo -e "\033[1;32mHAProxy is running.\033[0m"
    read -p "Press Enter to continue: "
  else
    echo -e "\033[1;31mHAProxy is not running. Please check the service or start it.\033[0m"
    read -p "Press Enter to continue: "
    return 1  # Indicate failure
  fi

}


# Function to edit HAProxy configuration
edit_haproxy() {
  echo -e "\033[1;34m--- Editing HAProxy Configuration ---\033[0m"
  sudo nano $HAPROXY_CONFIG
}

# Main menu for managing HAProxy
haproxy_menu() {
  while true; do
  clear
    echo -e "\n\033[1;34m--- HAProxy Configuration Management ---\033[0m"
    echo "1. Install HAProxy"
    echo "2. Remove HAProxy"
    echo "3. Create Frontend+Backend"
    echo "4. check haproxy status"
    echo "5. Backup HAProxy Configuration"
    echo "6. Restore HAProxy Configuration"
    echo "7. Restart HAProxy"
    echo "8. Start HAProxy"
    echo "9. Stop HAProxy"
    echo "10. Edit HAProxy Configuration"
    echo "11. Exit"
    read -p "Select an option: " option

    case $option in
      1) install_haproxy ;;
      2) remove_haproxy ;;
      3) create_backend ;;
      4) check_haproxy_status ;;
      5) backup_haproxy ;;
      6) restore_haproxy ;;
      7) restart_haproxy ;;
      8) start_haproxy ;;
      9) stop_haproxy ;;
      10) edit_haproxy ;;
      11) break ;;
      *) echo -e "\033[1;31mInvalid option!\033[0m" ;;
    esac
  done
}

haproxy_menu
