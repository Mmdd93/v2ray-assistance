#!/bin/bash
# SSL issuance function
ssl() {


while true; do
clear
echo -e "\033[1;32mSSL Installation Options\033[0m"

echo -e "1.\033[1;34m acme New single/multi domain  (Let's Encrypt, Buypass, ZeroSSL) \033[0m"
echo -e "2.\033[1;34m Certbot New single/multi domain ssl\033[0m"
echo -e "3.\033[1;34m Certbot New wildcard ssl (*.domain.com)\033[0m"
echo -e "4.\033[1;34m Easy mode ESSL script \033[0m"
    
    echo -e "0. Return"
    echo -e "\033[1;32mEnter your choice:\033[0m"
    
    read -r ssl_choice

    case "$ssl_choice" in
        1)
            echo -e "\033[1;32mYou selected acme.\033[0m"
            ssl_multi
            ;;
        2)
            echo -e "\033[1;32mYou selected certbot method.\033[0m"
            get_ssl_with_certbot
            ;;
        3) get_wildcard_ssl_with_certbot ;;
	
	4) curl -Ls https://github.com/azavaxhuman/ESSL/raw/main/essl.sh -o essl.sh
            sudo bash essl.sh  ;;
        0)
            echo -e "\033[1;32mReturning to the previous menu.\033[0m"
            return
            ;;
        *)
            echo -e "\033[1;31mInvalid choice. Please select 0, 1, or 2.\033[0m"
            ;;
    esac
done
}

ssl_multi() {

    # Check if port 80 is in use
    if sudo lsof -i :80 | grep LISTEN &> /dev/null; then
        service_name=$(sudo lsof -i :80 | grep LISTEN | awk '{print $1}' | head -n 1)
        pid=$(sudo lsof -i :80 | grep LISTEN | awk '{print $2}' | head -n 1)
        echo -e "\033[1;31mPort 80 is in use by: $service_name (PID: $pid)\033[0m"

        # Display menu options
        while true; do
            echo -e "\033[1;33mPlease choose an option:\033[0m"
            echo "1) Stop $service_name to proceed with HTTP-01 challenge."
            echo "2) Continue  (not recommended) ."
            echo "0) Return."
            read -p "Enter your choice (1-3): " menu_choice

            case $menu_choice in
                1)
                    # Stop the service
                    if sudo systemctl list-units --type=service | grep -q "$service_name"; then
                        sudo systemctl stop "$service_name" || { echo -e "\033[1;31mFailed to stop $service_name using systemctl.\033[0m"; }
                    else
                        # Kill the process if systemctl does not recognize the service
                        echo -e "\033[1;33mAttempting to kill process $pid...\033[0m"
                        sudo kill -9 "$pid" || { echo -e "\033[1;31mFailed to kill process $pid.\033[0m"; return 1; }
                        echo -e "\033[1;32mProcess $pid ($service_name) has been killed.\033[0m"
                    fi
                    break
                    ;;
                2)
                    break
                    ;;
                0)
                    echo -e "\033[1;31mReturning to main menu...\033[0m"
                    ssl
                    ;;
                *)
                    echo -e "\033[1;31mInvalid choice. Please enter a number between 1 and 3.\033[0m"
                    ;;
            esac
        done
    fi
    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m   Multi-Domain SSL Certificate Issuance\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    # Prompt user for domains and email, with validation
    while true; do
        read -p "Enter your domain(s) (comma-separated, e.g., example.com,www.example.com): " DOMAIN_INPUT
        IFS=',' read -r -a DOMAIN_ARRAY <<< "$DOMAIN_INPUT"
        if [[ "${#DOMAIN_ARRAY[@]}" -gt 0 ]]; then
            break
        else
            echo -e "\033[1;31mInvalid domain format. Please try again.\033[0m"
        fi
    done

    while true; do
        read -p "Please enter your email address: " EMAIL
        if [[ "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
            break
        else
            echo -e "\033[1;31mInvalid email format. Please try again.\033[0m"
        fi
    done

    # Prompt for Certificate Authority (CA)
    echo "Please choose a Certificate Authority (CA):"
    echo "1) Let's Encrypt"
    echo "2) Buypass"
    echo "3) ZeroSSL"
    read -p "Enter your choice (1, 2, or 3): " CA_OPTION

    case $CA_OPTION in
        1) CA_SERVER="letsencrypt" ;;
        2) CA_SERVER="buypass" ;;
        3) CA_SERVER="zerossl" ;;
        *) echo -e "\033[1;31mInvalid choice.\033[0m"; exit 1 ;;
    esac

    # Install dependencies
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "Unable to determine the operating system type."
        exit 1
    fi

    case $OS in
        ubuntu|debian)
            sudo apt update
            sudo apt install -y curl socat git cron
            ;;
        centos)
            sudo yum update -y
            sudo yum install -y curl socat git cronie
            sudo systemctl start crond
            sudo systemctl enable crond
            ;;
        *)
            echo -e "\033[1;31mUnsupported operating system: $OS.\033[0m"
            exit 1
            ;;
    esac

    # Install acme.sh if not installed
    if ! command -v acme.sh >/dev/null 2>&1; then
        curl https://get.acme.sh | sh
    else
        echo -e "\033[1;32macme.sh is already installed.\033[0m"
    fi

    export PATH="$HOME/.acme.sh:$PATH"
    acme.sh --register-account -m "$EMAIL" --server "$CA_SERVER"

    # Build domain arguments
    DOMAIN_ARGS=""
    for DOMAIN in "${DOMAIN_ARRAY[@]}"; do
        DOMAIN_ARGS="$DOMAIN_ARGS -d $DOMAIN"
    done

    if ! ~/.acme.sh/acme.sh --issue --standalone $DOMAIN_ARGS --server "$CA_SERVER"; then
        echo -e "\033[1;31mCertificate request failed.\033[0m"
        for DOMAIN in "${DOMAIN_ARRAY[@]}"; do
            ~/.acme.sh/acme.sh --remove -d "$DOMAIN"
        done
        exit 1
    fi

    # Install the SSL certificate
    PRIMARY_DOMAIN="${DOMAIN_ARRAY[0]}"
    ~/.acme.sh/acme.sh --installcert -d "$PRIMARY_DOMAIN" \
        --key-file /root/${PRIMARY_DOMAIN}.key \
        --fullchain-file /root/${PRIMARY_DOMAIN}.crt

    echo -e "\033[1;32mSSL certificate and private key have been generated:\033[0m"
    echo -e "\033[1;34mCertificate:\033[0m /root/${PRIMARY_DOMAIN}.crt"
    echo -e "\033[1;34mPrivate Key:\033[0m /root/${PRIMARY_DOMAIN}.key"

    # Set up cron job for renewal
    echo -e "\033[1;32mSetting up automatic renewal...\033[0m"
    cat << EOF > /root/renew_cert.sh
#!/bin/bash
export PATH="\$HOME/.acme.sh:\$PATH"
acme.sh --renew $DOMAIN_ARGS --server $CA_SERVER
EOF
    chmod +x /root/renew_cert.sh
    (crontab -l 2>/dev/null; echo "0 0 * * * /root/renew_cert.sh > /dev/null 2>&1") | crontab -

    echo -e "\033[1;32mSSL certificate renewal is scheduled daily at midnight.\033[0m"


    echo -e "\033[1;32mWildcard SSL certificate generation completed successfully.\033[0m"
    echo -e "\033[1;34mPress Enter to return to the SSL menu...\033[0m"
    read -r
    ssl
}



get_ssl_with_certbot() {
    # Function to check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo -e "\033[1;31mCertbot is not installed.\033[0m"
        while true; do
            read -p "Do you want to install Certbot now? (yes/no): " install_choice
            if [[ "$install_choice" == "yes" ]]; then
                if [[ -f /etc/debian_version ]]; then
                    echo -e "\033[1;32mInstalling Certbot for Debian/Ubuntu...\033[0m"
                    sudo apt install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                elif [[ -f /etc/redhat-release ]]; then
                    echo -e "\033[1;32mInstalling Certbot for CentOS/RHEL...\033[0m"
                    sudo yum install epel-release -y && sudo yum install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                else
                    echo -e "\033[1;31mUnsupported OS.\033[0m"
                    return 1
                fi
                break
            elif [[ "$install_choice" == "no" ]]; then
                echo -e "\033[1;31mCertbot is required to proceed.\033[0m"
                return 1
            else
                echo -e "\033[1;31mInvalid choice. Please enter 'yes' or 'no'.\033[0m"
            fi
        done
    else
        echo -e "\033[1;32mCertbot is already installed.\033[0m"
    fi

    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m      Certbot multi domain SSL Generation\033[0m"
    echo -e "\033[1;36m============================================\033[0m"

    # Check if port 80 is in use
    if sudo lsof -i :80 | grep LISTEN &> /dev/null; then
        service_name=$(sudo lsof -i :80 | grep LISTEN | awk '{print $1}' | head -n 1)
        pid=$(sudo lsof -i :80 | grep LISTEN | awk '{print $2}' | head -n 1)
        echo -e "\033[1;31mPort 80 is in use by: $service_name (PID: $pid)\033[0m"

        # Display menu options
        while true; do
            echo -e "\033[1;33mPlease choose an option:\033[0m"
            echo "1) Stop $service_name to proceed with HTTP-01 challenge."
            echo "2) DNS challenge ."
            echo "3) Return to main menu."
            read -p "Enter your choice (1-3): " menu_choice

            case $menu_choice in
                1)
                    # Stop the service
                    if sudo systemctl list-units --type=service | grep -q "$service_name"; then
                        sudo systemctl stop "$service_name" || { echo -e "\033[1;31mFailed to stop $service_name using systemctl.\033[0m"; }
                    else
                        # Kill the process if systemctl does not recognize the service
                        echo -e "\033[1;33mAttempting to kill process $pid...\033[0m"
                        sudo kill -9 "$pid" || { echo -e "\033[1;31mFailed to kill process $pid.\033[0m"; return 1; }
                        echo -e "\033[1;32mProcess $pid ($service_name) has been killed.\033[0m"
                    fi
                    break
                    ;;
                2)
                    certbot certonly --manual --preferred-challenges dns || { echo -e "\033[1;31mFailed to issue SSL with DNS-01 challenge.\033[0m"; return 1; }
                    return
                    ;;
                3)
                    echo -e "\033[1;31mReturning to main menu...\033[0m"
                    return
                    ;;
                *)
                    echo -e "\033[1;31mInvalid choice. Please enter a number between 1 and 3.\033[0m"
                    ;;
            esac
        done
    fi

   # Loop for entering domains
   
# Get the public IP of the server
   # Get the public IP of the server
    server_ip=$(curl -s ifconfig.me)

    while true; do
        read -p "Enter your email (leave blank if you don't want to provide one): " email
        read -p "Enter your domains (comma separated, e.g., example.com,www.example.com): " domains
        
        # Check if domains are empty
        if [[ -z "$domains" ]]; then
            echo -e "\033[1;31mError: You must enter at least one domain.\033[0m"
            continue
        fi

        IFS=',' read -r -a domain_array <<< "$domains"

        # Check if the IPs behind the domains match the server's public IP
        for domain in "${domain_array[@]}"; do
            domain_ip=$(dig +short "$domain" | tail -n1)  # Get the last resolved IP
            if [[ "$domain_ip" != "$server_ip" ]]; then
                echo -e "\033[1;31mError: Domain '$domain' does not resolve to the server's public IP ($server_ip).\033[0m"
                echo -e "\033[1;33mResolved IP for '$domain' is $domain_ip.\033[0m"
                echo -e "\033[1;33mPlease ensure that the DNS records are correctly set before continuing.\033[0m"
                echo -e "\033[1;33mReturning to domain entry.\033[0m"
                continue 2  # Go back to the start of the while loop to prompt for domains again
            fi
        done

        # If all domains resolve correctly, break out of the loop
        break
    done

    domain_args=""
    for domain in "${domain_array[@]}"; do
        domain_args="$domain_args -d $domain"
    done

    # Check if email was provided
    if [[ -z "$email" ]]; then
        # No email provided, use the option to register without email
        certbot_command="certbot certonly --standalone --agree-tos --register-unsafely-without-email $domain_args"
    else
        # Email provided, validate email format
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "\033[1;31mError: Invalid email format. Please enter a valid email.\033[0m"
            continue  # Go back to the start of the loop to re-enter the email and domains
        fi
        certbot_command="certbot certonly --standalone --agree-tos --email \"$email\" $domain_args"
    fi

    # Run certbot command and display its output
    if ! eval "$certbot_command"; then
        echo -e "\033[1;31mWildcard SSL certificate generation failed.\033[0m"

    fi

    echo -e "\033[1;32mWildcard SSL certificate generation completed successfully.\033[0m"
    echo -e "\033[1;34mPress Enter to return to the SSL menu...\033[0m"
    read -r
    ssl
}

# Function to generate wildcard SSL certificates using certbot with DNS challenge
get_wildcard_ssl_with_certbot() {

    # Function to check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo -e "\033[1;31mCertbot is not installed.\033[0m"
        while true; do
            read -p "Do you want to install Certbot now? (yes/no): " install_choice
            if [[ "$install_choice" == "yes" ]]; then
                if [[ -f /etc/debian_version ]]; then
                    echo -e "\033[1;32mInstalling Certbot for Debian/Ubuntu...\033[0m"
                    sudo apt install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                elif [[ -f /etc/redhat-release ]]; then
                    echo -e "\033[1;32mInstalling Certbot for CentOS/RHEL...\033[0m"
                    sudo yum install epel-release -y && sudo yum install certbot -y || { echo -e "\033[1;31mFailed to install Certbot.\033[0m"; return 1; }
                else
                    echo -e "\033[1;31mUnsupported OS.\033[0m"
                    return 1
                fi
                break
            elif [[ "$install_choice" == "no" ]]; then
                echo -e "\033[1;31mCertbot is required to proceed.\033[0m"
                return 1
            else
                echo -e "\033[1;31mInvalid choice. Please enter 'yes' or 'no'.\033[0m"
            fi
        done
    else
        echo -e "\033[1;32mCertbot is already installed.\033[0m"
    fi

    echo -e "\033[1;36m============================================\033[0m"
    echo -e "\033[1;33m      Certbot Wildcard SSL Generation\033[0m"
    echo -e "\033[1;36m============================================\033[0m"
    
    while true; do
        read -p "Enter your email (leave blank if you don't want to provide one): " email
        read -p "Enter the base domain (e.g., example.com): " base_domain

        # Check if the base domain is empty
        if [[ -z "$base_domain" ]]; then
            echo -e "\033[1;31mError: You must enter a base domain.\033[0m"
            continue
        fi

        break
    done

    # Construct the domain arguments for the wildcard SSL request
    domain_args="-d $base_domain -d *.$base_domain"

        # Inform the user about the manual DNS challenge
    echo -e "\033[1;33mNote:\033[0m This process requires you to manually add DNS TXT records for domain verification."
    sleep 1
    echo -e "\033[1;32mCertbot will prompt you to create a TXT record for each domain.\033[0m"
    sleep 1
    echo -e "\033[1;32mYou will need to log into your DNS provider's control panel and add the TXT records.\033[0m"
    sleep 1
    echo -e "\033[1;34mPress Enter when you're ready to continue...\033[0m"
    read -r  # Wait for the user to press Enter

    # Check if email was provided
    if [[ -z "$email" ]]; then
        # No email provided, use the option to register without email
        certbot_command="certbot certonly --manual --preferred-challenges=dns --server https://acme-v02.api.letsencrypt.org/directory --agree-tos --register-unsafely-without-email $domain_args"
    else
        # Validate the email format
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            echo -e "\033[1;31mError: Invalid email format. Please enter a valid email.\033[0m"
            continue  # Go back to the start of the loop to re-enter the email and domain
        fi
        certbot_command="certbot certonly --manual --preferred-challenges=dns --email \"$email\" --server https://acme-v02.api.letsencrypt.org/directory --agree-tos $domain_args"
    fi
sleep 1


    # Run certbot command and display its output
    if ! eval "$certbot_command"; then
        echo -e "\033[1;31mWildcard SSL certificate generation failed.\033[0m"

    fi

    echo -e "\033[1;32mWildcard SSL certificate generation completed successfully.\033[0m"
    echo -e "\033[1;34mPress Enter to return to the SSL menu...\033[0m"
    read -r
    ssl
}


ssl
