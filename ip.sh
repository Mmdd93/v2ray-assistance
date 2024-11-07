#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'  # Green color for success
RED='\033[0;31m'    # Red color for failure
YELLOW='\033[1;33m' # Yellow color for tips
NC='\033[0m'        # No color (default)

# Configuration file paths
CONFIG_FILE="/root/api_config.txt"
TOKENS_FILE="/root/api_tokens.txt"

# Function to validate IPv4 address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0  # Valid IPv4 address
    else
        return 1  # Invalid IPv4 address
    fi
}

# Function to fetch DNS record ID for the specified subdomain
fetch_record_id() {
    local subdomain=$1
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")
    
    # Check if response is null or empty
    if [[ -z "$response" ]]; then
        echo -e "${RED}Error:${NC} API response is empty when fetching DNS records."
        return 1
    fi
    
    # Check if jq result is empty or contains null
    local record_id=$(echo "$response" | jq -r '.result[] | select(.name == "'"$subdomain"'") | .id')
    if [[ -z "$record_id" || "$record_id" == "null" ]]; then
        echo -e "${RED}Error:${NC} Failed to find DNS record ID for $subdomain."
        return 1
    fi
    
    echo "$record_id"
}

# Function to fetch currently set IP address from DNS record
fetch_current_ip() {
    local record_id=$1
    local response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json")
    
    # Check if response is null or empty
    if [[ -z "$response" ]]; then
        echo -e "${RED}Error:${NC} API response is empty when fetching current IP address."
        return 1
    fi
    
    local current_ip=$(echo "$response" | jq -r '.result.content')
    if [[ -z "$current_ip" ]]; then
        echo -e "${RED}Error:${NC} Failed to fetch current IP address from DNS record."
        return 1
    fi
    
    echo "$current_ip"
}

# Function to update DNS record
update_dns() {
    local record_id=$1
    local new_ip=$2

    echo "Updating DNS record with IP address: $new_ip"

    # Fetch current IP address from DNS record
    CURRENT_IP=$(fetch_current_ip "$record_id")

    # Skip update if the new IP matches the current set IP
    if [[ "$new_ip" == "$CURRENT_IP" ]]; then
        echo -e "${YELLOW}Skipping update as the IP address $new_ip is already set.${NC}"
        return
    fi

    # Validate IP address before updating
    if validate_ip "$new_ip"; then
        response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "{\"type\":\"A\",\"name\":\"$SUBDOMAIN\",\"content\":\"$new_ip\",\"ttl\":120,\"proxied\":false}")

        echo "Response from API:"
        echo "$response"

        if [[ $(echo "$response" | jq -r .success) == "true" ]]; then
            echo -e "${GREEN}Success:${NC} DNS record updated successfully with IP address: $new_ip"
        else
            echo -e "${RED}Error:${NC} Failed to update DNS record with IP address: $new_ip"
            echo "$response" | jq .
        fi
    else
        echo -e "${YELLOW}Tip:${NC} IP address $new_ip is not valid. Skipping."
    fi
}

# Function to prompt user for configuration variables
prompt_configuration() {
    echo -e "${YELLOW}Configuration file is missing or incomplete.${NC} Please enter the required configuration:"
    
    read -p "Subdomain (e.g., api.example.com): " SUBDOMAIN
    read -p "API Token: " API_TOKEN
    read -p "Zone ID: " ZONE_ID
    
    # Save configuration to files
    echo "API_TOKEN=\"$API_TOKEN\"" > "$TOKENS_FILE"
    echo "ZONE_ID=\"$ZONE_ID\"" >> "$TOKENS_FILE"
    echo "SUBDOMAIN=\"$SUBDOMAIN\"" >> "$TOKENS_FILE"
    echo "SUBDOMAIN=\"$SUBDOMAIN\"" >> "$CONFIG_FILE"
}

# Function to load configuration variables from files
load_configuration() {
    source "$CONFIG_FILE"
}

# Function to load API_TOKEN, ZONE_ID, and SUBDOMAIN from tokens file
load_tokens() {
    source "$TOKENS_FILE"
}

# Function to get public IP address of the server
get_public_ip() {
    curl -s http://ipv4.icanhazip.com
}

# Check if tokens file exists and load API_TOKEN, ZONE_ID, and SUBDOMAIN
if [ -s "$TOKENS_FILE" ]; then
    load_tokens
fi

# Check if config file exists and load configuration
if [ ! -s "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Configuration file not found or empty.${NC} Creating a new one."
    prompt_configuration
else
    load_configuration
    
    # Check if variables are properly loaded
    if [[ -z "$SUBDOMAIN" ]]; then
        echo -e "${YELLOW}Tip:${NC} Configuration file is missing required variables (SUBDOMAIN)."
        prompt_configuration
    fi
fi

# Fetch the DNS record ID for the specified subdomain
RECORD_ID=$(fetch_record_id "$SUBDOMAIN")

if [ -z "$RECORD_ID" ]; then
    echo -e "${RED}Error:${NC} Failed to find DNS record ID for $SUBDOMAIN"
    exit 1
else
    echo -e "${GREEN}Success:${NC} Found RECORD_ID: $RECORD_ID"
fi

# Get public IP address of the server
PUBLIC_IP=$(get_public_ip)

if [[ -z "$PUBLIC_IP" ]]; then
    echo -e "${RED}Error:${NC} Failed to fetch public IP address of the server."
    exit 1
else
    echo -e "${GREEN}Success:${NC} Server public IP address: $PUBLIC_IP"
fi

# Update DNS record with the server's public IP address
update_dns "$RECORD_ID" "$PUBLIC_IP"
