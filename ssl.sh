#!/bin/bash
# SSL issuance function
ssl() {


while true; do
clear
echo -e "\033[1;32mSSL Installation Options\033[0m"

echo -e "1.\033[1;34m acme script. New single/multi-domain (Let's Encrypt, Buypass, ZeroSSL) \033[0m"
echo -e "2.\033[1;34m Certbot. New single/multi-domain ssl\033[0m"
echo -e "3.\033[1;34m Certbot. New wildcard ssl (*.domain.com)\033[0m"
echo -e "4.\033[1;34m Easy mode. (ESSL) script \033[0m"
echo -e "5.\033[1;34m Copy certs \033[0m"    
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
	5) main  ;;
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
   

# Get the public IPv4 and IPv6 of the server
server_ipv4=$(curl -4 -s https://checkip.amazonaws.com)
server_ipv6=$(curl -6 -s https://checkip.amazonaws.com 2>/dev/null)

echo -e "\033[1;32mServer IPv4: $server_ipv4\033[0m"
echo -e "\033[1;32mServer IPv6: ${server_ipv6:-Not available}\033[0m"

while true; do
    read -p "Enter your email (leave blank if you don't want to provide one): " email
    read -p "Enter your domains (comma separated, e.g., example.com,www.example.com): " domains

    if [[ -z "$domains" ]]; then
        echo -e "\033[1;31mError: You must enter at least one domain.\033[0m"
        continue
    fi

    IFS=',' read -r -a domain_array <<< "$domains"

    for domain in "${domain_array[@]}"; do
        ipv4s=($(dig +short A "$domain"))
        ipv6s=($(dig +short AAAA "$domain"))

        echo -e "\033[1;33mResolved IPs for '$domain': IPv4: ${ipv4s[*]} IPv6: ${ipv6s[*]}\033[0m"

        match_found=false

        # Check for a match in either IPv4 or IPv6
        for ip in "${ipv4s[@]}"; do
            echo -e "\033[1;34mComparing Domain IPv4: $ip with Server IPv4: $server_ipv4\033[0m"
            if [[ "$ip" == "$server_ipv4" ]]; then
                match_found=true
                break
            fi
        done

        for ip in "${ipv6s[@]}"; do
            echo -e "\033[1;34mComparing Domain IPv6: $ip with Server IPv6: $server_ipv6\033[0m"
            if [[ "$ip" == "$server_ipv6" || "$server_ipv6" == "Not available" ]]; then
                match_found=true
                break
            fi
        done

        if [[ "$match_found" == false ]]; then
            echo -e "\033[1;31mError: Domain '$domain' does not resolve to the server's public IP.\033[0m"
            echo -e "\033[1;33mServer IPv4: $server_ipv4\033[0m"
            echo -e "\033[1;33mServer IPv6: ${server_ipv6:-Not available}\033[0m"
            echo -e "\033[1;33mResolved IPs for '$domain': IPv4: ${ipv4s[*]} IPv6: ${ipv6s[*]}\033[0m"
            echo -e "\033[1;33mPlease ensure that the DNS records are correctly set before continuing.\033[0m"
            echo -e "\033[1;33mReturning to domain entry.\033[0m"
            continue 2
        fi
    done

    break  # All domains passed the check
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
    
    echo -e "\033[1;32mCertbot will prompt you to create a TXT record for each domain.\033[0m"
    
    echo -e "\033[1;32mYou will need to log into your DNS provider's control panel and add the TXT records.\033[0m"
    
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

# --- Configuration ---
# Default directories to search for certificates
declare -a CERT_SOURCES=(
    "/etc/letsencrypt/live"
    "/etc/letsencrypt/archive"
    "/var/lib/letsencrypt"
    "/opt/certbot"
    "$HOME/.acme.sh"
)

# Default destination for copied certificates
DEFAULT_DEST="/root/certs"

# --- Style and Utility Functions ---
# Colors for status messages
declare -A COLORS
COLORS[RED]='\033[0;31m'
COLORS[GREEN]='\033[0;32m'
COLORS[YELLOW]='\033[1;33m'
COLORS[BLUE]='\033[0;34m'
COLORS[CYAN]='\033[0;36m'
COLORS[NC]='\033[0m'

# Prints a colored status message to the console
print_status() {
    local message="$1"
    local color="${COLORS[$2]}"
    echo -e "${color}${message}${COLORS[NC]}"
}

# --- Core Functions ---

# Discovers certificate directories and prints them as a null-delimited list.
# This is a helper function for select_certificates.
discover_certificates() {
    local temp_cert_paths=()
    
    # Find directories with certificate files
    for source_dir in "${CERT_SOURCES[@]}"; do
        if [[ -d "$source_dir" && -r "$source_dir" ]]; then
            while IFS= read -r -d '' file_path; do
                local parent_dir=$(dirname "$file_path")
                temp_cert_paths+=("$parent_dir")
            done < <(find "$source_dir" -mindepth 1 -type f \( -name "*.pem" -o -name "*.crt" -o -name "*.key" \) -print0 2>/dev/null)
        fi
    done

    local unique_cert_paths=()
    if [[ ${#temp_cert_paths[@]} -gt 0 ]]; then
        readarray -t unique_cert_paths < <(printf '%s\n' "${temp_cert_paths[@]}" | sort -u)
    fi

    # Fallback using certbot command if no certificates were found
    if [[ ${#unique_cert_paths[@]} -eq 0 && $(command -v certbot >/dev/null 2>&1) ]]; then
        while read -r domain; do
            local domain_path="/etc/letsencrypt/live/${domain}"
            if [[ -d "$domain_path" ]]; then
                unique_cert_paths+=("$domain_path")
            fi
        done < <(certbot certificates 2>/dev/null | grep "Certificate Name:" | awk '{print $3}')
    fi

    # Print the null-delimited list for mapfile to read
    if [[ ${#unique_cert_paths[@]} -gt 0 ]]; then
        printf '%s\0' "${unique_cert_paths[@]}"
        return 0
    else
        return 1
    fi
}

# Prompts the user for a destination directory
ask_destination() {
    echo
    print_status "=== SSL Certificate Copier ===" "BLUE"
    echo "Enter destination directory (default: ${DEFAULT_DEST})"

    read -p "Destination directory [${DEFAULT_DEST}]: " dest_input

    if [[ -z "$dest_input" ]]; then
        DEST_DIR="$DEFAULT_DEST"
    else
        DEST_DIR="${dest_input%/}"
    fi

    print_status "Using destination: ${DEST_DIR}" "YELLOW"
    echo
}

# Creates the destination directory with secure permissions
create_dest_dir() {
    if [[ ! -d "$DEST_DIR" ]]; then
        mkdir -p "$DEST_DIR" || { print_status "Failed to create ${DEST_DIR}" "RED"; exit 1; }
    fi
    chmod 700 "$DEST_DIR"
    print_status "Destination ready: ${DEST_DIR}" "GREEN"
}

# Copies the selected certificates
copy_selected_certs() {
    local selected_certs=("$@")
    local files_copied=0

    print_status "Copying certificates..." "BLUE"

    for cert_path in "${selected_certs[@]}"; do
        local base_name=$(basename "$cert_path")
        local dest_path="${DEST_DIR}/${base_name}"
        if [[ -d "$cert_path" ]]; then
            mkdir -p "$dest_path"
            cp -p "${cert_path}"/* "$dest_path/" && files_copied=$((files_copied + $(ls "${cert_path}"/* 2>/dev/null | wc -l)))
            print_status "✓ Copied domain directory: ${base_name}" "GREEN"
        elif [[ -f "$cert_path" ]]; then
            cp -p "$cert_path" "$dest_path" && files_copied=$((files_copied + 1))
            print_status "✓ Copied file: ${base_name}" "GREEN"
        fi
    done

    return $files_copied
}

# Sets secure file permissions on the copied certificates
set_secure_permissions() {
    find "$DEST_DIR" -type f \( -name "*.key" -o -name "*.pem" -o -name "*.crt" \) -exec chmod 600 {} \;
    find "$DEST_DIR" -type d -exec chmod 700 {} \;
    print_status "Permissions secured" "GREEN"
}

# Displays a summary of the copy operation
show_summary() {
    local files_copied=$1
    echo
    echo "====================================="
    print_status "COPY COMPLETE" "GREEN"
    echo "Destination: ${DEST_DIR}"
    echo "Files copied: ${files_copied}"
    echo "====================================="
    if [[ $files_copied -gt 0 ]]; then
        if command -v tree >/dev/null 2>&1; then
            tree "$DEST_DIR"
        else
            ls -R "$DEST_DIR"
        fi
    fi
}

# --- Main Logic ---
main() {
    ask_destination
    create_dest_dir
    
    print_status "Searching for available certificates..." "CYAN"
    echo

    local cert_paths=()
    mapfile -d '' cert_paths < <(discover_certificates)

    if [[ ${#cert_paths[@]} -eq 0 ]]; then
        print_status "⚠ No certificates discovered. Exiting." "RED"
        exit 1
    fi
    
    local selected_certs=()
    echo
    print_status "=== SELECT CERTIFICATES TO COPY ===" "BLUE"

    for i in "${!cert_paths[@]}"; do
        domain=$(basename "${cert_paths[$i]}")
        file_count=$(ls "${cert_paths[$i]}"/* 2>/dev/null | wc -l)
        printf "  [%2d] %-40s (%d files)\n" "$((i+1))" "$domain" "$file_count"
    done

    echo
    echo "  [ a ] SELECT ALL"
    echo "  [ q ] QUIT"
    echo

    while true; do
        read -p "Enter numbers (e.g., 1 3 5) or 'a' for all: " selection
        if [[ "$selection" =~ ^[Qq]$ ]]; then
            print_status "Cancelled." "YELLOW"
            exit 0
        elif [[ "$selection" =~ ^[Aa]$ ]]; then
            selected_certs=("${cert_paths[@]}")
            break
        else
            selected_certs=()
            for num in $selection; do
                if [[ "$num" =~ ^[0-9]+$ ]]; then
                    index=$((num-1))
                    if [[ $index -ge 0 && $index -lt ${#cert_paths[@]} ]]; then
                        selected_certs+=("${cert_paths[$index]}")
                    else
                        print_status "Invalid selection: $num" "RED"
                    fi
                fi
            done
            if [[ ${#selected_certs[@]} -gt 0 ]]; then
                break
            fi
        fi
    done

    echo
    print_status "Selected certificates:" "CYAN"
    for cert in "${selected_certs[@]}"; do
        echo "  📁 $(basename "$cert")"
    done
    echo

    read -p "Confirm? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cancelled." "YELLOW"
        exit 0
    fi
    
    copy_selected_certs "${selected_certs[@]}"
    local files_copied=$?
    set_secure_permissions
    show_summary "${files_copied}"
	echo -e "\033[1;34mPress Enter to return to the SSL menu...\033[0m"
    read -r
}
ssl
