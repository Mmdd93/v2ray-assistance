#!/bin/bash

# ============================================================================
# Script: monthly_traffic_monitor.sh
# Description: Monitors monthly traffic and enables firewall when threshold exceeded
# Version: 2.0
# ============================================================================

set -euo pipefail  # Strict mode: exit on error, undefined variables, pipe failures

# ============================================================================
# Configuration and Global Variables
# ============================================================================

SCRIPT_DIR="/root"
CONFIG_FILE="${SCRIPT_DIR}/telegram_info.txt"
LOCK_FILE="${SCRIPT_DIR}/monthly_traffic.lock"
FLAG_FILE="${SCRIPT_DIR}/ufw_auto_enabled.flag"
LOG_FILE="${SCRIPT_DIR}/monthly_traffic.log"
IMAGE_PATH="${SCRIPT_DIR}/traffic_log.png"
VNSTAT_PATH="/usr/bin/vnstat"

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# Logging Functions
# ============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# ============================================================================
# Configuration Loading and Validation
# ============================================================================

load_configuration() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    # Source the config file
    source "$CONFIG_FILE"

    # Validate required variables
    local missing_vars=()
    [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] && missing_vars+=("TELEGRAM_BOT_TOKEN")
    [[ -z "${TELEGRAM_CHAT_ID:-}" ]] && missing_vars+=("TELEGRAM_CHAT_ID")
    [[ -z "${THRESHOLD_GIB:-}" ]] && missing_vars+=("THRESHOLD_GIB")
    [[ -z "${TITLE:-}" ]] && missing_vars+=("TITLE")

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required configuration variables: ${missing_vars[*]}"
        exit 1
    fi

    # Validate threshold is a positive number
    if ! [[ "$THRESHOLD_GIB" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$THRESHOLD_GIB <= 0" | bc -l) )); then
        log_error "THRESHOLD_GIB must be a positive number, got: $THRESHOLD_GIB"
        exit 1
    fi

    log_info "Configuration loaded successfully"
    log_info "Traffic threshold: ${THRESHOLD_GIB} GiB"
}

# ============================================================================
# Dependency Management
# ============================================================================

ensure_installed() {
    local package=$1
    if ! dpkg -s "$package" &> /dev/null; then
        log_info "Installing package: $package"
        sudo apt-get update -y && sudo apt-get install "$package" -y
        if [[ $? -ne 0 ]]; then
            log_error "Failed to install $package"
            return 1
        fi
        log_info "Successfully installed: $package"
    fi
}

install_dependencies() {
    log_info "Checking and installing dependencies..."
    
    local dependencies=("bc" "vnstat" "python3-pil" "python3-pip" "ufw")
    local failed=0
    
    for dep in "${dependencies[@]}"; do
        if ! ensure_installed "$dep"; then
            failed=1
        fi
    done
    
    # Ensure vnstat service is running
    if ! systemctl is-active --quiet vnstat; then
        log_info "Starting vnstat service..."
        sudo systemctl start vnstat
        sudo systemctl enable vnstat
    fi
    
    if [[ $failed -eq 1 ]]; then
        log_error "Failed to install some dependencies"
        exit 1
    fi
    
    log_info "All dependencies installed successfully"
}

# ============================================================================
# Traffic Calculation Functions
# ============================================================================

convert_to_bytes() {
    local value=$1
    local unit=$2
    
    # Remove commas and clean the value
    value=$(echo "$value" | sed 's/,//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Define unit multipliers in bytes
    declare -A unit_multipliers=(
        ["TiB"]=1099511627776
        ["GiB"]=1073741824
        ["MiB"]=1048576
        ["KiB"]=1024
        ["B"]=1
        ["TB"]=1000000000000
        ["GB"]=1000000000
        ["MB"]=1000000
        ["KB"]=1000
    )
    
    local multiplier=${unit_multipliers[$unit]}
    if [[ -z $multiplier ]]; then
        log_error "Unknown unit: $unit"
        return 1
    fi
    
    # Use bc for precise calculation
    echo "scale=0; $value * $multiplier / 1" | bc
}

get_monthly_traffic() {
    local current_date=$(date "+%Y-%m")
    
    # Get vnstat monthly output
    local vnstat_output
    vnstat_output=$($VNSTAT_PATH -m 2>&1)
    if [[ $? -ne 0 ]]; then
        log_error "Failed to execute vnstat command: $vnstat_output"
        return 1
    fi
    
    # Extract total traffic for current month
    local total_traffic_line
    total_traffic_line=$(echo "$vnstat_output" | grep " $current_date" | head -1)
    
    if [[ -z "$total_traffic_line" ]]; then
        log_error "No traffic data found for $current_date"
        return 1
    fi
    
    # Extract value and unit (handles different vnstat output formats)
    local traffic_value traffic_unit
    traffic_value=$(echo "$total_traffic_line" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9.,]+$/) print $i}' | head -1)
    traffic_unit=$(echo "$total_traffic_line" | awk '{for(i=1;i<=NF;i++) if($i ~ /[A-Za-z]+B$/) print $i}' | head -1)
    
    if [[ -z "$traffic_value" ]] || [[ -z "$traffic_unit" ]]; then
        log_error "Failed to parse traffic data: $total_traffic_line"
        return 1
    fi
    
    # Convert to bytes then to GiB
    local bytes
    bytes=$(convert_to_bytes "$traffic_value" "$traffic_unit")
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    
    local traffic_gib
    traffic_gib=$(echo "scale=2; $bytes / 1073741824" | bc)
    
    echo "$traffic_gib"
    return 0
}

# ============================================================================
# Firewall Management Functions
# ============================================================================

check_ufw_status() {
    if ! command -v ufw &> /dev/null; then
        return 1
    fi
    
    sudo ufw status | grep -q "Status: active"
}

get_allowed_ports_from_config() {
    local ports=()
    
    if [[ -f "$CONFIG_FILE" ]]; then
        while IFS= read -r line; do
            # Match ufw allow commands safely without eval
            if [[ "$line" =~ ^[[:space:]]*sudo[[:space:]]+ufw[[:space:]]+allow[[:space:]]+([0-9]+(/tcp|/udp)?) ]]; then
                ports+=("${BASH_REMATCH[1]}")
            elif [[ "$line" =~ ^[[:space:]]*ufw[[:space:]]+allow[[:space:]]+([0-9]+(/tcp|/udp)?) ]]; then
                ports+=("${BASH_REMATCH[1]}")
            fi
        done < "$CONFIG_FILE"
    fi
    
    printf '%s\n' "${ports[@]}"
}

configure_firewall() {
    local action=$1  # 'enable' or 'disable'
    
    case $action in
        enable)
            log_info "Configuring firewall..."
            
            # Reset UFW to default state
            sudo ufw --force reset
            
            # Set default policies
            sudo ufw default deny incoming
            sudo ufw default allow outgoing
            
            # Always allow SSH (port 22) to prevent lockout
            sudo ufw allow 22/tcp
            log_info "SSH port 22/tcp allowed"
            
            # Allow ports from configuration
            local ports=()
            while IFS= read -r port; do
                [[ -n "$port" ]] && ports+=("$port")
            done < <(get_allowed_ports_from_config)
            
            if [[ ${#ports[@]} -eq 0 ]]; then
                log_warning "No additional ports found in configuration"
            else
                for port in "${ports[@]}"; do
                    sudo ufw allow "$port"
                    log_info "Allowed port: $port"
                done
            fi
            
            # Enable UFW (non-interactive)
            echo "y" | sudo ufw enable
            
            # Create flag file to indicate auto-enablement
            touch "$FLAG_FILE"
            log_info "Firewall enabled and configured"
            ;;
            
        disable)
            if [[ -f "$FLAG_FILE" ]]; then
                log_info "Disabling firewall (was auto-enabled by script)..."
                sudo ufw --force disable
                rm -f "$FLAG_FILE"
                log_info "Firewall disabled"
            else
                log_info "Firewall was not auto-enabled by script, skipping disable"
            fi
            ;;
    esac
}

# ============================================================================
# Telegram Notification Functions
# ============================================================================

send_telegram_message() {
    local message="$1"
    local parse_mode="${2:-HTML}"
    
    local response
    response=$(curl -s -w "%{http_code}" -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=${parse_mode}" \
        -d "disable_web_page_preview=true")
    
    local http_code="${response: -3}"
    if [[ "$http_code" != "200" ]]; then
        log_error "Failed to send Telegram message (HTTP $http_code)"
        return 1
    fi
    
    log_info "Telegram message sent successfully"
    return 0
}

send_telegram_image() {
    local image_path="$1"
    local caption="${2:-}"
    
    if [[ ! -f "$image_path" ]]; then
        log_error "Image file not found: $image_path"
        return 1
    fi
    
    local response
    response=$(curl -s -w "%{http_code}" -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendPhoto" \
        -F "chat_id=${TELEGRAM_CHAT_ID}" \
        -F "photo=@${image_path}" \
        -F "caption=${caption}")
    
    local http_code="${response: -3}"
    if [[ "$http_code" != "200" ]]; then
        log_error "Failed to send Telegram image (HTTP $http_code)"
        return 1
    fi
    
    log_info "Telegram image sent successfully"
    return 0
}

# ============================================================================
# Image Generation Functions
# ============================================================================

generate_traffic_image() {
    local total_traffic_gib=$1
    local threshold_gib=$2
    local remaining_percentage=$3
    local message=$4
    
    # Determine colors based on traffic usage
    local background_color
    local bar_color
    
    if (( $(echo "$total_traffic_gib > $threshold_gib" | bc -l) )); then
        background_color="255,200,200"  # Light red background if threshold exceeded
        bar_color="255,0,0"             # Red bar
    else
        background_color="255,255,255"  # White background
        
        # Adjust bar color based on remaining percentage
        if (( $(echo "$remaining_percentage <= 10" | bc -l) )); then
            bar_color="255,0,0"          # Red if <= 10% remaining
        elif (( $(echo "$remaining_percentage <= 25" | bc -l) )); then
            bar_color="255,165,0"        # Orange if <= 25% remaining
        else
            bar_color="0,255,0"          # Green otherwise
        fi
    fi
    
    # Create Python script for image generation
    local python_script=$(cat << 'EOF'
from PIL import Image, ImageDraw, ImageFont
import sys
import os

def create_traffic_image(img_width, img_height, bar_width, bar_height, padding,
                         bg_color, bar_color, total_traffic, threshold, 
                         remaining_pct, log_message, image_path):
    
    # Convert color strings to tuples
    bg_color = tuple(map(int, bg_color.split(',')))
    bar_color = tuple(map(int, bar_color.split(',')))
    
    # Create image
    img = Image.new('RGB', (img_width, img_height), color=bg_color)
    draw = ImageDraw.Draw(img)
    
    # Load font
    font_size = 16
    title_font_size = 24
    try:
        font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', font_size)
        title_font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', title_font_size)
    except:
        font = ImageFont.load_default()
        title_font = ImageFont.load_default()
    
    # Draw title
    title = "Monthly Traffic Report"
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (img_width - title_width) // 2
    draw.text((title_x, padding), title, fill=(0, 0, 0), font=title_font)
    
    # Draw traffic info
    y_offset = title_font_size + padding * 2
    info_text = f"Total Traffic: {total_traffic} GiB / {threshold} GiB"
    draw.text((padding, y_offset), info_text, fill=(0, 0, 0), font=font)
    
    y_offset += font_size + 5
    remaining_text = f"Remaining: {remaining_pct}%"
    draw.text((padding, y_offset), remaining_text, fill=(0, 0, 0), font=font)
    
    # Draw log message
    y_offset += font_size + 10
    log_lines = log_message.split('\n')
    for line in log_lines[:15]:  # Limit to 15 lines
        draw.text((padding, y_offset), line[:100], fill=(0, 0, 0), font=font)
        y_offset += font_size + 2
    
    # Draw bar background
    bar_y = img_height - bar_height - padding
    bar_x = (img_width - bar_width) // 2
    draw.rectangle([bar_x, bar_y, bar_x + bar_width, bar_y + bar_height], 
                   fill=(200, 200, 200))
    
    # Calculate used bar width
    used_ratio = min(total_traffic / threshold, 1.0)
    used_bar_width = int(bar_width * used_ratio)
    
    # Draw used bar
    if used_bar_width > 0:
        draw.rectangle([bar_x, bar_y, bar_x + used_bar_width, bar_y + bar_height], 
                       fill=bar_color)
    
    # Draw bar border
    draw.rectangle([bar_x, bar_y, bar_x + bar_width, bar_y + bar_height], 
                   outline=(0, 0, 0), width=2)
    
    # Add percentage text inside bar
    percentage_text = f"{used_ratio * 100:.1f}%"
    text_bbox = draw.textbbox((0, 0), percentage_text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    text_x = bar_x + (bar_width - text_width) // 2
    text_y = bar_y + (bar_height - text_height) // 2
    draw.text((text_x, text_y), percentage_text, fill=(0, 0, 0), font=font)
    
    # Save image
    img.save(image_path)
    print(f"Image saved to {image_path}")

if __name__ == "__main__":
    if len(sys.argv) != 10:
        sys.exit(1)
    
    create_traffic_image(
        int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]),
        int(sys.argv[5]), sys.argv[6], sys.argv[7], float(sys.argv[8]),
        float(sys.argv[9]), float(sys.argv[10]), sys.argv[11], sys.argv[12]
    )
EOF
)
    
    # Execute Python script
    python3 -c "$python_script" 800 600 700 30 10 \
        "$background_color" "$bar_color" "$total_traffic_gib" \
        "$threshold_gib" "$remaining_percentage" "$message" "$IMAGE_PATH"
    
    if [[ $? -eq 0 ]] && [[ -f "$IMAGE_PATH" ]]; then
        log_info "Traffic image generated successfully"
        return 0
    else
        log_error "Failed to generate traffic image"
        return 1
    fi
}

# ============================================================================
# Main Script Logic
# ============================================================================

acquire_lock() {
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        log_warning "Another instance of the script is already running"
        exit 0
    fi
    log_info "Lock acquired"
}

release_lock() {
    flock -u 200
    rm -f "$LOCK_FILE"
    log_info "Lock released"
}

cleanup() {
    log_info "Cleaning up..."
    release_lock
    # Remove old images older than 7 days
    find "$SCRIPT_DIR" -name "traffic_log*.png" -mtime +7 -delete 2>/dev/null || true
}

# ============================================================================
# Main Execution
# ============================================================================

main() {
    log_info "========================================="
    log_info "Starting Monthly Traffic Monitor v2.0"
    log_info "========================================="
    
    # Acquire lock to prevent concurrent execution
    acquire_lock
    
    # Set trap for cleanup
    trap cleanup EXIT INT TERM
    
    # Load configuration
    load_configuration
    
    # Install dependencies
    install_dependencies
    
    # Get current traffic
    local total_traffic_gib
    total_traffic_gib=$(get_monthly_traffic)
    if [[ $? -ne 0 ]] || [[ -z "$total_traffic_gib" ]]; then
        log_error "Failed to retrieve traffic data"
        exit 1
    fi
    
    local current_date
    current_date=$(TZ=":Asia/Tehran" date "+%Y-%m-%d %H:%M:%S")
    local current_month
    current_month=$(date "+%Y-%m")
    
    log_info "Current month: $current_month"
    log_info "Total traffic so far: ${total_traffic_gib} GiB"
    log_info "Threshold: ${THRESHOLD_GIB} GiB"
    
    # Calculate remaining traffic and percentage
    local remaining_traffic_gib
    local remaining_percentage
    local threshold_exceeded=false
    
    if (( $(echo "$total_traffic_gib > $THRESHOLD_GIB" | bc -l) )); then
        threshold_exceeded=true
        remaining_traffic_gib=0
        remaining_percentage=0
        log_warning "Traffic threshold has been EXCEEDED!"
    else
        remaining_traffic_gib=$(echo "scale=2; $THRESHOLD_GIB - $total_traffic_gib" | bc)
        remaining_percentage=$(echo "scale=2; ($remaining_traffic_gib / $THRESHOLD_GIB) * 100" | bc)
        log_info "Remaining traffic: ${remaining_traffic_gib} GiB (${remaining_percentage}%)"
    fi
    
    # Prepare message
    local status_icon="📊"
    local status_text="Normal"
    if [[ "$threshold_exceeded" == true ]]; then
        status_icon="⚠️"
        status_text="THRESHOLD EXCEEDED"
    fi
    
    local message="${status_icon} ${TITLE}${status_icon}\n"
    message+="━━━━━━━━━━━━━━━━━━━━━━\n"
    message+="📅 Date: ${current_date}\n"
    message+="📆 Month: ${current_month}\n"
    message+="📈 Total Traffic: ${total_traffic_gib} GiB\n"
    message+="🎯 Threshold: ${THRESHOLD_GIB} GiB\n"
    
    if [[ "$threshold_exceeded" == false ]]; then
        message+="✅ Remaining: ${remaining_traffic_gib} GiB (${remaining_percentage}%)\n"
    else
        message+="⚠️ STATUS: ${status_text} ⚠️\n"
        message+="🔒 Firewall will be enabled\n"
    fi
    
    # Generate and send image
    generate_traffic_image "$total_traffic_gib" "$THRESHOLD_GIB" \
        "$remaining_percentage" "$(tail -20 "$LOG_FILE" 2>/dev/null || echo 'No log data')"
    
    if [[ -f "$IMAGE_PATH" ]]; then
        send_telegram_image "$IMAGE_PATH" "$message"
    else
        log_warning "Image not generated, sending text message only"
        send_telegram_message "$message"
    fi
    
    # Handle firewall based on threshold
    if [[ "$threshold_exceeded" == true ]]; then
        log_warning "Traffic limit exceeded! Enabling firewall..."
        
        # Send warning message
        local warning_msg="🚨 <b>URGENT: Traffic Limit Exceeded!</b> 🚨\n\n"
        warning_msg+="Total traffic (${total_traffic_gib} GiB) has exceeded the threshold (${THRESHOLD_GIB} GiB).\n\n"
        warning_msg+="<b>Firewall is being enabled now.</b>\n"
        warning_msg+="Only allowed ports (SSH + configured ports) will remain open."
        
        send_telegram_message "$warning_msg" "HTML"
        
        # Small delay before enabling firewall
        log_info "Waiting 5 seconds before enabling firewall..."
        sleep 5
        
        # Configure and enable firewall
        configure_firewall "enable"
        
        # Send confirmation
        send_telegram_message "✅ Firewall has been enabled successfully.\nSSH and configured ports are accessible."
    else
        # Check if we should disable firewall (only if it was auto-enabled by this script)
        if check_ufw_status && [[ -f "$FLAG_FILE" ]]; then
            log_info "Traffic is under threshold and firewall was auto-enabled, considering disable..."
            
            # Only disable if we have significant remaining traffic (>10%)
            if (( $(echo "$remaining_percentage > 10" | bc -l) )); then
                configure_firewall "disable"
                send_telegram_message "✅ Firewall has been disabled.\nTraffic is now ${remaining_traffic_gib} GiB (${remaining_percentage}%) under the ${THRESHOLD_GIB} GiB threshold."
            else
                log_info "Remaining traffic is low (${remaining_percentage}%), keeping firewall enabled"
            fi
        fi
    fi
    
    log_info "Script completed successfully"
    echo "----------------------------------------"
}

# Run main function
main "$@"
