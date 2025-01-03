#!/bin/bash

# Color settings for nice output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

add_cron_job() {
    while true; do
        echo -e "${YELLOW}Cron job scheduler selected.${RESET}"
        echo "You will need to specify the time and frequency."
        echo -e "${BLUE}How often should the cron job run?${RESET}"
        echo -e "${BLUE}1)${RESET} Every X minutes (1-60)"
        echo -e "${BLUE}2)${RESET} Every X hours (1-23)"
        echo -e "${BLUE}3)${RESET} Every day"
        echo -e "${BLUE}4)${RESET} Every X days"
        echo -e "${BLUE}5)${RESET} Every week (Sunday-Saturday)"
        echo -e "${BLUE}6)${RESET} Every X weeks"
        echo -e "${BLUE}7)${RESET} Every month"
        echo -e "${BLUE}8)${RESET} Every X months"
        echo -e "${RED}9)${RESET} Return"
        read -p "Enter your choice: " frequency_choice

        frequency_days=1
        frequency_months=1
        frequency_minutes=1
        frequency_hours=1
        day_of_week=""
        
        case "$frequency_choice" in
            1)
                read -p "Enter the number of minutes (1-60): " frequency_minutes
                [[ "$frequency_minutes" =~ ^[0-9]+$ && "$frequency_minutes" -ge 1 && "$frequency_minutes" -le 60 ]] || { echo -e "${RED}Invalid input. Please enter a number between 1 and 60.${RESET}"; continue; }
                echo "Cron job will run every $frequency_minutes minute(s)."
                ;;
            2)
                read -p "Enter the number of hours (1-23): " frequency_hours
                [[ "$frequency_hours" =~ ^[0-9]+$ && "$frequency_hours" -ge 1 && "$frequency_hours" -le 23 ]] || { echo -e "${RED}Invalid input. Please enter a number between 1 and 23.${RESET}"; continue; }
                echo "Cron job will run every $frequency_hours hour(s)."
                ;;
            3) echo "Cron job will run every day." ;;
            4)
                read -p "Enter the number of days (e.g., 2 for every 2 days): " frequency_days
                [[ "$frequency_days" =~ ^[0-9]+$ ]] || { echo -e "${RED}Invalid input. Please enter a number.${RESET}"; continue; }
                echo "Cron job will run every $frequency_days day(s)."
                ;;
            5)
                echo "Select the day of the week to run the cron job:"
                echo "0) Sunday"
                echo "1) Monday"
                echo "2) Tuesday"
                echo "3) Wednesday"
                echo "4) Thursday"
                echo "5) Friday"
                echo "6) Saturday"
                read -p "Enter the day of the week (0-6): " day_of_week
                [[ "$day_of_week" =~ ^[0-6]$ ]] || { echo -e "${RED}Invalid day. Please enter a number between 0-6.${RESET}"; continue; }
                frequency_days=7
                echo "Cron job will run every $day_of_week day(s) of the week."
                ;;
            6)
                read -p "Enter the number of weeks (e.g., 2 for every 2 weeks): " frequency_weeks
                [[ "$frequency_weeks" =~ ^[0-9]+$ ]] || { echo -e "${RED}Invalid input. Please enter a number.${RESET}"; continue; }
                frequency_days=$((frequency_weeks * 7))
                ;;
            7) echo "Cron job will run every month." ;;
            8)
                read -p "Enter the number of months (e.g., 2 for every 2 months): " frequency_months
                [[ "$frequency_months" =~ ^[0-9]+$ ]] || { echo -e "${RED}Invalid input. Please enter a number.${RESET}"; continue; }
                echo "Cron job will run every $frequency_months month(s)."
                ;;
            9) echo -e "${BLUE}Returning to the previous menu...${RESET}"; return ;;
            *) echo -e "${RED}Invalid choice...${RESET}"; continue ;;
        esac

        # Handle minute intervals (1-60)
        if [[ "$frequency_choice" -eq 1 ]]; then
            schedule="*/$frequency_minutes * * * *"
        # Handle hour intervals (1-23)
        elif [[ "$frequency_choice" -eq 2 ]]; then
            schedule="0 */$frequency_hours * * *"
        else
            # For other frequencies, ask for the time (hour and minute)
            while true; do
                read -p "Enter the hour (0-23): " hour
                read -p "Enter the minute (00-59): " minute
                if [[ "$hour" =~ ^[0-9]$|^1[0-9]$|^2[0-3]$ ]] && [[ "$minute" =~ ^[0-5][0-9]$ ]]; then
                    schedule="$minute $hour * * *"
                    break
                else
                    echo -e "${RED}Invalid time. Enter a valid hour (0-23) and minute (00-59).${RESET}"
                fi
            done
        fi

        # Adjust schedule for days/weeks/months
        if [[ "$frequency_days" -gt 1 && "$frequency_choice" -ne 2 ]]; then
            schedule="$minute $hour */$frequency_days * *"
        elif [[ "$frequency_months" -gt 1 && "$frequency_choice" -eq 8 ]]; then
            schedule="$minute $hour 1 */$frequency_months *"
        elif [[ "$frequency_days" -eq 7 && "$frequency_choice" -ne 2 ]]; then
            schedule="$minute $hour * * $day_of_week"
        fi

        read -p "Enter the command (e.g., sudo /root/cron.sh): " cron_command
        cron_command=$(echo "$cron_command" | xargs) # Strip quotes and spaces

        echo -e "${GREEN}Scheduled Cron Job: ${RESET}$schedule $cron_command"
        read -p "Do you want to add this cron job to the crontab? (default: yes): " add_cron
        add_cron="${add_cron:-yes}"

        if [[ "$add_cron" == "yes" ]]; then
        # Get current crontab, remove empty lines, and add the new cron job
        (crontab -l 2>/dev/null | grep -v '^$'; echo "$schedule $cron_command") | crontab -

        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}Cron job added successfully!${RESET}"
        else
            echo -e "${RED}Failed to add cron job. Please check the crontab syntax.${RESET}"
        fi
      else
          echo -e "${RED}Cron job was not added.${RESET}"
      fi

        break
    done
    read -p "Press Enter to continue..."
    cron_menu
}


# Function for the main menu
cron_menu() {
clear
    echo -e "${GREEN}=== Cron Job Management ===${RESET}"
    echo -e "${RED}1.${RESET} Add a new cron job"
    echo -e "${RED}2.${RESET} View existing cron jobs"
    echo -e "${RED}3.${RESET} Edit cron job with nano"
    echo -e "${RED}4.${RESET} Delete a cron job"
    echo -e "${RED}5.${RESET} View cron job log"
    echo -e "${RED}6.${RESET} install Cron"
    echo -e "${RED}7.${RESET} reload Cron"
    echo -e "${BLUE}0. Exit${RESET}"
    
    # Prompt user for input with color
    read -p "$(echo -e "${YELLOW}Choose an option: ${RESET}")" choice

    case $choice in
        1)
            echo -e "${YELLOW}You selected to add a new cron job.${RESET}"
            add_cron_job
            sudo service cron reload
            ;;
        2)
            echo -e "${YELLOW}You selected to view existing cron jobs.${RESET}"
            view_cron_jobs
            ;;
        3)
            echo -e "${YELLOW}You selected to edit a cron job.${RESET}"
            edit_cron_job
            ;;
        4)
            echo -e "${YELLOW}You selected to delete a cron job.${RESET}"
            delete_cron_job
            ;;
        5)
            echo -e "${YELLOW}You selected to view cron job logs.${RESET}"
            view_cron_log
            ;;
        6)
            echo -e "${YELLOW}You selected to check and install Cron if missing.${RESET}"
            check_cron_installed
            check_cron_service
            read -p "Press Enter to continue..."
            cron_menu
            ;;
        7)
            echo -e "${YELLOW}You selected to reload cron.${RESET}"
            reload_cron_service
            ;;
        0)
            echo -e "${GREEN}Exiting Cron Management. Goodbye!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option, please try again.${RESET}"
            read -p "Press Enter to continue..."
            cron_menu
            ;;
    esac
}

# Function to check if cron is installed
check_cron_installed() {
    echo -e "${CYAN}Checking if Cron is installed...${RESET}"
    if ! command -v cron &> /dev/null; then
        echo -e "${RED}Error: Cron is not installed. Installing cron...${RESET}"
        sudo apt update && sudo apt install cron -y
        sudo service cron start
        echo -e "${GREEN}Cron installed and started successfully.${RESET}"
    else
        echo -e "${GREEN}Cron is already installed.${RESET}"
    fi
}

# Function to check if cron service is running
check_cron_service() {
    echo -e "${CYAN}Checking if Cron service is running...${RESET}"
    if systemctl is-active --quiet cron; then
        echo -e "${GREEN}Cron service is running.${RESET}"
    else
        echo -e "${RED}Cron service is not running. Starting cron service...${RESET}"
        sudo service cron start
        echo -e "${GREEN}Cron service started successfully.${RESET}"
    fi
}

# Function to view existing cron jobs
view_cron_jobs() {
    echo -e "${YELLOW}Your Current Cron Jobs:${RESET}"

    # Display current cron jobs
    crontab -l

    echo -e "${GREEN}End of Cron Jobs.${RESET}"
    read -p "Press Enter to continue..."
    cron_menu
}

edit_cron_job() {
    echo -e "${YELLOW}Edit Cron Jobs${RESET}"
    
    # Check for existing cron jobs
    if ! crontab -l &>/dev/null; then
        echo -e "${RED}No cron jobs found!${RESET}"
        cron_menu
        return
    fi
    
    # Open cron jobs in nano for editing
    echo -e "${YELLOW}Opening the cron jobs in nano...${RESET}"
    crontab -l > /tmp/cron_edit
    nano /tmp/cron_edit

    # Update cron jobs after editing
    crontab /tmp/cron_edit
    rm /tmp/cron_edit

    echo -e "${GREEN}Cron jobs updated successfully!${RESET}"
    sudo service cron reload
    read -p "Press Enter to continue..."
    cron_menu
}


delete_cron_job() {
    echo -e "${YELLOW}Delete a Cron Job${RESET}"

    # View current cron jobs and clean leading/trailing spaces
    cron_jobs=$(crontab -l | sed 's/^[[:space:]]*//')

    # Check if there are any existing cron jobs
    if [[ -z "$cron_jobs" ]]; then
        echo -e "${RED}No cron jobs found!${RESET}"
        read -p "Press Enter to continue..."
    cron_menu
    fi

    # List existing cron jobs, making sure there are no extra spaces
    echo -e "${YELLOW}Current Cron Jobs:${RESET}"
    echo "$cron_jobs" | nl -s '. '  # List with line numbers, no leading spaces

    # Prompt user to select a cron job to delete
    echo -e "${YELLOW}Enter the cron job number you want to delete (starting from 1):${RESET}"
    read -p "$(echo -e "${CYAN}Enter the job number: ${RESET}")" job_num

    # Validate job number and ensure it's within the range
    if ! [[ "$job_num" =~ ^[0-9]+$ ]] || [ "$job_num" -le 0 ] || [ "$job_num" -gt "$(echo "$cron_jobs" | wc -l)" ]; then
        echo -e "${RED}Invalid job number. Please try again.${RESET}"
        delete_cron_job
        return
    fi

    # Remove the selected cron job
    cron_jobs=$(echo "$cron_jobs" | sed "${job_num}d")

    # Save the updated cron jobs
    echo "$cron_jobs" | crontab -

    echo -e "${GREEN}Cron job deleted successfully!${RESET}"
    read -p "Press Enter to continue..."
    cron_menu
}




# Function to view cron job logs (optional log file or standard output)
view_cron_log() {
    echo -e "${YELLOW}View Cron Job Log${RESET}"

    # Display system cron logs (e.g., /var/log/syslog for Ubuntu)
    # You may need root privileges to access system log files
    sudo cat /var/log/syslog | grep CRON

    echo -e "${GREEN}End of Cron Logs.${RESET}"
    read -p "Press Enter to continue..."
    cron_menu
}

# Function to reload the cron service
reload_cron_service() {
    echo -e "${YELLOW}Reloading cron service...${RESET}"

    sudo service cron reload

    echo -e "${GREEN}Cron service reloaded successfully!${RESET}"
    read -p "Press Enter to continue..."
    cron_menu
}

# Run the main menu function to start the script
check_cron_installed
cron_menu
