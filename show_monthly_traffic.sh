#!/bin/bash

# Source the telegram_info.txt file to read variables
source /root/telegram_info.txt

VNSTAT_PATH="/usr/bin/vnstat"

LOG_FILE="/root/show_monthly_traffic.log"

IMAGE_PATH="/root/traffic_log.png"

# Get current Tehran time and date
TEHRAN_TIME=$(TZ=":Asia/Tehran" date "+%Y-%m-%d %H:%M:%S")


# Function to send image to Telegram
send_telegram_image() {
    local image_path="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendPhoto" -F "chat_id=$TELEGRAM_CHAT_ID" -F "photo=@$image_path" >/dev/null
}

# Function to convert traffic to bytes
convert_to_bytes() {
    local value=$1
    local unit=$2
    declare -A unit_multipliers=( ["TiB"]=1099511627776 ["GiB"]=1073741824 ["MiB"]=1048576 ["KiB"]=1024 ["B"]=1 )
    local multiplier=${unit_multipliers[$unit]}
    if [[ -z $multiplier ]]; then
        echo "Unknown unit: $unit" >&2
        exit 1
    fi
    echo $(bc <<< "$value * $multiplier")
}

# Ensure required packages are installed
ensure_installed() {
    local package=$1
    if ! dpkg -s $package &> /dev/null; then
        sudo apt-get update -y && sudo apt-get install $package -y
        if [[ $? -ne 0 ]]; then
            echo "Failed to install $package." >&2
            exit 1
        fi
    fi
}

# Install necessary packages
ensure_installed bc
ensure_installed vnstat
ensure_installed python3-pil
ensure_installed python3-pip

# Log file setup
rm -f "$LOG_FILE"
touch "$LOG_FILE"

# Get current date information
CURRENT_DATE=$(date "+%Y-%m")
CURRENT_MONTH=${CURRENT_DATE:5:2}
CURRENT_YEAR=${CURRENT_DATE:0:4}

# Get vnstat output
VNSTAT_OUTPUT=$($VNSTAT_PATH -m)
if [[ $? -ne 0 ]]; then
    echo "Error executing vnstat command" >&2
    exit 1
fi

# Extract total traffic for the current month
TOTAL_TRAFFIC=$(echo "$VNSTAT_OUTPUT" | grep " $CURRENT_DATE" | awk '{print $8" "$9}')
if [[ -z "$TOTAL_TRAFFIC" ]]; then
    echo "Error retrieving total traffic" >&2
    exit 1
fi

# Split total traffic into value and unit
TRAFFIC_VALUE=$(echo $TOTAL_TRAFFIC | awk '{print $1}')
TRAFFIC_UNIT=$(echo $TOTAL_TRAFFIC | awk '{print $2}')

# Convert traffic to bytes and then to GiB
TOTAL_TRAFFIC_BYTES=$(convert_to_bytes $TRAFFIC_VALUE $TRAFFIC_UNIT)
TOTAL_TRAFFIC_GIB=$(bc <<< "scale=2; $TOTAL_TRAFFIC_BYTES / (1024 * 1024 * 1024)")
# Calculate remaining traffic percentage
REMAINING_PERCENTAGE=$(bc <<< "scale=2; ($THRESHOLD_GIB - $TOTAL_TRAFFIC_GIB) / $THRESHOLD_GIB * 100")

# Compose message
message="\n\n$TITLE\n$(TZ=":Asia/Tehran" date "+%Y-%m-%d %H:%M:%S")\n"
#message+="$CURRENT_MONTH $CURRENT_YEAR\n\n"
message+="vnstat output:\n$VNSTAT_OUTPUT\n\n"
message+=" $CURRENT_YEAR-$CURRENT_MONTH-01 to now: $TOTAL_TRAFFIC_GIB GiB\n\n"

# Function to check if ufw is enabled
check_ufw_status() {
    if sudo ufw status | grep -q "Status: active"; then
        echo "UFW is enabled."
        return 0  # ufw is enabled
    else
        echo "UFW is not enabled."
        return 1  # ufw is not enabled
    fi
}

# Check if ufw is enabled and traffic is under threshold, then disable ufw
if check_ufw_status && (( $(echo "$TOTAL_TRAFFIC_GIB <= $THRESHOLD_GIB" | bc -l) )); then
    echo "Disabling ufw..."
    sudo ufw --force disable
fi


# Function to generate and send image with log message and bar visualization
generate_and_send_image() {
    if (( $(echo "$TOTAL_TRAFFIC_GIB > $THRESHOLD_GIB" | bc -l) )); then
        background_color="255,0,0"  # Red background if threshold exceeded
    else
        background_color="255,255,255"  # White background if threshold not exceeded
    fi

    # Adjusted color based on remaining percentage
    if (( $(echo "$REMAINING_PERCENTAGE <= 10" | bc -l) )); then
        bar_color="255,0,0"  # Red if remaining percentage <= 10%
    else
        bar_color="0,255,0"  # Green otherwise
    fi

    python3 - <<EOF
from PIL import Image, ImageDraw, ImageFont

# Constants
img_width = 800
img_height = 600
bar_width = 700
bar_height = 30
padding = 10
bar_x = (img_width - bar_width) // 2
bar_y = img_height - bar_height - padding

# Create image
img = Image.new('RGB', (img_width, img_height), color = ($background_color))
d = ImageDraw.Draw(img)

# Load font
try:
    f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 16)
except IOError:
    f = ImageFont.load_default()

# Draw log text
d.multiline_text((10,10), open('$LOG_FILE').read(), fill=(0,0,0), font=f)

# Draw bar background
d.rectangle([bar_x, bar_y, bar_x + bar_width, bar_y + bar_height], fill=(200,200,200))

# Calculate used bar width
used_bar_width = int(bar_width * $TOTAL_TRAFFIC_GIB / $THRESHOLD_GIB)

# Adjusted color based on remaining percentage
if $REMAINING_PERCENTAGE <= 10:
    bar_color="255,0,0"  # Red if remaining percentage <= 10%
else:
    bar_color="0,255,0"  # Green otherwise

# Draw used bar
d.rectangle([bar_x, bar_y, bar_x + used_bar_width, bar_y + bar_height], fill=($bar_color))

# Draw bar border
d.rectangle([bar_x, bar_y, bar_x + bar_width, bar_y + bar_height], outline=(0,0,0), width=2)

# Add text to the bar
bar_text = f"Remaining traffic: {${REMAINING_PERCENTAGE}}%"
text_width, text_height = d.textsize(bar_text, font=f)
text_x = (img_width - text_width) // 2
text_y = bar_y - text_height - padding
d.text((text_x, text_y), bar_text, fill=(0,0,0), font=f)

# Save image
img.save('$IMAGE_PATH')
EOF
    send_telegram_image "$IMAGE_PATH"
}

# Check if traffic exceeds threshold and handle accordingly
if (( $(echo "$TOTAL_TRAFFIC_GIB > $THRESHOLD_GIB" | bc -l) )); then
    message+="Total traffic exceeds $THRESHOLD_GIB GiB. Enabling firewall and blocking all traffic except SSH.\n"
    echo -e "$message" | tee -a $LOG_FILE
    generate_and_send_image
    echo "Delaying 5 seconds before enabling firewall..."
    sleep 5
    sudo ufw --force enable
    
    # Read ports from file and allow them
    if [[ -f /root/telegram_info.txt ]]; then
        echo "Reading ports from /root/telegram_info.txt..."
        while IFS= read -r line; do
            if [[ "$line" == sudo*ufw*allow* ]]; then
                echo "Allowing port: ${line#*allow }"
                eval "$line"  # Execute the 'ufw allow <port>' command
            fi
        done < /root/telegram_info.txt
    else
        echo "Error: /root/telegram_info.txt not found."
        exit 1
    fi

    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw reload
else
    REMAINING_TRAFFIC_GIB=$(bc <<< "scale=2; $THRESHOLD_GIB - $TOTAL_TRAFFIC_GIB")
    REMAINING_PERCENTAGE=$(bc <<< "scale=2; ($REMAINING_TRAFFIC_GIB / $THRESHOLD_GIB) * 100")
    message+="Remaining traffic: $REMAINING_TRAFFIC_GIB GiB of $THRESHOLD_GIB GiB ($REMAINING_PERCENTAGE%)\n"
    echo -e "$message" | tee -a $LOG_FILE
    generate_and_send_image
fi
