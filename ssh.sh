#!/bin/bash
# Function to check if the config file exists, and if not, call save_ssh_config
check_and_save_ssh_config() {
    # Check if the configuration file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        # If it doesn't exist, save the SSH configuration
        echo -e "\033[1;31mConfiguration file does not exist. start create....\033[0m"
        save_ssh_config
    else
        # If it exists, inform the user
        echo -e "\033[1;32mConfiguration file exists at $CONFIG_FILE.\033[0m"
    fi
}
# Configuration file path
CONFIG_FILE="/root/send-file-ssh.txt"

# Function to check and install sshpass if not already installed
install_sshpass() {
    if ! command -v sshpass &> /dev/null; then
        echo "sshpass is not installed. Installing now..."
        if [[ -x "$(command -v apt-get)" ]]; then
            sudo apt-get update && sudo apt-get install -y sshpass
        elif [[ -x "$(command -v yum)" ]]; then
            sudo yum install -y sshpass
        else
            echo "Package manager not supported. Please install sshpass manually."
            exit 1
        fi
        echo "sshpass installed successfully."
    else
        echo "sshpass is already installed."
    fi
}

# Function to start a regular SSH session using details from the configuration file
start_regular_ssh() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        
        if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" || -z "$REMOTE_PORT" ]]; then
            echo "Error: Missing required configuration details in $CONFIG_FILE."
            return 1
        fi

        ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST"
    else
        echo "Configuration file $CONFIG_FILE not found."
        return 1
    fi
    read -p "Press Enter to continue..."
}

# Function to start an SSH session using sshpass with details from the configuration file
start_sshpass_ssh() {
    install_sshpass

    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        
        if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" || -z "$REMOTE_PORT" || -z "$ROOT_PASSWORD" ]]; then
            echo "Error: Missing required configuration details in $CONFIG_FILE."
            return 1
        fi

        sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST"
    else
        echo "Configuration file $CONFIG_FILE not found."
        return 1
    fi
    read -p "Press Enter to continue..."
}

# Function to prompt for values and save to configuration file
save_ssh_config() {
    while [[ -z "$FILE" ]]; do
        read -p "Enter the path of the file to send: " FILE
    done

    while [[ -z "$REMOTE_USER" ]]; do
        read -p "Enter the remote user: " REMOTE_USER
    done

    while [[ -z "$REMOTE_HOST" ]]; do
        read -p "Enter the remote host: " REMOTE_HOST
    done

    while [[ -z "$REMOTE_PORT" ]]; do
        read -p "Enter the remote SSH port: " REMOTE_PORT
    done

    while [[ -z "$REMOTE_DIR" ]]; do
        read -p "Enter the remote directory: " REMOTE_DIR
    done

    while [[ -z "$ROOT_PASSWORD" ]]; do
        read -sp "Enter the root password: " ROOT_PASSWORD
        echo
    done

    while [[ -z "$BOT_TOKEN" ]]; do
        read -p "Enter your Telegram Bot Token: " BOT_TOKEN
    done

    while [[ -z "$CHAT_ID" ]]; do
        read -p "Enter your Telegram Chat ID: " CHAT_ID
    done

    cat <<EOL > "$CONFIG_FILE"
FILE="$FILE"
REMOTE_USER="$REMOTE_USER"
REMOTE_HOST="$REMOTE_HOST"
REMOTE_PORT="$REMOTE_PORT"
REMOTE_DIR="$REMOTE_DIR"
ROOT_PASSWORD="$ROOT_PASSWORD"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOL

    echo "Configuration saved to $CONFIG_FILE"
    read -p "Press Enter to continue..."
}

# Function to edit the configuration file with nano
edit_ssh_config() {
    if [ -f "$CONFIG_FILE" ]; then
        nano "$CONFIG_FILE"
    else
        echo "Configuration file $CONFIG_FILE does not exist. Creating it now."
        save_ssh_config
        nano "$CONFIG_FILE"
    fi
    read -p "Press Enter to continue..."
}

# Function to create the send_file_to_telegram.sh script on the remote server
create_send_file_to_telegram_script() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        
        if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" || -z "$REMOTE_USER" || -z "$REMOTE_HOST" || -z "$REMOTE_PORT" || -z "$ROOT_PASSWORD" || -z "$REMOTE_DIR" ]]; then
            echo "Error: Missing required configuration details in $CONFIG_FILE."
            return 1
        fi

        REMOTE_SCRIPT_PATH="$REMOTE_DIR/send_file_to_telegram.sh"

        sshpass -p "$ROOT_PASSWORD" ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" <<EOF
mkdir -p "$REMOTE_DIR"
cat > "$REMOTE_SCRIPT_PATH" <<'EOL'
#!/bin/bash

BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
FILE_PATH="$FILE"

if [ ! -f "\$FILE_PATH" ]; then
  echo "File does not exist: \$FILE_PATH" >&2
  exit 1
fi

curl -s -X POST "https://api.telegram.org/bot\$BOT_TOKEN/sendDocument" \
  -F chat_id="\$CHAT_ID" \
  -F document=@"\$FILE_PATH"

echo "File \$FILE_PATH sent to Telegram."
EOL

chmod +x "$REMOTE_SCRIPT_PATH"
EOF

        echo "send_file_to_telegram.sh script created on remote server at $REMOTE_SCRIPT_PATH."
    else
        echo "Configuration file $CONFIG_FILE not found. Please create it first."
    fi
    read -p "Press Enter to continue..."
}

create_send_file_ssh_script() {
    SCRIPT_PATH="/root/send_file_ssh.sh"

    cat > "$SCRIPT_PATH" << 'EOF'
#!/bin/bash

CONFIG_FILE="/root/send-file-ssh.txt"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file $CONFIG_FILE does not exist." >&2
  exit 1
fi

source "$CONFIG_FILE"

if [ ! -f "$FILE" ]; then
  echo "File $FILE does not exist." >&2
  exit 1
fi

if ! command -v sshpass &> /dev/null; then
  echo "sshpass is not installed or not executable." >&2
  exit 1
fi

if sshpass -p "$ROOT_PASSWORD" ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" exit; then
  echo "SSH connection to $REMOTE_USER@$REMOTE_HOST successful."
else
  echo "Failed to connect to $REMOTE_USER@$REMOTE_HOST via SSH." >&2
  exit 1
fi

if sshpass -p "$ROOT_PASSWORD" scp -P "$REMOTE_PORT" "$FILE" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"; then
  echo "File successfully sent to $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
else
  echo "Failed to send file to $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR" >&2
  exit 1
fi

if sshpass -p "$ROOT_PASSWORD" ssh -o StrictHostKeyChecking=no -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" '/root/send_file_to_telegram.sh'; then
  echo "send_file_to_telegram.sh started successfully on $REMOTE_USER@$REMOTE_HOST"
else
  echo "Failed to start send_file_to_telegram.sh on $REMOTE_USER@$REMOTE_HOST" >&2
  exit 1
fi

EOF

    chmod +x "$SCRIPT_PATH"
    echo "send_file_ssh.sh script created at $SCRIPT_PATH."
    read -p "Press Enter to continue..."
}


# Function to prompt user and set cron job for send_file_ssh.sh
set_send_file_ssh_cron() {
    # Default interval in hours
    default_send_file_interval=2  # default to run once a day

    # Prompt user for interval in hours
    echo -e "\033[1;33mEnter the interval (in hours) to run the send_file_ssh.sh script:\033[0m"
    read -p "Enter hours (default $default_send_file_interval hours): " send_file_hours

    # Use default if no input is provided
    send_file_hours=${send_file_hours:-$default_send_file_interval}

    # Command for sending file using /root/send_file_ssh.sh
    send_file_command="/root/send_file_ssh.sh"

    # Remove old cron job if it exists
    if crontab -l | grep -q "$send_file_command"; then
        echo -e "\033[1;33mUpdating existing cron job for send_file_ssh.sh...\033[0m"
        crontab -l | grep -v "$send_file_command" | crontab - || {
            echo -e "\033[1;31mFailed to remove the existing cron job for send_file_ssh.sh.\033[0m"
            return 1
        }
    fi

    # Add new cron job based on user input
    if [[ "$send_file_hours" -eq 0 ]]; then
        echo -e "\033[1;31mWarning: send_file_ssh.sh will run every hour!\033[0m"
        (crontab -l 2>/dev/null | grep -v "$send_file_command"; echo "0 * * * * $send_file_command") | crontab - || {
            echo -e "\033[1;31mFailed to set cron job for send_file_ssh.sh.\033[0m"
            return 1
        }
    else
        # Set cron job to run every specified hour
        (crontab -l 2>/dev/null | grep -v "$send_file_command"; echo "0 */$send_file_hours * * * $send_file_command") | crontab - || {
            echo -e "\033[1;31mFailed to set cron job for send_file_ssh.sh.\033[0m"
            return 1
        }
    fi

    # Reload cron service
    if ! sudo service cron reload; then
        echo -e "\033[1;31mFailed to reload cron service.\033[0m"
        return 1
    fi

    sleep 1
    echo -e "\033[1;32mCron job for send_file_ssh.sh set to run every $send_file_hours hour(s).\033[0m"
    read -p "Press Enter to continue..."
}



show_menu() {
    while true; do
        clear
        echo -e "\033[1;36m========================================\033[0m"
        echo -e "\033[1;32m  Send File to Remote Server & Forward to Telegram \033[0m"
        echo -e "\033[1;36m========================================\033[0m\n"
        
        echo -e "\033[1;33m10.\033[0m Setup send file via SSH and Telegram transfer"
        echo -e "\033[1;33m 1.\033[0m Start SSH connection"
        echo -e "\033[1;33m 2.\033[0m Start sshpass-based SSH"
        echo -e "\033[1;33m 3.\033[0m Edit SSH configuration"
        echo -e "\033[1;33m 4.\033[0m Save SSH configuration"
        echo -e "\033[1;33m 5.\033[0m Save configuration on local server"
        echo -e "\033[1;33m 6.\033[0m Save configuration on remote server"
        echo -e "\033[1;33m 7.\033[0m Set cron job for file transfer"
        echo -e "\033[1;33m 8.\033[0m Check and save SSH configuration"
        echo -e "\033[1;33m 9.\033[0m Edit cron jobs (nano)"
        echo -e "\033[1;33m 0.\033[0m Exit\n"
        
        echo -e "\033[1;36m========================================\033[0m"
        read -p "Select an option: " option


        case $option in
            10) 
                create_send_file_ssh_script
                create_send_file_to_telegram_script
                set_send_file_ssh_cron
                ;;
            1) start_regular_ssh ;;
            2) start_sshpass_ssh ;;
            3) edit_ssh_config ;;
            4) save_ssh_config ;;
            5) create_send_file_ssh_script ;;
            6) create_send_file_to_telegram_script ;;
            7) 
                set_send_file_ssh_cron
                echo -e "\033[1;32mCron job set successfully.\033[0m"
                sleep 1
                ;;
            8) check_and_save_ssh_config ;;
            9) 
                echo -e "\033[1;33mOpening cron jobs for editing...\033[0m"
                sudo EDITOR=nano crontab -e
                echo -e "\033[1;32mCron jobs updated and reloaded.\033[0m"
                sudo service cron reload
                sleep 1
                ;;
            0) 
                echo -e "\033[1;31mExiting...\033[0m"
                exit 0
                ;;
            *) 
                echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                sleep 1
                ;;
        esac
    done
}

# Run the menu
show_menu
