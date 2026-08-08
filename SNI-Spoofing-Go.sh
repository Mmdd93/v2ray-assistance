#!/bin/bash
# SNI Spoofing Manager – Fully interactive, asks before overwriting anything
# Run as root: sudo ./sni-manager.sh

set -euo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Root check
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)."
    exit 1
fi

# Constants
REPO="aleskxyz/SNI-Spoofing-Go"
INSTALL_DIR="/root"
BINARY="${INSTALL_DIR}/sni-spoofing"
CONFIG="${INSTALL_DIR}/config.ini"
VERSION_FILE="${INSTALL_DIR}/sni-spoofing.version"
SERVICE_NAME="sni-spoofing"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Check if binary exists
is_installed() { [[ -f "$BINARY" ]]; }

# Get service status
get_service_status() {
    if ! is_installed; then
        echo -e "${RED}Not Installed${NC}"
    elif systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}Running${NC}"
    elif systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Stopped (Enabled)${NC}"
    else
        echo -e "${YELLOW}Stopped (Disabled)${NC}"
    fi
}

# Get enabled/disabled status
get_enabled_status() {
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        echo -e "${GREEN}Enabled${NC}"
    else
        echo -e "${RED}Disabled${NC}"
    fi
}

# Get version
get_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE"
    else
        echo -e "${RED}N/A${NC}"
    fi
}

# Reload and restart prompt
reload_restart_prompt() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Configuration files have been modified.${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    read -p "Reload systemd and restart service? (y/n) [y] : " CONFIRM
    
    if [[ "$CONFIRM" =~ ^[Yy]?$ ]]; then
        systemctl daemon-reload
        info "systemd reloaded."
        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            systemctl restart "$SERVICE_NAME"
            info "Service restarted."
        else
            warn "Service not enabled. Starting service..."
            systemctl start "$SERVICE_NAME" 2>/dev/null || error "Failed to start service."
        fi
    else
        info "Skipped. Remember to reload/restart manually if needed."
    fi
}

# Dependencies
check_deps() {
    for cmd in curl systemctl; do
        if ! command -v "$cmd" &>/dev/null; then
            error "'$cmd' is required. Install with: apt install curl systemd"
            exit 1
        fi
    done
}

# Architecture
detect_arch() {
    case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "arm" ;;
        armv6l)  echo "arm" ;;
        *)       echo "amd64" ;;
    esac
}

# Latest release tag
get_latest_tag() {
    local tag
    tag=$(curl -sI "https://github.com/${REPO}/releases/latest" | \
          grep -i '^location:' | \
          sed -E 's|.*/tag/([^/[:space:]]+).*|\1|' | \
          tr -d '\r')
    if [[ -z "$tag" ]]; then
        error "Failed to fetch latest release. Check internet."
        exit 1
    fi
    echo "$tag"
}

# Download binary (only if allowed by caller)
download_binary() {
    local tag="$1" arch="$2" url
    url="https://github.com/${REPO}/releases/download/${tag}/sni-spoofing-linux-${arch}"
    info "Downloading SNI Spoofing ${tag} (linux-${arch})..."
    if curl -fSL --progress-bar -o "$BINARY" "$url"; then
        chmod +x "$BINARY"
        echo "$tag" > "$VERSION_FILE"
        info "Binary saved to $BINARY"
    else
        error "Download failed. Asset may not exist for $arch."
        exit 1
    fi
}

# Interactive config wizard – asks every parameter
create_config_interactive() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}   SNI Spoofing Configuration Wizard${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo "Answer each question; press Enter to keep default."
    echo ""

    read -p "Listen address + port [0.0.0.0:40443] : " LISTEN
    LISTEN=${LISTEN:-0.0.0.0:40443}

    echo ""
    echo -e "${CYAN}━━━━━━━ Connect Destination ━━━━━━━${NC}"
    read -p "Connect IP address [104.19.229.21] : " CONNECT_IP
    CONNECT_IP=${CONNECT_IP:-104.19.229.21}
    
    echo ""
    echo -e "${CYAN}━━━━━━━ Port Selection ━━━━━━━${NC}"
    echo -e "${YELLOW}Cloudflare HTTPS ports: 443, 8443, 2053, 2083, 2087, 2096${NC}"
    echo ""
    read -p "Connect port [443] : " CONNECT_PORT
    CONNECT_PORT=${CONNECT_PORT:-443}
    
    # Validate port
    if [[ ! "$CONNECT_PORT" =~ ^[0-9]+$ ]] || [[ "$CONNECT_PORT" -lt 1 ]] || [[ "$CONNECT_PORT" -gt 65535 ]]; then
        warn "Invalid port. Using default 443."
        CONNECT_PORT="443"
    fi
    
    CONNECT="${CONNECT_IP}:${CONNECT_PORT}"
    echo -e "${GREEN}✓ Connect: $CONNECT${NC}"
    echo ""

    read -p "Fake SNI (hostname to send) [hcaptcha.com] : " FAKESNI
    FAKESNI=${FAKESNI:-hcaptcha.com}

    read -p "uTLS fingerprint (firefox/chrome/ios/random) [firefox] : " UTLS
    UTLS=${UTLS:-firefox}

    read -p "Fake repeat count [1] : " FAKEREPEAT
    FAKEREPEAT=${FAKEREPEAT:-1}

    read -p "Fake delay (e.g., 2ms, 500us) [2ms] : " FAKEDELAY
    FAKEDELAY=${FAKEDELAY:-2ms}

    read -p "ACK timeout (e.g., 2s) [2s] : " ACKTIMEOUT
    ACKTIMEOUT=${ACKTIMEOUT:-2s}

    read -p "Injector mode (active/passive) [active] : " INJECTOR
    INJECTOR=${INJECTOR:-active}

    read -p "Enable fragment? (y/n) [y] : " FRAG
    if [[ "$FRAG" =~ ^[nN]$ ]]; then
        ENABLE_FRAGMENT="false"
    else
        ENABLE_FRAGMENT="true"
    fi

    read -p "Fragment delay [500ms] : " FRAGDELAY
    FRAGDELAY=${FRAGDELAY:-500ms}

    read -p "SNI chunk size [3] : " SNICHUNK
    SNICHUNK=${SNICHUNK:-3}

    echo ""
    echo -e "${YELLOW}━━━━━━━━ Preview ━━━━━━━━${NC}"
    cat <<EOF
listen = ${LISTEN}
connect = ${CONNECT}
fake-sni = ${FAKESNI}
utls = ${UTLS}
fake-repeat = ${FAKEREPEAT}
fake-delay = ${FAKEDELAY}
ack-timeout = ${ACKTIMEOUT}
injector = ${INJECTOR}
enable-fragment = ${ENABLE_FRAGMENT}
fragment-delay = ${FRAGDELAY}
sni-chunk = ${SNICHUNK}
EOF
    read -p "Write this configuration? (y/n) [y] : " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        info "Configuration cancelled."
        return 1
    fi

    cat > "$CONFIG" <<EOF
listen = ${LISTEN}
connect = ${CONNECT}
fake-sni = ${FAKESNI}
utls = ${UTLS}
fake-repeat = ${FAKEREPEAT}
fake-delay = ${FAKEDELAY}
ack-timeout = ${ACKTIMEOUT}
injector = ${INJECTOR}
enable-fragment = ${ENABLE_FRAGMENT}
fragment-delay = ${FRAGDELAY}
sni-chunk = ${SNICHUNK}
EOF
    info "Configuration saved to $CONFIG"
}

# Service management
install_service() {
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=SNI Spoofing Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BINARY} -config ${CONFIG}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now "$SERVICE_NAME"
    info "Service enabled and started."
}

# ----- Actions -----
do_install() {
    check_deps
    local arch tag
    arch=$(detect_arch)
    tag=$(get_latest_tag)
    info "Architecture: $arch | Latest release: $tag"

    # Binary handling
    if is_installed; then
        warn "Binary already exists at $BINARY"
        read -p "Overwrite it with the latest release? (y/n) [n] : " OV
        if [[ "$OV" =~ ^[Yy]$ ]]; then
            download_binary "$tag" "$arch"
        else
            info "Keeping existing binary."
        fi
    else
        download_binary "$tag" "$arch"
    fi

    # Config handling
    if [[ -f "$CONFIG" ]]; then
        warn "Configuration already exists."
        read -p "Overwrite it with interactive wizard? (y/n) [n] : " OV
        if [[ "$OV" =~ ^[Yy]$ ]]; then
            create_config_interactive
        else
            info "Keeping existing configuration."
        fi
    else
        create_config_interactive
    fi

    install_service
    info "Installation complete."
}

do_uninstall() {
    warn "This will stop the service and remove all files."
    read -p "Are you sure? (y/n) [n] : " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        info "Aborted."
        return
    fi
    systemctl disable --now "$SERVICE_NAME" 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
    rm -f "$BINARY" "$CONFIG" "$VERSION_FILE"
    systemctl reset-failed "$SERVICE_NAME" 2>/dev/null || true
    info "Uninstall completed."
}

do_update() {
    check_deps
    if ! is_installed; then
        error "Not installed. Use install first."
        return
    fi
    local arch tag current_tag
    arch=$(detect_arch)
    tag=$(get_latest_tag)

    if [[ -f "$VERSION_FILE" ]]; then
        current_tag=$(cat "$VERSION_FILE")
        if [[ "$current_tag" == "$tag" ]]; then
            info "Already up-to-date ($tag)."
            return
        fi
        info "Newer version found: $tag (current: $current_tag)"
    else
        warn "No version info found."
    fi

    read -p "Download and overwrite existing binary with $tag? (y/n) [y] : " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]?$ ]]; then
        info "Update cancelled."
        return
    fi

    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    download_binary "$tag" "$arch"
    systemctl start "$SERVICE_NAME"
    info "Update complete. Service restarted."
}

do_edit_config() {
    if [[ -f "$CONFIG" ]]; then
        nano "$CONFIG"
        info "Configuration edited."
        reload_restart_prompt
    else
        error "No config file found."
    fi
}

do_edit_service() {
    if [[ -f "$SERVICE_FILE" ]]; then
        nano "$SERVICE_FILE"
        info "Service file edited."
        reload_restart_prompt
    else
        error "Service file not found. Install first."
    fi
}

do_reconfigure() {
    if ! is_installed; then
        error "Install first."
        return
    fi
    create_config_interactive
    info "Reconfiguration done."
    reload_restart_prompt
}

do_show_config() {
    if [[ -f "$CONFIG" ]]; then
        echo -e "${CYAN}━━━━━━━━ Config File: ${CONFIG} ━━━━━━━━${NC}"
        cat "$CONFIG"
    else
        error "Config file not found."
    fi
}

do_show_service() {
    if [[ -f "$SERVICE_FILE" ]]; then
        echo -e "${CYAN}━━━━━━━━ Service File: ${SERVICE_FILE} ━━━━━━━━${NC}"
        cat "$SERVICE_FILE"
    else
        error "Service file not found."
    fi
}

do_start() {
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl start "$SERVICE_NAME"
        info "Service started."
    else
        error "Service not installed. Run install first."
    fi
}

do_enable() {
    if [[ -f "$SERVICE_FILE" ]]; then
        systemctl enable "$SERVICE_NAME"
        info "Service enabled (auto-start on boot)."
    else
        error "Service not installed. Run install first."
    fi
}

do_restart() {
    if systemctl is-active --quiet "$SERVICE_NAME" || systemctl is-enabled --quiet "$SERVICE_NAME"; then
        systemctl restart "$SERVICE_NAME"
        info "Service restarted."
    else
        error "Service not installed. Run install first."
    fi
}

do_stop() {
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        info "Service stopped."
    else
        warn "Service is not running."
    fi
}

do_status() {
    systemctl status "$SERVICE_NAME" 2>/dev/null || error "Service not found."
}

do_logs() {
    echo -e "${CYAN}Showing logs (press Enter to exit)...${NC}"
    echo ""
    
    # Run journalctl in background
    journalctl -u "$SERVICE_NAME" -f &
    LOG_PID=$!
    
    # Wait for Enter key
    read -p ""
    
    # Kill the journalctl process
    kill $LOG_PID 2>/dev/null
    wait $LOG_PID 2>/dev/null
    
    info "Stopped following logs."
}





do_disable_logs() {
    echo -e "${YELLOW}This will disable log storage for ${SERVICE_NAME}${NC}"
    echo "After disabling, logs won't be saved to disk (still visible in live view)"
    read -p "Disable log storage? (y/n) [n] : " CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        # Disable persistent logging for this service
        mkdir -p /etc/systemd/journald.conf.d/
        cat > "/etc/systemd/journald.conf.d/90-${SERVICE_NAME}.conf" <<EOF
[Journal]
Storage=none
EOF
        systemctl restart systemd-journald
        info "Log storage disabled. Logs won't be saved to disk."
        warn "Service restart required to apply changes to service logs."
        reload_restart_prompt
    else
        info "Cancelled."
    fi
}

do_enable_logs() {
    if [[ -f "/etc/systemd/journald.conf.d/90-${SERVICE_NAME}.conf" ]]; then
        read -p "Enable log storage? (y/n) [y] : " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]?$ ]]; then
            rm -f "/etc/systemd/journald.conf.d/90-${SERVICE_NAME}.conf"
            systemctl restart systemd-journald
            info "Log storage enabled."
            reload_restart_prompt
        else
            info "Cancelled."
        fi
    else
        info "Log storage is already enabled."
    fi
}

do_clear_logs() {
    echo -e "${RED}⚠ This will delete ALL logs for ${SERVICE_NAME}${NC}"
    echo -e "${RED}This action cannot be undone!${NC}"
    read -p "Are you sure? (yes/no) [no] : " CONFIRM
    if [[ "$CONFIRM" == "yes" ]]; then
        journalctl -u "$SERVICE_NAME" --rotate
        journalctl -u "$SERVICE_NAME" --vacuum-time=1s
        info "All logs for ${SERVICE_NAME} have been cleared."
    else
        info "Cancelled. Type 'yes' to confirm deletion."
    fi
}

do_log_size() {
    echo -e "${CYAN}━━━━━━━━ Log Disk Usage ━━━━━━━━${NC}"
    journalctl -u "$SERVICE_NAME" --disk-usage
}

# ----- Interactive menu -----
show_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          SNI Spoofing Manager                      ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════╣${NC}"
    printf "${BLUE}║${NC} Status  : %-42s ${BLUE}║${NC}\n" "$(get_service_status)"
    printf "${BLUE}║${NC} Version : %-42s ${BLUE}║${NC}\n" "$(get_version)"
    printf "${BLUE}║${NC} Boot    : %-42s ${BLUE}║${NC}\n" "$(get_enabled_status)"
    printf "${BLUE}║${NC} Binary  : %-42s ${BLUE}║${NC}\n" "${BINARY}"
    printf "${BLUE}║${NC} Config  : %-42s ${BLUE}║${NC}\n" "${CONFIG}"
    printf "${BLUE}║${NC} Service : %-42s ${BLUE}║${NC}\n" "${SERVICE_FILE}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
}

show_menu() {
    while true; do
        show_header
        echo -e "${CYAN}─── Installation ───${NC}"
        echo " 1) Install / Setup"
        echo " 2) Uninstall"
        echo " 3) Update binary"
        echo ""
        echo -e "${CYAN}─── Configuration ───${NC}"
        echo " 4) Edit config file (config.ini)"
        echo " 5) Edit service file (systemd)"
        echo " 6) Show config file"
        echo " 7) Show service file"
        echo " 8) Reconfigure (interactive wizard)"
        echo ""
        echo -e "${CYAN}─── Service Control ───${NC}"
        echo " 9) Start service"
        echo "10) Stop service"
        echo "11) Restart service"
        echo "12) Enable auto-start on boot"
        echo "13) Disable auto-start on boot"
        echo "14) Reload systemd daemon"
        echo ""
        echo -e "${CYAN}─── Logs Management ───${NC}"
        echo "15) View live logs"
        echo "16) Show log disk usage"
        echo "17) Disable log storage"
        echo "18) Enable log storage"
        echo "19) Clear all logs"
        echo ""
        echo -e "${CYAN}─── Monitoring ───${NC}"
        echo "20) Service status"
        echo ""
        echo " 0) Exit"
        echo ""
        read -p "Select an option [0-20]: " choice
        case "$choice" in
            1) do_install ;;
            2) do_uninstall ;;
            3) do_update ;;
            4) do_edit_config ;;
            5) do_edit_service ;;
            6) do_show_config ;;
            7) do_show_service ;;
            8) do_reconfigure ;;
            9) do_start ;;
            10) do_stop ;;
            11) do_restart ;;
            12) do_enable ;;
            13) systemctl disable "$SERVICE_NAME" 2>/dev/null && info "Service disabled." || error "Service not found." ;;
            14) systemctl daemon-reload && info "systemd daemon reloaded." || error "Failed to reload systemd." ;;
            15) do_logs ;;
            16) do_log_size ;;
            17) do_disable_logs ;;
            18) do_enable_logs ;;
            19) do_clear_logs ;;
            20) do_status ;;
            0) info "Goodbye."; exit 0 ;;
            *) warn "Invalid option. Press Enter to continue..."; read ;;
        esac
        echo ""
        read -p "Press Enter to continue..."
    done
}

# ----- Main -----
if [[ $# -eq 0 ]]; then
    show_menu
else
    case "${1:-}" in
        install)    do_install ;;
        uninstall)  do_uninstall ;;
        update)     do_update ;;
        edit-config)   do_edit_config ;;
        edit-service)  do_edit_service ;;
        show-config)   do_show_config ;;
        show-service)  do_show_service ;;
        reconfigure) do_reconfigure ;;
        start)      do_start ;;
        stop)       do_stop ;;
        restart)    do_restart ;;
        enable)     do_enable ;;
        disable)    systemctl disable "$SERVICE_NAME" 2>/dev/null && info "Service disabled." || error "Service not found." ;;
        reload)     systemctl daemon-reload && info "systemd daemon reloaded." ;;
        logs)       do_logs ;;
        log-size)   do_log_size ;;
        disable-logs) do_disable_logs ;;
        enable-logs)  do_enable_logs ;;
        clear-logs)   do_clear_logs ;;
        status)     do_status ;;
        menu)       show_menu ;;
        *)
            echo "Usage: $0 {install|uninstall|update|edit-config|edit-service|show-config|show-service|reconfigure|start|stop|restart|enable|disable|reload|logs|log-size|disable-logs|enable-logs|clear-logs|status|menu}"
            ;;
    esac
fi