#!/bin/bash

CONFIG_FILE="/root/config.txt"
IMAGE_PATH="/root/check_sites_image.png"  # Define the image path

# Function to prompt for values and save them in the config file
setup_config() {
  URL_FILE="${URL_FILE:-urls.txt}"
  LOG_FILE="${LOG_FILE:-check_sites.log}"

  read -p "Enter remote user (default: root): " REMOTE_USER
  REMOTE_USER="${REMOTE_USER:-root}"

  read -p "Enter remote host ip: " REMOTE_HOST

  read -p "Enter remote port (default: 22): " REMOTE_PORT
  REMOTE_PORT="${REMOTE_PORT:-22}"

  read -p "Enter remote directory (default: /root): " REMOTE_DIR
  REMOTE_DIR="${REMOTE_DIR:-/root}"

  read -p "Enter target port to check (default: 80): " TARGET_PORT
  TARGET_PORT="${TARGET_PORT:-80}"

  read -p "Enter root password: " ROOT_PASSWORD
  echo

  # Telegram bot details
  read -p "Enter Telegram bot token: " BOT_TOKEN
  read -p "Enter Telegram chat ID: " CHAT_ID

  # Save configuration to the config file
  cat <<EOL > "$CONFIG_FILE"
URL_FILE="$URL_FILE"
LOG_FILE="$LOG_FILE"
REMOTE_USER="$REMOTE_USER"
REMOTE_HOST="$REMOTE_HOST"
REMOTE_PORT="$REMOTE_PORT"
REMOTE_DIR="$REMOTE_DIR"
TARGET_PORT="$TARGET_PORT"
ROOT_PASSWORD="$ROOT_PASSWORD"
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"
EOL

  echo "Configuration saved to $CONFIG_FILE."
}

# Function to check if the config file exists and run setup_config if not
check_config() {
  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file not found. Setting up configuration..."
    setup_config
  fi
}

# Define the required packages
REQUIRED_PACKAGES=("curl" "sshpass" "dnsutils" "imagemagick" "python3-pillow")

# Function to install a package if it is not installed
install_if_missing() {
  PACKAGE=$1
  if ! command -v "$PACKAGE" &> /dev/null; then
    echo "$PACKAGE is not installed. Installing..."
    if ! sudo apt-get update && sudo apt-get install -y "$PACKAGE"; then
      echo "Failed to install $PACKAGE" >&2
      exit 1
    fi
  else
    echo "$PACKAGE is already installed."
  fi
}

# Function to save URLs to a file
save_urls_to_file() {
  local URL_FILE="$1"  # The file to save URLs

  # Check if the URL file exists
  if [ ! -f "$URL_FILE" ]; then
    echo "URL file not found. Please enter the URLs you want to check."
    echo "Enter each URL on a new line. Type 'done' when finished."

    # Clear or create the file
    > "$URL_FILE"

    # Loop to read and validate URLs
    while true; do
      read -p "Enter URL: " URL
      if [ "$URL" == "done" ]; then
        break
      elif [[ "$URL" =~ ^https?:// ]]; then
        echo "$URL" >> "$URL_FILE"
      else
        echo "Invalid URL format. Please start with http:// or https://"
      fi
    done

    echo "URLs saved to $URL_FILE."
  else
    echo "URL file already exists at $URL_FILE."
  fi
}

# Function to set up the URL testing cron job
set_url_test_cron() {
  # Default interval in hours
  default_send_file_interval=2  # Default to run once every 2 hours

  # Prompt user for interval in hours
  echo -e "\033[1;33mEnter the interval (in hours) to run the url_test.sh script:\033[0m"
  read -p "Enter hours (default $default_send_file_interval hours): " send_file_hours

  # If input is empty, use the default interval
  send_file_hours=${send_file_hours:-$default_send_file_interval}

  # Validate that the input is a number
  if ! [[ "$send_file_hours" =~ ^[0-9]+$ ]]; then
    echo -e "\033[1;31mInvalid input. Please enter a valid number.\033[0m"
    return 1
  fi

  # Command for running the script
  send_file_command="/root/check_url.sh"

  # Remove old cron job if it exists
  if crontab -l | grep -q "$send_file_command"; then
    echo -e "\033[1;33mUpdating existing cron job...\033[0m"
    crontab -l | grep -v "$send_file_command" | crontab - || {
      echo -e "\033[1;31mFailed to remove the existing cron job.\033[0m"
      return 1
    }
  fi

  # Add new cron job based on user input
  if [[ "$send_file_hours" -eq 0 ]]; then
    echo -e "\033[1;31mWarning: script will run every hour!\033[0m"
    (crontab -l 2>/dev/null | grep -v "$send_file_command"; echo "0 * * * * $send_file_command") | crontab - || {
      echo -e "\033[1;31mFailed to set cron job.\033[0m"
      return 1
    }
  else
    # Set cron job to run every specified hour
    (crontab -l 2>/dev/null | grep -v "$send_file_command"; echo "0 */$send_file_hours * * * $send_file_command") | crontab - || {
      echo -e "\033[1;31mFailed to set cron job.\033[0m"
      return 1
    }
  fi

  # Reload cron service
  if ! sudo service cron reload; then
    echo -e "\033[1;31mFailed to reload cron service.\033[0m"
    return 1
  fi

  sleep 1
  echo -e "\033[1;32mCron job set to run every $send_file_hours hour(s).\033[0m"
  read -p "Press Enter to continue..."
}

# Function to download the check_url.sh script from GitHub
download_check_url_script() {
  echo -e "\033[1;33mDownloading check_url.sh script from GitHub...\033[0m"
  curl -Ls https://raw.githubusercontent.com/Mmdd93/v2ray-assistance/refs/heads/main/check_url.sh -o /root/check_url.sh
  if [ $? -eq 0 ]; then
    echo -e "\033[1;32mcheck_url.sh script downloaded successfully.\033[0m"
    sudo chmod +x /root/check_url.sh
  else
    echo -e "\033[1;31mFailed to download check_url.sh.\033[0m"
  fi
}

# Function to edit cron job
edit_cron_job() {
    # List current cron jobs and prompt user to edit
    echo -e "\033[1;33mCurrent cron jobs:\033[0m"
    crontab -l

    echo -e "\033[1;33mDo you want to edit the cron job? (yes/no)\033[0m"
    read -p "Enter your choice: " edit_choice

    if [[ "$edit_choice" == "yes" ]]; then
        # Edit the cron job
        echo -e "\033[1;33mEditing cron jobs...\033[0m"
        crontab -e  # Opens the crontab in the default editor
        # Reload cron service after editing
        if sudo service cron reload; then
            echo -e "\033[1;32mCron job reloaded successfully.\033[0m"
        else
            echo -e "\033[1;31mFailed to reload cron service.\033[0m"
        fi
    else
        echo -e "\033[1;32mNo changes made to the cron job.\033[0m"
    fi

    sleep 1  # Pause before returning to the menu
}


menu() {
    while true; do  # Start an infinite loop
        clear
        echo -e "\033[1;32mSelect an option:\033[0m"
        echo "1) Setup"
        echo "2) Edit Cron Job"
        echo "0) Exit"

        read -p "Enter your choice: " choice

        case $choice in
            1)
                install_if_missing
                check_config
                download_check_url_script  # Download the script as part of option 1
                set_url_test_cron
                sudo chmod +x /root/check_url.sh
                /bin/bash /root/check_url.sh
                ;;
            2)
                edit_cron_job
                ;;
            0)
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                ;;
        esac
    done
}

menu
