#!/bin/bash

port_in_use() {
    local check_port="$1"

    if [ -n "$CONTROL_PORT" ] && [ "$check_port" = "$CONTROL_PORT" ]; then
        return 0
    fi

    for p in "${USED_PORTS[@]}"; do
        if [ "$check_port" = "$p" ]; then
            return 0
        fi
    done

    return 1
}
patch_reverse_tunnel_sources() {
    local BASE_DIR="/root/reverse-tunnel"
    local REPO_URL="https://github.com/snsinfu/reverse-tunnel"

    cd /root || cd /

    if [ ! -d "$BASE_DIR" ]; then
        git clone "$REPO_URL" "$BASE_DIR"
    fi

    cd "$BASE_DIR" || exit 1

    local AGENT_FILE="$BASE_DIR/agent/agent.go"
    local BINDER_FILE="$BASE_DIR/server/tcp/binder.go"

    if [ -f "$AGENT_FILE" ]; then
        sed -i 's/net.Dial(agent.service.Protocol, agent.destination)/net.DialTimeout(agent.service.Protocol, agent.destination, 5*time.Second)/' "$AGENT_FILE"

        if ! grep -q "SetKeepAlivePeriod(30 * time.Second)" "$AGENT_FILE"; then
            sed -i '/defer conn.Close()/a \
\
\t// Enable TCP KeepAlive\n\tif tcpConn, ok := conn.(*net.TCPConn); ok {\n\t\ttcpConn.SetKeepAlive(true)\n\t\ttcpConn.SetKeepAlivePeriod(30 * time.Second)\n\t}' "$AGENT_FILE"
        fi

        sed -i 's/retryInterval[[:space:]]*=.*/\tretryInterval  = 1 * time.Second/' "$AGENT_FILE"
        sed -i 's/wsCloseTimeout[[:space:]]*=.*/\twsCloseTimeout = 30 * time.Second/' "$AGENT_FILE"
    fi

    if [ -f "$BINDER_FILE" ]; then
        sed -i 's/connTimeout[[:space:]]*=.*/\tconnTimeout = 30 * time.Second/' "$BINDER_FILE"
        sed -i 's/acceptRetryWait[[:space:]]*=.*/\tacceptRetryWait = 50 * time.Millisecond/' "$BINDER_FILE"
    fi
}
function error_exit {
    echo "$1" 1>&2
    exit 1
}
validate_number() {
    local input=$1
    local name=$2
    if [ -z "$input" ]; then
        echo "Error: $name cannot be empty. Please try again."
        return 1
    fi
    if [[ ! $input =~ ^[0-9]+$ ]]; then
        echo "Error: $name must be a non-negative integer. Please try again."
        return 1
    fi
    return 0
}
prompt_number() {
    local prompt=$1
    local var_name=$2
    local value
    while true; do
        read -r -p "$prompt" value
        if validate_number "$value" "$var_name"; then
            echo "$value"
            break
        fi
    done
}
check_prerequisites() {
    echo "Checking prerequisites..."

    if command -v mpstat >/dev/null 2>&1; then
        echo "✔ sysstat (mpstat) is installed."
    else
        echo "✘ sysstat (mpstat) is not installed. Attempting to install..."
        if sudo apt-get update && sudo apt-get install -y sysstat; then
            echo "✔ sysstat installed successfully."
        else
            echo "✘ Failed to install sysstat. Please install it manually."
            return 1
        fi
    fi

    if command -v bc >/dev/null 2>&1; then
        echo "✔ bc is installed."
    else
        echo "✘ bc is not installed. Attempting to install..."
        if sudo apt-get update && sudo apt-get install -y bc; then
            echo "✔ bc installed successfully."
        else
            echo "✘ Failed to install bc. Please install it manually."
            return 1
        fi
    fi

    if [ -w "/var/log/" ]; then
        echo "✔ /var/log/ is writable."
    else
        echo "✘ /var/log/ is not writable. Please ensure it is writable."
        return 1
    fi

    if sudo -n systemctl status >/dev/null 2>&1; then
        echo "✔ sudo access for systemctl is available."
    else
        echo "✘ No sudo access for systemctl. Please configure sudo permissions."
        return 1
    fi

    return 0
}
validate_service() {
    local service=$1
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        echo "✔ Service $service exists and is enabled."
        return 0
    else
        echo "✘ Service $service does not exist or is not enabled."
        return 1
    fi
}
db_backup_menu() {
    clear
    echo "===== DB Backuper ====="
    echo ""
    sudo apt install -y lftp >/dev/null 2>&1

    read -p "FTP_HOST: " FTP_HOST
    read -p "FTP_USER: " FTP_USER
    read -p "FTP_PASSWORD: " FTP_PASSWORD
    read -p "BackupFile (local DB file path): " BackupFile
    read -p "HostDirectory (remote FTP path): " HostDirectory
    read -p "Backup interval in HOURS: " BackUPPERHOUR
    read -p "Backup File Prefix Name (ex: mydb_): " PRFNM
    read -p "Bot Token: " MYBOTTOKEN
    read -p "Telegram ChatID: " MYBOTCHATID
    read -p "Your Backup Directory (ex: /home/user/public_html/backup/): " MYBACKUPDIR
    read -p "Bot Domain + Path (ex: domain.com/backup/): " MYBOTDOM

    random_filename=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 12)
    php_file_path="/root/${random_filename}.php"

    cat <<EOL > "$php_file_path"
<?php
\$token = "$MYBOTTOKEN";
\$chat_id = "$MYBOTCHATID";
\$directory = '$MYBACKUPDIR';
\$logFile = 'log.txt';

function logMessage(\$message) {
    global \$logFile;
    \$timestamp = date('Y-m-d H:i:s');
    file_put_contents(\$logFile, "[\$timestamp] \$message" . PHP_EOL, FILE_APPEND);
}

logMessage("Starting script...");

\$files = array_filter(scandir(\$directory), function(\$file) use (\$directory) {
    return pathinfo(\$file, PATHINFO_EXTENSION) === 'db'
        && is_file("\$directory/\$file")
        && strpos(\$file, '$PRFNM') === 0;
});

if (empty(\$files)) {
    logMessage("No .db files starting with '$PRFNM' found.");
} else {
    usort(\$files, function(\$a, \$b) use (\$directory) {
        return filemtime("\$directory/\$b") - filemtime("\$directory/\$a");
    });

    \$latestFile = \$files[0];
    logMessage("Found latest file: \$latestFile");

    \$filePath = "\$directory/\$latestFile";

    if (!file_exists(\$filePath)) {
        logMessage("File does not exist: \$filePath");
    } else {
        \$result = sendFileToTelegram(\$token, \$chat_id, \$filePath);
        logMessage("Telegram API response: \$result");

        if (\$result === false || json_decode(\$result)->ok !== true) {
            logMessage("Failed to send file: \$filePath");
        } else {
            logMessage("Successfully sent file: \$filePath");
        }
    }
}

function sendFileToTelegram(\$token, \$chat_id, \$filePath) {
    \$url = "https://api.telegram.org/bot\$token/sendDocument";

    \$postFields = [
        'chat_id' => \$chat_id,
        'document' => new CURLFile(realpath(\$filePath))
    ];

    \$ch = curl_init();
    curl_setopt(\$ch, CURLOPT_URL, \$url);
    curl_setopt(\$ch, CURLOPT_POST, true);
    curl_setopt(\$ch, CURLOPT_POSTFIELDS, \$postFields);
    curl_setopt(\$ch, CURLOPT_RETURNTRANSFER, true);

    \$result = curl_exec(\$ch);
    if (curl_errno(\$ch)) {
        logMessage('CURL error: ' . curl_error(\$ch));
    }

    curl_close(\$ch);
    return \$result;
}
?>
EOL

    echo "'${random_filename}.php' created at '$php_file_path'"

    lftp -u "$FTP_USER","$FTP_PASSWORD" "$FTP_HOST" <<EOF
set ftp:ssl-allow no
put "$php_file_path" -o "$HostDirectory/$random_filename.php"
bye
EOF

    if [ $? -eq 0 ]; then
        echo "Bot PHP file uploaded successfully."
    else
        echo "Bot PHP upload FAILED."
    fi

    cat <<EOL > /etc/backUPeRF.sh
#!/bin/bash
FTP_HOST="$FTP_HOST"
FTP_USER="$FTP_USER"
FTP_PASSWORD="$FTP_PASSWORD"
LOCAL_FILE="$BackupFile"
REMOTE_DIR="$HostDirectory"
PRFNM="$PRFNM"

TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="\${PRFNM}\$TIMESTAMP.db"

lftp -u "\$FTP_USER","\$FTP_PASSWORD" "\$FTP_HOST" <<EOF2
set ftp:ssl-allow no
put "\$LOCAL_FILE" -o "\$REMOTE_DIR/\$BACKUP_FILE"
bye
EOF2

if [ \$? -eq 0 ]; then
    echo "DONE \$BACKUP_FILE"
else
    echo "FAILED"
fi
EOL

    chmod +x /etc/backUPeRF.sh

    crontab -l 2>/dev/null | grep -v "/etc/backUPeRF.sh" | crontab -

    echo "0 */$BackUPPERHOUR * * * /etc/backUPeRF.sh" | crontab -

    /etc/backUPeRF.sh

    wget -q "https://api.telegram.org/bot$MYBOTTOKEN/setwebhook?url=https://$MYBOTDOM$random_filename.php"

    wget -q "https://$MYBOTDOM$random_filename.php" -O /dev/null

    echo "DB Backup System Installed!"
    echo "Telegram notifier active."
    echo "Cron job runs every $BackUPPERHOUR hours."
    read -p "Press Enter to return..."
}
install_checker() {
    local CHECKER_SCRIPT="/etc/cheker.sh"
    local RAM_TEMP_FILE="/var/log/ram_usage_monitor.txt"
    local CPU_TEMP_FILE="/var/log/cpu_usage_monitor.txt"
    local RESTART_LOG="/var/log/restartservice.txt"

    TOTAL_RAM_MB=$(free -m | awk '/Mem/{print $2}')
    RECOMMENDED_MB=$(( TOTAL_RAM_MB * 75 / 100 ))
    echo "Server total RAM: ${TOTAL_RAM_MB}MB"

    RAM_THRESHOLD=$(prompt_number "Enter RAM threshold (Server RAM is ${TOTAL_RAM_MB}MB, Recommend 75% = ${RECOMMENDED_MB}MB, or 0 to disable RAM monitoring): " "RAM threshold (MB)")

    CPU_THRESHOLD=$(prompt_number "Enter CPU threshold (in percentage, e.g., 90 for 90%, or 0 to disable CPU monitoring): " "CPU threshold")
    DURATION=$(prompt_number "Enter duration (in seconds, e.g., 15): " "Duration")

    VALID_SERVICES=()

    echo "Searching for custom services (from /etc/systemd/system)..."

    mapfile -t ALL_ENABLED < <(systemctl list-unit-files --type=service --state=enabled --no-legend 2>/dev/null | awk '{print $1}')

    CUSTOM_SERVICES=()
    for svc in "${ALL_ENABLED[@]}"; do
        base="${svc%.service}"
        frag=$(systemctl show -p FragmentPath "$svc" 2>/dev/null | cut -d= -f2)
        if [[ "$frag" == /etc/systemd/system/* ]]; then
            CUSTOM_SERVICES+=("$base")
        fi
    done

    if [ ${#CUSTOM_SERVICES[@]} -gt 0 ]; then
        echo "Available custom services:"
        for i in "${!CUSTOM_SERVICES[@]}"; do
            echo "$((i+1))) ${CUSTOM_SERVICES[i]}"
        done
        echo "Select services by number (comma-separated, e.g., 1,3), or leave empty to skip:"
        read -r SELECTED
        if [ -n "$SELECTED" ]; then
            IFS=',' read -r -a SEL_ARRAY <<< "$SELECTED"
            for idx in "${SEL_ARRAY[@]}"; do
                idx_trim="${idx//[[:space:]]/}"
                if [[ "$idx_trim" =~ ^[0-9]+$ ]] && [ "$idx_trim" -ge 1 ] && [ "$idx_trim" -le "${#CUSTOM_SERVICES[@]}" ]; then
                    svc="${CUSTOM_SERVICES[$((idx_trim-1))]}"
                    if validate_service "$svc"; then
                        VALID_SERVICES+=("$svc")
                    fi
                else
                    echo "Invalid selection: $idx_trim"
                fi
            done
        else
            echo "No services selected from list."
        fi
    else
        echo "No custom services detected in /etc/systemd/system. You can enter names manually."
    fi

    if [ ${#VALID_SERVICES[@]} -eq 0 ]; then
        echo "Enter service names to restart manually (comma-separated, e.g., rtun-server,rtun), or leave empty to skip: "
        read -r MANUAL_SERVICES
        if [ -n "$MANUAL_SERVICES" ]; then
            IFS=',' read -r -a SERVICE_ARRAY <<< "$MANUAL_SERVICES"
            for SERVICE in "${SERVICE_ARRAY[@]}"; do
                SERVICE_TRIM="${SERVICE//[[:space:]]/}"
                if [ -n "$SERVICE_TRIM" ] && validate_service "$SERVICE_TRIM"; then
                    VALID_SERVICES+=("$SERVICE_TRIM")
                fi
            done
        fi
    fi

    if [ ${#VALID_SERVICES[@]} -eq 0 ]; then
        echo "Warning: No valid services found. Checker will not restart any service."
    else
        echo "Valid services selected: ${VALID_SERVICES[*]}"
    fi


    local CRON_UNIT=""
    while true; do
        echo "Select cron unit:"
        echo "1) Minutes"
        echo "2) Hours"
        read -r -p "Enter 1 or 2: " CRON_CHOICE
        if [ "$CRON_CHOICE" = "1" ]; then
            CRON_UNIT="minutes"
            break
        elif [ "$CRON_CHOICE" = "2" ]; then
            CRON_UNIT="hours"
            break
        else
            echo "Error: Please enter 1 or 2."
        fi
    done

    CRON_INTERVAL=$(prompt_number "Enter the interval for cron (e.g., 5 for 5 $CRON_UNIT): " "Cron interval")

    if [ "$RAM_THRESHOLD" -eq 0 ] && [ "$CPU_THRESHOLD" -eq 0 ] && [ ${#VALID_SERVICES[@]} -eq 0 ]; then
        echo "Error: No monitoring enabled (both RAM and CPU thresholds are 0, and no valid services). Exiting."
        return 1
    fi

    cat << EOF > "$CHECKER_SCRIPT"
#!/bin/bash

RAM_THRESHOLD=$RAM_THRESHOLD      # MB
CPU_THRESHOLD=$CPU_THRESHOLD
DURATION=$DURATION
RAM_TEMP_FILE="$RAM_TEMP_FILE"
CPU_TEMP_FILE="$CPU_TEMP_FILE"
RESTART_LOG="$RESTART_LOG"

monitor() {
EOF

    if [ "$RAM_THRESHOLD" -ne 0 ]; then
        cat << 'EOF' >> "$CHECKER_SCRIPT"
    RAM_USAGE=$(free -m | awk '/Mem/{print $3}')

    if [ "$RAM_USAGE" -gt "$RAM_THRESHOLD" ]; then
        if [ ! -f "$RAM_TEMP_FILE" ]; then
            echo "$(date +%s)" > "$RAM_TEMP_FILE"
        fi
    else
        if [ -f "$RAM_TEMP_FILE" ]; then
            rm "$RAM_TEMP_FILE"
        fi
    fi
EOF
    fi

    if [ "$CPU_THRESHOLD" -ne 0 ]; then
        cat << 'EOF' >> "$CHECKER_SCRIPT"
    CPU_USAGE=$(mpstat 1 1 | awk '/Average:/ {print 100 - $NF}')

    if (( $(echo "$CPU_USAGE >= $CPU_THRESHOLD" | bc -l) )); then
        if [ ! -f "$CPU_TEMP_FILE" ]; then
            echo "$(date +%s)" > "$CPU_TEMP_FILE"
        fi
    else
        if [ -f "$CPU_TEMP_FILE" ]; then
            rm "$CPU_TEMP_FILE"
        fi
    fi
EOF
    fi

    if [ "$RAM_THRESHOLD" -ne 0 ]; then
        cat << 'EOF' >> "$CHECKER_SCRIPT"
    if [ -f "$RAM_TEMP_FILE" ]; then
        RAM_START_TIME=$(cat "$RAM_TEMP_FILE")
        CURRENT_TIME=$(date +%s)
        RAM_ELAPSED_TIME=$((CURRENT_TIME - RAM_START_TIME))

        if [ "$RAM_ELAPSED_TIME" -ge "$DURATION" ]; then
EOF
        if [ ${#VALID_SERVICES[@]} -gt 0 ]; then
            for SERVICE in "${VALID_SERVICES[@]}"; do
                cat << EOF >> "$CHECKER_SCRIPT"
            sudo systemctl restart $SERVICE
            echo "Service $SERVICE restarted at: \$(date) due to high RAM usage (\$RAM_USAGE MB)" >> "\$RESTART_LOG"
EOF
            done
        fi
        cat << 'EOF' >> "$CHECKER_SCRIPT"
            rm "$RAM_TEMP_FILE"
        fi
    fi
EOF
    fi

    if [ "$CPU_THRESHOLD" -ne 0 ]; then
        cat << 'EOF' >> "$CHECKER_SCRIPT"
    if [ -f "$CPU_TEMP_FILE" ]; then
        CPU_START_TIME=$(cat "$CPU_TEMP_FILE")
        CURRENT_TIME=$(date +%s)
        CPU_ELAPSED_TIME=$((CURRENT_TIME - CPU_START_TIME))

        if [ "$CPU_ELAPSED_TIME" -ge "$DURATION" ]; then
EOF
        if [ ${#VALID_SERVICES[@]} -gt 0 ]; then
            for SERVICE in "${VALID_SERVICES[@]}"; do
                cat << EOF >> "$CHECKER_SCRIPT"
            sudo systemctl restart $SERVICE
            echo "Service $SERVICE restarted at: \$(date) due to high CPU usage (\$CPU_USAGE%)" >> "\$RESTART_LOG"
EOF
            done
        fi
        cat << 'EOF' >> "$CHECKER_SCRIPT"
            rm "$CPU_TEMP_FILE"
        fi
    fi
EOF
    fi

    cat << 'EOF' >> "$CHECKER_SCRIPT"
}
monitor
EOF

    chmod +x "$CHECKER_SCRIPT"

    if [ ${#VALID_SERVICES[@]} -gt 0 ] && { [ "$RAM_THRESHOLD" -ne 0 ] || [ "$CPU_THRESHOLD" -ne 0 ]; }; then
        if [ "$CRON_UNIT" = "minutes" ]; then
            CRON_JOB="*/$CRON_INTERVAL * * * * /bin/bash $CHECKER_SCRIPT"
        else
            CRON_JOB="* */$CRON_INTERVAL * * * /bin/bash $CHECKER_SCRIPT"
        fi
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
        echo "Script $CHECKER_SCRIPT created/overwritten and added to crontab to run every $CRON_INTERVAL $CRON_UNIT."
        echo "Services to be restarted: ${VALID_SERVICES[*]}"
    else
        echo "Script $CHECKER_SCRIPT created/overwritten but not added to crontab due to no valid services or both thresholds set to 0."
    fi

    echo "Checker installed successfully."
    return 0
}
run_checker() {
    local CHECKER_SCRIPT="/etc/cheker.sh"
    local RESTART_LOG="/var/log/restartservice.txt"
    if [ -f "$CHECKER_SCRIPT" ]; then
        echo "Running $CHECKER_SCRIPT for testing..."
        bash "$CHECKER_SCRIPT"
        echo "Checker execution completed."
        if [ -f "$RESTART_LOG" ]; then
            echo "Restart log contents:"
            cat "$RESTART_LOG"
        else
            echo "No restart log found at $RESTART_LOG."
        fi
    else
        echo "Error: $CHECKER_SCRIPT does not exist. Please install checker first."
    fi
}
uninstall_checker() {
    local CHECKER_SCRIPT="/etc/cheker.sh"

    if crontab -l 2>/dev/null | grep -q "$CHECKER_SCRIPT"; then
        crontab -l 2>/dev/null | grep -v "$CHECKER_SCRIPT" | crontab -
        echo "Cron job for $CHECKER_SCRIPT removed."
    else
        echo "No cron job found for $CHECKER_SCRIPT."
    fi

    if [ -f "$CHECKER_SCRIPT" ]; then
        rm -f "$CHECKER_SCRIPT"
        echo "File $CHECKER_SCRIPT removed."
    else
        echo "File $CHECKER_SCRIPT does not exist."
    fi

    echo "Checker uninstalled successfully."
}
view_log() {
    local RESTART_LOG="/var/log/restartservice.txt"
    if [ -f "$RESTART_LOG" ]; then
        echo "Restart log contents:"
        cat "$RESTART_LOG"
    else
        echo "No restart log found at $RESTART_LOG."
    fi
}
handle_error() {
    echo -e "\033[31mError: $1\033[0m" >&2
    echo "Press Enter to return to previous menu..."
    read -r
}
ipv6_check_prerequisites() {
    local packages=("iproute2" "net-tools")
    local missing=()
    echo "Checking prerequisites..."
    for pkg in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            missing+=("$pkg")
        fi
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Missing packages: ${missing[*]}"
        echo "Attempting to install..."
        if ! sudo apt-get update; then
            handle_error "Failed to update package lists"
            return 1
        fi
        if ! sudo apt-get install -y "${missing[@]}"; then
            handle_error "Failed to install packages"
            return 1
        fi
        echo "Packages installed successfully."
    else
        echo "All prerequisites are installed."
    fi
    if ! lsmod | grep -q "^sit "; then
        if ! sudo modprobe sit; then
            handle_error "Failed to load sit kernel module"
            return 1
        fi
    fi
    if ! lsmod | grep -q "^ipv6 "; then
        if ! sudo modprobe ipv6; then
            handle_error "Failed to load ipv6 kernel module"
            return 1
        fi
    fi
    return 0
}
display_package_status() {
    local packages=("iproute2" "net-tools")
    echo -e "\nPackage Status:"
    for pkg in "${packages[@]}"; do
        if dpkg -l | grep -q "^ii  $pkg "; then
            echo "$pkg > installed"
        else
            echo "$pkg > need install"
        fi
    done
    echo ""
}
validate_ipv4() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}
validate_ipv6() {
    local ip=$1
    if [[ ! $ip =~ ^([0-9a-fA-F:]+)(/[0-9]{1,3})$ ]]; then
        return 1
    fi
    local addr="${BASH_REMATCH[1]}"
    local prefix_len="${BASH_REMATCH[2]:1}"
    if [ "$prefix_len" -lt 1 ] || [ "$prefix_len" -gt 128 ]; then
        return 1
    fi
    local IFS=':'
    read -r -a segments <<< "$addr"
    local segment_count=${#segments[@]}
    local has_double_colon=false
    local empty_segment_count=0
    for segment in "${segments[@]}"; do
        if [[ -z "$segment" ]]; then
            empty_segment_count=$((empty_segment_count + 1))
        fi
    done
    if [ "$empty_segment_count" -gt 1 ]; then
        return 1
    fi
    if [[ "$addr" =~ :: ]]; then
        has_double_colon=true
    fi
    if $has_double_colon; then
        local missing_segments=$((8 - segment_count + empty_segment_count))
        segment_count=$((segment_count + missing_segments - empty_segment_count))
    fi
    if [ "$segment_count" -gt 8 ] || [ "$segment_count" -lt 1 ]; then
        return 1
    fi
    for segment in "${segments[@]}"; do
        if [[ -n "$segment" ]]; then
            if [[ ! $segment =~ ^[0-9a-fA-F]{1,4}$ ]]; then
                return 1
            fi
        fi
    done
    return 0
}
validate_ttl() {
    local ttl=$1
    if [[ $ttl =~ ^[0-9]+$ ]] && [ "$ttl" -ge 1 ] && [ "$ttl" -le 255 ]; then
        return 0
    fi
    return 1
}
validate_mtu() {
    local mtu=$1
    if [[ $mtu =~ ^[0-9]+$ ]] && [ "$mtu" -ge 1280 ] && [ "$mtu" -le 1500 ]; then
        return 0
    fi
    return 1
}
validate_sit_name() {
    local sit_name=$1
    if [[ $sit_name =~ ^[a-zA-Z0-9]+$ ]]; then
        if [[ "$sit_name" == "sit0" ]]; then
            echo "Error: sit0 is reserved and cannot be used." >&2
            return 1
        fi
        if ip link show "$sit_name" > /dev/null 2>&1; then
            echo "Error: Interface $sit_name already exists." >&2
            return 1
        fi
        return 0
    fi
    return 1
}
find_iface_mtu() {
    local default_mtu=1280
    local iface phys_mtu mtu

    iface=$(ip route 2>/dev/null | awk '/default/ {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')

    if [[ -z "$iface" ]]; then
        iface=$(ip -o link show 2>/dev/null | awk -F': ' '$2 != "lo" {print $2; exit}')
    fi

    if [[ -z "$iface" ]]; then
        echo "$default_mtu"
        return
    fi

    phys_mtu=$(ip link show "$iface" 2>/dev/null | awk '/mtu/ {for (i=1;i<=NF;i++) if ($i=="mtu") {print $(i+1); break}}')

    if [[ -z "$phys_mtu" ]] || ! [[ "$phys_mtu" =~ ^[0-9]+$ ]]; then
        echo "$default_mtu"
        return
    fi

    mtu=$((phys_mtu - 20))
    if (( mtu < 1280 )); then mtu=1280; fi
    if (( mtu > 1500 )); then mtu=1500; fi

    echo "$mtu"
}
probe_mtu() {
    local local_ip=$1
    local remote_ip=$2
    local default_mtu=1280
    local max_mtu=1500
    local overhead=60

    if [[ -z "$remote_ip" ]]; then
        echo "$default_mtu"
        return
    fi

    local iface
    iface=$(ip route get "$remote_ip" 2>/dev/null | awk '/dev/ {for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); break}}')
    if [[ -z "$iface" ]]; then
        echo "$default_mtu"
        return
    fi

    local phys_mtu
    phys_mtu=$(ip link show "$iface" 2>/dev/null | awk '/mtu/ {for (i=1;i<=NF;i++) if ($i=="mtu") {print $(i+1); break}}')
    if [[ -z "$phys_mtu" ]] || ! [[ "$phys_mtu" =~ ^[0-9]+$ ]]; then
        echo "$default_mtu"
        return
    fi

    local base_mtu=$((phys_mtu - overhead))
    if (( base_mtu > max_mtu )); then base_mtu=$max_mtu; fi
    if (( base_mtu < 1280 )); then base_mtu=1280; fi

    local packet_size=$((base_mtu - 28))

    if ping -c 1 -W 1 -M do -s "$packet_size" "$remote_ip" >/dev/null 2>&1; then
        echo "$base_mtu"
    else
        echo "$default_mtu"
    fi
}
create_systemd_service() {
    local name=$1
    local sit_name=$2
    local local_ip=$3
    local remote_ip=$4
    local ipv6_addrs=$5
    local ttl=$6
    local mtu=$7
    local service_file="/etc/systemd/system/ipv6tunnel-$name.service"
    local script_file="/usr/local/bin/ipv6tunnel-$name.sh"

    if ip link show "$sit_name" > /dev/null 2>&1; then
        handle_error "Tunnel interface $sit_name already exists. Please choose a different sit name."
        return 1
    fi

    cat << EOF | sudo tee "$script_file" > /dev/null
#!/bin/bash
if ip link show $sit_name > /dev/null 2>&1; then
    echo "Tunnel $sit_name already exists" >&2
    exit 1
fi
ip tunnel add $sit_name mode sit local $local_ip remote $remote_ip ttl $ttl
if [ \$? -ne 0 ]; then
    echo "Failed to create tunnel $sit_name: \$?" >&2
    exit 1
fi
ip link set $sit_name up
if [ \$? -ne 0 ]; then
    echo "Failed to bring up tunnel $sit_name" >&2
    exit 1
fi
$(for addr in ${ipv6_addrs//,/ }; do echo "ip addr add $addr dev $sit_name"; done)
if [ \$? -ne 0 ]; then
    echo "Failed to add IPv6 addresses to $sit_name" >&2
    exit 1
fi
ip link set $sit_name mtu $mtu
if [ \$? -ne 0 ]; then
    echo "Failed to set MTU for $sit_name" >&2
    exit 1
fi
EOF
    sudo chmod +x "$script_file"

    cat << EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=IPv6 Tunnel Service for $name
After=network.target

[Service]
Type=oneshot
ExecStart=$script_file
RemainAfterExit=yes
ExecStop=/sbin/ip tunnel del $sit_name
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

    if ! sudo systemctl daemon-reload; then
        handle_error "Failed to reload systemd daemon"
        return 1
    fi
    if ! sudo systemctl enable "ipv6tunnel-$name.service"; then
        handle_error "Failed to enable systemd service"
        return 1
    fi
    if ! sudo systemctl start "ipv6tunnel-$name.service"; then
        handle_error "Failed to start systemd service"
        return 1
    fi
    echo "Tunnel $name created and started successfully."
    return 0
}
delete_tunnel() {
    local name=$1
    local sit_name=$2
    local service_file="/etc/systemd/system/ipv6tunnel-$name.service"
    local script_file="/usr/local/bin/ipv6tunnel-$name.sh"

    if sudo systemctl stop "ipv6tunnel-$name.service"; then
        echo "Service ipv6tunnel-$name stopped."
    else
        echo "Warning: Failed to stop service ipv6tunnel-$name. It may not be running."
    fi
    if sudo systemctl disable "ipv6tunnel-$name.service"; then
        echo "Service ipv6tunnel-$name disabled."
    else
        echo "Warning: Failed to disable service ipv6tunnel-$name."
    fi

    if ip link show "$sit_name" > /dev/null 2>&1; then
        if sudo ip tunnel del "$sit_name"; then
            echo "Tunnel interface $sit_name deleted."
        else
            handle_error "Failed to delete tunnel interface $sit_name."
            return 1
        fi
    else
        echo "Tunnel interface $sit_name does not exist."
    fi

    if [[ -f "$service_file" ]]; then
        if sudo rm "$service_file"; then
            echo "Service file $service_file removed."
        else
            handle_error "Failed to remove service file $service_file."
            return 1
        fi
    fi
    if [[ -f "$script_file" ]]; then
        if sudo rm "$script_file"; then
            echo "Script file $script_file removed."
        else
            handle_error "Failed to remove script file $script_file."
            return 1
        fi
    fi

    if sudo systemctl daemon-reload; then
        echo "Systemd daemon reloaded."
    else
        handle_error "Failed to reload systemd daemon."
        return 1
    fi
    if sudo systemctl reset-failed; then
        echo "Systemd failed state reset."
    fi

    echo "Tunnel $name deleted successfully."
    return 0
}
generate_tunnel() {
    local type=$1
    local remote_label="remote ip ($([ "$type" == "Gateway" ] && echo "Guest" || echo "Gateway"))"
    local local_label="local ip ($type)"
    local name sit_name remote_ip local_ip ipv6_addrs ttl mtu

    while true; do
        clear
        display_package_status
        echo "Generate IPv6 Tunnel on $type"
        read -p "Name (e.g., ipv6tunB): " name
        if [[ -z "$name" ]] || [[ "$name" =~ [^a-zA-Z0-9] ]]; then
            handle_error "Invalid name. Use alphanumeric characters only."
            continue
        fi
        if [[ -f "/etc/systemd/system/ipv6tunnel-$name.service" ]]; then
            handle_error "Service name $name already exists."
            continue
        fi
        read -p "sit name (e.g., sit5, not sit0): " sit_name
        if ! validate_sit_name "$sit_name"; then
            handle_error "Invalid or existing sit name. Use alphanumeric characters, ensure it's unique, and avoid sit0."
            continue
        fi
        read -p "$remote_label: " remote_ip
        if ! validate_ipv4 "$remote_ip"; then
            handle_error "Invalid IPv4 address for remote IP."
            continue
        fi
        read -p "$local_label: " local_ip
        if ! validate_ipv4 "$local_ip"; then
            handle_error "Invalid IPv4 address for local IP."
            continue
        fi
                read -p "custom ipv6 addresses (e.g., 2001:db8::1/64,2001:db8::2/64): " ipv6_addrs
        for addr in ${ipv6_addrs//,/ }; do
            if ! validate_ipv6 "$addr"; then
                handle_error "Invalid IPv6 address: $addr. Ensure it has a valid format (e.g., 2001:db8::1/64)."
                continue 2
            fi
        done

        local ttl ttl_input
        local ttl_suggest1=64
        local ttl_suggest2=128

        echo "Suggested TTL values:"
        echo "  1) $ttl_suggest1  (typical Linux default)"
        echo "  2) $ttl_suggest2  (higher TTL)"
        read -p "Choose TTL [1/2 or custom 1-255]: " ttl_input

        if [[ "$ttl_input" == "1" ]]; then
            ttl="$ttl_suggest1"
        elif [[ "$ttl_input" == "2" ]]; then
            ttl="$ttl_suggest2"
        else
            ttl="$ttl_input"
        fi

        if ! validate_ttl "$ttl"; then
            handle_error "Invalid TTL value."
            continue
        fi

        echo "Detecting MTU suggestions..."
        local mtu mtu_input mtu_iface mtu_probe
        mtu_iface=$(find_iface_mtu)
        mtu_probe=$(probe_mtu "$local_ip" "$remote_ip")

        echo "Suggested MTUs:"
        echo "  1) $mtu_iface  (based on primary interface MTU - 20)"
        echo "  2) $mtu_probe  (based on probe to $remote_ip)"
        read -p "Choose MTU: [1/2 or enter custom 1280-1500]: " mtu_input

        if [[ "$mtu_input" == "1" ]]; then
            mtu="$mtu_iface"
        elif [[ "$mtu_input" == "2" ]]; then
            mtu="$mtu_probe"
        elif validate_mtu "$mtu_input"; then
            mtu="$mtu_input"
        else
            handle_error "Invalid MTU selection/value."
            continue
        fi


        create_systemd_service "$name" "$sit_name" "$local_ip" "$remote_ip" "$ipv6_addrs" "$ttl" "$mtu" || continue
        echo "Press Enter to return to menu..."
        read -r
        break
    done
}
view_edit_tunnels() {
    local tunnels=()
    local name sit_name ipv6_addrs ttl mtu
    while true; do
        clear
        display_package_status
        echo "Existing IPv6 Tunnels:"
        echo "ID | Name | Sit Name | IPv6 Addresses | TTL | MTU"
        echo "---|------|----------|----------------|-----|-----"
        tunnels=()
        local id=1
        for service in /etc/systemd/system/ipv6tunnel-*.service; do
            if [[ -f "$service" ]]; then
                name=$(basename "$service" | sed 's/ipv6tunnel-\(.*\)\.service/\1/')
                script="/usr/local/bin/ipv6tunnel-$name.sh"
                if [[ -f "$script" ]]; then
                    sit_name=$(grep 'ip tunnel add' "$script" | awk '{print $4}')
                    ipv6_addrs=$(grep 'ip addr add' "$script" | awk '{print $4}' | paste -sd,)
                    ttl=$(grep 'ttl' "$script" | awk '{print $NF}')
                    mtu=$(grep 'mtu' "$script" | awk '{print $NF}')
                    tunnels+=("$name|$sit_name|$ipv6_addrs|$ttl|$mtu")
                    echo "$id | $name | $sit_name | $ipv6_addrs | $ttl | $mtu"
                    ((id++))
                fi
            fi
        done
        if [ ${#tunnels[@]} -eq 0 ]; then
            echo "No tunnels found."
        fi
        echo ""
        echo "Select a tunnel ID to edit/delete (or 0 to return):"
        read -p "> " choice
        if [ "$choice" -eq 0 ]; then
            break
        fi
        if [ "$choice" -gt 0 ] && [ "$choice" -le "${#tunnels[@]}" ]; then
            IFS='|' read -r name sit_name ipv6_addrs ttl mtu <<< "${tunnels[$((choice-1))]}"
            clear
            echo "Selected Tunnel: $name"
            echo "1. Edit"
            echo "2. Delete"
            echo "0. Back"
            read -p "Choose an option: " action
            case $action in
                1)
                    edit_tunnel "$name" "$sit_name" "$ipv6_addrs" "$ttl" "$mtu"
                    ;;
                2)
                    read -p "Are you sure you want to delete tunnel $name? (y/n): " confirm
                    if [[ "$confirm" == "y" ]]; then
                        delete_tunnel "$name" "$sit_name" || continue
                        echo "Press Enter to continue..."
                        read -r
                    else
                        echo "Deletion cancelled."
                        echo "Press Enter to continue..."
                        read -r
                    fi
                    ;;
                0)
                    continue
                    ;;
                *)
                    handle_error "Invalid option."
                    ;;
            esac
        else
            handle_error "Invalid selection."
        fi
    done
}
edit_tunnel() {
    local name=$1 old_sit_name=$2 old_ipv6_addrs=$3 old_ttl=$4 old_mtu=$5
    local new_sit_name=$old_sit_name new_ipv6_addrs=$old_ipv6_addrs new_ttl=$old_ttl new_mtu=$old_mtu choice
    clear
    echo "Editing Tunnel: $name"
    echo "Current Sit Name: $old_sit_name"
    read -p "Change Sit Name? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        read -p "New Sit Name (e.g., sit5, not sit0): " new_sit_name
        if ! validate_sit_name "$new_sit_name"; then
            handle_error "Invalid or existing sit name."
            return
        fi
    fi
    echo "Current IPv6 Addresses: $old_ipv6_addrs"
    read -p "Change IPv6 Addresses? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        read -p "New IPv6 Addresses (e.g., 2001:db8::1/64,2001:db8::2/64): " new_ipv6_addrs
        for addr in ${new_ipv6_addrs//,/ }; do
            if ! validate_ipv6 "$addr"; then
                handle_error "Invalid IPv6 address: $addr. Ensure it has a valid format (e.g., 2001:db8::1/64)."
                return
            fi
        done
    fi
    echo "Current TTL: $old_ttl"
    read -p "Change TTL? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        read -p "New TTL (1-255): " new_ttl
        if ! validate_ttl "$new_ttl"; then
            handle_error "Invalid TTL value."
            return
        fi
    fi
        echo "Current MTU: $old_mtu"
    read -p "Change MTU? (y/n): " choice
    if [[ "$choice" == "y" ]]; then
        local script_file="/usr/local/bin/ipv6tunnel-$name.sh"
        local local_ip remote_ip
        local_ip=$(grep 'local' "$script_file" | awk '{print $(NF-1)}')
        remote_ip=$(grep 'remote' "$script_file" | awk '{print $NF}')

        echo "Detecting MTU suggestions..."
        local mtu_iface mtu_probe mtu_input
        mtu_iface=$(find_iface_mtu)
        mtu_probe=$(probe_mtu "$local_ip" "$remote_ip")

        echo "Suggested MTUs:"
        echo "  1) $mtu_iface  (based on primary interface MTU - 20)"
        echo "  2) $mtu_probe  (based on probe to $remote_ip)"
        read -p "Choose MTU: [1/2 or enter custom 1280-1500]: " mtu_input

        if [[ "$mtu_input" == "1" ]]; then
            new_mtu="$mtu_iface"
        elif [[ "$mtu_input" == "2" ]]; then
            new_mtu="$mtu_probe"
        elif validate_mtu "$mtu_input"; then
            new_mtu="$mtu_input"
        else
            handle_error "Invalid MTU value."
            return
        fi
    fi
    local script_file="/usr/local/bin/ipv6tunnel-$name.sh"
    if [[ -f "$script_file" ]]; then
        local local_ip remote_ip
        local_ip=$(grep 'local' "$script_file" | awk '{print $(NF-1)}')
        remote_ip=$(grep 'remote' "$script_file" | awk '{print $NF}')
        if sudo systemctl stop "ipv6tunnel-$name.service"; then
            create_systemd_service "$name" "$new_sit_name" "$local_ip" "$remote_ip" "$new_ipv6_addrs" "$new_ttl" "$new_mtu" || return
            echo "Tunnel $name updated successfully."
            echo "Press Enter to return..."
            read -r
        else
            handle_error "Failed to stop service for $name."
        fi
    else
        handle_error "Configuration script not found for $name."
    fi
}
ipv6_generator_menu() {
    if ! ipv6_check_prerequisites; then
        return
    fi
    while true; do
        clear
        display_package_status
        echo "IPv6 Generator Menu:"
        echo "1. Generate on Gateway"
        echo "2. Generate on Guest Server"
        echo "3. View and Edit IPv6"
        echo "4. Back"
        read -r -p "Choose an option: " choice
        case $choice in
            1)
                generate_tunnel "Gateway"
                ;;
            2)
                generate_tunnel "Guest"
                ;;
            3)
                view_edit_tunnels
                ;;
            4)
                return
                ;;
            *)
                handle_error "Invalid option."
                ;;
        esac
    done
}
ensure_zip_tools() {
    if ! command -v zip >/dev/null 2>&1; then
        echo "zip not found — installing..."
        apt install -y zip
    fi

    if ! command -v unzip >/dev/null 2>&1; then
        echo "unzip not found — installing..."
        apt install -y unzip
    fi
}
backup_server() {
    ensure_zip_tools

    local ts=$(date +"%Y%m%d_%H%M%S")
    local backup_file="/root/server-${ts}.zip"

    if [ ! -f /root/reverse-tunnel/rtun-server.yml ]; then
        echo "rtun-server.yml not found!"
        return
    fi

    if [ ! -f /etc/systemd/system/rtun-server.service ]; then
        echo "rtun-server.service not found!"
        return
    fi

    zip -j "$backup_file" \
        /root/reverse-tunnel/rtun-server.yml \
        /etc/systemd/system/rtun-server.service

    echo -e "\e[32mBackup created: $backup_file\e[0m"
}
restore_server() {
    ensure_zip_tools

    read -p "Backup zip file path: " zip_path
    [ ! -f "$zip_path" ] && echo "Backup file not found!" && return

    rm -rf /tmp/server-backup
    mkdir -p /tmp/server-backup
    unzip -o "$zip_path" -d /tmp/server-backup || { echo "Failed to unzip!"; return; }

    cd /root || cd /
    if [ ! -d /root/reverse-tunnel ]; then
        echo "reverse-tunnel missing — cloning..."
        git clone https://github.com/snsinfu/reverse-tunnel /root/reverse-tunnel
    fi

    cd /root/reverse-tunnel || return
    make

    cp /tmp/server-backup/rtun-server.yml /root/reverse-tunnel/ 2>/dev/null
    cp /tmp/server-backup/rtun-server.service /etc/systemd/system/ 2>/dev/null

    systemctl daemon-reload
    systemctl restart rtun-server
    echo -e "\e[32mServer restore completed!\e[0m"
}
backup_client() {
    ensure_zip_tools

    local ts=$(date +"%Y%m%d_%H%M%S")
    local backup_file="/root/client-${ts}.zip"

    if [ ! -f /root/reverse-tunnel/rtun.yml ]; then
        echo "rtun.yml not found!"
        return
    fi

    if [ ! -f /etc/systemd/system/rtun.service ]; then
        echo "rtun.service not found!"
        return
    fi

    zip -j "$backup_file" \
        /root/reverse-tunnel/rtun.yml \
        /etc/systemd/system/rtun.service

    echo -e "\e[32mBackup created: $backup_file\e[0m"
}
restore_client() {
    ensure_zip_tools

    read -p "Backup zip file path: " zip_path
    [ ! -f "$zip_path" ] && echo "Backup file not found!" && return

    rm -rf /tmp/client-backup
    mkdir -p /tmp/client-backup
    unzip -o "$zip_path" -d /tmp/client-backup || { echo "Failed to unzip!"; return; }

    cd /root || cd /
    if [ ! -d /root/reverse-tunnel ]; then
        echo "reverse-tunnel missing — cloning..."
        git clone https://github.com/snsinfu/reverse-tunnel /root/reverse-tunnel
    fi

    cd /root/reverse-tunnel || return
    make

    cp /tmp/client-backup/rtun.yml /root/reverse-tunnel/ 2>/dev/null
    cp /tmp/client-backup/rtun.service /etc/systemd/system/ 2>/dev/null

    systemctl daemon-reload
    systemctl restart rtun
    echo -e "\e[32mClient restore completed!\e[0m"
}
backup_menu() {
    while true; do
        clear

        echo "=== Backup & Restore ==="
        echo "1) tunnel backup"
        echo "2) DB backuper"
        echo "q) back"
        read -p "> " b0

        case $b0 in
            1) tunnel_backup_menu ;;
            2) db_backup_menu ;;
            q) return ;;
            *) echo "invalid" ;;
        esac
    done
}
tunnel_backup_menu() {
    while true; do
        clear

        echo "=== Tunnel Backup ==="
        echo "1) server backup and restore"
        echo "2) client backup and restore"
        echo "q) back"
        read -p "> " b1

        case $b1 in
            1) tunnel_server_menu ;;
            2) tunnel_client_menu ;;
            q) return ;;
            *) echo "invalid" ;;
        esac
    done
}
tunnel_server_menu() {
    echo "1) Backup"
    echo "2) Restore"
    read -p "> " s

    case $s in
        1) backup_server ;;
        2) restore_server ;;
        *) echo "invalid" ;;
    esac
}
tunnel_client_menu() {
    echo "1) Backup"
    echo "2) Restore"
    read -p "> " s

    case $s in
        1) backup_client ;;
        2) restore_client ;;
        *) echo "invalid" ;;
    esac
}
while true; do
    clear

    echo "what do yo do?"
    echo "0) Local IPV6 Creator"
    echo "1) OS and Optimize Setup"
    echo "2) Tunnel Server side tunnel setup"
    echo "3) Client Server side tunnel setup"
    echo "4) Add CronJob Time"
    echo "5) Add New Server/Port To Tunnel Server"
    echo "6) Add Port To Client Server"
    echo "7) Allow Port on Firewall"
    echo "8) SERVER USAGE CHECKERF"
    echo "9) UNISTALL"
	echo "B) backup and restore"
    echo "q) exit"
    read -p "Enter number (0-9,q) " choice

    case $choice in
	    B|b)
        backup_menu
        ;;

        0)
            ipv6_generator_menu
        ;;
        1)
read -p $'\e[37mSSHPORT\e[0m: ' ssh_port
read -p $'\e[37mAllow Port For UFW--> (example 2053,2052,2082)-->\e[0m: ' other_ports
echo -e "\e[1;36mPress Enter To Start\e[0m"
read
sudo sed -i "s/^#Port 22/Port $ssh_port/" /etc/ssh/sshd_config
sudo systemctl restart sshd
sh -c 'apt-get update; apt-get upgrade -y; apt-get dist-upgrade -y; apt-get autoremove -y; apt-get autoclean -y'
sudo apt-get install -y software-properties-common ufw wget curl git socat cron busybox bash-completion locales nano apt-utils make golang make git logrotate
sudo ufw enable
IFS=',' read -r -a ports <<< "$other_ports"
for port in "${ports[@]}"; do
    sudo ufw allow "$port"/tcp
done
sudo ufw allow "$ssh_port"/tcp
for ip in 200.0.0.0/8 102.0.0.0/8 100.64.0.0/10 169.254.0.0/16 \
           198.18.0.0/15 198.51.100.0/24 203.0.113.0/24 \
           224.0.0.0/4 240.0.0.0/4 255.255.255.255/32 \
           192.0.0.0/24 192.0.2.0/24 127.0.0.0/8 \
           127.0.53.53 192.168.0.0/16 172.16.0.0/12 \
           10.0.0.0/8; do
    sudo ufw deny out from any to "$ip"
done
for ip in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 \
           169.254.0.0/16 172.16.0.0/12 \
           192.0.0.0/24 192.0.2.0/24 \
           192.168.0.0/16 198.18.0.0/15 \
           198.51.100.0/24 203.0.113.0/24 \
           224.0.0.0/4 240.0.0.0/4 \
           103.71.29.0/24; do
    sudo iptables -A OUTPUT -p tcp -s 0/0 -d "$ip" -j DROP
done
sudo ufw reload
sudo timedatectl set-timezone Asia/Tehran
sudo systemctl restart systemd-timesyncd
echo 'su root syslog
/var/log/syslog {
    size 1G
    rotate 1
    missingok
    notifempty
    compress
    delaycompress
    postrotate
        /etc/init.d/rsyslog restart
    endscript
}' | sudo tee -a /etc/logrotate.d/syslog
echo 'su root syslog' | sudo tee -a /etc/init.d/rsyslog
echo 'su root syslog' | sudo tee -a /etc/logrotate.conf
sudo logrotate -f /etc/logrotate.d/syslog
sudo logrotate -f /etc/logrotate.d/syslog
clear
sudo swapoff -v /swapfile
sudo rm /swapfile
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

SYSCTL_FILE="/etc/sysctl.conf"

add_sysctl() {
    local line="$1"
    if ! grep -qxF "$line" "$SYSCTL_FILE"; then
        echo "$line" | sudo tee -a "$SYSCTL_FILE" >/dev/null
    fi
}
add_sysctl "vm.swappiness=40"
add_sysctl "net.ipv4.tcp_keepalive_time = 30"
add_sysctl "net.ipv4.tcp_keepalive_intvl = 10"
add_sysctl "net.ipv4.tcp_keepalive_probes = 3"
add_sysctl "net.core.somaxconn = 65535"
add_sysctl "net.ipv4.tcp_max_syn_backlog = 8192"
add_sysctl "net.ipv4.tcp_tw_reuse = 1"
add_sysctl "net.ipv4.ip_local_port_range = 1024 65535"
add_sysctl "fs.file-max = 2097152"
add_sysctl "net.core.netdev_max_backlog = 5000"
add_sysctl "net.core.default_qdisc = fq"
add_sysctl "net.ipv4.tcp_congestion_control = bbr"

LIMITS_FILE="/etc/security/limits.conf"

add_limit() {
    local line="$1"
    if ! grep -qxF "$line" "$LIMITS_FILE"; then
        echo "$line" | sudo tee -a "$LIMITS_FILE" >/dev/null
    fi
}
add_limit "* soft nofile 1048576"
add_limit "* hard nofile 1048576"
add_limit "root soft nofile 1048576"
add_limit "root hard nofile 1048576"

clear
sudo sysctl -p
echo $'\e[33;40mSegaro Script Optimizer Done - REBOOT AND Go To Tunneling\e[0m'
        ;;

        2)
read -p $'\e[1;36mTunnel PORT\e[0m --> ' connect_port
read -p $'\e[1;36minput inbund+panel ports (example: 2052,2053,2082,2083) \e[0m --> ' tunnel_ports
read -p $'\e[1;36minput protocol(tcp or udp)\e[0m --> ' protocol
if [[ "$protocol" == "tcp" || "$protocol" == "udp" ]]; then
    ports_string=""
    IFS=',' read -ra ports <<< "$tunnel_ports"
    for port in "${ports[@]}"; do
        ports_string+="$port/$protocol, "
    done
    ports_string=${ports_string%, }

    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    LIMIT_RAM_KB=$(( TOTAL_RAM_KB * 75 / 100 ))
    LIMIT_RAM_MB=$(( LIMIT_RAM_KB / 1024 ))
    MEMORY_MAX="${LIMIT_RAM_MB}M"

    auth_key=$(openssl rand -hex 32)

    patch_reverse_tunnel_sources
    make

    echo "control_address: 0.0.0.0:$connect_port
agents:
- auth_key: $auth_key
  ports: [$ports_string]" | sudo tee /root/reverse-tunnel/rtun-server.yml

sudo tee /etc/reset.sh >/dev/null << 'EOF'
#!/bin/bash
sudo systemctl restart rtun-server 2>/dev/null || true
sudo journalctl --vacuum-size=1M
EOF
sudo chmod +x /etc/reset.sh


    cat <<EOF | sudo tee /etc/systemd/system/rtun-server.service
[Unit]
Description=rtun server

[Service]
Type=simple
ExecStart=/root/reverse-tunnel/./rtun-server -f /root/reverse-tunnel/rtun-server.yml
Restart=always
RestartSec=3
LimitNOFILE=1048576
LimitNPROC=100000
TimeoutSec=600
WorkingDirectory=/root/reverse-tunnel
Nice=-10
StandardOutput=journal
StandardError=journal
MemoryMax=${MEMORY_MAX}

[Install]
WantedBy=default.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable rtun-server
    sudo systemctl start rtun-server
    sudo systemctl status rtun-server
	echo -e "\e[33;40mSERVER KEY : $auth_key\e[0m"
	echo -e "\e[32;40mTUNNEL Port : $connect_port\e[0m	"
	echo -e "\e[33;40mOPEN PORTS : [$ports_string]\e[0m"
else
    echo "invaild port/protocol"
fi
        ;;

        3)
read -p $'\e[1;36mTunnel PORT\e[0m--> ' connect_port
read -p $'\e[1;36minput inbound+panel ports (example: 2052,2053,2082,2083)\e[0m--> ' tunnel_ports
read -p $'\e[1;36minput protocol(tcp or udp)--> \e[0m ' protocol
read -p $'\e[1;36mSERVER IP\e[0m--> ' myservertip
read -p $'\e[1;36mSERVER KEY\e[0m--> ' myservertkey
clear
if [[ "$protocol" == "tcp" || "$protocol" == "udp" ]]; then
    ports_string=""
    IFS=',' read -ra ports <<< "$tunnel_ports"
    for port in "${ports[@]}"; do
        ports_string+="  - port: $port/$protocol\n    destination: 127.0.0.1:$port\n"
    done
    ports_string=${ports_string%\\n}

    patch_reverse_tunnel_sources
    make
clear
    echo -e "
gateway_url: ws://$myservertip:$connect_port
auth_key: $myservertkey
forwards:
$ports_string" | sudo tee /root/reverse-tunnel/rtun.yml
sudo tee /etc/reset.sh >/dev/null << 'EOF'
#!/bin/bash
sudo systemctl restart rtun 2>/dev/null || true
sudo journalctl --vacuum-size=1M
EOF
sudo chmod +x /etc/reset.sh
clear

    TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    LIMIT_RAM_KB=$(( TOTAL_RAM_KB * 75 / 100 ))
    LIMIT_RAM_MB=$(( LIMIT_RAM_KB / 1024 ))
    MEMORY_MAX="${LIMIT_RAM_MB}M"

    cat <<EOF | sudo tee /etc/systemd/system/rtun.service
[Unit]
Description=rtun

[Service]
Type=simple
ExecStart=/root/reverse-tunnel/./rtun -f /root/reverse-tunnel/rtun.yml
Restart=always
RestartSec=3
LimitNOFILE=1048576
LimitNPROC=100000
TimeoutSec=600
WorkingDirectory=/root/reverse-tunnel
Nice=-10
StandardOutput=journal
StandardError=journal
MemoryMax=${MEMORY_MAX}

[Install]
WantedBy=default.target
EOF

clear
    sudo systemctl daemon-reload
    sudo systemctl enable rtun
    sudo systemctl start rtun
clear
    sudo systemctl status rtun
    echo -e "\e[33;40mSERVER IP : $myservertip\e[0m"
    echo -e "\e[32;45mSERVER KEY : $myservertkey\e[0m"
    echo -e "\e[33;40mTUNNEL Port : $connect_port\e[0m"
    echo -e "\e[32;45mOPEN PORTS : [$ports_string]\e[0m"
else
    echo "invalid port/protocol"
fi
        ;;

        4)
echo -e "\e[33;40mCron Mode:\e[0m"
echo "1) add per clock (specific times like 04:20)"
echo "2) add per time interval (every N minutes/hours)"
read -p $'\e[33;40mSelect option (1 or 2)\e[0m --> ' cron_mode

if [[ "$cron_mode" == "1" ]]; then
    times=()
    while true; do
        read -p $'\e[33;40madd time to cron (Format 04:20)\e[0m --> ' time_input
        if [[ ! "$time_input" =~ ^[01][0-9]:[0-5][0-9]$ && ! "$time_input" =~ ^2[0-3]:[0-5][0-9]$ ]]; then
            echo -e "\e[31;40minvalid time\e[0m"
            continue
        fi
        times+=("$time_input")
        read -p $'\e[33;40miput Y for add new time to cron / S for created cronjob\e[0m --> ' answer
        if [[ "$answer" == "s" || "$answer" == "S" ]]; then
            break 
        fi
    done
    cron_jobs=""
    for time in "${times[@]}"; do
        IFS=: read hour minute <<< "$time"
        cron_jobs+="${minute} ${hour} * * * /bin/bash /etc/reset.sh  > /dev/null 2>&1\n"
    done
    (crontab -l 2>/dev/null; echo -e "$cron_jobs") | crontab -
    echo -e "$cron_jobs"
    echo -e "\e[33;40mTIME Added to cron\e[0m"

elif [[ "$cron_mode" == "2" ]]; then
    echo -e "\e[33;40mInterval Mode:\e[0m"
    echo "1) add per minute"
    echo "2) add per hours"
    read -p $'\e[33;40mSelect option (1 or 2)\e[0m --> ' interval_mode

    if [[ "$interval_mode" == "1" ]]; then
        while true; do
            read -p $'\e[33;40mEnter interval in minutes (1-59)\e[0m --> ' minutes
            if [[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -ge 1 ] && [ "$minutes" -le 59 ]; then
                break
            else
                echo -e "\e[31;40minvalid minutes. please enter 1-59\e[0m"
            fi
        done
        cron_job="*/${minutes} * * * * /bin/bash /etc/reset.sh  > /dev/null 2>&1"
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo -e "$cron_job"
        echo -e "\e[33;40mInterval cron (every ${minutes} minute) added.\e[0m"

    elif [[ "$interval_mode" == "2" ]]; then
        while true; do
            read -p $'\e[33;40mEnter interval in hours (1-23)\e[0m --> ' hours
            if [[ "$hours" =~ ^[0-9]+$ ]] && [ "$hours" -ge 1 ] && [ "$hours" -le 23 ]; then
                break
            else
                echo -e "\e[31;40minvalid hours. please enter 1-23\e[0m"
            fi
        done
        cron_job="* */${hours} * * * /bin/bash /etc/reset.sh  > /dev/null 2>&1"
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo -e "$cron_job"
        echo -e "\e[33;40mInterval cron (every ${hours} hour) added.\e[0m"

    else
        echo -e "\e[31;40minvalid option for interval mode\e[0m"
    fi
else
    echo -e "\e[31;40minvalid option for cron mode\e[0m"
fi
        ;;

    5)
file_path="/root/reverse-tunnel/rtun-server.yml"

if [ ! -f "$file_path" ]; then
    echo -e "\e[31;40mrtun-server.yml not found. Please run tunnel server setup first (option 2).\e[0m"
else
    CONTROL_PORT=$(awk -F: '/^control_address:/ {gsub(/ /,"",$NF); print $NF}' "$file_path")

    mapfile -t USED_PORTS < <(grep -o '[0-9]\+\/[a-z]\+' "$file_path" | cut -d'/' -f1 | sort -u)

    echo -e "\e[33;40mAdd New Server/Port To Tunnel Server\e[0m"
    echo "1) add new server connection"
    echo "2) add new port to server"
    read -p $'\e[33;40mSelect option (1 or 2)\e[0m --> ' sub_choice

    case "$sub_choice" in
        1)
            read -p $'\e[33;40minput inbund+panel ports (example: 2052,2053,2082,2083)\e[0m --> ' tunnel_ports
            read -p $'\e[33;40minput protocol (tcp or udp)\e[0m --> ' protocol

            if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
                echo -e "\e[31;40mInvalid protocol. Please enter tcp or udp.\e[0m"
            else
                IFS=',' read -ra ports <<< "$tunnel_ports"
                ports_string=""
                duplicates=()
                has_valid=0

                for port in "${ports[@]}"; do
                    port_trimmed="${port//[[:space:]]/}"

                    if [[ -z "$port_trimmed" ]]; then
                        continue
                    fi

                    if ! [[ "$port_trimmed" =~ ^[0-9]+$ ]] || [ "$port_trimmed" -lt 1 ] || [ "$port_trimmed" -gt 65535 ]; then
                        echo -e "\e[31;40mInvalid port: $port_trimmed (must be 1-65535)\e[0m"
                        continue
                    fi

                    if port_in_use "$port_trimmed"; then
                        duplicates+=("$port_trimmed")
                        continue
                    fi

                    has_valid=1
                    ports_string+="${port_trimmed}/${protocol}, "
                done

                ports_string=${ports_string%, }

                if [ "$has_valid" -eq 0 ]; then
                    echo -e "\e[31;40mNo new valid ports to add. All provided ports are invalid or already in use (or equal to tunnel control port).\e[0m"
                    if [ "${#duplicates[@]}" -gt 0 ]; then
                        echo -e "\e[33;40mDuplicate/in-use ports:\e[0m ${duplicates[*]}"
                    fi
                else
                    auth_key=$(openssl rand -hex 32)

                    {
                        echo "- auth_key: $auth_key"
                        echo "  ports: [$ports_string]"
                    } >> "$file_path"

                    sudo systemctl restart rtun-server

                    echo -e "\e[32;40mNew server connection added.\e[0m"
                    echo -e "\e[33;40mAUTH KEY : $auth_key\e[0m"
                    echo -e "\e[33;40mPORTS    : [$ports_string]\e[0m"

                    if [ "${#duplicates[@]}" -gt 0 ]; then
                        echo -e "\e[33;40mSkipped duplicate/in-use ports:\e[0m ${duplicates[*]}"
                    fi
                fi
            fi
            ;;

        2)
            mapfile -t auths < <(awk '/^- auth_key:/ {sub("^- auth_key: ", ""); print}' "$file_path")

            if [ "${#auths[@]}" -eq 0 ]; then
                echo -e "\e[31;40mNo server connections (agents) found in rtun-server.yml.\e[0m"
            else
                echo -e "\e[33;40mSelect server connection to add port:\e[0m"
                idx=1
                for key in "${auths[@]}"; do
                    short="${key:0:8}"
                    echo "$idx) server connection $idx (auth_key: ${short}...)"
                    idx=$((idx + 1))
                done

                read -p $'\e[33;40mEnter server connection number\e[0m --> ' sel

                if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "${#auths[@]}" ]; then
                    echo -e "\e[31;40minvalid selection.\e[0m"
                else
                    chosen_key="${auths[$((sel-1))]}"

                    while true; do
                        read -p $'\e[33;40mNEW PORT\e[0m --> ' new_port
                        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
                            echo -e "\e[31;40mInvalid port. Please enter a number between 1 and 65535.\e[0m"
                        else
                            break
                        fi
                    done

                    while true; do
                        read -p $'\e[33;40mProtocol (udp or tcp)\e[0m --> ' protocol
                        if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
                            echo -e "\e[31;40mInvalid protocol. Please enter tcp or udp.\e[0m"
                        else
                            break
                        fi
                    done

                    if port_in_use "$new_port"; then
                        echo -e "\e[31;40mPort $new_port is already in use or equals tunnel control port ($CONTROL_PORT). Not adding.\e[0m"
                    else
                        sed -i "/- auth_key: ${chosen_key//\//\\/}/{n; s/ports: \[\(.*\)\]/ports: [\1, ${new_port}\/${protocol}]/}" "$file_path"

                        sudo systemctl restart rtun-server
                        echo -e "\e[32;40m${new_port}/${protocol} added to server connection (auth_key: ${chosen_key:0:8}...).\e[0m"
                    fi
                fi
            fi
            ;;

        *)
            echo -e "\e[31;40minvalid option.\e[0m"
            ;;
    esac
fi
        ;;


    6)
rtun_client_file="/root/reverse-tunnel/rtun.yml"

if [ ! -f "$rtun_client_file" ]; then
    echo -e "\e[31;40mrtun.yml not found. Please run client tunnel setup first (option 3).\e[0m"
else
    mapfile -t USED_CLIENT_PORTS < <(awk '/^[[:space:]]*- port:/ {gsub("^[[:space:]]*- port: ",""); sub(/\/.*/,""); print}' "$rtun_client_file" | sort -u)

    client_port_in_use() {
        local cp="$1"
        for p in "${USED_CLIENT_PORTS[@]}"; do
            if [ "$cp" = "$p" ]; then
                return 0
            fi
        done
        return 1
    }

    while true; do
        read -p $'\e[33;40mNEW PORT\e[0m --> ' new_port
        read -p $'\e[33;40mProtocol (udp or tcp)\e[0m --> ' protocol

        if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
            echo -e "\e[31;40mInvalid protocol. Please enter '\''tcp'\'' or '\''udp'\''.\e[0m"
            continue 
        fi

        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
            echo -e "\e[31;40mInvalid port. Please enter a number between 1 and 65535.\e[0m"
            continue  
        fi

        if client_port_in_use "$new_port"; then
            echo -e "\e[31;40mPort $new_port is already used in rtun.yml forwards. Choose another port.\e[0m"
            continue
        fi

        new_entry="  - port: ${new_port}/${protocol}\n    destination: 127.0.0.1:${new_port}"
        echo -e "$new_entry" >> "$rtun_client_file"
        sudo systemctl restart rtun

        echo -e "\e[32;40m$new_port/$protocol added successfully.\e[0m"   
        break
    done
fi
        ;;


    7)
if [ "$EUID" -ne 0 ]; then
  echo "RUN by ROOT user"
  continue
fi
while true; do
  read -p $'\e[33;40mNEW PORT(example 2052,2053)\e[0m --> ' ports
  IFS=',' read -r -a port_array <<< "$ports"
  valid_ports=true
  for port in "${port_array[@]}"; do
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
echo $'\e[33;40mPlease enter valid numeric ports.\e[0m --> '
      valid_ports=false
      break
    fi
  done
  if $valid_ports; then
    break
  fi
done
while true; do
  read -p $'\e[33;40mProtocol (udp or tcp)\e[0m --> ' protocol
  if [[ "$protocol" != "tcp" && "$protocol" != "udp" ]]; then
echo $'\e[33;40mInput tcp or udp\e[0m --> '
  else
    break
  fi
done
for port in "${port_array[@]}"; do
  ufw allow "$port/$protocol"
done
sudo ufw reload
clear
echo $'\e[33;40mFIREWALL(UFW) STATUS\e[0m --> '
ufw status
        ;;

    8)
echo -e "\e[33;40mSERVER USAGE CHECKERF\e[0m"

if ! check_prerequisites; then
    echo -e "\e[31;40mPrerequisites failed. Cannot continue SERVER USAGE CHECKERF.\e[0m"
else
    while true; do
        echo "Select an option:"
        echo "1) Install checker"
        echo "2) Run checker"
        echo "3) Uninstall Checker"
        echo "4) View log"
        echo "q) Back to main menu"
        read -r -p "Enter 1, 2, 3, 4, or q: " CHOICE8

        case "$CHOICE8" in
            1)
                install_checker
                ;;
            2)
                run_checker
                ;;
            3)
                uninstall_checker
                ;;
            4)
                view_log
                ;;
            q)
                echo "Back to main menu..."
                break
                ;;
            *)
                echo "Error: Invalid option. Please enter 1, 2, 3, 4, or q."
                ;;
        esac
        echo
    done
fi
        ;;

        9)
remove_service() {
    local service_name=$1
    if systemctl is-active --quiet "$service_name"; then
        echo "unistall $service_name..."
        systemctl stop "$service_name"
        systemctl disable "$service_name"
    fi
    echo "unistall $service_name..."
    systemctl reset-failed "$service_name" 
    rm -f "/etc/systemd/system/$service_name.service"
    systemctl daemon-reload
}
clear
remove_service "rtun"
remove_service "rtun-server"
if [ -f "/root/reverse-tunnel/rtun.yml" ]; then
    echo "delete /root/reverse-tunnel/rtun.yml..."
    rm -f "/root/reverse-tunnel/rtun.yml"
fi
if [ -f "/root/reverse-tunnel/rtun-server.yml" ]; then
    echo "delete /root/reverse-tunnel/rtun-server.yml..."
    rm -f "/root/reverse-tunnel/rtun-server.yml"
fi
if [ -d "/root/reverse-tunnel/" ]; then
    echo "delete /root/reverse-tunnel/..."
    cd /root 2>/dev/null || cd /
    rm -rf "/root/reverse-tunnel/"
fi
systemctl daemon-reload
echo -e "\e[32;40mTunnel Service Unistall\e[0m"
        ;;

        q)
echo "exit"
break
        ;;

        *)
echo "invaild parametrs"
        ;;
    esac

    echo
    read -p $'\e[36mPress Enter to return to main menu...\e[0m' _
done
