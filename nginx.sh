#!/bin/bash
manage_nginx() {
clear
    while true; do
        echo -e "\033[1;34mNginx Management Menu:\033[0m"
        echo -e "\033[1;32m1. Install Nginx\033[0m"
        echo -e "\033[1;32m2. Start Nginx\033[0m"
        echo -e "\033[1;32m3. Stop Nginx\033[0m"
        echo -e "\033[1;32m4. Restart Nginx\033[0m"
        echo -e "\033[1;32m5. Nginx Status\033[0m"
        echo -e "\033[1;32m6. Configuration Test\033[0m"
        echo -e "\033[1;32m7. Add New Server Block\033[0m"
        echo -e "\033[1;32m8. Enable/Disable/Remove Server Block\033[0m"
        echo -e "\033[1;32m10. Edit Server Block\033[0m"
        echo -e "\033[1;32m11. Nginx Logs\033[0m"
        echo -e "\033[1;32m12. Set Up a Reverse Proxy\033[0m"
	echo -e "\033[1;32m13. bypass marzban ssl with Reverse Proxy\033[0m"
        echo -e "\033[1;32m14. Remove Nginx\033[0m"
        echo -e "\033[1;32m0. return to main menu \033[0m"

        read -p "Choose an option: " option

        case $option in
            1)
                echo -e "\033[1;33mInstalling Nginx...\033[0m"
                if sudo apt update && sudo apt install -y nginx; then
                    echo -e "\033[1;32mNginx installed successfully.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to install Nginx.\033[0m"
                fi
                ;;
            2)
                echo -e "\033[1;33mStarting Nginx...\033[0m"
                if sudo systemctl start nginx; then
                    echo -e "\033[1;32mNginx started.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to start Nginx.\033[0m"
                fi
                ;;
            3)
                echo -e "\033[1;33mStopping Nginx...\033[0m"
                if sudo systemctl stop nginx; then
                    echo -e "\033[1;32mNginx stopped.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to stop Nginx.\033[0m"
                fi
                ;;
            4)
                echo -e "\033[1;33mRestarting Nginx...\033[0m"
                if sudo systemctl restart nginx; then
                    echo -e "\033[1;32mNginx restarted.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to restart Nginx.\033[0m"
                fi
                ;;
            5)
                echo -e "\033[1;33mChecking Nginx status...\033[0m"
                if sudo systemctl status nginx; then
                    echo -e "\033[1;32mNginx is running.\033[0m"
                else
                    echo -e "\033[1;31mError: Nginx service could not be found or is not running.\033[0m"
                fi
                ;;
            6)
                echo -e "\033[1;33mTesting Nginx configuration...\033[0m"
                if sudo nginx -t; then
                    echo -e "\033[1;32mNginx configuration is valid.\033[0m"
                else
                    echo -e "\033[1;31mError: Nginx configuration is invalid.\033[0m"
                fi
                ;;
            7)
               read -p "Enter the domain name (e.g., example.com) or 0 to return: " domain

if [[ "$domain" != "0" && -n "$domain" ]]; then
    # Prompt for the custom port
    read -p "Enter the port number (default is 80): " port
    port=${port:-80}  # Default to port 80 if no input

    # Define both IPv4 and IPv6 listen directives
    listen_ipv4="listen $port;"
    listen_ipv6="listen [::]:$port;"

    # Create the Nginx server block configuration
    sudo tee /etc/nginx/sites-available/$domain > /dev/null <<EOF
server {
    $listen_ipv4
    $listen_ipv6
    server_name $domain www.$domain;

    location / {
        root /var/www/$domain;
        index index.html index.htm;
    }
}
EOF

    # Create the web root directory
    sudo mkdir -p /var/www/$domain

    # Download the HTML template (Insertion) for the site
    echo -e "\033[1;33mDownloading the Insertion HTML template for $domain...\033[0m"
    wget -O /var/www/$domain/template.zip https://www.tooplate.com/zip-templates/2101_insertion.zip >/dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo -e "\033[1;31mError: Failed to download the HTML template.\033[0m"
        exit 1
    fi

    # Unzip the template into a temporary folder under the domain directory
    echo -e "\033[1;33mExtracting the template to /var/www/$domain/2101_insertion/ ...\033[0m"
    sudo unzip -o /var/www/$domain/template.zip -d /var/www/$domain/ >/dev/null 2>&1
    sudo rm /var/www/$domain/template.zip  # Remove the zip file after extraction

    # Move the content from 2101_insertion/ to the domain root
    if [ -d "/var/www/$domain/2101_insertion" ]; then
        echo -e "\033[1;33mMoving template content to /var/www/$domain/ ...\033[0m"
        sudo mv /var/www/$domain/2101_insertion/* /var/www/$domain/
        sudo rm -rf /var/www/$domain/2101_insertion  # Remove the now-empty folder
    fi

    # Check if the symbolic link already exists, and create it if it doesn't
    if [ ! -L /etc/nginx/sites-enabled/$domain ]; then
        sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    else
        echo -e "\033[1;33mSymbolic link already exists for $domain. Skipping...\033[0m"
    fi

    # Reload Nginx to apply changes
    if sudo systemctl reload nginx; then
        echo -e "\033[1;32mServer block for $domain created on ports $port (IPv4) and [::]:$port (IPv6), and Nginx reloaded.\033[0m"
    else
        echo -e "\033[1;31mError: Failed to reload Nginx. Please check the configuration.\033[0m"
    fi
fi




                ;;

            8)
                while true; do
                    echo -e "\033[1;33mAvailable Server Blocks:\033[0m"
                    local index=1
                    for file in /etc/nginx/sites-available/*; do
                        if [[ -f $file ]]; then
                            echo -e "\033[1;32m$index. $(basename "$file")\033[0m"
                            index=$((index + 1))
                        fi
                    done

                    read -p "Select a server block by number or 0 to return: " server_block_number

                    if [[ "$server_block_number" == "0" ]]; then
                        echo -e "\033[1;34mReturning to the main menu...\033[0m"
                        break
                    fi

                    if [[ -n "$server_block_number" ]]; then
                        selected_block=$(ls /etc/nginx/sites-available/ | sed -n "${server_block_number}p")

                        if [[ -n $selected_block ]]; then
                            echo -e "\033[1;33mYou selected: $selected_block\033[0m"
                            echo -e "\033[1;33mChoose an action:\033[0m"
                            echo -e "\033[1;32m1. Enable the server block\033[0m"
                            echo -e "\033[1;32m2. Disable the server block\033[0m"
                            echo -e "\033[1;32m3. Remove the server block\033[0m"
                            echo -e "\033[1;32m0. Cancel and return to the server block selection\033[0m"

                            read -p "Select an action (1-3) or 0 to cancel: " action_number

                            case $action_number in
                                1)
                                    if [[ ! -L /etc/nginx/sites-enabled/$selected_block ]]; then
                                        sudo ln -s /etc/nginx/sites-available/$selected_block /etc/nginx/sites-enabled/
                                        echo -e "\033[1;32mServer block for $selected_block enabled.\033[0m"
                                    else
                                        echo -e "\033[1;33mServer block for $selected_block is already enabled.\033[0m"
                                    fi
                                    ;;
                                2)
                                    if [[ -L /etc/nginx/sites-enabled/$selected_block ]]; then
                                        sudo rm /etc/nginx/sites-enabled/$selected_block
                                        echo -e "\033[1;32mServer block for $selected_block disabled.\033[0m"
                                    else
                                        echo -e "\033[1;33mServer block for $selected_block is not enabled.\033[0m"
                                    fi
                                    ;;
                                3)
                                    if [[ -f /etc/nginx/sites-available/$selected_block ]]; then
                                        sudo rm /etc/nginx/sites-available/$selected_block
                                        echo -e "\033[1;32mServer block for $selected_block removed.\033[0m"
                                        sudo rm /etc/nginx/sites-enabled/$selected_block 2>/dev/null
                                    else
                                        echo -e "\033[1;31mServer block for $selected_block does not exist.\033[0m"
                                    fi
                                    ;;
                                0)
                                    echo -e "\033[1;34mCancelling...\033[0m"
                                    ;;
                                *)
                                    echo -e "\033[1;31mError: Invalid action selected.\033[0m"
                                    ;;
                            esac
                        else
                            echo -e "\033[1;31mError: Invalid server block number.\033[0m"
                        fi
                    fi
                done
                ;;
            10)
                echo -e "\033[1;33mAvailable server blocks:\033[0m"

# List the server blocks in /etc/nginx/sites-available/
server_blocks=($(ls /etc/nginx/sites-available))

if [[ ${#server_blocks[@]} -eq 0 ]]; then
    echo -e "\033[1;31mNo server blocks available in /etc/nginx/sites-available/.\033[0m"
    exit 1
fi

# Display the list of server blocks
for i in "${!server_blocks[@]}"; do
    echo -e "\033[1;32m$((i+1)).\033[0m ${server_blocks[$i]}"
done

# Prompt the user to select a server block by number
read -p "Enter the number of the server block to edit: " server_block_number

# Check if the input is a valid number and corresponds to a server block
if [[ $server_block_number =~ ^[0-9]+$ ]] && ((server_block_number > 0 && server_block_number <= ${#server_blocks[@]})); then
    server_block_name=${server_blocks[$((server_block_number-1))]}
    echo -e "\033[1;33mEditing server block: $server_block_name\033[0m"
    sudo nano /etc/nginx/sites-available/$server_block_name
    echo -e "\033[1;32mServer block $server_block_name edited successfully.\033[0m"
else
    echo -e "\033[1;31mError: Invalid selection. Please choose a valid server block number.\033[0m"
fi

                ;;
            11)
                echo -e "\033[1;33mNginx access logs:\033[0m"
                sudo tail -f /var/log/nginx/access.log
                ;;
           
12)


# Function to remove http/https from the input
strip_scheme() {
    echo "$1" | sed -e 's|^http://||' -e 's|^https://||'
}

# Read user inputs for the target site
read -p "Enter the target site to proxy (e.g., google.com): " target_site
echo "Is the target site using http or https?"
echo "1) http"
echo "2) https"
read -p "Enter 1 or 2: " scheme_choice

# Map user's choice to the correct scheme
if [[ "$scheme_choice" == "1" ]]; then
    scheme="http"
elif [[ "$scheme_choice" == "2" ]]; then
    scheme="https"
else
    echo -e "\033[1;31mInvalid option selected. Please run the script again and choose 1 for http or 2 for https.\033[0m"
    exit 1
fi

# Ask for the domain and its scheme
read -p "Enter your domain for replacements (e.g., domain.com): " your_domain
echo "Is your domain using http or https?"
echo "1) http"
echo "2) https"
read -p "Enter 1 or 2: " domain_scheme_choice

# Map user's choice for the domain to the correct scheme
if [[ "$domain_scheme_choice" == "1" ]]; then
    domain_scheme="http"
    ssl_config=""
elif [[ "$domain_scheme_choice" == "2" ]]; then
    domain_scheme="https"
    ssl_config=""
else
    echo -e "\033[1;31mInvalid option selected. Please run the script again and choose 1 for http or 2 for https.\033[0m"
    exit 1
fi

# Ask for ports for both HTTP and HTTPS based on domain scheme
if [[ "$domain_scheme" == "http" ]]; then
    read -p "Enter the port for HTTP (default: 80): " http_port
    http_port=${http_port:-80}
else
    read -p "Enter the port for HTTP (default: 80): " http_port
    http_port=${http_port:-80}

    read -p "Enter the port for HTTPS (default: 443): " https_port
    https_port=${https_port:-443}
fi

# Ask for SSL certificate locations if domain uses HTTPS
if [[ "$domain_scheme" == "https" ]]; then
    read -p "Enter the path to your SSL certificate (e.g., /etc/ssl/certs/your_certificate.crt): " ssl_cert
    read -p "Enter the path to your SSL certificate key (e.g., /etc/ssl/private/your_key.key): " ssl_key
fi

# Set default config name if not provided
read -p "Enter a name for the Nginx configuration file (default: reverse_proxy): " config_name
config_name=${config_name:-reverse_proxy}

# Strip the scheme from the target site and your domain
target_site=$(strip_scheme "$target_site")
your_domain=$(strip_scheme "$your_domain")

# Create the Nginx configuration content in a variable
nginx_config=$(cat <<EOF
server {
    listen $http_port; # Listen on the specified HTTP port

    server_name _;

    location / {
        proxy_pass $scheme://$target_site;
        proxy_set_header Host $target_site;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_server_name on;

        # Disable compression to make sub_filter work effectively
        proxy_set_header Accept-Encoding "";

        # Prevent redirects to the target site from changing the URL in the browser
        proxy_redirect $scheme://$target_site /;

        # Replace the target site URLs with your domain's URLs
        sub_filter '$scheme://$target_site' 'http://$your_domain:$http_port'; # Include the HTTP port

        # Ensure sub_filter works with multiple content types
        sub_filter_types text/html application/xhtml+xml;
        sub_filter_once off;
    }
}
EOF
)

# If the domain uses HTTPS, create an additional server block for it
if [[ "$domain_scheme" == "https" ]]; then
    nginx_config+=$(cat <<EOF
server {
    listen $https_port ssl; # Listen on the specified HTTPS port
    ssl_certificate $ssl_cert; # Path to your SSL certificate
    ssl_certificate_key $ssl_key; # Path to your SSL certificate key

    server_name _;

    location / {
        proxy_pass $scheme://$target_site;
        proxy_set_header Host $target_site;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_server_name on;

        # Disable compression to make sub_filter work effectively
        proxy_set_header Accept-Encoding "";

        # Prevent redirects to the target site from changing the URL in the browser
        proxy_redirect $scheme://$target_site /;

        # Replace the target site URLs with your domain's URLs
        sub_filter '$scheme://$target_site' 'https://$your_domain:$https_port'; # Include the HTTPS port

        # Ensure sub_filter works with multiple content types
        sub_filter_types text/html application/xhtml+xml;
        sub_filter_once off;
    }
}
EOF
)
fi

# Write the Nginx configuration to the file
echo "$nginx_config" | sudo tee /etc/nginx/sites-available/$config_name > /dev/null

# Check if the symbolic link already exists; if not, create it
if [ ! -L /etc/nginx/sites-enabled/$config_name ]; then
    sudo ln -s /etc/nginx/sites-available/$config_name /etc/nginx/sites-enabled/
    echo -e "\033[1;32mSymbolic link created for $config_name in sites-enabled.\033[0m"
else
    echo -e "\033[1;33mSymbolic link for $config_name already exists in sites-enabled.\033[0m"
fi

# Test Nginx configuration
if sudo nginx -t; then
    echo -e "\033[1;32mNginx configuration is valid.\033[0m"
    # Reload Nginx to apply the new configuration
    sudo systemctl reload nginx
    echo -e "\033[1;34mFull proxy set up for $your_domain.\033[0m"
else
    echo -e "\033[1;31mNginx configuration test failed. Please check the configuration.\033[0m"
fi



;;

13)
# Function to strip the scheme from a URL
strip_scheme() {
    echo "$1" | sed -e 's|^http://||' -e 's|^https://||'
}

# Fetch the public IP address
public_ip=$(curl -s icanhazip.com)

# Read user input for the target site
read -p "Enter the target (default: 127.0.0.1:8000): " target_site
target_site=${target_site:-127.0.0.1:8000}

# Set the scheme to HTTP by default
scheme="http"

# Ask for the port for HTTP
read -p "Enter the HTTP port to listen (default: 8001): " http_port
http_port=${http_port:-8001}

# Set default config name if not provided
read -p "Enter a name for the Nginx configuration file (default: default): " config_name
config_name=${config_name:-default}

# Strip the scheme from the target site
target_site=$(strip_scheme "$target_site")

# Create the Nginx configuration content in a variable
nginx_config=$(cat <<EOF
server {
    listen $http_port; # Listen on the specified HTTP port

    server_name _;

    location / {
        proxy_pass $scheme://$target_site;
        proxy_set_header Host $target_site;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_ssl_server_name on;

        # Disable compression to make proxy behavior more predictable
        proxy_set_header Accept-Encoding "";

        # Prevent redirects to the target site from changing the URL in the browser
        proxy_redirect $scheme://$target_site /;
    }
}
EOF
)

# Write the Nginx configuration to the file
echo "$nginx_config" | sudo tee /etc/nginx/sites-available/$config_name > /dev/null

# Check if the symbolic link already exists; if not, create it
if [ ! -L /etc/nginx/sites-enabled/$config_name ]; then
    sudo ln -s /etc/nginx/sites-available/$config_name /etc/nginx/sites-enabled/
    echo -e "\033[1;32mSymbolic link created for $config_name in sites-enabled.\033[0m"
else
    echo -e "\033[1;33mSymbolic link for $config_name already exists in sites-enabled.\033[0m"
fi

# Test Nginx configuration
if sudo nginx -t; then
    echo -e "\033[1;32mNginx configuration is valid.\033[0m"
    # Reload Nginx to apply the new configuration
    sudo systemctl reload nginx
    echo -e "\033[1;34mProxy setup complete on port $http_port.\033[0m"

    # Display Marzban URL with the public IP
    echo -e "\033[1;32mhttp://$public_ip:$http_port/dashboard/\033[0m"
    read -p "Press Enter to continue..."
else
    echo -e "\033[1;31mNginx configuration test failed. Please check the configuration.\033[0m"
    read -p "Press Enter to continue..."
fi

;;
            14)
                echo -e "\033[1;33mRemoving Nginx...\033[0m"
                if sudo apt remove --purge -y nginx nginx-common; then
                    echo -e "\033[1;32mNginx removed successfully.\033[0m"
                else
                    echo -e "\033[1;31mError: Failed to remove Nginx.\033[0m"
                fi
                ;;
            0)
                echo -e "\033[1;34mExiting Nginx management menu...\033[0m"
                break
                ;;
            *)
                echo -e "\033[1;31mError: Invalid option selected.\033[0m"
                ;;
        esac
    done
}

manage_nginx
