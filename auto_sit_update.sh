#!/bin/bash

# Define colors for formatting
RED="\033[1;31m"
GREEN="\033[1;32m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Variables for service file and IPs
service_file=""
new_local_domain=""
new_remote_domain=""
new_local_ip=""
new_remote_ip=""
current_local_ip=""
current_remote_ip=""
service_updated=false  # Flag to track if the service needs to be restarted

# Check if the file /root/sit.txt exists
if [[ ! -f /root/sit.txt ]]; then
    echo -e "${RED}Error: File /root/sit.txt not found.${RESET}"
    read -p "Press Enter to exit..."
    exit 1
fi

# Read variables from /root/sit.txt
echo -e "${CYAN}Reading configuration from /root/sit.txt...${RESET}"
service_file=$(grep '^service_file' /root/sit.txt | awk '{print $2}')
new_local_domain=$(grep '^local' /root/sit.txt | awk '{print $2}')
new_remote_domain=$(grep '^remote' /root/sit.txt | awk '{print $2}')

# Validate service file path
if [[ ! -f "$service_file" ]]; then
    echo -e "${RED}Error: Service file not found at $service_file.${RESET}"
    read -p "Press Enter to exit..."
    exit 1
fi

# Resolve domains to IPs using dig
new_local_ip=$(dig +short "$new_local_domain")
new_remote_ip=$(dig +short "$new_remote_domain")

# Validate resolved IPs
if [[ -z "$new_local_ip" || -z "$new_remote_ip" ]]; then
    echo -e "${RED}Error: Could not resolve IPs for the domains provided.${RESET}"
    echo -e "${YELLOW}Check the domains in /root/sit.txt and ensure they are valid.${RESET}"
    read -p "Press Enter to exit..."
    exit 1
fi

echo -e "${CYAN}Service file: ${GREEN}$service_file${RESET}"
echo -e "${CYAN}New local IP: ${GREEN}$new_local_ip${RESET}"
echo -e "${CYAN}New remote IP: ${GREEN}$new_remote_ip${RESET}"

# Extract current remote IP from the service file
current_remote_ip=$(grep -oP 'remote \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$service_file")
if [[ -n "$current_remote_ip" ]]; then
    echo -e "${CYAN}Current remote IP: ${GREEN}$current_remote_ip${RESET}"
else
    echo -e "${YELLOW}No remote IP found in the service file.${RESET}"
fi

# Extract current local IP from the service file
current_local_ip=$(grep -oP 'local \K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "$service_file")
if [[ -n "$current_local_ip" ]]; then
    echo -e "${CYAN}Current local IP: ${GREEN}$current_local_ip${RESET}"
else
    echo -e "${YELLOW}No local IP found in the service file.${RESET}"
fi

# Update local IP only if it differs
if [[ "$current_local_ip" != "$new_local_ip" ]]; then
    echo -e "${YELLOW}Updating local IP...${RESET}"
    sed -i "s/local [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/local $new_local_ip/" "$service_file"
    service_updated=true  # Set flag to true if the IP was updated
else
    echo -e "${GREEN}Local IP is already up-to-date.${RESET}"
fi

# Update remote IP only if it differs
if [[ "$current_remote_ip" != "$new_remote_ip" ]]; then
    echo -e "${YELLOW}Updating remote IP...${RESET}"
    sed -i "s/remote [0-9]*\.[0-9]*\.[0-9]*\.[0-9]*/remote $new_remote_ip/" "$service_file"
    service_updated=true  # Set flag to true if the IP was updated
else
    echo -e "${GREEN}Remote IP is already up-to-date.${RESET}"
fi

# Reload systemd and restart the service if the service file was updated
if $service_updated; then
    echo -e "${YELLOW}Reloading systemd and restarting the service...${RESET}"
    sudo systemctl daemon-reload
    service_name=$(basename "$service_file" .service)
    sudo systemctl restart "$service_name"
    echo -e "${GREEN}Service $service_name updated...${RESET}"
else
    echo -e "${GREEN}No changes detected. Service restart not required.${RESET}"
fi

