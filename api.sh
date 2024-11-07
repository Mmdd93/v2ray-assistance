#!/bin/bash

# ANSI color codes
GREEN='\033[0;32m'  # Green color for success
RED='\033[0;31m'    # Red color for failure
YELLOW='\033[1;33m' # Yellow color for tips
NC='\033[0m'        # No color (default)

# Configuration file paths
CONFIG_FILE="/root/api/api_config.txt"
TOKENS_FILE="/root/api/api_tokens.txt"

# Function to validate IPv4 address and check if port 80 is open
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        # Check if port 80 is open using nc (netcat)
        nc -z -w 1 $ip 80
        local result=$?
        if [ $result -eq 0 ]; then
            return 0  # Valid IPv4 address and port 80 is open
        else
            return 1  # Valid IPv4 address but port 80 is closed
        fi
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
    local found_valid_ip=0

    # Iterate through each IP address in IPS array
    for ip_value in "${IPS[@]}"; do
        echo "Testing IP address: $ip_value"

        # Fetch current IP address from DNS record
        CURRENT_IP=$(fetch_current_ip "$record_id")

        # Skip IP if it matches the current set IP
        if [[ "$ip_value" == "$CURRENT_IP" ]]; then
            echo -e "${YELLOW}Skipping IP address $ip_value as it is already set.${NC}"
            continue
        fi

        # Validate IP address before updating
        if validate_ip "$ip_value"; then
            response=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
                -H "Authorization: Bearer $API_TOKEN" \
                -H "Content-Type: application/json" \
                --data "{\"type\":\"A\",\"name\":\"$SUBDOMAIN\",\"content\":\"$ip_value\",\"ttl\":120,\"proxied\":false}")

            echo "Response from API:"
            echo "$response"

            if [[ $(echo "$response" | jq -r .success) == "true" ]]; then
                echo -e "${GREEN}Success:${NC} DNS record updated successfully with IP address: $ip_value"
                found_valid_ip=1
                break  # Exit loop if update is successful
            else
                echo -e "${RED}Error:${NC} Failed to update DNS record with IP address: $ip_value"
                echo "$response" | jq .
            fi
        else
            echo -e "${YELLOW}Tip:${NC} IP address $ip_value is not valid or port 80 is not open. Skipping."
        fi
    done

    # Check if a valid IP address was found and updated
    if [ $found_valid_ip -eq 0 ]; then
        echo -e "${RED}Error:${NC} No valid IP addresses found to update DNS record."
    fi
}

# Function to prompt user for configuration variables
prompt_configuration() {
    echo -e "${YELLOW}Configuration file is missing or incomplete.${NC} Please enter the required configuration:"
    
    read -p "Subdomain (e.g., api.example.com): " SUBDOMAIN
    read -p "API Token: " API_TOKEN
    read -p "Zone ID: " ZONE_ID
    read -p "IP addresses separated by space: " IPS_INPUT
    
    # Validate IP addresses and format them into an array
    IPS=()
    for ip in $IPS_INPUT; do
        IPS+=("$ip")
    done
    
    # Save configuration to files
    echo "API_TOKEN=\"$API_TOKEN\"" > "$TOKENS_FILE"
    echo "ZONE_ID=\"$ZONE_ID\"" >> "$TOKENS_FILE"
    echo "SUBDOMAIN=\"$SUBDOMAIN\"" >> "$TOKENS_FILE"
    echo "IPS=(${IPS[@]})" > "$CONFIG_FILE"
}

# Function to load configuration variables from files
load_configuration() {
    source "$CONFIG_FILE"
}

# Function to load API_TOKEN, ZONE_ID, and SUBDOMAIN from tokens file
load_tokens() {
    source "$TOKENS_FILE"
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
    if [[ -z "$SUBDOMAIN" || ! ${IPS[@]} ]]; then
        echo -e "${YELLOW}Tip:${NC} Configuration file is missing required variables (SUBDOMAIN, IPS)."
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

# Update DNS record with the next IP address
update_dns "$RECORD_ID"

# Rotate the IPs array for the next run
IPS=("${IPS[@]:1}" "${IPS[0]}")
echo -e "Updated IP list for next run: ${YELLOW}${IPS[@]}${NC}"
echo "IPS=(${IPS[@]})" > "$CONFIG_FILE"
