#!/bin/bash

# Configuration file paths
CONFIG_FILE="/root/random/api_config.txt"
TOKENS_FILE="/root/random/api_tokens.txt"
SUBDOMAINS_FILE="/root/random/subdomains.txt"
DOMAINS_FILE="/root/random/random_domains.txt"

# Color codes
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Ensure the directory exists
DIR_PATH=$(dirname "$CONFIG_FILE")
mkdir -p "$DIR_PATH"

# Function to prompt for configuration if not found
prompt_configuration() {
    echo -e "${YELLOW}Configuration file is missing or incomplete. Please enter the required configuration:${RESET}"
    
    read -p "Zone ID: " ZONE_ID
    read -p "Port to check: " PORT  # Ask for the port number
    echo -e "${YELLOW}Select Record Type:${RESET}"
    echo -e "${BLUE}1) A${RESET}"
    echo -e "${BLUE}2) CNAME${RESET}"
    read -p "Enter 1 for A, 2 for CNAME: " RECORD_TYPE_CHOICE
    
    if [[ "$RECORD_TYPE_CHOICE" -eq 1 ]]; then
        RECORD_TYPE="A"
    elif [[ "$RECORD_TYPE_CHOICE" -eq 2 ]]; then
        RECORD_TYPE="CNAME"
    else
        echo -e "${RED}Invalid choice. Exiting.${RESET}"
        exit 1
    fi
    
    echo -e "${GREEN}Saving configuration...${RESET}"
    # Save configuration to file
    {
        echo "ZONE_ID=\"$ZONE_ID\""
        echo "PORT=\"$PORT\""
        echo "RECORD_TYPE=\"$RECORD_TYPE\""
        echo "CURRENT_INDEX=0"
    } > "$CONFIG_FILE"
    echo -e "${GREEN}Configuration saved to $CONFIG_FILE.${RESET}"
}

# Function to prompt for API token if not found
prompt_token() {
    echo -e "${YELLOW}Token file is missing or incomplete. Please enter your API Token:${RESET}"
    read -p "API Token: " API_TOKEN
    echo -e "${GREEN}Saving token...${RESET}"
    # Save token to file
    echo "API_TOKEN=\"$API_TOKEN\"" > "$TOKENS_FILE"
    echo -e "${GREEN}API token saved to $TOKENS_FILE.${RESET}"
}

# Function to prompt for subdomains if not found
prompt_subdomains() {
    echo -e "${YELLOW}Subdomains are missing. Please enter subdomains (one per line). Press Enter with no input when done:${RESET}"
    
    # Start with an empty subdomains list
    SUBDOMAINS_LIST=""
    
    while true; do
        read -r SUBDOMAIN
        # Break if the input is empty (blank line)
        if [[ -z "$SUBDOMAIN" ]]; then
            break
        fi
        # Append subdomain to the list
        SUBDOMAINS_LIST+="$SUBDOMAIN"$'\n'
    done
    
    # Save subdomains to file
    echo -e "${GREEN}Saving subdomains to $SUBDOMAINS_FILE...${RESET}"
    echo -e "$SUBDOMAINS_LIST" > "$SUBDOMAINS_FILE"
    echo -e "${GREEN}Subdomains saved to $SUBDOMAINS_FILE.${RESET}"
}

# Function to prompt for domains if not found
prompt_domains() {
    echo -e "${YELLOW}Domains are missing or incomplete. Please enter domains (one per line). Press Enter with no input when done:${RESET}"
    
    # Start with an empty domains list
    DOMAINS_LIST=""
    
    while true; do
        read -r DOMAIN
        # Break if the input is empty (blank line)
        if [[ -z "$DOMAIN" ]]; then
            break
        fi
        # Append domain to the list
        DOMAINS_LIST+="$DOMAIN"$'\n'
    done
    
    # Save domains to file
    echo -e "${GREEN}Saving domains to $DOMAINS_FILE...${RESET}"
    echo -e "$DOMAINS_LIST" > "$DOMAINS_FILE"
    echo -e "${GREEN}Domains saved to $DOMAINS_FILE.${RESET}"
}
# Function to randomly select a subdomain from the list
select_random_subdomain() {
    if [[ ! -f "$SUBDOMAINS_FILE" ]]; then
        echo -e "${RED}Subdomains file not found. Please add subdomains first.${RESET}"
        exit 1
    fi
    shuf -n 1 "$SUBDOMAINS_FILE"
}

generate_random_ip() {
    # Check if the domains file exists
    if [[ ! -f "$DOMAINS_FILE" ]]; then
        echo -e "${RED}Error: Domain file $DOMAINS_FILE not found.${RESET}"
        exit 1
    fi

    # Read all domains from the file into an array
    mapfile -t domains < "$DOMAINS_FILE"

    # Ensure there are domains in the file
    if [[ ${#domains[@]} -eq 0 ]]; then
        echo -e "${RED}Error: No domains available in the file. Please add domains and try again.${RESET}"
        exit 1
    fi

    # Select a random domain from the array
    random_domain=${domains[RANDOM % ${#domains[@]}]}
    

    # Get the IP address of the selected domain using dig
    ip=$(dig +short "$random_domain" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)

    # Check if an IP address was found, and print it or an error message
    if [[ -n $ip ]]; then
        echo "$ip"
    else
        echo "No IP found for $random_domain"
    fi
}




# Function to check if the IP is reachable on the specified port
is_port_open() {
    local ip="$1"
    local port="$2"

    # Check if the IP is reachable using ping
    if ! ping -c 1 -W 2 "$ip" &>/dev/null; then
        echo "IP $ip is not reachable."
        return 1
    fi

    # Check if the specified port is open
    if timeout 2 bash -c "echo '' > /dev/tcp/$ip/$port" 2>/dev/null; then
        echo "Port $port on IP $ip is open."
        return 0
    else
        echo "Port $port on IP $ip is closed."
        return 2
    fi
}

# Function to check or create DNS records
check_or_create_dns_record() {
    local SUBDOMAIN="$1"
    local RECORD_TYPE="$2"
    local ZONE_ID="$3"
    local API_TOKEN="$4"
    local PORT="$5"

    while true; do
        TARGET_IP=$(generate_random_ip)
        echo -e "${YELLOW}Checking port $PORT for generated IP $TARGET_IP...${RESET}"
        
        if is_port_open "$TARGET_IP" "$PORT"; then
            echo -e "${GREEN}Port $PORT is open on $TARGET_IP. Processing record update...${RESET}"
            RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$SUBDOMAIN&type=$RECORD_TYPE" \
                -H "Authorization: Bearer $API_TOKEN" \
                -H "Content-Type: application/json")

            if echo "$RESPONSE" | jq -e '.result | length > 0' > /dev/null; then
                RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')
                UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$SUBDOMAIN\",\"content\":\"$TARGET_IP\",\"ttl\":1,\"proxied\":false}")

                if echo "$UPDATE_RESPONSE" | jq -e '.success == true' > /dev/null; then
                    echo -e "${GREEN}$RECORD_TYPE record for $SUBDOMAIN updated to target $TARGET_IP.${RESET}"
                    break
                else
                    echo -e "${RED}Error updating record: $(echo "$UPDATE_RESPONSE" | jq '.errors[0].message')${RESET}"
                fi
            else
                CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$SUBDOMAIN\",\"content\":\"$TARGET_IP\",\"ttl\":1,\"proxied\":false}")

                if echo "$CREATE_RESPONSE" | jq -e '.success == true' > /dev/null; then
                    echo -e "${GREEN}$RECORD_TYPE record for $SUBDOMAIN created with target $TARGET_IP.${RESET}"
                    break
                else
                    echo -e "${RED}Error creating record: $(echo "$CREATE_RESPONSE" | jq '.errors[0].message')${RESET}"
                fi
            fi
        else
            echo -e "${RED}Port $PORT is not open on $TARGET_IP. Generating a new IP.${RESET}"
        fi
    done
}

# Load API token if available
if [ -f "$TOKENS_FILE" ]; then
    source "$TOKENS_FILE"
else
    echo -e "${RED}Error: Token file not found.${RESET}"
    prompt_token
fi

# Load configuration if available
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}Error: Configuration file not found.${RESET}"
    prompt_configuration
fi


# Load subdomains if available
if [ -f "$SUBDOMAINS_FILE" ]; then
    mapfile -t SUBDOMAINS < "$SUBDOMAINS_FILE"
else
    echo -e "${RED}Error: Subdomains file not found.${RESET}"
    prompt_subdomains
fi

# Load domains if available
if [ -f "$DOMAINS_FILE" ]; then
    mapfile -t DOMAINS < "$DOMAINS_FILE"
else
    echo -e "${RED}Error: Domains file not found.${RESET}"
    prompt_domains
fi

# Select a random subdomain
SUBDOMAIN=$(select_random_subdomain)

# Main function to check or create DNS records
check_or_create_dns_record "$SUBDOMAIN" "$RECORD_TYPE" "$ZONE_ID" "$API_TOKEN" "$PORT"
