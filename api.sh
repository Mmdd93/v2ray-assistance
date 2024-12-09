#!/bin/bash

# Configuration file paths
CONFIG_FILE="/root/api_config.txt"
TOKENS_FILE="/root/api_tokens.txt"

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
    read -p "Target subdomain: " SUBDOMAIN
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
    
    read -p "Enter the IPs or CNAMEs separated by commas: " input_string
# Convert the comma-separated string into an array
IFS=',' read -r -a IP_LIST <<< "$input_string"

# Print the IP_LIST for debugging (optional)
echo "You entered the following IPs/CNAMEs:"
for ip in "${IP_LIST[@]}"; do
    echo "$ip"
done


    echo -e "${GREEN}Saving configuration...${RESET}"
    # Save configuration to file
    {
        echo "SUBDOMAIN=\"$SUBDOMAIN\""
        echo "ZONE_ID=\"$ZONE_ID\""
        echo "PORT=\"$PORT\""
        echo "RECORD_TYPE=\"$RECORD_TYPE\""
        echo "IP_LIST=(${IP_LIST[*]})"
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
# Function to check if the IP is reachable on the specified port
is_port_open() {
    local ip="$1"
    local port="$2"  # Use the port number passed as an argument
    timeout 2 bash -c "echo '' > /dev/tcp/$ip/$port" 2>/dev/null
}

# Function to check or create DNS records
check_or_create_dns_record() {
    SUBDOMAIN="$1"
    RECORD_TYPE="$2"
    ZONE_ID="$3"
    API_TOKEN="$4"
    IP_LIST=("${!5}")
    CURRENT_INDEX="$6"
    PORT="$7"  # Get the port number

    while true; do
        # Select the next IP/CNAME from the list
        TARGET_IP="${IP_LIST[$CURRENT_INDEX]}"

        echo -e "${YELLOW}Checking port $PORT for $TARGET_IP...${RESET}"  # Use the specified port

        # Check if the IP is reachable on the specified port
        if is_port_open "$TARGET_IP" "$PORT"; then
            echo -e "${GREEN}Port $PORT is open on $TARGET_IP. Processing record update...${RESET}"

            # Check if the DNS record already exists
            RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$SUBDOMAIN&type=$RECORD_TYPE" \
                -H "Authorization: Bearer $API_TOKEN" \
                -H "Content-Type: application/json")

            # Use jq to parse the response and check if the record exists
            if echo "$RESPONSE" | jq -e '.result | length > 0' > /dev/null; then
                # Update the existing DNS record with the new target IP/CNAME
                RECORD_ID=$(echo "$RESPONSE" | jq -r '.result[0].id')
                UPDATE_RESPONSE=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$SUBDOMAIN\",\"content\":\"$TARGET_IP\",\"ttl\":1,\"proxied\":false}")

                if echo "$UPDATE_RESPONSE" | jq -e '.success == true' > /dev/null; then
                    echo -e "${GREEN}$RECORD_TYPE record for $SUBDOMAIN updated to target $TARGET_IP.${RESET}"
                    
                    # Update CURRENT_INDEX after a successful update
                    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#IP_LIST[@]} ))
                    break  # Exit the loop after a successful update
                else
                    echo -e "${RED}Error updating record: $(echo "$UPDATE_RESPONSE" | jq '.errors[0].message')${RESET}"
                    # Move to the next IP without changing the index if the update fails
                fi
            else
                # Create a new DNS record
                echo -e "${YELLOW}Record not found. Creating a new $RECORD_TYPE record for $SUBDOMAIN with target $TARGET_IP...${RESET}"
                CREATE_RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
                    -H "Authorization: Bearer $API_TOKEN" \
                    -H "Content-Type: application/json" \
                    --data "{\"type\":\"$RECORD_TYPE\",\"name\":\"$SUBDOMAIN\",\"content\":\"$TARGET_IP\",\"ttl\":1,\"proxied\":false}")

                if echo "$CREATE_RESPONSE" | jq -e '.success == true' > /dev/null; then
                    echo -e "${GREEN}$RECORD_TYPE record for $SUBDOMAIN created with target $TARGET_IP.${RESET}"
                    
                    # Update CURRENT_INDEX after a successful creation
                    CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#IP_LIST[@]} ))
                    break  # Exit the loop after a successful creation
                else
                    echo -e "${RED}Error creating record: $(echo "$CREATE_RESPONSE" | jq '.errors[0].message')${RESET}"
                    # Move to the next IP without changing the index if the creation fails
                fi
            fi
        else
            echo -e "${RED}Port $PORT is not open on $TARGET_IP. Moving to the next record.${RESET}"
            # Update CURRENT_INDEX to check the next IP
            CURRENT_INDEX=$(( (CURRENT_INDEX + 1) % ${#IP_LIST[@]} ))
        fi

        
    done

    # Save the updated index to the configuration file
    sed -i "s/^CURRENT_INDEX=.*/CURRENT_INDEX=$CURRENT_INDEX/" "$CONFIG_FILE"
    echo -e "${GREEN}Next IP will be ${IP_LIST[$CURRENT_INDEX]} on the next run.${RESET}"
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

# Main function to check or create DNS records
check_or_create_dns_record "$SUBDOMAIN" "$RECORD_TYPE" "$ZONE_ID" "$API_TOKEN" "IP_LIST[@]" "$CURRENT_INDEX" "$PORT"  # Pass the port number
