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
                sudo marzban cli admin create || echo -e "\033[1;31mError occurred while creating admin. Returning to CLI commands.\033[0m"
                ;;
            2)
                sudo marzban cli admin delete || echo -e "\033[1;31mError occurred while deleting admin. Returning to CLI commands.\033[0m"
                ;;
            3)
                sudo marzban cli admin import-from-env || echo -e "\033[1;31mError occurred while importing admin. Returning to CLI commands.\033[0m"
                ;;
            4)
                sudo marzban cli admin list || echo -e "\033[1;31mError occurred while displaying admin list. Returning to CLI commands.\033[0m"
                ;;
            5)
                sudo marzban cli admin update || echo -e "\033[1;31mError occurred while updating admin. Returning to CLI commands.\033[0m"
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
#mysql
# Define file paths
env_file="/opt/marzban/.env"
compose_file="/opt/marzban/docker-compose.yml"
backup_dir="/opt/marzban/backups"
marzban_lib_dir="/var/lib/marzban"
timestamp=$(date +%Y%m%d_%H%M%S)

# Function to update Docker Compose configuration
update_docker_compose() {
    if [[ -f "$compose_file" ]]; then
        echo -e "\033[1;34mUpdating Docker Compose configuration...\033[0m"
        cat <<EOL > "$compose_file"
services:
  marzban:
    image: gozargah/marzban:dev
    restart: always
    env_file: .env
    network_mode: host
    volumes:
      - /var/lib/marzban:/var/lib/marzban

    depends_on:
      - mysql
      
  mysql:
    image: mysql:latest
    restart: always
    env_file: .env
    network_mode: host
    command: --bind-address=127.0.0.1 --mysqlx-bind-address=127.0.0.1 --disable-log-bin
    environment:
      MYSQL_DATABASE: marzban
    volumes:
      - /var/lib/marzban/mysql:/var/lib/mysql
      
  phpmyadmin:
    image: phpmyadmin/phpmyadmin:latest
    restart: always
    env_file: .env
    network_mode: host
    environment:
      PMA_HOST: 127.0.0.1
      APACHE_PORT: 8010
      UPLOAD_LIMIT: 1024M
    depends_on:
      - mysql
EOL
        echo -e "\033[1;32mDocker Compose updated successfully.\033[0m"
    else
        echo -e "\033[1;31mError: $compose_file not found.\033[0m"
    fi
}

update_env_variables() {
    # Ask for the MySQL root password twice
    read -p "Enter the MySQL root password: " db_password_1
    echo
    read -p "Confirm the MySQL root password: " db_password_2
    echo

    # Check if both passwords match
    if [[ "$db_password_1" != "$db_password_2" ]]; then
        echo -e "\033[1;31mError: Passwords do not match. Please try again.\033[0m"
        return 1
    fi

    # Ensure the password is not empty
    if [[ -z "$db_password_1" ]]; then
        echo -e "\033[1;31mError: Password cannot be empty.\033[0m"
        return 1
    fi



    if [[ -f "$env_file" ]]; then
        echo -e "\033[1;34mUpdating environment variables in $env_file...\033[0m"

        # Remove existing MySQL-related variables
        sed -i '/^SQLALCHEMY_DATABASE_URL=mysql+pymysql:.*$/d' "$env_file"
        sed -i '/^MYSQL_ROOT_PASSWORD=.*$/d' "$env_file"

        # Comment out existing SQLite configuration if it exists
        sed -i 's|^SQLALCHEMY_DATABASE_URL = "sqlite:////var/lib/marzban/db.sqlite3"|#&|' "$env_file"

        # Add MySQL-related variables
        sed -i "\$aSQLALCHEMY_DATABASE_URL=mysql+pymysql://root:$db_password_1@127.0.0.1/marzban" "$env_file"
        sed -i "\$aMYSQL_ROOT_PASSWORD=$db_password_1" "$env_file"

        echo -e "\033[1;32mEnvironment variables updated successfully.\033[0m"
    else
        echo -e "\033[1;31mError: $env_file not found.\033[0m"
        return 1
    fi
}


# Function to backup essential directories
backup_essential_folders() {
    backup_file="$backup_dir/backup_$timestamp.tar.gz"
    echo -e "\033[1;34mBacking up essential folders...\033[0m"

    mkdir -p "$backup_dir"
    tar -czvf "$backup_file" "$env_file" "$compose_file" "$marzban_lib_dir" "$backup_dir" || {
        echo -e "\033[1;31mBackup failed. Please check the error messages above.\033[0m"
        return 1
    }
    
    echo -e "\033[1;32mBackup created successfully at $backup_file\033[0m"
}

# Function to restore from a backup
restore_from_backup() {
    echo -e "\033[1;34mAvailable backups:\033[0m"
    ls "$backup_dir"

    read -p "Enter the name of the backup file to restore (e.g., backup_YYYYMMDD_HHMMSS.tar.gz): " backup_file

    if [[ -f "$backup_dir/$backup_file" ]]; then
        echo -e "\033[1;34mRestoring from $backup_file...\033[0m"
        tar -xzvf "$backup_dir/$backup_file" -C / || {
            echo -e "\033[1;31mRestore failed. Please check the error messages above.\033[0m"
            return 1
        }
        echo -e "\033[1;32mRestore completed successfully.\033[0m"
    else
        echo -e "\033[1;31mError: Backup file not found.\033[0m"
    fi
}
# Function to check if necessary applications are installed
check_and_install_dependencies() {
    for cmd in sqlite3 sed docker-compose; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "\033[1;31mError: $cmd is not installed. Attempting to install...\033[0m"
            if [[ "$cmd" == "sqlite3" ]]; then
                if [[ -x "$(command -v apt)" ]]; then
                    sudo apt update && sudo apt install -y sqlite3 || { echo -e "\033[1;31mFailed to install sqlite3.\033[0m"; exit 1; }
                elif [[ -x "$(command -v yum)" ]]; then
                    sudo yum install -y sqlite || { echo -e "\033[1;31mFailed to install sqlite3.\033[0m"; exit 1; }
                else
                    echo -e "\033[1;31mPackage manager not supported. Please install sqlite3 manually.\033[0m"
                    exit 1
                fi
            else
                echo -e "\033[1;31mPlease install $cmd manually.\033[0m"
                exit 1
            fi
        fi
    done
}

# Function to dump SQLite database
dump_sqlite_database() {
    echo -e "\033[1;34mDumping SQLite database...\033[0m"
    sqlite3 /var/lib/marzban/db.sqlite3 '.dump --data-only' | sed "s/INSERT INTO \([^ ]*\)/REPLACE INTO \`\\1\`/g" > /tmp/dump.sql || {
        echo -e "\033[1;31mFailed to dump the database. Please check the error messages above.\033[0m"
        return 1
    }
    echo -e "\033[1;32mDatabase dumped successfully to /tmp/dump.sql\033[0m"
}

# Function to restore from the dump file to MySQL
restore_from_dump() {
    echo -e "\033[1;34mRestoring database from dump file to MySQL...\033[0m"

    # Change to the Marzban directory
    cd /opt/marzban || {
        echo -e "\033[1;31mError: Could not change to /opt/marzban directory.\033[0m"
        return 1
    }

    # Copy the dump.sql file to the MySQL container
    docker-compose cp /tmp/dump.sql mysql:/dump.sql || {
        echo -e "\033[1;31mError: Failed to copy dump.sql to MySQL container.\033[0m"
        return 1
    }

    # Execute the SQL commands in the MySQL container
    read -s -p "Enter the MySQL root password: " db_password
    echo

    docker-compose exec mysql mysql -u root -p"$db_password" -h 127.0.0.1 marzban -e "SET FOREIGN_KEY_CHECKS = 0; SET NAMES utf8mb4; SOURCE /dump.sql;" || {
        echo -e "\033[1;31mError: Failed to execute SQL commands in MySQL container.\033[0m"
        return 1
    }

    echo -e "\033[1;32mDatabase restored successfully from dump.sql to MySQL.\033[0m"
}

# Function to transfer data from SQLite to MySQL
transfer_data() {
    check_and_install_dependencies
    dump_sqlite_database
    restore_from_dump
}
# Main menu function
mysql() {
    while true; do
        echo -e "\033[1;34mChange database to MySql:\033[0m"
        echo -e "\033[1;32m1.\033[0m Update Docker Compose for mysql"
        echo -e "\033[1;32m2.\033[0m Update env for mysql"
        echo -e "\033[1;32m3.\033[0m Create Backup"
        echo -e "\033[1;32m4.\033[0m Restore backup"
        echo -e "\033[1;32m5.\033[0m Transfer data from SQLite to MySQL"
        echo -e "\033[1;32m6.\033[0m Edit .env using nano"
        echo -e "\033[1;32m7.\033[0m Edit compose_file using nano"
        echo -e "\033[1;32m8.\033[0m Restart Marzban"
        echo -e "\033[1;32m0.\033[0m return"

        read -p "Choose an option [0-8]: " choice

        case $choice in
            1) update_docker_compose ;;
            2) update_env_variables ;;
            3) backup_essential_folders ;;
            4) restore_from_backup ;;
            5) transfer_data ;;
            6) nano "$env_file" ;;
            7) nano "$compose_file" ;;
            8) marzban restart ;;
            0) 
                 echo -e "\033[1;32mExiting...\033[0m"; 
                 marzban_commands
                ;;
            *) echo -e "\033[1;31mInvalid option. Please choose a valid option [0-8].\033[0m" 
        esac
        echo -e "\033[1;34mReturning to the main menu...\033[0m"
    done
}
marzban_commands
