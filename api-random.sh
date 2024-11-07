#!/bin/bash

# Configuration file paths
CONFIG_FILE="/root/random/api_config.txt"
TOKENS_FILE="/root/random/api_tokens.txt"
SUBDOMAINS_FILE="/root/random/subdomains.txt"

# Color codes
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
RESET="\033[0m"

# Ensure the directory exists
DIR_PATH=$(dirname "$CONFIG_FILE")
mkdir -p "$DIR_PATH"

generate_random_ip() {
    # Generate a random number to select the range (1, 2, or more)
    range=$((RANDOM % 2 + 1))

    case $range in
        1)
            third_octet=$((RANDOM % 13 + 210))  # Random number between 210 and 222
            fourth_octet=$((RANDOM % 256))      # Random number between 0 and 255
            echo "18.165.$third_octet.$fourth_octet"
            ;;
        2)
            third_octet=$((RANDOM % 14 + 70))   # Random number between 70 and 83
            fourth_octet=$((RANDOM % 256))      # Random number between 0 and 255
            echo "108.158.$third_octet.$fourth_octet"
            ;;
    esac
}

# Function to prompt for configuration if not found
prompt_configuration() {
    echo -e "${YELLOW}Configuration file is missing or incomplete. Please enter the required configuration:${RESET}"
    
    # Prompt for multiple subdomains
    echo -e "${YELLOW}Enter subdomains (one per line). Press Ctrl+D when done:${RESET}"
    while read -r SUBDOMAIN; do
        echo "$SUBDOMAIN" >> "$SUBDOMAINS_FILE"
    done

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

# Function to randomly select a subdomain from the list
select_random_subdomain() {
    if [[ ! -f "$SUBDOMAINS_FILE" ]]; then
        echo -e "${RED}Subdomains file not found. Please add subdomains first.${RESET}"
        exit 1
    fi
    shuf -n 1 "$SUBDOMAINS_FILE"
}



# Function to check if the IP is reachable on the specified port
is_port_open() {
    local ip="$1"
    local port="$2"
    timeout 2 bash -c "echo '' > /dev/tcp/$ip/$port" 2>/dev/null
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

# Load configuration if available
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo -e "${RED}Error: Configuration file not found.${RESET}"
    prompt_configuration
fi

# Load API token if available
if [ -f "$TOKENS_FILE" ]; then
    source "$TOKENS_FILE"
else
    echo -e "${RED}Error: Token file not found.${RESET}"
    prompt_token
fi

# Select a random subdomain
SUBDOMAIN=$(select_random_subdomain)

# Main function to check or create DNS records
check_or_create_dns_record "$SUBDOMAIN" "$RECORD_TYPE" "$ZONE_ID" "$API_TOKEN" "$PORT"
