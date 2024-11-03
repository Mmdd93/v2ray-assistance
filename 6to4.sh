#!/bin/bash
# Function to check if any SIT tunnel already exists
check_existing_sit_tunnel() {
  existing_tunnels=$(ip tunnel show | grep "sit")

  # Check if any SIT tunnels exist
  if [[ -n "$existing_tunnels" ]]; then
    echo -e "\033[1;33mExisting SIT tunnels detected:\033[0m"
    echo "$existing_tunnels"

  else
    echo -e "\033[1;32mNo existing SIT tunnels found.\033[0m"
  fi
read -p "Enter to continue: "
  return 0
}




# Default configuration file name
DEFAULT_NETPLAN_FILE="00-installer-config.yaml"

# Function to prompt for a custom configuration file name
prompt_netplan_filename() {
  read -p "Enter Netplan file name (default: $DEFAULT_NETPLAN_FILE): " netplan_file
  if [[ -z "$netplan_file" ]]; then
    netplan_file=$DEFAULT_NETPLAN_FILE
  elif [[ ! "$netplan_file" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "\033[1;31mInvalid file name. Only alphanumeric characters, dashes, and underscores are allowed.\033[0m"
    netplan_file=$DEFAULT_NETPLAN_FILE
  fi

  # Append .yaml if not already present
  if [[ ! "$netplan_file" =~ \.yaml$ ]]; then
    netplan_file="${netplan_file}.yaml"
  fi

  echo -e "\033[1;32mUsing Netplan configuration file: $netplan_file\033[0m"
}

# Function to determine default IPv6 address based on server location
determine_default_ipv6() {
  read -p "Is this an Iran server? (yes/no): " iran_server
  if [[ "$iran_server" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
    DEFAULT_IPV6_ADDRESS="2001:db8:1::1/64"
  else
    DEFAULT_IPV6_ADDRESS="2001:db8:1::2/64"
  fi
  echo -e "\033[1;32mDefault IPv6 address set to: $DEFAULT_IPV6_ADDRESS\033[0m"
}

# Function to detect the main network interface and its IP address
get_main_interface_and_ip() {
  main_interface=$(ip route | grep '^default' | awk '{print $5}')
  if [[ -z "$main_interface" ]]; then
    echo -e "\033[1;31mCould not detect the main network interface. Please check your network settings.\033[0m"
    exit 1
  fi

  public_ip=$(ip -4 addr show "$main_interface" | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | grep -Ev '^10\.|^172\.(1[6-9]|2[0-9]|3[01])\.|^192\.168\.')
  local_ip=$(ip -4 addr show "$main_interface" | grep -oP '(?<=inet\s)\d+\.\d+\.\d+\.\d+' | head -n 1)

  if [[ -n "$public_ip" ]]; then
    main_ip=$public_ip
    echo -e "\033[1;32mDetected public IP: $main_ip\033[0m"
  else
    main_ip=$local_ip
    echo -e "\033[1;32mNo public IP detected. Using local IP: $main_ip\033[0m"
  fi
}

# Function to create SIT tunnel configuration
# Function to create SIT tunnel configuration
create_sit_tunnel() {
  echo -e "\033[1;32mCreating SIT Tunnel 6to4 Configuration...\033[0m"

  while true; do
    # Prompt user for SIT tunnel number
    read -p "Enter SIT tunnel number (e.g., 1 for sit1): " sit_number
    if [[ "$sit_number" =~ ^[1-9][0-9]*$ ]]; then
      echo -e "\033[1;32mValid SIT tunnel number: sit$sit_number\033[0m"
      break  # Exit the loop if a valid number is entered
    else
      echo -e "\033[1;31mInvalid SIT tunnel number. Please enter a positive integer.\033[0m"
    fi
  done

  # Proceed with SIT tunnel creation using the valid sit_number
  # (Add the commands here to create the SIT tunnel)


  
  # Create the SIT tunnel name based on user input
  local sit_tunnel_name="sit$sit_number"

  # Prompt user for remote IP and get the current local IP
  read -p "Enter remote IPv4 address (e.g., 91.107.16.16): " remote_ipv4

  # Use the current local IP as the default
  read -p "Enter local IPv4 address (default: $main_ip): " local_ipv4
  local_ipv4=${local_ipv4:-$main_ip}  # Set current local IP as default if no input

  # Prompt for IPv6 address, with a default based on location
  read -p "Enter IPv6 address (default: $DEFAULT_IPV6_ADDRESS): " ipv6_address
  ipv6_address=${ipv6_address:-$DEFAULT_IPV6_ADDRESS}

  # Create the netplan configuration
  sudo tee /etc/netplan/$netplan_file > /dev/null <<EOF
network:
  version: 2
  ethernets:
    $main_interface:
      dhcp4: true
  tunnels:
    $sit_tunnel_name:
      mode: sit
      local: ${local_ipv4}
      remote: ${remote_ipv4}
      addresses:
        - ${ipv6_address}
EOF

  echo -e "\033[1;32mSIT tunnel configuration for $sit_tunnel_name added to /etc/netplan/$netplan_file\033[0m"
  echo -e "\033[1;32mSetting permissions...\033[0m"
  sudo chmod 600 /etc/netplan/$netplan_file
  echo -e "\033[1;32mapplying netplan... \033[0m"
  apply_netplan
  read -p "Enter to continue: "
}



# Function to install Open vSwitch
install_openvswitch() {
  echo -e "\033[1;32mInstalling Open vSwitch...\033[0m"
  sudo apt install openvswitch-switch -y
  echo -e "\033[1;32mOpen vSwitch installed successfully.\033[0m"
}



# Function to edit the Netplan configuration file with nano
edit_netplan_file() {
  # Initialize an array to hold the YAML files
  local files=()

  # Check for existing YAML files in /etc/netplan/
  if compgen -G "/etc/netplan/*.yaml" > /dev/null; then
    files=(/etc/netplan/*.yaml)  # Populate the array only if files exist
  fi

  # Check if any YAML files were found
  if [[ ${#files[@]} -eq 0 ]]; then
    echo -e "\033[1;31mNo Netplan configuration files found in /etc/netplan/\033[0m"
    read -p "Press Enter to continue..."
    return
  fi

  # Display the files with numbering
  echo -e "\033[1;34mAvailable Netplan configuration files:\033[0m"
  for i in "${!files[@]}"; do
    echo "$((i + 1)). ${files[i]}"
  done

  # Prompt user to select a file
  read -p "Select a file to edit (1-${#files[@]}): " selection

  # Validate selection
  if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le ${#files[@]} ]; then
    selected_file=${files[$((selection - 1))]}
    echo -e "\033[1;32mOpening Netplan configuration file: $selected_file\033[0m"
    sudo nano "$selected_file"
  else
    echo -e "\033[1;31mInvalid selection. Please try again.\033[0m"
  fi
  read -p "Press Enter to continue: "
}




# Function to edit an existing SIT tunnel configuration
edit_existing_sit_tunnel() {
  local existing_tunnels=$(ip tunnel show | grep "sit")

  if [[ -z "$existing_tunnels" ]]; then
    echo -e "\033[1;31mNo existing SIT tunnels found.\033[0m"
    return
  fi

  echo -e "\033[1;34mSelect a SIT tunnel to edit:\033[0m"
  select tunnel in $(echo "$existing_tunnels" | awk '{print $1}'); do
    if [[ -n "$tunnel" ]]; then
      echo "Editing SIT tunnel: $tunnel"

      # Get current tunnel information
      local tunnel_info=$(ip tunnel show "$tunnel")

      # Output the entire tunnel info for debugging
      echo -e "\033[1;33mTunnel Info:\033[0m"
      echo "$tunnel_info"

      # Extract remote, local IPv4 addresses, and IPv6 addresses
      local current_remote_ipv4=$(echo "$tunnel_info" | awk '{print $4}') # Extract the 4th field for remote
      local current_local_ipv4=$(echo "$tunnel_info" | awk '{print $6}')  # Extract the 6th field for local
      local current_ipv6_addresses=$(ip -6 addr show "$tunnel" | grep 'inet6' | awk '{print $2}')

      # Display current addresses
      echo "Current remote IPv4 address: ${current_remote_ipv4:-None}"
      echo "Current local IPv4 address: ${current_local_ipv4:-None}"
      echo "Current IPv6 addresses:"
      echo "$current_ipv6_addresses"

      # Prompt for new settings
      read -p "Enter new remote IPv4 address: " new_remote_ipv4
      read -p "Enter new local IPv4 address: " new_local_ipv4
      echo -e "Enter new IPv6 addresses (separate multiple addresses with spaces):"
      read -p "IPv6 addresses: " new_ipv6_addresses

      # Automatically detect the Netplan configuration files
      local config_file
      local config_found=false
      for file in /etc/netplan/*.yaml; do
        if [[ -f "$file" ]]; then
          # Check if the file contains configuration for the selected SIT tunnel
          if grep -q "$tunnel" "$file"; then
            config_file="$file"
            config_found=true
            break
          fi
        fi
      done

      if [[ "$config_found" == false ]]; then
          echo -e "\033[1;31mNo Netplan configuration found for the selected SIT tunnel in /etc/netplan/\033[0m"
          return
      fi

      # Backup current configuration
      sudo cp "$config_file" "${config_file}.backup" || { echo -e "\033[1;31mFailed to backup configuration file.\033[0m"; return; }

      # Overwrite the Netplan configuration file with new settings
      sudo bash -c "cat > $config_file" <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: true

  tunnels:
    $tunnel:  # Use the dynamic tunnel name
      mode: sit
      remote: ${new_remote_ipv4}
      local: ${new_local_ipv4}
      addresses:
EOF

      # Append each IPv6 address to the file
      for ipv6 in $new_ipv6_addresses; do
        sudo bash -c "echo '        - $ipv6' >> $config_file"
      done

      echo -e "\033[1;32mNetplan configuration overwritten with new SIT tunnel settings for $tunnel.\033[0m"

      # Apply the new configuration
      if sudo netplan apply; then
        echo -e "\033[1;32mNetplan configuration applied successfully.\033[0m"
      else
        echo -e "\033[1;31mFailed to apply Netplan configuration.\033[0m"
      fi

      break
    else
      echo -e "\033[1;31mInvalid selection. Please try again.\033[0m"
    fi
  done
  read -p "Enter to continue: "
}

# Function to remove an existing SIT tunnel configuration
# Function to remove an existing SIT tunnel configuration
remove_sit_tunnel() {
  local existing_tunnels=$(ip tunnel show | grep "sit")

  if [[ -z "$existing_tunnels" ]]; then
    echo -e "\033[1;31mNo existing SIT tunnels found.\033[0m"
    return
  fi

  echo -e "\033[1;34mSelect a SIT tunnel to remove:\033[0m"

  # List the existing SIT tunnels with numbering
  local index=1
  for tunnel in $(echo "$existing_tunnels" | awk '{print $1}'); do
    echo -e "$index: $tunnel"
    ((index++))
  done


  read -p "Enter your choice:" choice

  if [[ "$choice" -ge 1 && "$choice" -lt $index ]]; then
    # Get the selected tunnel based on user input
    local tunnel=$(echo "$existing_tunnels" | awk "NR==$choice {print \$1}")
    echo -e "Removing SIT tunnel: $tunnel"

    # Remove the SIT tunnel
    if sudo ip tunnel del "$tunnel"; then
      echo -e "\033[1;32mSIT tunnel $tunnel removed successfully.\033[0m"
    else
      echo -e "\033[1;31mFailed to remove SIT tunnel $tunnel.\033[0m"
      return
    fi

    # Automatically detect the Netplan configuration files
    local config_file
    local config_found=false
    for file in /etc/netplan/*.yaml; do
      if [[ -f "$file" ]]; then
        # Check if the file contains configuration for the selected SIT tunnel
        if grep -q "$tunnel" "$file"; then
          config_file="$file"
          config_found=true
          break
        fi
      fi
    done

    if [[ "$config_found" == true ]]; then
      echo -e "\033[1;33mFound configuration file: $config_file\033[0m"

      # Directly remove the Netplan configuration file
      echo -e "\033[1;33mRemoving configuration file: $config_file...\033[0m"
      if sudo rm "$config_file"; then
        echo -e "\033[1;32mNetplan configuration file for $tunnel removed completely.\033[0m"
      else
        echo -e "\033[1;31mFailed to remove Netplan configuration file for $tunnel.\033[0m"
      fi
    else
      echo -e "\033[1;31mNo Netplan configuration found for the selected SIT tunnel.\033[0m"
    fi
  else
    echo -e "\033[1;31mInvalid selection. Please try again.\033[0m"
  fi

  read -p "Press Enter to continue..."
}


apply_netplan() {
  # Check for existing Netplan configuration files
  local config_files=(/etc/netplan/*.yaml)

  if [ ! -e "${config_files[0]}" ]; then
    echo -e "\033[1;31mNo Netplan configuration files found. Cannot apply configuration.\033[0m"
    read -p "Press Enter to continue..."
    return
  fi

  # Display a warning tip about potential connection loss
  echo -e "\033[1;33mWarning: Applying an invalid YAML file could result in loss of connection.\033[0m"

  # Prompt the user for confirmation
  read -p "Are you sure you want to check and apply the Netplan configuration? (yes/no): " confirm

  if [[ "$confirm" != "yes" ]]; then
    echo -e "\033[1;33mOperation canceled. Netplan configuration not applied.\033[0m"
    read -p "Press Enter to continue..."
    return
  fi

  # Check the validity of the YAML files
  for file in "${config_files[@]}"; do
    if ! sudo netplan try; then
      echo -e "\033[1;31mInvalid configuration found in $file. Please fix the configuration before applying.\033[0m"
      return
    fi
  done

  # Apply the Netplan configuration
  sudo netplan apply

  if [ $? -eq 0 ]; then
    echo -e "\033[1;32mNetplan applied successfully.\033[0m"
  else
    echo -e "\033[1;31mFailed to apply Netplan configuration.\033[0m"
  fi
}





# Main menu function
main_menu() {
  
  while true; do
    echo -e "\n\033[1;34m=============================\033[0m"
    echo -e "\033[1;34m     Select an option:\033[0m"
    echo -e "\033[1;33m1. Create SIT Tunnel 6to4 Configuration\033[0m"
    echo -e "\033[1;33m2. Edit Existing SIT Tunnel\033[0m"
    echo -e "\033[1;33m3. Install Open vSwitch\033[0m"
    echo -e "\033[1;33m4. Apply Netplan Configuration\033[0m"
    echo -e "\033[1;33m5. Edit Netplan Configuration File\033[0m"
    echo -e "\033[1;33m6. Remove SIT Tunnel\033[0m"
    echo -e "\033[1;33m7. Check Existing SIT Tunnel\033[0m"
    echo -e "\033[1;34m0. Exit\033[0m"
    echo -e "\033[1;34m=============================\033[0m"

    read -p "Enter your choice [0-7]: " choice

    case $choice in
      1) install_openvswitch && prompt_netplan_filename && determine_default_ipv6 && get_main_interface_and_ip && create_sit_tunnel ;;
      2) edit_existing_sit_tunnel ;;
      3) install_openvswitch ;;
      4) apply_netplan
         echo -e "\033[1;32mNetplan applied successfully.\033[0m" ;;
      5) edit_netplan_file ;;
      6) remove_sit_tunnel ;;
      7) check_existing_sit_tunnel ;;
      0) 
         echo -e "\033[1;32mExiting...\033[0m"
         break ;;
      *) 
         echo -e "\033[1;31mInvalid choice, please try again.\033[0m" ;;
    esac
  done
}

# Start the main menu
main_menu
