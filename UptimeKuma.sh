#!/bin/bash

# Define working directory and default port
UK_DIR="$HOME/uptime"
UK_PORT=442
COMPOSE_FILE="$UK_DIR/docker-compose.yml"

# Color codes
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
MAGENTA="\033[1;35m"
CYAN="\033[1;36m"
RESET="\033[0m"

print_header() {
  echo -e "${CYAN}========================================"
  echo -e "        Uptime Kuma Manager"
  echo -e "========================================${RESET}"
}

check_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing Docker...${RESET}"
    curl -fsSL https://get.docker.com | sh
    systemctl start docker
    systemctl enable docker
    echo -e "${GREEN}Docker installed successfully.${RESET}"
  else
    echo -e "${GREEN}Docker is already installed.${RESET}"
  fi
}

check_docker_compose() {
  if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose v2 not found. Attempting installation...${RESET}"
    DOCKER_COMPOSE_PLUGIN_DIR="/usr/libexec/docker/cli-plugins"
    mkdir -p "$DOCKER_COMPOSE_PLUGIN_DIR"
    curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
      -o "$DOCKER_COMPOSE_PLUGIN_DIR/docker-compose"
    chmod +x "$DOCKER_COMPOSE_PLUGIN_DIR/docker-compose"
    echo -e "${GREEN}Docker Compose plugin installed successfully.${RESET}"
  else
    echo -e "${GREEN}Docker Compose is already installed.${RESET}"
  fi
}

select_port() {
  echo -ne "${YELLOW}Enter the port for Uptime Kuma [default: ${UK_PORT}]: ${RESET}"
  read input_port
  [[ -n "$input_port" ]] && UK_PORT="$input_port"
}

create_compose_file() {
  mkdir -p "$UK_DIR"
  cat > "$COMPOSE_FILE" <<EOF
services:
  uptime-kuma:
    image: louislam/uptime-kuma:1
    container_name: uptime-kuma
    volumes:
      - ./uptime-kuma-data:/app/data
    ports:
      - ${UK_PORT}:${UK_PORT}
    restart: always
EOF
}

install_kuma() {
  print_header
  check_docker
  check_docker_compose
  if [ -f "$COMPOSE_FILE" ]; then
    echo -e "${YELLOW}Uptime Kuma is already installed.${RESET}"
    return
  fi
  select_port
  create_compose_file
  cd "$UK_DIR" && docker compose up -d
  echo -e "${GREEN}Uptime Kuma installed and running on port ${UK_PORT}.${RESET}"
}

start_kuma() {
  print_header
  cd "$UK_DIR" && docker compose start
  echo -e "${GREEN}Uptime Kuma started.${RESET}"
}

stop_kuma() {
  print_header
  cd "$UK_DIR" && docker compose stop
  echo -e "${YELLOW}Uptime Kuma stopped.${RESET}"
}

restart_kuma() {
  print_header
  cd "$UK_DIR" && docker compose restart
  echo -e "${BLUE}Uptime Kuma restarted.${RESET}"
}

status_kuma() {
  print_header
  cd "$UK_DIR" && docker compose ps
}

remove_kuma() {
  print_header
  echo -ne "${RED}Are you sure you want to remove Uptime Kuma? (yes/no): ${RESET}"
  read confirm
  if [[ "$confirm" == "yes" ]]; then
    cd "$UK_DIR" && docker compose down
    rm -rf "$UK_DIR"
    echo -e "${RED}Uptime Kuma removed completely.${RESET}"
  else
    echo -e "${YELLOW}Cancelled.${RESET}"
  fi
}

main_menu() {
  while true; do
    print_header
    echo -e "${MAGENTA}Please select an option:${RESET}"
    echo -e "${GREEN}1.${RESET} Install Uptime Kuma"
    echo -e "${GREEN}2.${RESET} Start Uptime Kuma"
    echo -e "${GREEN}3.${RESET} Stop Uptime Kuma"
    echo -e "${GREEN}4.${RESET} Restart Uptime Kuma"
    echo -e "${GREEN}5.${RESET} Check Status"
    echo -e "${GREEN}6.${RESET} Remove Uptime Kuma"
    echo -e "${GREEN}0.${RESET} Exit"
    echo -ne "${CYAN}Enter choice [1-7]: ${RESET}"
    read choice

    case "$choice" in
      1) install_kuma ;;
      2) start_kuma ;;
      3) stop_kuma ;;
      4) restart_kuma ;;
      5) status_kuma ;;
      6) remove_kuma ;;
      0) echo -e "${CYAN}Goodbye!${RESET}"; exit ;;
      *) echo -e "${RED}Invalid choice. Try again.${RESET}" ;;
    esac

    echo -e "\n${MAGENTA}Press Enter to continue...${RESET}"
    read
  done
}

main_menu
