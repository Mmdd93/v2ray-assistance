#!/bin/bash
#marzban
marzban_commands() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m           Marzban Commands\033[0m"
        echo -e "\033[1;36m============================================\033[0m"

        echo -e "\033[1;32mAvailable commands:\033[0m"
        echo -e "\033[1;32m1.\033[0m Install Marzban"
        echo -e "\033[1;31m2.\033[0m Create sudo admin"
        echo -e "\033[1;32m3.\033[0m Edit admin"
        echo -e "\033[1;32m4.\033[0m Start services"
        echo -e "\033[1;32m5.\033[0m Stop services"
        echo -e "\033[1;32m6.\033[0m Restart services"
        echo -e "\033[1;32m7.\033[0m Marzban status"
        echo -e "\033[1;32m8.\033[0m Show logs"
        echo -e "\033[1;32m9.\033[0m Update Marzban"
        echo -e "\033[1;32m10.\033[0m Uninstall Marzban"
        echo -e "\033[1;32m11.\033[0m Install Marzban script"
        echo -e "\033[1;32m12.\033[0m Update/Change Xray core"
        echo -e "\033[1;32m13.\033[0m Edit .env"
        echo -e "\033[1;32m14.\033[0m Edit docker-compose.yml"
        echo -e "\033[1;32m15.\033[0m Change database to MySql"
	echo -e "\033[1;32m16.\033[0m bypass ssl"
 	echo -e "\033[1;32m17.\033[0m Manual backup launchl"
  	echo -e "\033[1;32m18.\033[0m Marzban Backupservice to backup to TG, and a new job in crontab"
        echo -e "\033[1;32m0.\033[0m Return to the main menu"

        echo -e "\033[1;36m============================================\033[0m"

        read -p "Select a command number: " command_choice

        case $command_choice in
            1) install_marzban ;;
            2) sudo marzban cli admin create --sudo || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            3) marzban_cli_commands || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            4) sudo marzban up || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            5) sudo marzban down || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            6) sudo marzban restart || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            7) sudo marzban status || echo -e "\033[1;31m Marzban not installed.\033[0m" ;;
            8) sudo marzban logs || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            9) sudo marzban update || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            10) sudo marzban uninstall || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            11) sudo marzban install-script || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            12) sudo marzban core-update || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            13) sudo nano /opt/marzban/.env || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            14) sudo nano /opt/marzban/docker-compose.yml || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
            15) mysql || echo -e "\033[1;31mcheck [marzban status]\033[0m" ;;
	    16) bypass ;;   
		17) sudo marzban backup ;;
		18) sudo marzban backup-service ;;

            0) return ;;  
            *)
                echo -e "\033[1;31mInvalid choice. Please enter a number between 0 and 15.\033[0m" ;;
        esac

        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the Marzban Commands."
        read
    done
}
bypass() {
    echo -e "\033[1;34mTo bypass SSL for Marzban:\033[0m"
    echo -e "\033[1;32m\033[0m Install Nginx if it's not already installed."
    echo -e "\033[1;32m\033[0m use bypass option (13) in Nginx configuration."
    echo -e "\033[1;32m\033[0m Restart Nginx to apply the changes."
    # Prompt to continue
    read -p "Press Enter to continue..."
    
    # Call manage_nginx function
    curl -Ls https://github.com/Mmdd93/v2ray-assistance/raw/refs/heads/main/nginx.sh -o nginx.sh
            sudo bash nginx.sh 
}

install_marzban() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m        Installing Marzban\033[0m"
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;31m1. Press ctrl+c anytime to stop viewing the logs after installation.\033[0m"
        echo -e "\033[1;31m2. You need to create a sudo admin after installing to access the panel.\033[0m"
        echo -e "\033[1;31m3. Access the panel at: http://YOUR_SERVER_IP:8000/dashboard/\033[0m"
        
        echo -e "\033[1;36mChoose installation version:\033[0m"
        echo -e "\033[1;32m1. Latest version (SQLite)\033[0m"
        echo -e "\033[1;32m2. Development version (SQLite)\033[0m"
        echo -e "\033[1;32m3. Latest version (MySQL)\033[0m"
        echo -e "\033[1;32m4. Development version (MySQL)\033[0m"
        echo -e "\033[1;32m5. custom version (SQLite)\033[0m"
        echo -e "\033[1;32m6. custom version (MySQL)\033[0m"
	echo -e "\033[1;32m7. Latest version (MariaDB)\033[0m"
 	echo -e "\033[1;32m8. Development version (MariaD)\033[0m"
  	echo -e "\033[1;32m9. custom version (MariaD)\033[0m"
        echo -e "\033[1;32m0. Return\033[0m"
        read -p "Enter your choice: " version_choice

        case $version_choice in
            1)
                echo -e "\033[1;32mRunning the Latest Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
                ;;
            2)
                echo -e "\033[1;32mRunning the Dev Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --dev
                ;;
                
            3)
                echo -e "\033[1;32mRunning the Latest MySQL Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mysql
                ;;
                
            4)
                echo -e "\033[1;32mRunning the Dev MySQL Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mysql --dev
                ;;
                
              5)
                echo -e "\033[1;32mFetching all releases from GitHub...\033[0m"
                # Fetch all release tags for SQLite
                releases=$(curl -s https://api.github.com/repos/Gozargah/Marzban/releases | jq -r '.[].tag_name')
                echo -e "\033[1;32mAvailable Releases for SQLite:\033[0m"
                
                # Display available versions
                PS3="Please select a version (enter number e.g 1): "
                select version in $releases; do
                    if [[ -n "$version" ]]; then
                        echo -e "\033[1;32mRunning the Custom Marzban installation script for SQLite version $version...\033[0m"
                        sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --version "$version"
                        break
                    else
                        echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                    fi
                done
                ;;

            6)
                echo -e "\033[1;32mFetching all releases from GitHub...\033[0m"
                # Fetch all release tags for MySQL
                releases=$(curl -s https://api.github.com/repos/Gozargah/Marzban/releases | jq -r '.[].tag_name')
                echo -e "\033[1;32mAvailable Releases for MySQL:\033[0m"
                
                # Display available versions
                PS3="Please select a version (enter number e.g 2): "
                select version in $releases; do
                    if [[ -n "$version" ]]; then
                        echo -e "\033[1;32mRunning the Custom Marzban installation script for MySQL version $version...\033[0m"
                        sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mysql --version "$version"
                        break
                    else
                        echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                    fi
                done
                ;;
		7)
                echo -e "\033[1;32mRunning the Latest MariaDB Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mariadb
                ;;
		8)
                echo -e "\033[1;32mRunning the Dev MariaDB Marzban installation script...\033[0m"
                sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mariadb --dev
                ;;
		9)
                echo -e "\033[1;32mFetching all releases from GitHub...\033[0m"
                # Fetch all release tags for MySQL
                releases=$(curl -s https://api.github.com/repos/Gozargah/Marzban/releases | jq -r '.[].tag_name')
                echo -e "\033[1;32mAvailable Releases for MySQL:\033[0m"
                
                # Display available versions
                PS3="Please select a version (enter number e.g 2): "
                select version in $releases; do
                    if [[ -n "$version" ]]; then
                        echo -e "\033[1;32mRunning the Custom Marzban installation script for MariaDB version $version...\033[0m"
                        sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install --database mariadb --version "$version"
                        break
                    else
                        echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
                    fi
                done
                ;;
            0)
                echo -e "\033[1;31mReturning to Marzban Commands.\033[0m"
                marzban_commands
                break  # Break out of the loop and return to the main menu
                ;;
            *)
                echo -e "\033[1;31mInvalid choice. Please enter [0, 1, or 2].\033[0m"
                ;;
        esac

        # Wait for user to press Enter before returning to the loop
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\nPress Enter to return to the Marzban Commands."
        read
    done
}

marzban_cli_commands() {
    while true; do
        echo -e "\033[1;36m============================================\033[0m"
        echo -e "\033[1;33m           Marzban CLI Commands\033[0m"
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
                sudo marzban cli admin create "$admin_name" || echo -e "\033[1;31mError occurred while creating admin. Returning to CLI commands.\033[0m"
                ;;
            2)
                read -p "Enter the admin name to delete: " admin_name
                sudo marzban cli admin delete "$admin_name" || echo -e "\033[1;31mError occurred while deleting admin. Returning to CLI commands.\033[0m"
                ;;
            3)
                sudo marzban cli admin import-from-env || echo -e "\033[1;31mError occurred while importing admin. Returning to CLI commands.\033[0m"
                ;;
            4)
                sudo marzban cli admin list || echo -e "\033[1;31mError occurred while displaying admin list. Returning to CLI commands.\033[0m"
                ;;
            5)
                read -p "Enter the admin name to update: " admin_name
                sudo marzban cli admin update "$admin_name" || echo -e "\033[1;31mError occurred while updating admin. Returning to CLI commands.\033[0m"
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
marzban_commands