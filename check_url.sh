#!/bin/bash

CONFIG_FILE="/root/config.txt"
IMAGE_PATH="/root/check_sites_image.png"  # Define the image path


# Source the config file to load the variables
source "$CONFIG_FILE"


# Clear the log file if it exists
> "$LOG_FILE"

# Log header with timestamp
echo "pishgaman $(TZ=":Asia/Tehran" date "+%Y-%m-%d %H:%M:%S")" | tee -a "$LOG_FILE"

# Read and process each URL
while IFS= read -r URL; do
  # Validate URL format
  if ! [[ "$URL" =~ ^https?:// ]]; then
    echo "Invalid URL format: $URL" | tee -a "$LOG_FILE"
    continue
  fi

  # Extract the domain from the URL
  DOMAIN=$(echo "$URL" | awk -F[/:] '{print $4}')
  TARGET_URL="http://$DOMAIN:$TARGET_PORT"

  # Run curl and capture the HTTP status code on the specified port
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$TARGET_URL")

  # Lookup the IP address for the domain
  IP_ADDRESS=$(dig +short "$DOMAIN" | head -n 1)

  if [ "$STATUS" -eq 000 ]; then
    echo "$DOMAIN [$IP_ADDRESS][status: $STATUS] Connection timeout on port $TARGET_PORT" | tee -a "$LOG_FILE"
  else
    echo "$DOMAIN [$IP_ADDRESS][status: $STATUS] Success on port $TARGET_PORT" | tee -a "$LOG_FILE"
  fi
done < "$URL_FILE"

# Function to generate an image from the log file
generate_simple_image_from_log() {
    local log_file="$1"
    local image_path="$2"
    
    python3 - <<EOF
from PIL import Image, ImageDraw, ImageFont

# Constants
img_width = 800
img_height = 600
padding = 10
line_height = 20

# Create image
img = Image.new('RGB', (img_width, img_height), color = (255, 255, 255))
d = ImageDraw.Draw(img)

# Load font
try:
    f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 16)
except IOError:
    f = ImageFont.load_default()

# Read the log file and process its content
with open('$log_file', 'r') as file:
    log_text = file.readlines()

# Function to draw colored text based on status
def draw_colored_text(text, status, y_position):
    if "Success" in status:
        color = (0, 255, 0)  # Green for success
    else:
        color = (255, 0, 0)  # Red for failure
    
    d.text((padding, y_position), text, fill=color, font=f)

# Draw each line from the log file
y_position = padding
for line in log_text:
    line = line.strip()
    if line:  # Avoid empty lines
        # Check if the line contains a success or failure status
        if "Success" in line:
            draw_colored_text(line, "Success", y_position)
        elif "Connection timeout" in line:
            draw_colored_text(line, "Failure", y_position)
        else:
            # Default to black for other lines
            d.text((padding, y_position), line, fill=(0, 0, 0), font=f)
        
        y_position += line_height

# Save image
img.save('$image_path')
EOF
}

# Call the function to generate the image
generate_simple_image_from_log "$LOG_FILE" "$IMAGE_PATH"

# Function to send the PNG file to Telegram from the remote server
send_png_to_telegram_via_sshpass() {
    local image_path="$1"
    local remote_user="$2"
    local remote_host="$3"
    local remote_port="$4"
    local root_password="$5"
    local bot_token="$6"
    local chat_id="$7"

    if [ ! -f "$image_path" ]; then
        echo "PNG file does not exist. Skipping sending to Telegram."
        return 1
    fi

    # Copy PNG file to remote server using sshpass and scp
    if sshpass -p "$root_password" scp -P "$remote_port" "$image_path" "$remote_user@$remote_host:/root/"; then
        echo "PNG file successfully transferred to remote server."

        # Send PNG file to Telegram from the remote server
        sshpass -p "$root_password" ssh -p "$remote_port" "$remote_user@$remote_host" << EOF
            curl -X POST "https://api.telegram.org/bot$bot_token/sendPhoto" \
                -F chat_id="$chat_id" \
                -F photo=@/root/$(basename "$image_path") \
                -F caption="url test image."
EOF

        if [ $? -eq 0 ]; then
            echo "PNG file successfully sent to Telegram from the remote server."
        else
            echo "Failed to send PNG file to Telegram." 
        fi
    else
        echo "Failed to transfer PNG file to the remote server."
    fi
}

# Send the PNG to Telegram
send_png_to_telegram_via_sshpass "$IMAGE_PATH" "$REMOTE_USER" "$REMOTE_HOST" "$REMOTE_PORT" "$ROOT_PASSWORD" "$BOT_TOKEN" "$CHAT_ID"

