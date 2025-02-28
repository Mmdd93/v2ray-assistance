#!/bin/bash
#marzneshin
marzneshin_commands() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m           marzneshin Commands\033[0m"
        echo -e "\033[1;36m============================================\033[0m"

        echo -e "\033[1;32mAvailable commands:\033[0m"
        echo -e "\033[1;32m1.\033[0m Install marzneshin"
        echo -e "\033[1;31m2.\033[0m Create sudo admin"
        echo -e "\033[1;32m3.\033[0m Edit admin (marzneshin cli commands)"
        echo -e "\033[1;32m4.\033[0m Start services"
        echo -e "\033[1;32m5.\033[0m Stop services"
        echo -e "\033[1;32m6.\033[0m Restart services"
        echo -e "\033[1;32m7.\033[0m marzneshin status"
        echo -e "\033[1;32m8.\033[0m Show logs"
        echo -e "\033[1;32m9.\033[0m Update marzneshin"
        echo -e "\033[1;32m10.\033[0m Uninstall marzneshin"
        echo -e "\033[1;32m11.\033[0m Install marzneshin script"
        echo -e "\033[1;32m12.\033[0m Update/Change Xray core"
        echo -e "\033[1;32m13.\033[0m Edit .env"
        echo -e "\033[1;32m14.\033[0m Edit docker-compose.yml"
        echo -e "\033[1;32m15.\033[0m Change database to MySql"
	echo -e "\033[1;32m16.\033[0m bypass ssl"
 	echo -e "\033[1;32m17.\033[0m Manual backup launchl"
  	echo -e "\033[1;32m18.\033[0m marzneshin Backupservice to backup to TG, and a new job in crontab"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        echo -e "\033[1;36m============================================\033[0m"

        read -p "Select a command number: " command_choice

        case $command_choice in
            1) install_marzneshin ;;
            2) sudo marzneshin cli admin create --sudo ;;
            3) marzneshin_cli_commands ;;
            4) sudo marzneshin up ;;
            5) sudo marzneshin down ;;
            6) sudo marzneshin restart ;;
            7) sudo marzneshin status ;;
            8) sudo marzneshin logs ;;
            9) sudo marzneshin update ;;
            10) sudo marzneshin uninstall ;;
            11) sudo marzneshin install-script ;;
            12) sudo marzneshin core-update ;;
            13) sudo nano /etc/opt/marzneshin/.env ;;
            14) sudo nano /etc/opt/marzneshin/docker-compose.yml ;;
            15) mysql ;;
	    16) bypass ;;   
		17) sudo marzneshin backup ;;
		18) sudo marzneshin backup-service ;;

            0) return ;;  
            *)
                echo -e "\033[1;31mInvalid choice. Please enter a number between 0 and 15.\033[0m" ;;
        esac

        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the marzneshin Commands."
        read
    done
}
bypass() {
    echo -e "\033[1;34mTo bypass SSL for marzneshin:\033[0m"
    echo -e "\033[1;32m\033[0m Install Nginx if it's not already installed."
    echo -e "\033[1;32m\033[0m use bypass option (13) in Nginx configuration."
    echo -e "\033[1;32m\033[0m Restart Nginx to apply the changes."
    # Prompt to continue
    read -p "Press Enter to continue..."
    
    # Call manage_nginx function
    curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/nginx.sh -o nginx.sh
            sudo bash nginx.sh 
}

install_marzneshin() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m        Installing marzneshin\033[0m"
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;31m1. Press ctrl+c anytime to stop viewing the logs after installation.\033[0m"
        echo -e "\033[1;31m2. You need to create a sudo admin after installing to access the panel.\033[0m"
        echo -e "\033[1;31m3. Access the panel at: http://YOUR_SERVER_IP:8000/dashboard/\033[0m"
        
        echo -e "\033[1;36mChoose installation version:\033[0m"
        echo -e "\033[1;32m1. Latest version (SQLite)\033[0m"
		echo -e "\033[1;32m2. Latest version (MySQL)\033[0m"
		echo -e "\033[1;32m3. Latest version (MariaDB)\033[0m"
        echo -e "\033[1;32m4. Nightly version (SQLite)\033[0m"
        echo -e "\033[1;32m5. Nightly version (MySQL)\033[0m"
		echo -e "\033[1;32m6. Nightly version (MariaD)\033[0m"
        echo -e "\033[1;32m7. custom version (SQLite)\033[0m"
        echo -e "\033[1;32m8. custom version (MySQL)\033[0m"
		echo -e "\033[1;32m9. custom version (MariaD)\033[0m"
        echo -e "\033[1;32m0. Return\033[0m"
        read -p "Enter your choice: " version_choice

        case $version_choice in
            1)
                echo -e "\033[1;32mRunning the Latest marzneshin installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install
                ;;
            4)
                echo -e "\033[1;32mRunning the nightly  marzneshin installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --nightly 
                ;;
                
            2)
                echo -e "\033[1;32mRunning the Latest MySQL marzneshin installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --database mysql
                ;;
                
            5)
                echo -e "\033[1;32mRunning the nightly  MySQL marzneshin installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --database mysql --nightly 
                ;;
                
              7)
                echo -e "\033[1;32mFetching all releases from GitHub...\033[0m"
                # Fetch all release tags for SQLite
                releases=$(curl -s https://api.github.com/repos/marzneshin/marzneshin/releases | jq -r '.[].tag_name')
                echo -e "\033[1;32mAvailable Releases for SQLite:\033[0m"
                
                # Display available versions
                PS3="Please select a version (enter number e.g 1): "
                select version in $releases; do
                    if [[ -n "$version" ]]; then
                        echo -e "\033[1;32mRunning the Custom marzneshin installation script for SQLite version $version...\033[0m"
                        sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --version "$version"
                        break
                    else
                        echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                    fi
                done
                ;;

            8)
                echo -e "\033[1;32mFetching all releases from GitHub...\033[0m"
                # Fetch all release tags for MySQL
                releases=$(curl -s https://api.github.com/repos/marzneshin/marzneshin/releases | jq -r '.[].tag_name')
                echo -e "\033[1;32mAvailable Releases for MySQL:\033[0m"
                
                # Display available versions
                PS3="Please select a version (enter number e.g 2): "
                select version in $releases; do
                    if [[ -n "$version" ]]; then
                        echo -e "\033[1;32mRunning the Custom marzneshin installation script for MySQL version $version...\033[0m"
                        sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --database mysql --version "$version"
                        break
                    else
                        echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                    fi
                done
                ;;
		3)
                echo -e "\033[1;32mRunning the Latest MariaDB marzneshin installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --database mariadb
                ;;
		6)
                echo -e "\033[1;32mRunning the nightly  MariaDB marzneshin installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --database mariadb --nightly 
                ;;
		9)
                echo -e "\033[1;32mFetching all releases from GitHub...\033[0m"
                # Fetch all release tags for MySQL
                releases=$(curl -s https://api.github.com/repos/marzneshin/marzneshin/releases | jq -r '.[].tag_name')
                echo -e "\033[1;32mAvailable Releases for MySQL:\033[0m"
                
                # Display available versions
                PS3="Please select a version (enter number e.g 2): "
                select version in $releases; do
                    if [[ -n "$version" ]]; then
                        echo -e "\033[1;32mRunning the Custom marzneshin installation script for MariaDB version $version...\033[0m"
                        sudo bash -c "$(curl -sL https://github.com/marzneshin/Marzneshin/raw/master/script.sh)" @ install --database mariadb --version "$version"
                        break
                    else
                        echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                    fi
                done
                ;;
            0)
                echo -e "\033[1;31mReturning to marzneshin Commands.\033[0m"
                marzneshin_commands
                break  # Break out of the loop and return to the main menu
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please enter [0, 1, or 2].\033[0m"
                ;;
        esac

        # Wait for user to press Enter before returning to the loop
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the marzneshin Commands."
        read
    done
}

marzneshin_cli_commands() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m           marzneshin CLI Commands\033[0m"
        echo -e "\033[1;36m============================================\033[0m"

        echo -e "\033[1;32mAvailable CLI commands:\033[0m"
        echo -e "\033[1;32m1.\033[0m Create an admin"
        echo -e "\033[1;32m2.\033[0m Delete the admin"
        echo -e "\033[1;32m3.\033[0m Import the sudo admin from env"
        echo -e "\033[1;32m4.\033[0m Display list of admins"
        echo -e "\033[1;32m5.\033[0m Edit and update admin"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        echo -e "\033[1;36m============================================\033[0m"

        read -p "Select a CLI command number (0-5): " cli_choice

        case $cli_choice in
            1)
                read -p "Enter the admin name to create: " admin_name
                sudo marzneshin cli admin create "$admin_name" || echo -e "\033[1;31mError occurred while creating admin. Returning to CLI commands.\033[0m"
                ;;
            2)
                read -p "Enter the admin name to delete: " admin_name
                sudo marzneshin cli admin delete "$admin_name" || echo -e "\033[1;31mError occurred while deleting admin. Returning to CLI commands.\033[0m"
                ;;
            3)
                sudo marzneshin cli admin import-from-env || echo -e "\033[1;31mError occurred while importing admin. Returning to CLI commands.\033[0m"
                ;;
            4)
                sudo marzneshin cli admin list || echo -e "\033[1;31mError occurred while displaying admin list. Returning to CLI commands.\033[0m"
                ;;
            5)
                read -p "Enter the admin name to update: " admin_name
                sudo marzneshin cli admin update "$admin_name" || echo -e "\033[1;31mError occurred while updating admin. Returning to CLI commands.\033[0m"
                ;;
            0)
                return
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please enter a number between 0 and 5.\033[0m"
                ;;
        esac

        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the CLI commands."
        read
    done
}
marzneshin_commands