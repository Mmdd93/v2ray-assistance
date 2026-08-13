#!/usr/bin/env bash
set -e

INSTALL_DIR="/opt"
if [ -z "$APP_NAME" ]; then
    APP_NAME="rebecca"
fi
ensure_valid_app_name() {
    local candidate="${APP_NAME:-rebecca}"
    if ! [[ "$candidate" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        candidate="rebecca"
        echo "Invalid app name detected. Falling back to default: $candidate"
    fi
    APP_NAME="$candidate"
}
ensure_valid_app_name
APP_DIR="$INSTALL_DIR/$APP_NAME"
DATA_DIR="/var/lib/$APP_NAME"
ENV_FILE="$APP_DIR/.env"
LAST_XRAY_CORES=10
CERTS_BASE="/var/lib/$APP_NAME/certs"
REBECCA_REPO="${REBECCA_REPO:-rebeccapanel/Rebecca}"
REBECCA_REF="${REBECCA_REF:-dev}"
REBECCA_RAW_BASE="${REBECCA_RAW_BASE:-https://raw.githubusercontent.com/${REBECCA_REPO}/${REBECCA_REF}}"
REBECCA_SCRIPT_BASE_URL_EXPLICIT=0
if [ -n "${REBECCA_SCRIPT_BASE_URL+x}" ]; then
    REBECCA_SCRIPT_BASE_URL_EXPLICIT=1
fi
REBECCA_SCRIPT_BASE_URL="${REBECCA_SCRIPT_BASE_URL:-${REBECCA_RAW_BASE}/scripts/rebecca}"
REBECCA_RELEASE_REPO="${REBECCA_RELEASE_REPO:-rebeccapanel/Rebecca}"
REBECCA_BINARY_DEV_BRANCH="${REBECCA_BINARY_DEV_BRANCH:-dev}"
REBECCA_BINARY_WORKFLOW_NAME="${REBECCA_BINARY_WORKFLOW_NAME:-binary-build}"
REBECCA_BINARY_DEV_MANIFEST_BRANCH="${REBECCA_BINARY_DEV_MANIFEST_BRANCH:-dev-build-manifest}"
REBECCA_BINARY_DEV_MANIFEST_PATH="${REBECCA_BINARY_DEV_MANIFEST_PATH:-dev-builds.json}"
REBECCA_BINARY_DEV_MANIFEST_URL="${REBECCA_BINARY_DEV_MANIFEST_URL:-}"
REBECCA_BINARY_DEV_RELEASE_TAG="${REBECCA_BINARY_DEV_RELEASE_TAG:-dev-builds}"
INSTALL_MODE_FILE="$APP_DIR/.install-mode"
CHANNEL_FILE="$APP_DIR/.channel"
BINARY_BIN_DIR="$APP_DIR/bin"
BINARY_SERVER="$BINARY_BIN_DIR/rebecca-server"
BINARY_CLI="$BINARY_BIN_DIR/rebecca-cli"
BINARY_CLI_LAUNCHER="/usr/local/bin/rebecca-cli"
BINARY_METADATA_FILE="$APP_DIR/.binary-release.json"
BINARY_ARTIFACT_PREFIX="${BINARY_ARTIFACT_PREFIX:-rebecca-binaries}"
BINARY_SERVICE_UNIT="/etc/systemd/system/$APP_NAME.service"
CERTBOT_VENV_DIR="$APP_DIR/certbot-venv"
CERTBOT_BIN=""
PARSED_DOMAINS=()
REBECCA_SCRIPT_FLAVOR="binary"
REBECCA_SCRIPT_SOURCE_FILE="${REBECCA_SCRIPT_SOURCE_FILE:-rebecca-binary.sh}"
REBECCA_SCRIPT_INSTALL_PATH="${REBECCA_SCRIPT_INSTALL_PATH:-/usr/local/bin/rebecca}"

colorized_echo() {
    local color=$1
    local text=$2
    
    case $color in
        "red")
        printf "\e[91m${text}\e[0m\n";;
        "green")
        printf "\e[92m${text}\e[0m\n";;
        "yellow")
        printf "\e[93m${text}\e[0m\n";;
        "blue")
        printf "\e[94m${text}\e[0m\n";;
        "magenta")
        printf "\e[95m${text}\e[0m\n";;
        "cyan")
        printf "\e[96m${text}\e[0m\n";;
        *)
            echo "${text}"
        ;;
    esac
}

ui_is_tty() {
    [ -t 1 ] && [ -z "${NO_COLOR:-}" ]
}

ui_supports_cursor_motion() {
    ui_is_tty && [ "${TERM:-dumb}" != "dumb" ]
}

ui_terminal_columns() {
    local columns="${COLUMNS:-}"
    if ! [[ "$columns" =~ ^[0-9]+$ ]] || [ "$columns" -lt 20 ]; then
        columns=""
        if command -v tput >/dev/null 2>&1; then
            columns=$(tput cols 2>/dev/null || true)
        fi
    fi
    if ! [[ "$columns" =~ ^[0-9]+$ ]] || [ "$columns" -lt 20 ]; then
        columns=80
    fi
    printf "%s" "$columns"
}

ui_color() {
    local code="$1"
    shift || true
    if ui_is_tty; then
        printf "\033[%sm%s\033[0m" "$code" "$*"
    else
        printf "%s" "$*"
    fi
}

ui_line() {
    ui_color "38;5;39" "------------------------------------------------------------"
    printf "\n"
}

ui_header() {
    local title="$1"
    local subtitle="${2:-}"
    printf "\n"
    ui_color "38;5;45;1" "?----------------------------------------------------------?"
    printf "\n  "
    ui_color "38;5;231;1" "$title"
    printf "\n"
    if [ -n "$subtitle" ]; then
        printf "  "
        ui_color "38;5;117" "$subtitle"
        printf "\n"
    fi
    ui_color "38;5;45;1" "?----------------------------------------------------------?"
    printf "\n"
}

ui_section() {
    printf "\n"
    ui_color "38;5;45;1" "? $1"
    printf "\n"
    ui_line
}

ui_status_row() {
    local label="$1"
    local value="$2"
    printf "  "
    ui_color "38;5;245" "$(printf '%-14s' "$label")"
    ui_color "38;5;231;1" "$value"
    printf "\n"
}

ui_menu_item() {
    local number="$1"
    local command="$2"
    local description="$3"
    local selected="${4:-0}"
    local columns command_width=20 description_width command_label description_text
    columns=$(ui_terminal_columns)
    if [ "$columns" -lt 30 ]; then
        command_width=$((columns - 10))
    fi
    [ "$command_width" -lt 1 ] && command_width=1
    description_width=$((columns - 10 - command_width))
    printf -v command_label "%-${command_width}.${command_width}s" "$command"
    if [ "$description_width" -gt 0 ]; then
        description_text="${description:0:$description_width}"
    else
        description_text=""
    fi
    printf "  "
    if [ "$selected" = "1" ]; then
        ui_color "38;5;16;48;5;45;1" " > "
    else
        printf "   "
    fi
    ui_color "38;5;45;1" "$(printf '%2s' "$number")"
    printf "  "
    if [ "$selected" = "1" ]; then
        ui_color "38;5;231;1" "$command_label"
        ui_color "38;5;231" "$description_text"
    else
        ui_color "38;5;231;1" "$command_label"
        ui_color "38;5;245" "$description_text"
    fi
    printf "\n"
}

ui_menu_category() {
    printf "\n"
    ui_color "38;5;117;1" "  $1"
    printf "\n"
}

ui_clear() {
    if ui_is_tty; then
        printf "\033[H\033[2J"
    fi
}

ui_read_menu_choice() {
    local selected="$1"
    local total="$2"
    local key rest digits

    IFS= read -rsn1 key || return 1
    case "$key" in
        "")
            echo "enter:$selected"
            return
        ;;
        $'\033')
            rest=""
            while [ "${#rest}" -lt 8 ] && IFS= read -rsn1 -t 0.05 key; do
                rest="${rest}${key}"
                case "$key" in
                    [A-Za-z~]) break ;;
                esac
            done
            case "$rest" in
                *A)
                    selected=$((selected - 1))
                    [ "$selected" -lt 1 ] && selected="$total"
                    echo "move:$selected"
                    return
                ;;
                *B)
                    selected=$((selected + 1))
                    [ "$selected" -gt "$total" ] && selected=1
                    echo "move:$selected"
                    return
                ;;
            esac
            echo "move:$selected"
            return
        ;;
        [0-9])
            digits="$key"
            while IFS= read -rsn1 -t 0.35 rest; do
                case "$rest" in
                    [0-9]) digits="${digits}${rest}" ;;
                    "") break ;;
                    *) break ;;
                esac
            done
            echo "value:$digits"
            return
        ;;
        q|Q)
            echo "quit:"
            return
        ;;
        *)
            IFS= read -r rest || true
            echo "value:${key}${rest}"
            return
        ;;
    esac
}

ui_read_yes_no() {
    local prompt="$1"
    local default_value="${2:-n}"
    local answer suffix
    if [ "$default_value" = "y" ]; then
        suffix="Y/n"
    else
        suffix="y/N"
    fi
    while true; do
        printf "%s [%s]: " "$prompt" "$suffix"
        IFS= read -r answer
        answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
        if [ -z "$answer" ]; then
            answer="$default_value"
        fi
        case "$answer" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) colorized_echo yellow "Please answer y or n." ;;
        esac
    done
}

ui_spinner_run() {
    local message="$1"
    shift
    if ! ui_is_tty; then
        "$@"
        return $?
    fi

    local log_file
    log_file=$(mktemp)
    "$@" >"$log_file" 2>&1 &
    local pid=$!
    local frames=("?" "?" "?" "?" "?" "?" "?" "?" "?" "?")
    local i=0
    while kill -0 "$pid" >/dev/null 2>&1; do
        printf "\r"
        ui_color "38;5;45;1" "${frames[$((i % ${#frames[@]}))]}"
        printf " %s" "$message"
        sleep 0.08
        i=$((i + 1))
    done

    local status=0
    wait "$pid" || status=$?
    printf "\r\033[K"
    if [ "$status" -eq 0 ]; then
        ui_color "38;5;82;1" "?"
        printf " %s\n" "$message"
        rm -f "$log_file"
        return 0
    fi

    ui_color "38;5;196;1" "?"
    printf " %s\n" "$message"
    tail -n 80 "$log_file" >&2 || true
    rm -f "$log_file"
    return "$status"
}

format_rebecca_journal_logs() {
    while IFS= read -r line; do
        local log_time=""
        local message="$line"
        if [[ "$line" =~ ^[0-9-]+[[:space:]T]([0-9]{2}:[0-9]{2}:[0-9]{2})(\.[0-9]+)?([+-][0-9:]+|Z)?[[:space:]][^[:space:]]+[[:space:]][^:]+:[[:space:]](.*)$ ]]; then
            log_time="${BASH_REMATCH[1]}"
            message="${BASH_REMATCH[4]}"
        elif [[ "$line" =~ ^[A-Za-z]{3}[[:space:]][[:space:][:digit:]][[:digit:]][[:space:]]([0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]][^[:space:]]+[[:space:]][^:]+:[[:space:]](.*)$ ]]; then
            log_time="${BASH_REMATCH[1]}"
            message="${BASH_REMATCH[2]}"
        elif [[ "$line" =~ ^([0-9]{2}:[0-9]{2}:[0-9]{2})[[:space:]][^[:space:]]+[[:space:]][^:]+:[[:space:]](.*)$ ]]; then
            log_time="${BASH_REMATCH[1]}"
            message="${BASH_REMATCH[2]}"
        fi
        if [[ "$message" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]](.*)$ ]]; then
            message="${BASH_REMATCH[1]}"
        fi
        if [ -z "$log_time" ]; then
            printf "%s\n" "$message"
            continue
        fi
        ui_color "38;5;208;1" "Rebecca"
        printf "-"
        ui_color "38;5;245" "$log_time"
        printf ": "
        if [[ "$message" =~ ^\[([^]]+)\][[:space:]](DEBUG|INFO|WARN|ERROR)[[:space:]](.*)$ ]]; then
            local component="${BASH_REMATCH[1]}"
            local level="${BASH_REMATCH[2]}"
            local text="${BASH_REMATCH[3]}"
            local component_color="38;5;45;1"
            local level_color="38;5;250"
            case "$component" in
                Admin) component_color="38;5;141;1" ;;
                Database) component_color="38;5;220;1" ;;
                Node) component_color="38;5;45;1" ;;
                Runtime) component_color="38;5;82;1" ;;
                Telegram) component_color="38;5;39;1" ;;
                User) component_color="38;5;213;1" ;;
                Webhook) component_color="38;5;214;1" ;;
            esac
            case "$level" in
                DEBUG) level_color="38;5;245" ;;
                INFO) level_color="38;5;82" ;;
                WARN) level_color="38;5;220;1" ;;
                ERROR) level_color="38;5;196;1" ;;
            esac
            ui_color "$component_color" "$component"
            printf " "
            ui_color "$level_color" "$level"
            printf " : %s\n" "$text"
        else
            printf "%s\n" "$message"
        fi
    done
}

journal_output_format() {
    if journalctl -o short-iso --no-pager -n 0 >/dev/null 2>&1; then
        echo "short-iso"
    else
        echo "short"
    fi
}

humanize_seconds() {
    local seconds="${1:-0}"
    local days hours minutes
    if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
        echo "-"
        return
    fi
    days=$((seconds / 86400))
    hours=$(((seconds % 86400) / 3600))
    minutes=$(((seconds % 3600) / 60))
    seconds=$((seconds % 60))
    if [ "$days" -gt 0 ]; then
        printf "%sd %sh %sm\n" "$days" "$hours" "$minutes"
    elif [ "$hours" -gt 0 ]; then
        printf "%sh %sm\n" "$hours" "$minutes"
    elif [ "$minutes" -gt 0 ]; then
        printf "%sm %ss\n" "$minutes" "$seconds"
    else
        printf "%ss\n" "$seconds"
    fi
}

get_current_rebecca_version() {
    local version=""
    if [ -f "$CHANNEL_FILE" ]; then
        version=$(tr -d '[:space:]' < "$CHANNEL_FILE")
    fi
    if [ -z "$version" ] && [ -f "$BINARY_METADATA_FILE" ]; then
        version=$(sed -nE 's/.*"tag"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$BINARY_METADATA_FILE" | head -n 1)
    fi
    printf '%s\n' "${version:-dev}"
}

print_menu_status_summary() {
    local service_status="stopped"
    local version uptime
    if systemctl is-active --quiet "$APP_NAME.service"; then
        service_status="running"
    fi
    version=$(get_current_rebecca_version)
    # Uptime not easily available in binary mode without pid; skip or use systemd
    ui_status_row "Version" "${version}"
    ui_status_row "Service" "${service_status}"
    ui_status_row "Mode" "binary"
}

set_rebecca_source_ref() {
    local ref="${1:-dev}"
    REBECCA_REF="$ref"
    REBECCA_RAW_BASE="https://raw.githubusercontent.com/${REBECCA_REPO}/${REBECCA_REF}"
    if [ "${REBECCA_SCRIPT_BASE_URL_EXPLICIT:-0}" != "1" ]; then
        REBECCA_SCRIPT_BASE_URL="${REBECCA_RAW_BASE}/scripts/rebecca"
    fi
}

check_running_as_root() {
    if [ "$(id -u)" != "0" ]; then
        colorized_echo red "This command must be run as root."
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/lsb-release ]; then
        OS=$(lsb_release -si)
    elif [ -f /etc/os-release ]; then
        OS=$(awk -F= '/^NAME/{print $2}' /etc/os-release | tr -d '"')
    elif [ -f /etc/redhat-release ]; then
        OS=$(cat /etc/redhat-release | awk '{print $1}')
    elif [ -f /etc/arch-release ]; then
        OS="Arch"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

remove_broken_xanmod_apt_sources() {
    local matches
    matches=$(grep -RIlE 'deb\.xanmod\.org|xanmod\.org' /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null || true)
    if [ -z "$matches" ]; then
        return 1
    fi
    colorized_echo yellow "Removing broken XanMod apt source entries"
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        case "$file" in
            /etc/apt/sources.list)
                sed -i.bak '/deb\.xanmod\.org/d;/xanmod\.org/d' "$file"
            ;;
            /etc/apt/sources.list.d/*)
                rm -f "$file"
            ;;
        esac
    done <<< "$matches"
    return 0
}

apt_update_with_repo_repair() {
    local log_file
    log_file=$(mktemp)
    if DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a "$PKG_MANAGER" "$@" update -qq >"$log_file" 2>&1; then
        rm -f "$log_file"
        return 0
    fi
    cat "$log_file" >&2
    if grep -qiE 'deb\.xanmod\.org|xanmod.*release file|does not have a release file' "$log_file" && remove_broken_xanmod_apt_sources; then
        rm -f "$log_file"
        DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a "$PKG_MANAGER" "$@" update -qq
        return
    fi
    rm -f "$log_file"
    return 1
}

detect_and_update_package_manager() {
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PKG_MANAGER="apt-get"
        ui_spinner_run "Updating package index" apt_update_with_repo_repair -o Acquire::AllowReleaseInfoChange=true -o Acquire::AllowReleaseInfoChange::Label=true
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        ui_spinner_run "Updating package index" "$PKG_MANAGER" update -y -q
        ui_spinner_run "Installing EPEL repository" "$PKG_MANAGER" install -y -q epel-release
    elif [ "$OS" == "Fedora"* ]; then
        PKG_MANAGER="dnf"
        ui_spinner_run "Updating package index" "$PKG_MANAGER" update -q -y
    elif [ "$OS" == "Arch" ]; then
        PKG_MANAGER="pacman"
        ui_spinner_run "Updating package index" "$PKG_MANAGER" -Sy --noconfirm --quiet
    elif [[ "$OS" == "openSUSE"* ]]; then
        PKG_MANAGER="zypper"
        ui_spinner_run "Updating package index" "$PKG_MANAGER" refresh --quiet
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_package_impl() {
    local PACKAGE="$1"
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a $PKG_MANAGER -y -qq install "$PACKAGE" \
            -o Dpkg::Options::="--force-confdef" \
            -o Dpkg::Options::="--force-confold"
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        $PKG_MANAGER install -y -q "$PACKAGE"
    elif [ "$OS" == "Fedora"* ]; then
        $PKG_MANAGER install -y -q "$PACKAGE"
    elif [ "$OS" == "Arch" ]; then
        $PKG_MANAGER -S --noconfirm --quiet "$PACKAGE"
    elif [[ "$OS" == "openSUSE"* ]]; then
        $PKG_MANAGER --quiet install -y "$PACKAGE"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_package () {
    if [ -z "$PKG_MANAGER" ]; then
        detect_and_update_package_manager
    fi

    local PACKAGE="$1"
    ui_spinner_run "Installing $PACKAGE" install_package_impl "$PACKAGE"
}

ensure_python3_venv() {
    detect_os
    if [[ "$OS" == "Ubuntu"* ]] || [[ "$OS" == "Debian"* ]]; then
        PY_VER=$(python3 -c 'import sys; print(f"%s.%s" % (sys.version_info.major, sys.version_info.minor))' 2>/dev/null || echo "3")
        install_package "python${PY_VER}-venv"
    else
        install_package python3-venv
    fi
}

normalize_install_mode() {
    echo "binary"
}

get_install_mode() {
    echo "binary"
}

is_binary_install() {
    return 0
}

set_env_value() {
    local key="$1"
    local value="$2"
    value=$(echo "$value" | sed 's/^"//;s/"$//')
    mkdir -p "$(dirname "$ENV_FILE")"
    touch "$ENV_FILE"
    if grep -qE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" 2>/dev/null; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=.*|${key} = \"${value}\"|" "$ENV_FILE"
    else
        echo "${key} = \"${value}\"" >> "$ENV_FILE"
    fi
}

get_env_value() {
    local key="$1"
    if [ ! -f "$ENV_FILE" ]; then
        return
    fi
    grep -E "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" 2>/dev/null \
        | tail -n 1 \
        | sed -E 's/^[^=]+=//; s/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//'
}

escape_dotenv_double_quoted() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//\$/\\\$}"
    printf '%s' "$value"
}

upsert_env_assignment() {
    local key="$1"
    local value="$2"
    local escaped_value
    local tmp_env

    escaped_value=$(escape_dotenv_double_quoted "$value")
    mkdir -p "$(dirname "$ENV_FILE")"
    touch "$ENV_FILE"

    tmp_env=$(mktemp)
    grep -vE "^[[:space:]]*#?[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" > "$tmp_env" || true
    mv "$tmp_env" "$ENV_FILE"

    echo "${key}=\"${escaped_value}\"" >> "$ENV_FILE"
}

urlencode_value() {
    local value="$1"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$value"
        return
    fi

    if command -v python >/dev/null 2>&1; then
        python -c "import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1], safe=''))" "$value"
        return
    fi

    if command -v jq >/dev/null 2>&1; then
        printf '%s' "$value" | jq -sRr @uri
        return
    fi

    printf '%s' "$value"
}

normalize_url_path() {
    local value="${1:-}"
    local default_value="${2:-dashboard}"
    value=$(echo "$value" | xargs)
    value="${value#/}"
    value="${value%/}"
    if [ -z "$value" ]; then
        value="$default_value"
    fi
    if ! [[ "$value" =~ ^[A-Za-z0-9._~/-]+$ ]]; then
        return 1
    fi
    printf "/%s/" "$value"
}

validate_tcp_port() {
    local value="$1"
    [[ "$value" =~ ^[0-9]+$ ]] && [ "$value" -ge 1 ] && [ "$value" -le 65535 ]
}

is_tcp_port_listening() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        ss -tuln 2>/dev/null | awk '{print $5}' | grep -Eq "(:|\\])${port}$"
        return $?
    fi
    if command -v lsof >/dev/null 2>&1; then
        lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
        return $?
    fi
    if command -v netstat >/dev/null 2>&1; then
        netstat -tuln 2>/dev/null | awk '{print $4}' | grep -Eq "(:|\\])${port}$"
        return $?
    fi
    return 1
}

prompt_tcp_port() {
    local label="$1"
    local default_value="$2"
    local value
    while true; do
        printf "%s [%s]: " "$label" "$default_value" >&2
        IFS= read -r value
        value="${value:-$default_value}"
        if validate_tcp_port "$value"; then
            if is_tcp_port_listening "$value"; then
                colorized_echo red "Port $value is already in use. Please choose another port." >&2
                continue
            fi
            printf "%s" "$value"
            return 0
        fi
        colorized_echo red "Port must be a number between 1 and 65535." >&2
    done
}

prompt_url_path() {
    local label="$1"
    local default_value="$2"
    local value normalized
    while true; do
        printf "%s [%s]: " "$label" "$default_value" >&2
        IFS= read -r value
        value="${value:-$default_value}"
        if normalized=$(normalize_url_path "$value" "${default_value#/}"); then
            printf "%s" "$normalized"
            return 0
        fi
        colorized_echo red "Path can contain only letters, numbers, dots, underscores, dashes, slashes, and tildes." >&2
    done
}

print_database_menu() {
    local selected="$1"
    local names=("MySQL" "SQLite" "MariaDB")
    local descriptions=("(recommended)" "" "")
    local idx
    ui_header "Rebecca Database" "Choose storage backend for binary install"
    for idx in 1 2 3; do
        printf "  "
        if [ "$idx" -eq "$selected" ]; then
            ui_color "38;5;16;48;5;45;1" " ? "
        else
            printf "   "
        fi
        ui_color "38;5;45;1" "$(printf '%2s' "$idx")"
        printf "  "
        if [ "$idx" -eq 1 ]; then
            ui_color "38;5;82;1" "$(printf '%-10s' "${names[$((idx - 1))]}")"
        else
            ui_color "38;5;231;1" "$(printf '%-10s' "${names[$((idx - 1))]}")"
        fi
        ui_color "38;5;245" "${descriptions[$((idx - 1))]}"
        printf "\n"
    done
    printf "\n"
    ui_color "38;5;245" "Use ?/? and Enter, type 1-3, or press Enter for MySQL."
    printf "\n"
}

select_database_type_interactive() {
    local selected=1
    local action kind value
    if ! ui_is_tty; then
        echo "mysql"
        return
    fi
    while true; do
        ui_clear >&2
        print_database_menu "$selected" >&2
        printf "Select database: " >&2
        action=$(ui_read_menu_choice "$selected" 3) || {
            echo "mysql"
            return
        }
        kind="${action%%:*}"
        value="${action#*:}"
        case "$kind" in
            move)
                selected="$value"
            ;;
            enter)
                selected="$value"
                break
            ;;
            value)
                if [[ "$value" =~ ^[1-3]$ ]]; then
                    selected="$value"
                    break
                fi
            ;;
            quit)
                echo "mysql"
                return
            ;;
        esac
    done
    case "$selected" in
        2) echo "sqlite" ;;
        3) echo "mariadb" ;;
        *) echo "mysql" ;;
    esac
}

prompt_dashboard_bind_settings() {
    local port
    if [ ! -t 0 ]; then
        upsert_env_assignment "UVICORN_PORT" "8000"
        return
    fi
    ui_section "Dashboard"
    port=$(prompt_tcp_port "Dashboard port" "8000")
    echo
    upsert_env_assignment "UVICORN_PORT" "$port"
}

mysql_password_is_strong() {
    local password="$1"
    [ "${#password}" -ge 12 ] || return 1
    [[ "$password" =~ [A-Z] ]] || return 1
    [[ "$password" =~ [a-z] ]] || return 1
    [[ "$password" =~ [0-9] ]] || return 1
    [[ "$password" =~ [^A-Za-z0-9] ]] || return 1
    [[ "$password" != *" "* ]] || return 1
    return 0
}

generate_secure_mysql_password() {
    local candidate
    while true; do
        candidate="$(tr -dc 'A-Za-z0-9@#%_=+.-' </dev/urandom | head -c 28)"
        if mysql_password_is_strong "$candidate"; then
            printf "%s" "$candidate"
            return
        fi
    done
}

read_secret() {
    local prompt="$1"
    local value
    if [ -t 0 ]; then
        IFS= read -rsp "$prompt" value
        printf "\n" >&2
    else
        IFS= read -r value
    fi
    printf "%s" "$value"
}

prompt_confirmed_secret() {
    local label="$1"
    local first second
    while true; do
        first=$(read_secret "$label: ")
        [ -n "$first" ] || {
            colorized_echo red "Password cannot be empty." >&2
            continue
        }
        second=$(read_secret "Confirm $label: ")
        if [ "$first" = "$second" ]; then
            printf "%s" "$first"
            return
        fi
        colorized_echo red "Passwords do not match." >&2
    done
}

prompt_initial_admin() {
    INITIAL_ADMIN_CREATE=0
    INITIAL_ADMIN_USERNAME=""
    INITIAL_ADMIN_PASSWORD=""
    [ -t 0 ] || return
    ui_section "Initial admin"
    if ! ui_read_yes_no "Create a full-access admin now?" "y"; then
        return
    fi
    while true; do
        IFS= read -r -p "Admin username [admin]: " INITIAL_ADMIN_USERNAME
        INITIAL_ADMIN_USERNAME="${INITIAL_ADMIN_USERNAME:-admin}"
        if [[ "$INITIAL_ADMIN_USERNAME" =~ ^[A-Za-z0-9_.@-]{3,64}$ ]]; then
            break
        fi
        colorized_echo red "Username must be 3-64 chars and may contain letters, numbers, dot, underscore, dash, and @."
    done
    INITIAL_ADMIN_PASSWORD=$(prompt_confirmed_secret "Admin password")
    INITIAL_ADMIN_CREATE=1
}

create_initial_admin_if_requested() {
    if [ "${INITIAL_ADMIN_CREATE:-0}" != "1" ]; then
        return
    fi
    ui_spinner_run "Running database migrations" rebecca_cli migrate up
    ui_spinner_run "Creating full-access admin ${INITIAL_ADMIN_USERNAME}" rebecca_cli admin create "$INITIAL_ADMIN_USERNAME" --role full_access --password "$INITIAL_ADMIN_PASSWORD"
}

prompt_phpmyadmin_settings() {
    PHPMYADMIN_PATH=$(prompt_url_path "phpMyAdmin path" "phpmyadmin")
    echo
}

find_php_fpm_sock() {
    local sock
    sock=$(find /run/php -maxdepth 1 -type s -name 'php*-fpm.sock' 2>/dev/null | sort -V | tail -n 1)
    [ -n "$sock" ] && printf "%s" "$sock"
}

install_phpmyadmin_blueberry_theme() {
    local theme_dir="/usr/share/phpmyadmin/themes"
    local theme_url="https://files.phpmyadmin.net/themes/blueberry/1.1.0/blueberry-1.1.0.zip"
    local temp_zip

    if [ ! -d "$theme_dir" ]; then
        return 0
    fi
    if [ -d "$theme_dir/blueberry" ]; then
        return 0
    fi
    install_package unzip
    temp_zip=$(mktemp)
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$theme_url" -o "$temp_zip" || {
            rm -f "$temp_zip"
            colorized_echo yellow "Could not download phpMyAdmin blueberry theme."
            return 0
        }
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$theme_url" -O "$temp_zip" || {
            rm -f "$temp_zip"
            colorized_echo yellow "Could not download phpMyAdmin blueberry theme."
            return 0
        }
    else
        rm -f "$temp_zip"
        colorized_echo yellow "curl or wget is required to download phpMyAdmin blueberry theme."
        return 0
    fi
    unzip -qo "$temp_zip" -d "$theme_dir" >/dev/null 2>&1 || colorized_echo yellow "Could not extract phpMyAdmin blueberry theme."
    rm -f "$temp_zip"
}

configure_phpmyadmin_upload_limits() {
    local ini_content
    ini_content="upload_max_filesize=1024M
post_max_size=1024M
memory_limit=4096M
max_execution_time=0
max_input_time=0"
    local wrote=0
    local dir
    for dir in /etc/php/*/fpm/conf.d /etc/php/*/cli/conf.d; do
        [ -d "$dir" ] || continue
        printf "%s\n" "$ini_content" > "$dir/99-rebecca-phpmyadmin-upload.ini" || true
        wrote=1
    done
    if [ "$wrote" = "1" ]; then
        systemctl reload php*-fpm >/dev/null 2>&1 || systemctl restart php*-fpm >/dev/null 2>&1 || true
    fi
}

phpmyadmin_nginx_config_path() {
    printf "/etc/nginx/sites-available/%s-phpmyadmin" "$APP_NAME"
}

enable_host_phpmyadmin() {
    local database_type
    local path="${1:-}"
    local normalized_path
    local fpm_sock

    database_type=$(get_configured_database_type)
    if [ "$database_type" = "sqlite" ]; then
        colorized_echo red "phpMyAdmin is supported only with MySQL or MariaDB. Current database is SQLite."
        return 1
    fi

    detect_os
    for package in php-fpm php-mysql phpmyadmin; do
        install_package "$package"
    done
    install_phpmyadmin_blueberry_theme
    configure_phpmyadmin_upload_limits
    systemctl enable --now php*-fpm >/dev/null 2>&1 || true

    path="${path:-${PHPMYADMIN_PATH:-phpmyadmin}}"
    normalized_path=$(normalize_url_path "$path" "phpmyadmin") || {
        colorized_echo red "Invalid phpMyAdmin path."
        return 1
    }
    path="$normalized_path"
    path="${path%/}"
    fpm_sock=$(find_php_fpm_sock)
    if [ -z "$fpm_sock" ]; then
        colorized_echo red "Could not find php-fpm socket under /run/php."
        return 1
    fi

    rm -f "/etc/nginx/sites-enabled/${APP_NAME}-phpmyadmin" "$(phpmyadmin_nginx_config_path)"
    if command -v nginx >/dev/null 2>&1; then
        nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
    fi
    colorized_echo green "phpMyAdmin is installed and will be served through Rebecca using local php-fpm."
}

disable_host_phpmyadmin() {
    rm -f "/etc/nginx/sites-enabled/${APP_NAME}-phpmyadmin" "$(phpmyadmin_nginx_config_path)"
    if command -v nginx >/dev/null 2>&1; then
        nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
    fi
    colorized_echo green "phpMyAdmin has been disabled."
}

enable_phpmyadmin() {
    check_running_as_root
    local cli_path=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --port)
                shift 2
                ;;
            --path)
                cli_path="${2:-}"
                shift 2
                ;;
            --yes|-y)
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    if ! is_rebecca_installed; then
        colorized_echo red "Rebecca is not installed. Please install Rebecca first."
        exit 1
    fi

    if [ "$(get_configured_database_type)" = "sqlite" ]; then
        colorized_echo red "phpMyAdmin is not supported for SQLite installations."
        return 0
    fi

    if [ -n "$cli_path" ]; then
        PHPMYADMIN_PATH="$cli_path"
    else
        prompt_phpmyadmin_settings
    fi
    enable_host_phpmyadmin "$PHPMYADMIN_PATH"
}

disable_phpmyadmin() {
    check_running_as_root
    disable_host_phpmyadmin
}

sync_ssl_env_paths() {
    local cert_dir="$1"
    local ca_type="${2:-public}"
    set_env_value "UVICORN_SSL_CERTFILE" "$cert_dir/fullchain.pem"
    set_env_value "UVICORN_SSL_KEYFILE" "$cert_dir/privkey.pem"
    set_env_value "UVICORN_SSL_CA_TYPE" "$ca_type"
}

perform_ssl_issue() {
    local email="$1"
    local preferred="${2:-auto}"
    shift 2
    local domains=("$@")
    local provider_used=""
    local has_ip=0
    local has_domain=0

    if [ ${#domains[@]} -eq 0 ]; then
        colorized_echo red "At least one domain is required for SSL issuance."
        return 1
    fi

    for d in "${domains[@]}"; do
        if is_valid_ip "$d"; then
            has_ip=1
        else
            has_domain=1
        fi
    done

    if [ "$has_ip" -eq 1 ] && [ "$has_domain" -eq 1 ]; then
        colorized_echo red "Mixing IP addresses and domains is not supported in one certificate request."
        return 1
    fi

    install_ssl_dependencies
    mkdir -p "$CERTS_BASE"

    if [ "$has_ip" -eq 1 ]; then
        if [ "$has_domain" -eq 1 ]; then
            colorized_echo red "IP certificates cannot be mixed with domain names."
            return 1
        fi
        case "$preferred" in
            letsencrypt-ip|ip|public-ip|shortlived|certbot-ip)
                issue_ssl_public_ip "$email" "${domains[@]}" || return 1
                provider_used="letsencrypt-ip"
                sync_ssl_env_paths "$SSL_CERT_DIR" "public"
                colorized_echo green "Public short-lived IP SSL certificate installed at $SSL_CERT_DIR for IP(s): ${domains[*]}"
                ;;
            auto|self-signed)
                issue_ssl_self_signed_ip "$email" "${domains[@]}" || return 1
                provider_used="self-signed"
                sync_ssl_env_paths "$SSL_CERT_DIR" "self-signed"
                colorized_echo green "Self-signed SSL certificate generated at $SSL_CERT_DIR for IP(s): ${domains[*]}"
                ;;
            *)
                colorized_echo red "IP SSL requires --provider letsencrypt-ip or --provider self-signed."
                return 1
                ;;
        esac
        
        if is_rebecca_installed; then
            if is_rebecca_up; then
                colorized_echo blue "Restarting Rebecca to apply SSL configuration..."
                down_rebecca
                up_rebecca
                colorized_echo green "Rebecca restarted with SSL configuration"
            fi
        fi
        
        return 0
    fi

    if [ "$preferred" = "self-signed" ] || [ "$preferred" = "letsencrypt-ip" ] || [ "$preferred" = "ip" ] || [ "$preferred" = "public-ip" ] || [ "$preferred" = "shortlived" ] || [ "$preferred" = "certbot-ip" ]; then
        colorized_echo red "Provider $preferred is only valid for IP address certificates."
        return 1
    fi

    if [ "$preferred" = "acme" ]; then
        issue_ssl_with_acme "$email" "${domains[@]}" || return 1
        provider_used="acme"
    elif [ "$preferred" = "certbot" ]; then
        issue_ssl_with_certbot "$email" "${domains[@]}" || return 1
        provider_used="certbot"
    else
        if issue_ssl_with_acme "$email" "${domains[@]}"; then
            provider_used="acme"
        else
            colorized_echo yellow "acme.sh issuance failed, falling back to certbot..."
            issue_ssl_with_certbot "$email" "${domains[@]}" || return 1
            provider_used="certbot"
        fi
    fi

    sync_ssl_env_paths "$SSL_CERT_DIR"
    colorized_echo green "SSL certificate installed at $SSL_CERT_DIR using $provider_used"
    
    if is_rebecca_installed; then
        if is_rebecca_up; then
            colorized_echo blue "Restarting Rebecca to apply SSL configuration..."
            down_rebecca
            up_rebecca
            colorized_echo green "Rebecca restarted with SSL configuration"
        fi
    fi
    
    return 0
}

parse_domains_input() {
    local input="$1"
    PARSED_DOMAINS=()
    PARSED_IS_IP=0
    local has_ip=0
    local has_domain=0
    IFS=',' read -ra raw_domains <<< "$input"
    for entry in "${raw_domains[@]}"; do
        local domain
        domain=$(trim_string "$entry")
        if [ -z "$domain" ]; then
            continue
        fi
        if is_valid_ip "$domain"; then
            has_ip=1
        else
            validate_domain_format "$domain" || return 1
            has_domain=1
        fi
        PARSED_DOMAINS+=("$domain")
    done
    if [ ${#PARSED_DOMAINS[@]} -eq 0 ]; then
        colorized_echo red "No valid domains provided."
        return 1
    fi
    if [ "$has_ip" -eq 1 ] && [ "$has_domain" -eq 1 ]; then
        colorized_echo red "Cannot mix IP addresses and domains in one request."
        return 1
    fi
    if [ "$has_ip" -eq 1 ]; then
        PARSED_IS_IP=1
    fi
}

prompt_ssl_setup() {
    read -p "Do you want to configure SSL certificates now? (y/N): " ssl_answer
    if [[ ! "$ssl_answer" =~ ^[Yy]$ ]]; then
        return
    fi

    colorized_echo cyan "Select SSL certificate type:"
    echo "  1) Domain certificate (Let's Encrypt, regular public SSL)"
    echo "  2) Temporary public IP certificate (Let's Encrypt short-lived, about 6 days)"
    echo "  3) Self-signed IP certificate (browser warning, local fallback)"
    read -p "Select option [1]: " ssl_mode
    ssl_mode="${ssl_mode:-1}"

    read -p "Enter email for certificate notifications: " ssl_email

    local ssl_domains=""
    local ssl_provider="auto"
    case "$ssl_mode" in
        2)
            local detected_ip=""
            detected_ip=$(detect_public_ip || true)
            if [ -n "$detected_ip" ]; then
                read -p "Enter server public IP [$detected_ip]: " ssl_domains
                ssl_domains="${ssl_domains:-$detected_ip}"
            else
                read -p "Enter server public IP: " ssl_domains
            fi
            ssl_provider="letsencrypt-ip"
            ;;
        3)
            local detected_self_ip=""
            detected_self_ip=$(detect_public_ip || true)
            if [ -n "$detected_self_ip" ]; then
                read -p "Enter server IP [$detected_self_ip]: " ssl_domains
                ssl_domains="${ssl_domains:-$detected_self_ip}"
            else
                read -p "Enter server IP: " ssl_domains
            fi
            ssl_provider="self-signed"
            ;;
        *)
            read -p "Enter domain(s) separated by comma: " ssl_domains
            ssl_provider="auto"
            ;;
    esac

    if ! ssl_command issue --email "$ssl_email" --domains "$ssl_domains" --provider "$ssl_provider" --non-interactive; then
        colorized_echo yellow "SSL setup skipped due to input/issuance error. You can retry with: rebecca ssl issue"
    fi
}

ssl_issue() {
    local email=""
    local domains_input=""
    local ip_input=""
    local provider="auto"
    local interactive=true

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --email=*)
                email="${1#*=}"
                shift
                ;;
            --email)
                email="$2"
                shift 2
                ;;
            --domains=*)
                domains_input="${1#*=}"
                shift
                ;;
            --domains)
                domains_input="$2"
                shift 2
                ;;
            --ip-address=*|--ip=*)
                ip_input="${1#*=}"
                if [ "$provider" = "auto" ]; then
                    provider="letsencrypt-ip"
                fi
                shift
                ;;
            --ip-address|--ip)
                ip_input="$2"
                if [ "$provider" = "auto" ]; then
                    provider="letsencrypt-ip"
                fi
                shift 2
                ;;
            --provider=*)
                provider="${1#*=}"
                shift
                ;;
            --provider)
                provider="$2"
                shift 2
                ;;
            --non-interactive)
                interactive=false
                shift
                ;;
            *)
                colorized_echo red "Unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -n "$ip_input" ]; then
        domains_input="$ip_input"
    fi

    if [ "$interactive" = true ]; then
        if [ -z "$email" ]; then
            read -p "Enter email address: " email
        fi
        if [ -z "$domains_input" ]; then
            read -p "Enter domain(s) or IP address(es) separated by comma: " domains_input
        fi
    else
        if [ -z "$email" ] || [ -z "$domains_input" ]; then
            colorized_echo red "Email and domains/IP addresses are required when using non-interactive mode."
            return 1
        fi
    fi

    parse_domains_input "$domains_input" || return 1
    perform_ssl_issue "$email" "$provider" "${PARSED_DOMAINS[@]}"
}

get_domain_from_env() {
    if [ ! -f "$ENV_FILE" ]; then
        return
    fi
    local line
    line=$(grep "^UVICORN_SSL_CERTFILE" "$ENV_FILE" | tail -n 1 | cut -d'=' -f2-)
    line=$(echo "$line" | tr -d ' "')
    if [ -z "$line" ]; then
        return
    fi
    basename "$(dirname "$line")"
}

ssl_renew() {
    local target_domain=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --domain=*)
                target_domain="${1#*=}"
                shift
                ;;
            --domain)
                target_domain="$2"
                shift 2
                ;;
            *)
                colorized_echo red "Unknown option: $1"
                return 1
                ;;
        esac
    done

    if [ -z "$target_domain" ]; then
        target_domain=$(get_domain_from_env)
    fi

    if [ -z "$target_domain" ]; then
        colorized_echo red "Unable to detect domain. Please specify --domain example.com"
        return 1
    fi

    local metadata="$CERTS_BASE/$target_domain/.metadata"
    if [ ! -f "$metadata" ]; then
        colorized_echo red "Metadata not found for domain $target_domain"
        return 1
    fi

    local provider email domains_line
    provider=$(grep '^provider=' "$metadata" | cut -d'=' -f2-)
    email=$(grep '^email=' "$metadata" | cut -d'=' -f2-)
    domains_line=$(grep '^domains=' "$metadata" | cut -d'=' -f2-)

    if [ -z "$email" ] || [ -z "$domains_line" ]; then
        colorized_echo red "Metadata is incomplete for $target_domain"
        return 1
    fi

    read -ra stored_domains <<< "$domains_line"
    perform_ssl_issue "$email" "$provider" "${stored_domains[@]}" || return 1
    colorized_echo green "SSL certificate renewed for $target_domain"
}

ssl_command() {
    local action="$1"
    shift || true

    case "$action" in
        issue)
            ssl_issue "$@"
            ;;
        renew)
            ssl_renew "$@"
            ;;
        *)
            colorized_echo blue "Usage: rebecca ssl <issue|renew> [options]"
            colorized_echo magenta "  Issue domain SSL: rebecca ssl issue --email you@example.com --domains example.com"
            colorized_echo magenta "  Issue public IP SSL: rebecca ssl issue --email you@example.com --ip-address 203.0.113.10"
            colorized_echo magenta "  Issue self-signed IP SSL: rebecca ssl issue --email you@example.com --domains 203.0.113.10 --provider self-signed"
            ;;
    esac
}

is_rebecca_installed() {
    if [ -d $APP_DIR ]; then
        return 0
    else
        return 1
    fi
}

identify_the_operating_system_and_architecture() {
    if [[ "$(uname)" == 'Linux' ]]; then
        case "$(uname -m)" in
            'i386' | 'i686')
                ARCH='32'
            ;;
            'amd64' | 'x86_64')
                ARCH='64'
            ;;
            'armv5tel')
                ARCH='arm32-v5'
            ;;
            'armv6l')
                ARCH='arm32-v6'
                grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5'
            ;;
            'armv7' | 'armv7l')
                ARCH='arm32-v7a'
                grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5'
            ;;
            'armv8' | 'aarch64')
                ARCH='arm64-v8a'
            ;;
            'mips')
                ARCH='mips32'
            ;;
            'mipsle')
                ARCH='mips32le'
            ;;
            'mips64')
                ARCH='mips64'
                lscpu | grep -q "Little Endian" && ARCH='mips64le'
            ;;
            'mips64le')
                ARCH='mips64le'
            ;;
            'ppc64')
                ARCH='ppc64'
            ;;
            'ppc64le')
                ARCH='ppc64le'
            ;;
            'riscv64')
                ARCH='riscv64'
            ;;
            's390x')
                ARCH='s390x'
            ;;
            *)
                echo "error: The architecture is not supported."
                exit 1
            ;;
        esac
    else
        echo "error: This operating system is not supported."
        exit 1
    fi
}

send_backup_to_telegram() {
    if [ -f "$ENV_FILE" ]; then
        while IFS='=' read -r key value; do
            if [[ -z "$key" || "$key" =~ ^# ]]; then
                continue
            fi
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                export "$key"="$value"
            else
                colorized_echo yellow "Skipping invalid line in .env: $key=$value"
            fi
        done < "$ENV_FILE"
    else
        colorized_echo red "Environment file (.env) not found."
        exit 1
    fi

    if [ "$BACKUP_SERVICE_ENABLED" != "true" ]; then
        colorized_echo yellow "Backup service is not enabled. Skipping Telegram upload."
        return
    fi

    local server_ip=$(curl -s ifconfig.me || echo "Unknown IP")
    local latest_backup=$(ls -t "$APP_DIR/backup" | head -n 1)
    local backup_path="$APP_DIR/backup/$latest_backup"

    if [ ! -f "$backup_path" ]; then
        colorized_echo red "No backups found to send."
        return
    fi

    local backup_size=$(du -m "$backup_path" | cut -f1)
    local split_dir="/tmp/rebecca_backup_split"
    local is_single_file=true

    mkdir -p "$split_dir"

    if [ "$backup_size" -gt 49 ]; then
        colorized_echo yellow "Backup is larger than 49MB. Splitting the archive..."
        split -b 49M "$backup_path" "$split_dir/part_"
        is_single_file=false
    else
        cp "$backup_path" "$split_dir/part_aa"
    fi


    local backup_time=$(date "+%Y-%m-%d %H:%M:%S %Z")


    for part in "$split_dir"/*; do
        local part_name=$(basename "$part")
        local custom_filename="backup_${part_name}.tar.gz"
        local caption="?? *Backup Information*\n?? *Server IP*: \`${server_ip}\`\n?? *Backup File*: \`${custom_filename}\`\n? *Backup Time*: \`${backup_time}\`"
        curl -s -F chat_id="$BACKUP_TELEGRAM_CHAT_ID" \
            -F document=@"$part;filename=$custom_filename" \
            -F caption="$(echo -e "$caption" | sed 's/-/\\-/g;s/\./\\./g;s/_/\\_/g')" \
            -F parse_mode="MarkdownV2" \
            "https://api.telegram.org/bot$BACKUP_TELEGRAM_BOT_KEY/sendDocument" >/dev/null 2>&1 && \
        colorized_echo green "Backup part $custom_filename successfully sent to Telegram." || \
        colorized_echo red "Failed to send backup part $custom_filename to Telegram."
    done

    rm -rf "$split_dir"
}

send_backup_error_to_telegram() {
    local error_messages=$1
    local log_file=$2
    local server_ip=$(curl -s ifconfig.me || echo "Unknown IP")
    local error_time=$(date "+%Y-%m-%d %H:%M:%S %Z")
    local message="?? *Backup Error Notification*\n"
    message+="?? *Server IP*: \`${server_ip}\`\n"
    message+="? *Errors*:\n\`${error_messages//_/\\_}\`\n"
    message+="? *Time*: \`${error_time}\`"


    message=$(echo -e "$message" | sed 's/-/\\-/g;s/\./\\./g;s/_/\\_/g;s/(/\\(/g;s/)/\\)/g')

    local max_length=1000
    if [ ${#message} -gt $max_length ]; then
        message="${message:0:$((max_length - 50))}...\n\`[Message truncated]\`"
    fi


    curl -s -X POST "https://api.telegram.org/bot$BACKUP_TELEGRAM_BOT_KEY/sendMessage" \
        -d chat_id="$BACKUP_TELEGRAM_CHAT_ID" \
        -d parse_mode="MarkdownV2" \
        -d text="$message" >/dev/null 2>&1 && \
    colorized_echo green "Backup error notification sent to Telegram." || \
    colorized_echo red "Failed to send error notification to Telegram."


    if [ -f "$log_file" ]; then
        response=$(curl -s -w "%{http_code}" -o /tmp/tg_response.json \
            -F chat_id="$BACKUP_TELEGRAM_CHAT_ID" \
            -F document=@"$log_file;filename=backup_error.log" \
            -F caption="?? *Backup Error Log* - ${error_time}" \
            "https://api.telegram.org/bot$BACKUP_TELEGRAM_BOT_KEY/sendDocument")

        http_code="${response:(-3)}"
        if [ "$http_code" -eq 200 ]; then
            colorized_echo green "Backup error log sent to Telegram."
        else
            colorized_echo red "Failed to send backup error log to Telegram. HTTP code: $http_code"
            cat /tmp/tg_response.json
        fi
    else
        colorized_echo red "Log file not found: $log_file"
    fi
}

backup_service() {
    local telegram_bot_key=""
    local telegram_chat_id=""
    local cron_schedule=""
    local interval_hours=""

    colorized_echo blue "====================================="
    colorized_echo blue "      Welcome to Backup Service      "
    colorized_echo blue "====================================="

    if grep -q "BACKUP_SERVICE_ENABLED=true" "$ENV_FILE"; then
        telegram_bot_key=$(awk -F'=' '/^BACKUP_TELEGRAM_BOT_KEY=/ {print $2}' "$ENV_FILE")
        telegram_chat_id=$(awk -F'=' '/^BACKUP_TELEGRAM_CHAT_ID=/ {print $2}' "$ENV_FILE")
        cron_schedule=$(awk -F'=' '/^BACKUP_CRON_SCHEDULE=/ {print $2}' "$ENV_FILE" | tr -d '"')

        if [[ "$cron_schedule" == "0 0 * * *" ]]; then
            interval_hours=24
        else
            interval_hours=$(echo "$cron_schedule" | grep -oP '(?<=\*/)[0-9]+')
        fi

        colorized_echo green "====================================="
        colorized_echo green "Current Backup Configuration:"
        colorized_echo cyan "Telegram Bot API Key: $telegram_bot_key"
        colorized_echo cyan "Telegram Chat ID: $telegram_chat_id"
        colorized_echo cyan "Backup Interval: Every $interval_hours hour(s)"
        colorized_echo green "====================================="
        echo "Choose an option:"
        echo "1. Reconfigure Backup Service"
        echo "2. Remove Backup Service"
        echo "3. Exit"
        read -p "Enter your choice (1-3): " user_choice

        case $user_choice in
            1)
                colorized_echo yellow "Starting reconfiguration..."
                remove_backup_service
                ;;
            2)
                colorized_echo yellow "Removing Backup Service..."
                remove_backup_service
                return
                ;;
            3)
                colorized_echo yellow "Exiting..."
                return
                ;;
            *)
                colorized_echo red "Invalid choice. Exiting."
                return
                ;;
        esac
    else
        colorized_echo yellow "No backup service is currently configured."
    fi

    while true; do
        printf "Enter your Telegram bot API key: "
        read telegram_bot_key
        if [[ -n "$telegram_bot_key" ]]; then
            break
        else
            colorized_echo red "API key cannot be empty. Please try again."
        fi
    done

    while true; do
        printf "Enter your Telegram chat ID: "
        read telegram_chat_id
        if [[ -n "$telegram_chat_id" ]]; then
            break
        else
            colorized_echo red "Chat ID cannot be empty. Please try again."
        fi
    done

    while true; do
        printf "Set up the backup interval in hours (1-24):\n"
        read interval_hours

        if ! [[ "$interval_hours" =~ ^[0-9]+$ ]]; then
            colorized_echo red "Invalid input. Please enter a valid number."
            continue
        fi

        if [[ "$interval_hours" -eq 24 ]]; then
            cron_schedule="0 0 * * *"
            colorized_echo green "Setting backup to run daily at midnight."
            break
        fi

        if [[ "$interval_hours" -ge 1 && "$interval_hours" -le 23 ]]; then
            cron_schedule="0 */$interval_hours * * *"
            colorized_echo green "Setting backup to run every $interval_hours hour(s)."
            break
        else
            colorized_echo red "Invalid input. Please enter a number between 1-24."
        fi
    done

    sed -i '/^BACKUP_SERVICE_ENABLED/d' "$ENV_FILE"
    sed -i '/^BACKUP_TELEGRAM_BOT_KEY/d' "$ENV_FILE"
    sed -i '/^BACKUP_TELEGRAM_CHAT_ID/d' "$ENV_FILE"
    sed -i '/^BACKUP_CRON_SCHEDULE/d' "$ENV_FILE"

    {
        echo ""
        echo "# Backup service configuration"
        echo "BACKUP_SERVICE_ENABLED=true"
        echo "BACKUP_TELEGRAM_BOT_KEY=$telegram_bot_key"
        echo "BACKUP_TELEGRAM_CHAT_ID=$telegram_chat_id"
        echo "BACKUP_CRON_SCHEDULE=\"$cron_schedule\""
    } >> "$ENV_FILE"

    colorized_echo green "Backup service configuration saved in $ENV_FILE."

    local backup_command
    backup_command="$(backup_cron_command)"
    add_cron_job "$cron_schedule" "$backup_command"

    colorized_echo green "Backup service successfully configured."
    if [[ "$interval_hours" -eq 24 ]]; then
        colorized_echo cyan "Backups will be sent to Telegram daily (every 24 hours at midnight)."
    else
        colorized_echo cyan "Backups will be sent to Telegram every $interval_hours hour(s)."
    fi
    colorized_echo green "====================================="
}

add_cron_job() {
    local schedule="$1"
    local command="$2"
    local temp_cron=$(mktemp)

    crontab -l 2>/dev/null > "$temp_cron" || true
    sed -i '/# rebecca-backup-service/d' "$temp_cron"
    echo "$schedule $command # rebecca-backup-service" >> "$temp_cron"
    
    if crontab "$temp_cron"; then
        colorized_echo green "Cron job successfully added."
    else
        colorized_echo red "Failed to add cron job. Please check manually."
    fi
    rm -f "$temp_cron"
}

remove_backup_service() {
    colorized_echo red "in process..."


    sed -i '/^# Backup service configuration/d' "$ENV_FILE"
    sed -i '/BACKUP_SERVICE_ENABLED/d' "$ENV_FILE"
    sed -i '/BACKUP_TELEGRAM_BOT_KEY/d' "$ENV_FILE"
    sed -i '/BACKUP_TELEGRAM_CHAT_ID/d' "$ENV_FILE"
    sed -i '/BACKUP_CRON_SCHEDULE/d' "$ENV_FILE"

    local temp_cron=$(mktemp)
    crontab -l 2>/dev/null > "$temp_cron"

    sed -i '/# rebecca-backup-service/d' "$temp_cron"

    if crontab "$temp_cron"; then
        colorized_echo green "Backup service task removed from crontab."
    else
        colorized_echo red "Failed to update crontab. Please check manually."
    fi

    rm -f "$temp_cron"

    colorized_echo green "Backup service has been removed."
}

backup_cron_command() {
    local script_path="${REBECCA_SCRIPT_INSTALL_PATH:-}"
    if [ -z "$script_path" ] || [ ! -x "$script_path" ]; then
        script_path="$(command -v "$APP_NAME" 2>/dev/null || true)"
    fi
    if [ -z "$script_path" ]; then
        script_path="/usr/local/bin/$APP_NAME"
    fi
    printf '%s backup' "$script_path"
}

backup_strip_quotes() {
    local value="$1"
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s' "$value"
}

backup_url_decode() {
    local value="$1"
    value="${value//%/\\x}"
    printf '%b' "$value"
}

backup_parse_database_url() {
    local raw
    raw="$(backup_strip_quotes "$1")"
    BACKUP_DB_TYPE=""
    BACKUP_SQLITE_FILE=""
    BACKUP_DB_USER=""
    BACKUP_DB_PASSWORD=""
    BACKUP_DB_HOST=""
    BACKUP_DB_PORT=""
    BACKUP_DB_NAME=""
    BACKUP_DB_SOCKET=""

    case "$raw" in
        sqlite:///*)
            BACKUP_DB_TYPE="sqlite"
            BACKUP_SQLITE_FILE="${raw#sqlite:///}"
            if [[ ! "$BACKUP_SQLITE_FILE" =~ ^/ ]]; then
                BACKUP_SQLITE_FILE="/$BACKUP_SQLITE_FILE"
            fi
            return 0
            ;;
        mysql*://*|mariadb*://*)
            BACKUP_DB_TYPE="mysql"
            local rest="${raw#*://}"
            local authority="${rest%%/*}"
            local path_query="${rest#*/}"
            local query=""
            BACKUP_DB_NAME="${path_query%%\?*}"
            if [[ "$path_query" == *"?"* ]]; then
                query="${path_query#*\?}"
            fi
            if [[ "$authority" == *"@"* ]]; then
                local credentials="${authority%@*}"
                local hostport="${authority##*@}"
                BACKUP_DB_USER="$(backup_url_decode "${credentials%%:*}")"
                if [[ "$credentials" == *":"* ]]; then
                    BACKUP_DB_PASSWORD="$(backup_url_decode "${credentials#*:}")"
                fi
                authority="$hostport"
            fi
            if [[ "$authority" == *":"* ]]; then
                BACKUP_DB_HOST="${authority%%:*}"
                BACKUP_DB_PORT="${authority##*:}"
            else
                BACKUP_DB_HOST="$authority"
                BACKUP_DB_PORT="3306"
            fi
            BACKUP_DB_HOST="${BACKUP_DB_HOST:-127.0.0.1}"
            BACKUP_DB_PORT="${BACKUP_DB_PORT:-3306}"
            BACKUP_DB_NAME="$(backup_url_decode "$BACKUP_DB_NAME")"
            if [ -n "$query" ]; then
                IFS='&' read -ra query_parts <<< "$query"
                for query_part in "${query_parts[@]}"; do
                    case "$query_part" in
                        unix_socket=*|socket=*)
                            BACKUP_DB_SOCKET="$(backup_url_decode "${query_part#*=}")"
                            ;;
                    esac
                done
            fi
            [ -n "$BACKUP_DB_NAME" ]
            return
            ;;
    esac
    return 1
}

write_mysql_backup_defaults() {
    local defaults_file="$1"
    {
        echo "[client]"
        [ -n "${BACKUP_DB_USER:-}" ] && printf 'user="%s"\n' "${BACKUP_DB_USER//\"/\\\"}"
        [ -n "${BACKUP_DB_PASSWORD:-}" ] && printf 'password="%s"\n' "${BACKUP_DB_PASSWORD//\"/\\\"}"
        if [ -n "${BACKUP_DB_SOCKET:-}" ]; then
            printf 'socket="%s"\n' "${BACKUP_DB_SOCKET//\"/\\\"}"
        else
            printf 'host="%s"\n' "${BACKUP_DB_HOST:-127.0.0.1}"
            printf 'port=%s\n' "${BACKUP_DB_PORT:-3306}"
            echo "protocol=tcp"
        fi
    } > "$defaults_file"
    chmod 600 "$defaults_file"
}

backup_command() {
    local backup_dir="$APP_DIR/backup"
    local temp_dir="/tmp/rebecca_backup"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    local backup_file="$backup_dir/backup_$timestamp.tar.gz"
    local error_messages=()
    local log_file="/var/log/rebecca_backup_error.log"
    > "$log_file"
    echo "Backup Log - $(date)" > "$log_file"

    if ! command -v rsync >/dev/null 2>&1; then
        detect_os
        install_package rsync
    fi

    rm -rf "$backup_dir"
    mkdir -p "$backup_dir"
    rm -rf "$temp_dir"
    mkdir -p "$temp_dir"

    if [ -f "$ENV_FILE" ]; then
        while IFS='=' read -r key value; do
            if [[ -z "$key" || "$key" =~ ^# ]]; then
                continue
            fi
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | xargs)
            if [[ "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                export "$key"="$value"
            else
                echo "Skipping invalid line in .env: $key=$value" >> "$log_file"
            fi
        done < "$ENV_FILE"
    else
        error_messages+=("Environment file (.env) not found.")
        echo "Environment file (.env) not found." >> "$log_file"
        send_backup_error_to_telegram "${error_messages[*]}" "$log_file"
        exit 1
    fi

    local db_type=""
    local sqlite_file=""
    if [ -n "${SQLALCHEMY_DATABASE_URL:-}" ] && backup_parse_database_url "$SQLALCHEMY_DATABASE_URL"; then
        db_type="$BACKUP_DB_TYPE"
        sqlite_file="$BACKUP_SQLITE_FILE"
    elif grep -q "SQLALCHEMY_DATABASE_URL = .*sqlite" "$ENV_FILE"; then
        db_type="sqlite"
        sqlite_file=$(grep -Po '(?<=SQLALCHEMY_DATABASE_URL = "sqlite:////).*"' "$ENV_FILE" | tr -d '"')
        if [[ ! "$sqlite_file" =~ ^/ ]]; then
            sqlite_file="/$sqlite_file"
        fi
    fi

    if [ -n "$db_type" ]; then
        echo "Database detected: $db_type" >> "$log_file"
        case $db_type in
            mysql|mariadb)
                local dump_bin
                dump_bin="$(command -v mysqldump 2>/dev/null || command -v mariadb-dump 2>/dev/null || true)"
                if [ -z "$dump_bin" ]; then
                    error_messages+=("mysqldump or mariadb-dump is not installed.")
                else
                    local defaults_file="$temp_dir/mysql-client.cnf"
                    write_mysql_backup_defaults "$defaults_file"
                    if ! "$dump_bin" --defaults-extra-file="$defaults_file" --single-transaction --quick --routines --triggers --events --hex-blob --default-character-set=utf8mb4 "$BACKUP_DB_NAME" > "$temp_dir/db_backup.sql" 2>>"$log_file"; then
                        error_messages+=("MySQL dump failed.")
                    fi
                fi
                ;;
            sqlite)
                if [ -f "$sqlite_file" ]; then
                    if ! cp "$sqlite_file" "$temp_dir/db_backup.sqlite" 2>>"$log_file"; then
                        error_messages+=("Failed to copy SQLite database.")
                    fi
                else
                    error_messages+=("SQLite database file not found at $sqlite_file.")
                fi
                ;;
        esac
    fi

    cp "$APP_DIR/.env" "$temp_dir/" 2>>"$log_file" || true
    if ! rsync -a --delete --exclude 'xray-core' --exclude 'mysql' "$DATA_DIR/" "$temp_dir/rebecca_data/" >>"$log_file" 2>&1; then
        error_messages+=("Failed to copy Rebecca data files.")
    fi

    if ! tar -C "$temp_dir" -cf - . | gzip -1 > "$backup_file"; then
        error_messages+=("Failed to create backup archive.")
        echo "Failed to create backup archive." >> "$log_file"
    fi

    rm -rf "$temp_dir"

    if [ ${#error_messages[@]} -gt 0 ]; then
        send_backup_error_to_telegram "${error_messages[*]}" "$log_file"
        return
    fi
    colorized_echo green "Backup created: $backup_file"
    send_backup_to_telegram "$backup_file"
}

get_xray_core() {
    identify_the_operating_system_and_architecture
    clear

    validate_version() {
        local version="$1"
        
        local response=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases/tags/$version")
        if echo "$response" | grep -q '"message": "Not Found"'; then
            echo "invalid"
        else
            echo "valid"
        fi
    }

print_menu() {
    ui_header "$APP_NAME" "$APP_NAME control center"
    ui_section "Status"
    print_menu_status_summary
    ui_section "Actions"

    local previous_category=""
    local idx=1
    local cmd category desc

    for cmd in $(menu_commands); do
        category=$(menu_category_for "$cmd")
        if [ "$category" != "$previous_category" ]; then
            ui_menu_category "$category"
            previous_category="$category"
        fi
        desc=$(menu_description_for "$cmd")
        printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$idx" "$cmd" "$desc"
        idx=$((idx + 1))
    done
    echo
}

    latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=$LAST_XRAY_CORES")

    versions=($(echo "$latest_releases" | grep -oP '"tag_name": "\K(.*?)(?=")'))

    while true; do
        print_menu
        read -p "Choose a version to install (1-${#versions[@]}), or press M to enter manually, Q to quit: " choice
        
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "${#versions[@]}" ]; then
            choice=$((choice - 1))
            selected_version=${versions[choice]}
            break
        elif [ "$choice" == "M" ] || [ "$choice" == "m" ]; then
            while true; do
                read -p "Enter the version manually (e.g., v1.2.3): " custom_version
                if [ "$(validate_version "$custom_version")" == "valid" ]; then
                    selected_version="$custom_version"
                    break 2
                else
                    echo -e "\033[1;31mInvalid version or version does not exist. Please try again.\033[0m"
                fi
            done
        elif [ "$choice" == "Q" ] || [ "$choice" == "q" ]; then
            echo -e "\033[1;31mExiting.\033[0m"
            exit 0
        else
            echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
            sleep 2
        fi
    done

    echo -e "\033[1;32mSelected version $selected_version for installation.\033[0m"

    if ! command -v unzip >/dev/null 2>&1; then
        echo -e "\033[1;33mInstalling required packages...\033[0m"
        detect_os
        install_package unzip
    fi
    if ! command -v wget >/dev/null 2>&1; then
        echo -e "\033[1;33mInstalling required packages...\033[0m"
        detect_os
        install_package wget
    fi

    mkdir -p $DATA_DIR/xray-core
    cd $DATA_DIR/xray-core

    xray_filename="Xray-linux-$ARCH.zip"
    xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${selected_version}/${xray_filename}"

    echo -e "\033[1;33mDownloading Xray-core version ${selected_version}...\033[0m"
    wget -q -O "${xray_filename}" "${xray_download_url}"

    echo -e "\033[1;33mExtracting Xray-core...\033[0m"
    unzip -o "${xray_filename}" >/dev/null 2>&1
    rm "${xray_filename}"
}

get_current_xray_core_version() {
    XRAY_BINARY="$DATA_DIR/xray-core/xray"
    if [ -f "$XRAY_BINARY" ]; then
        version_output=$("$XRAY_BINARY" -version 2>/dev/null)
        if [ $? -eq 0 ]; then
            version=$(echo "$version_output" | head -n1 | awk '{print $2}')
            echo "$version"
            return
        fi
    fi
    echo "Not installed"
}

update_core_command() {
    colorized_echo yellow "Master no longer runs a local Xray core. Update Xray from the Nodes page or the rebecca-node installer."
}

detect_binary_arch() {
    case "$(uname -m)" in
        amd64|x86_64)
            echo "amd64"
            ;;
        arm64|aarch64)
            echo "arm64"
            ;;
        i386|i486|i586|i686)
            echo "386"
            ;;
        armv5l|armv5tel|armv5tejl)
            echo "armv5"
            ;;
        armv6l|armv6)
            echo "armv6"
            ;;
        armv7l|armv7)
            echo "armv7"
            ;;
        ppc64le)
            echo "ppc64le"
            ;;
        s390x)
            echo "s390x"
            ;;
        *)
            colorized_echo red "Binary install is not available for architecture: $(uname -m)" >&2
            exit 1
            ;;
    esac
}

get_binary_release_asset_metadata() {
    local rebecca_version="$1"
    local binary_arch="$2"
    local release_api
    local release_payload
    local resolved_tag
    local server_asset_url
    local cli_asset_url
    local package_asset_url
    local package_asset_name
    local server_asset_name
    local cli_asset_name

    if [ "$rebecca_version" = "latest" ]; then
        release_api="https://api.github.com/repos/${REBECCA_RELEASE_REPO}/releases/latest"
    else
        release_api="https://api.github.com/repos/${REBECCA_RELEASE_REPO}/releases/tags/${rebecca_version}"
    fi

    release_payload=$(curl -fsSL "$release_api") || {
        colorized_echo red "Unable to read Rebecca release metadata: $release_api" >&2
        exit 1
    }

    resolved_tag=$(echo "$release_payload" | jq -r '.tag_name // empty')
    package_asset_name="rebecca-linux-${binary_arch}.tar.gz"
    server_asset_name="rebecca-server-${resolved_tag}-linux-${binary_arch}"
    cli_asset_name="rebecca-cli-${resolved_tag}-linux-${binary_arch}"

    package_asset_url=$(echo "$release_payload" | jq -r --arg name "$package_asset_name" '
        .assets[]?
        | select(.name == $name)
        | .browser_download_url
    ' | head -n 1)

    if [ -n "$package_asset_url" ] && [ "$package_asset_url" != "null" ]; then
        printf 'archive|%s|%s|\n' "${resolved_tag:-$rebecca_version}" "$package_asset_url"
        return
    fi

    server_asset_url=$(echo "$release_payload" | jq -r --arg name "$server_asset_name" '
        .assets[]?
        | select(.name == $name)
        | .browser_download_url
    ' | head -n 1)

    cli_asset_url=$(echo "$release_payload" | jq -r --arg name "$cli_asset_name" '
        .assets[]?
        | select(.name == $name)
        | .browser_download_url
    ' | head -n 1)

    if [ -n "$server_asset_url" ] && [ "$server_asset_url" != "null" ] && [ -n "$cli_asset_url" ] && [ "$cli_asset_url" != "null" ]; then
        printf 'split|%s|%s|%s\n' "${resolved_tag:-$rebecca_version}" "$server_asset_url" "$cli_asset_url"
        return
    fi

    colorized_echo red "No Go binary release assets found for linux-${binary_arch}." >&2
    exit 1
}

get_binary_dev_manifest_url() {
    if [ -n "$REBECCA_BINARY_DEV_MANIFEST_URL" ]; then
        printf '%s\n' "$REBECCA_BINARY_DEV_MANIFEST_URL"
        return
    fi
    printf 'https://raw.githubusercontent.com/%s/%s/%s\n' \
        "$REBECCA_RELEASE_REPO" \
        "$REBECCA_BINARY_DEV_MANIFEST_BRANCH" \
        "$REBECCA_BINARY_DEV_MANIFEST_PATH"
}

get_binary_dev_manifest_metadata() {
    local binary_arch="$1"
    local requested_version="${2:-dev}"
    local manifest_url
    local manifest_payload
    local selected

    manifest_url=$(get_binary_dev_manifest_url)
    manifest_payload=$(curl -fsSL "$manifest_url") || return 1

    selected=$(echo "$manifest_payload" | jq -r \
        --arg arch "linux-${binary_arch}" \
        --arg requested "$requested_version" \
        --arg repo "$REBECCA_RELEASE_REPO" \
        --arg release_tag "$REBECCA_BINARY_DEV_RELEASE_TAG" '
        def legacy_build:
            .latest? as $latest
            | if ($latest | type) == "object" then
                {
                    tag: ($latest.build_tag // $latest.tag // ""),
                    assets: (
                        reduce ($latest.assets[]? | strings) as $name
                          ({};
                            if ($name | startswith("rebecca-" + $arch + "-")) then
                              .[$arch] = {
                                name: $name,
                                url: ("https://github.com/" + $repo + "/releases/download/" + $release_tag + "/" + $name)
                              }
                            else
                              .
                            end)
                    )
                }
              else
                empty
              end;
        def builds:
            ([.builds[]? | select(type == "object")] + [legacy_build]);
        . as $root
        | builds as $builds
        | (if ($requested != "" and $requested != "dev") then
              ($builds[]? | select(.tag == $requested))
           else
              (if ($root.latest | type) == "string" then $root.latest else "" end) as $latest_tag
              | (($builds[]? | select(.tag == $latest_tag)) // $builds[0]?)
           end) as $build
        | ($build.assets[$arch] // empty) as $asset
        | ($asset.name // "") as $asset_name
        | ($asset.url // "") as $asset_url
        | select(($build.tag // "") != "" and $asset_name != "" and $asset_url != "")
        | [$build.tag, $asset_url, $asset_name] | @tsv
    ' | head -n 1)

    if [ -z "$selected" ]; then
        return 1
    fi

    printf '%s\n' "$selected" | awk -F '\t' '{ printf "%s|%s|%s\n", $1, $2, $3 }'
}

get_binary_dev_artifact_metadata() {
    local binary_arch="$1"
    local requested_version="${2:-dev}"
    local workflow_runs_api
    local workflow_runs_payload
    local latest_run_json
    local run_id
    local head_sha
    local artifact_name
    local artifacts_api
    local artifacts_payload
    local artifact_url
    local nightly_workflow

    if get_binary_dev_manifest_metadata "$binary_arch" "$requested_version"; then
        return
    fi

    if [ "$requested_version" != "dev" ]; then
        colorized_echo red "Dev binary build ${requested_version} was not found in $(get_binary_dev_manifest_url)." >&2
        exit 1
    fi

    nightly_workflow="$REBECCA_BINARY_WORKFLOW_NAME"
    case "$nightly_workflow" in
        *.yml|*.yaml) ;;
        *) nightly_workflow="${nightly_workflow}.yml" ;;
    esac
    workflow_runs_api="https://api.github.com/repos/${REBECCA_RELEASE_REPO}/actions/workflows/${nightly_workflow}/runs"
    workflow_runs_payload=$(curl -fsSLG "$workflow_runs_api" \
        --data-urlencode "branch=${REBECCA_BINARY_DEV_BRANCH}" \
        --data-urlencode "event=push" \
        --data-urlencode "status=success" \
        --data-urlencode "per_page=100") || {
        colorized_echo red "Unable to read binary dev workflow metadata: $workflow_runs_api" >&2
        exit 1
    }

    latest_run_json=$(echo "$workflow_runs_payload" | jq -c --arg branch "$REBECCA_BINARY_DEV_BRANCH" '
        .workflow_runs[]?
        | select(.head_branch == $branch and .event == "push" and .conclusion == "success")
    ' | head -n 1)

    if [ -z "$latest_run_json" ]; then
        colorized_echo red "No successful binary dev workflow run was found on branch ${REBECCA_BINARY_DEV_BRANCH}." >&2
        exit 1
    fi

    run_id=$(echo "$latest_run_json" | jq -r '.id // empty')
    head_sha=$(echo "$latest_run_json" | jq -r '.head_sha // empty')
    artifacts_api="https://api.github.com/repos/${REBECCA_RELEASE_REPO}/actions/runs/${run_id}/artifacts"
    artifacts_payload=$(curl -fsSL "$artifacts_api") || {
        colorized_echo red "Unable to read binary dev workflow artifacts: $artifacts_api" >&2
        exit 1
    }

    artifact_name=$(echo "$artifacts_payload" | jq -r --arg preferred "${BINARY_ARTIFACT_PREFIX}-linux-${binary_arch}" --arg arch "linux-${binary_arch}" '
        [
            .artifacts[]?
            | select((.expired | not) and (.name == $preferred or (.name | startswith("rebecca")) and (.name | contains($arch))))
        ]
        | sort_by(if .name == $preferred then 0 else 1 end, .created_at)
        | .[0].name // empty
    ')

    if [ -z "$artifact_name" ]; then
        colorized_echo red "No usable binary dev artifact was found for workflow run ${run_id}." >&2
        exit 1
    fi

    artifact_url="https://nightly.link/${REBECCA_RELEASE_REPO}/workflows/${nightly_workflow}/${REBECCA_BINARY_DEV_BRANCH}/${artifact_name}.zip"
    printf '%s|%s|%s.zip\n' "dev-${head_sha:0:7}" "$artifact_url" "$artifact_name"
}

install_binary_cli_launcher() {
    cat > "$BINARY_CLI_LAUNCHER" <<EOF
#!/usr/bin/env bash
set -e
export REBECCA_ENV_FILE="$ENV_FILE"
export REBECCA_APP_DIR="$APP_DIR"
export REBECCA_DATA_DIR="$DATA_DIR"
exec "$BINARY_CLI" "\$@"
EOF

    chmod 755 "$BINARY_CLI_LAUNCHER"
}

write_binary_release_metadata() {
    local resolved_version="$1"
    local binary_arch="$2"
    local asset_url="$3"

    jq -n \
        --arg image "rebecca-server (binary)" \
        --arg tag "$resolved_version" \
        --arg asset_url "$asset_url" \
        --arg arch "linux-${binary_arch}" \
        --arg server_binary "$BINARY_SERVER" \
        --arg cli_binary "$BINARY_CLI" \
        --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            install_mode: "binary",
            image: $image,
            tag: $tag,
            asset_url: $asset_url,
            arch: $arch,
            server_binary: $server_binary,
            cli_binary: $cli_binary,
            installed_at: $installed_at
        }' > "$BINARY_METADATA_FILE"
}

create_binary_service() {
    cat > "$BINARY_SERVICE_UNIT" <<EOF
[Unit]
Description=Rebecca Panel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment=REBECCA_APP_DIR=$APP_DIR
Environment=REBECCA_ENV_FILE=$ENV_FILE
Environment=REBECCA_INSTALL_MODE=binary
Environment=REBECCA_BINARY_METADATA_FILE=$BINARY_METADATA_FILE
Environment=REBECCA_DATA_DIR=$DATA_DIR
ExecStart=$BINARY_SERVER
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

install_binary_rebecca() {
    local rebecca_version="$1"
    local database_type="$2"
    local configure_database="${3:-1}"
    local binary_arch
    local binary_source_type
    local resolved_version
    local server_asset_url
    local cli_asset_url
    local artifact_url
    local artifact_name
    local tmp_dir
    local package_path=""
    local dev_package_path=""

    set_rebecca_source_ref "$rebecca_version"

    detect_os
    for package in curl jq tar gzip unzip; do
        if ! command -v "$package" >/dev/null 2>&1; then
            install_package "$package"
        fi
    done

    binary_arch=$(detect_binary_arch)
    tmp_dir=$(mktemp -d)

    if [ -n "${REBECCA_BINARY_SERVER_OVERRIDE:-}" ] || [ -n "${REBECCA_BINARY_CLI_OVERRIDE:-}" ]; then
        if [ ! -f "${REBECCA_BINARY_SERVER_OVERRIDE:-}" ] || [ ! -f "${REBECCA_BINARY_CLI_OVERRIDE:-}" ]; then
            colorized_echo red "Both REBECCA_BINARY_SERVER_OVERRIDE and REBECCA_BINARY_CLI_OVERRIDE must point to existing files." >&2
            rm -rf "$tmp_dir"
            exit 1
        fi
        ui_spinner_run "Installing Rebecca custom server binary" install -m 755 "$REBECCA_BINARY_SERVER_OVERRIDE" "$tmp_dir/rebecca-server"
        ui_spinner_run "Installing Rebecca custom CLI binary" install -m 755 "$REBECCA_BINARY_CLI_OVERRIDE" "$tmp_dir/rebecca-cli"
        resolved_version="${REBECCA_BINARY_OVERRIDE_VERSION:-custom}"
        artifact_url="local-override"
    elif [[ "$rebecca_version" = "dev" || "$rebecca_version" == dev-* ]]; then
        IFS='|' read -r resolved_version artifact_url artifact_name < <(get_binary_dev_artifact_metadata "$binary_arch" "$rebecca_version")
        artifact_name="${artifact_name:-rebecca-binaries.zip}"
        package_path="$tmp_dir/$artifact_name"
        ui_spinner_run "Downloading Rebecca dev binary artifact" curl -fL "$artifact_url" -o "$package_path"
        if [[ "$package_path" == *.zip ]]; then
            ui_spinner_run "Extracting Rebecca dev artifact" unzip -j -o "$package_path" -d "$tmp_dir"
            dev_package_path="$tmp_dir/rebecca-linux-${binary_arch}.tar.gz"
            if [ -f "$dev_package_path" ]; then
                ui_spinner_run "Unpacking Rebecca binary package" tar -xzf "$dev_package_path" -C "$tmp_dir"
            elif ls "$tmp_dir"/rebecca-*.tar.gz >/dev/null 2>&1; then
                ui_spinner_run "Unpacking Rebecca binary package" tar -xzf "$(ls "$tmp_dir"/rebecca-*.tar.gz | head -n 1)" -C "$tmp_dir"
            fi
        elif [[ "$package_path" == *.tar.gz ]]; then
            ui_spinner_run "Unpacking Rebecca binary package" tar -xzf "$package_path" -C "$tmp_dir"
        else
            colorized_echo red "Unsupported dev binary asset format: $artifact_name" >&2
            rm -rf "$tmp_dir"
            exit 1
        fi
    else
        IFS='|' read -r binary_source_type resolved_version server_asset_url cli_asset_url < <(get_binary_release_asset_metadata "$rebecca_version" "$binary_arch")
        if [ "$binary_source_type" = "split" ]; then
            ui_spinner_run "Downloading Rebecca server binary" curl -fL "$server_asset_url" -o "$tmp_dir/rebecca-server"
            ui_spinner_run "Downloading Rebecca CLI binary" curl -fL "$cli_asset_url" -o "$tmp_dir/rebecca-cli"
        else
            package_path="$tmp_dir/rebecca-binary.tar.gz"
            ui_spinner_run "Downloading Rebecca binary package" curl -fL "$server_asset_url" -o "$package_path"
            ui_spinner_run "Unpacking Rebecca binary package" tar -xzf "$package_path" -C "$tmp_dir"
        fi
    fi

    if [ ! -f "$tmp_dir/rebecca-server" ] || [ ! -f "$tmp_dir/rebecca-cli" ]; then
        colorized_echo red "Downloaded binary package is incomplete; rebecca-server or rebecca-cli is missing." >&2
        rm -rf "$tmp_dir"
        exit 1
    fi

    mkdir -p "$BINARY_BIN_DIR" "$DATA_DIR" "$APP_DIR/scripts"
    install -m 755 "$tmp_dir/rebecca-server" "$BINARY_SERVER"
    install -m 755 "$tmp_dir/rebecca-cli" "$BINARY_CLI"
    install_binary_cli_launcher

    if [ ! -f "$ENV_FILE" ]; then
        ui_spinner_run "Fetching default .env file" curl -fsSL "$REBECCA_RAW_BASE/.env.example" -o "$ENV_FILE"
    fi

    upsert_env_assignment "REBECCA_DATA_DIR" "$DATA_DIR"
    upsert_env_assignment "XRAY_JSON" "$DATA_DIR/xray_config.json"
    if [ "$configure_database" = "1" ]; then
        configure_binary_database "$database_type"
    fi

    if [ ! -f "$DATA_DIR/xray_config.json" ]; then
        curl -fsSL --retry 3 --retry-delay 2 --retry-all-errors "$REBECCA_RAW_BASE/xray_config.json" -o "$DATA_DIR/xray_config.json" 2>/dev/null || {
            rm -f "$DATA_DIR/xray_config.json"
            colorized_echo yellow "No bundled xray_config.json found; Rebecca will use its built-in default."
        }
    fi

    write_binary_release_metadata "${resolved_version:-$rebecca_version}" "$binary_arch" "${artifact_url:-${server_asset_url:-}}"
    echo "binary" > "$INSTALL_MODE_FILE"
    create_binary_service
    rm -rf "$tmp_dir"
    colorized_echo green "Rebecca binary files installed successfully"
}

up_rebecca() {
    systemctl enable --now "$APP_NAME.service"
}

schedule_binary_service_restart() {
    local delay_seconds="${1:-1}"
    local unit_name="${APP_NAME}-delayed-restart-$(date +%s%N)"
    local restart_script="sleep ${delay_seconds}; systemctl restart ${APP_NAME}.service"

    if command -v systemd-run >/dev/null 2>&1; then
        systemd-run \
            --unit "$unit_name" \
            --collect \
            --description "Rebecca delayed service restart" \
            -- /bin/sh -c "$restart_script" >/dev/null
        return
    fi

    nohup /bin/sh -c "$restart_script" >/dev/null 2>&1 &
}

restart_binary_service_now() {
    systemctl restart "$APP_NAME.service"
}

follow_rebecca_logs() {
    journalctl -u "$APP_NAME.service" -f -o "$(journal_output_format)" --no-pager | format_rebecca_journal_logs
}

status_command() {
    if ! is_rebecca_installed; then
        echo -n "Status: "
        colorized_echo red "Not Installed"
        exit 1
    fi

    if ! is_rebecca_up; then
        echo -n "Status: "
        colorized_echo blue "Down"
        exit 1
    fi

    echo -n "Status: "
    colorized_echo green "Up"
    systemctl status "$APP_NAME.service" --no-pager
}

prompt_for_rebecca_password() {
    if [ -n "${MYSQL_PASSWORD:-}" ]; then
        if ! mysql_password_is_strong "$MYSQL_PASSWORD"; then
            colorized_echo red "MYSQL_PASSWORD is not strong enough. Use at least 12 chars with uppercase, lowercase, digit, and symbol."
            exit 1
        fi
        return
    fi
    MYSQL_PASSWORD=$(get_env_value "MYSQL_PASSWORD")
    if [ -n "${MYSQL_PASSWORD:-}" ]; then
        if ! mysql_password_is_strong "$MYSQL_PASSWORD"; then
            colorized_echo red "MYSQL_PASSWORD in .env is not strong enough. Use at least 12 chars with uppercase, lowercase, digit, and symbol."
            exit 1
        fi
        return
    fi
    if [ ! -t 0 ]; then
        MYSQL_PASSWORD=$(generate_secure_mysql_password)
        colorized_echo green "A secure database password has been generated automatically."
        return
    fi
    colorized_echo cyan "This password will be used to access the database and should be strong."
    colorized_echo cyan "Leave it empty to generate a secure password automatically."
    while true; do
        MYSQL_PASSWORD=$(read_secret "Database password: ")
        if [ -z "$MYSQL_PASSWORD" ]; then
            MYSQL_PASSWORD=$(generate_secure_mysql_password)
            colorized_echo green "A secure password has been generated automatically."
            break
        fi
        if mysql_password_is_strong "$MYSQL_PASSWORD"; then
            local confirm_password
            confirm_password=$(read_secret "Confirm database password: ")
            if [ "$MYSQL_PASSWORD" = "$confirm_password" ]; then
                break
            fi
            colorized_echo red "Passwords do not match."
        else
            colorized_echo red "Password must be at least 12 chars and include uppercase, lowercase, digit, and symbol. Press Enter for auto-generation."
        fi
    done
    colorized_echo green "This password will be recorded in the .env file for future use."
}

get_configured_database_type() {
    local flavor
    local db_url
    flavor=$(get_env_value "REBECCA_DATABASE_FLAVOR")
    case "$flavor" in
        mysql|mariadb|sqlite)
            echo "$flavor"
            return
        ;;
    esac

    db_url=$(get_env_value "SQLALCHEMY_DATABASE_URL")
    if [[ "$db_url" == sqlite* ]]; then
        echo "sqlite"
    elif [[ "$db_url" == mysql* ]]; then
        echo "mysql"
    else
        echo "sqlite"
    fi
}

mysql_root_command() {
    if command -v mysql >/dev/null 2>&1; then
        mysql --protocol=socket -uroot "$@"
    elif command -v mariadb >/dev/null 2>&1; then
        mariadb --protocol=socket -uroot "$@"
    else
        return 1
    fi
}

install_host_database() {
    local database_type="$1"
    local package_name
    local service_name
    local config_file

    case "$database_type" in
        mysql)
            package_name="mysql-server"
            service_name="mysql"
            config_file="/etc/mysql/mysql.conf.d/rebecca.cnf"
        ;;
        mariadb)
            package_name="mariadb-server"
            service_name="mariadb"
            config_file="/etc/mysql/mariadb.conf.d/60-rebecca.cnf"
        ;;
        *)
            return 0
        ;;
    esac

    detect_os
    if ! command -v mysql >/dev/null 2>&1 && ! command -v mariadb >/dev/null 2>&1; then
        install_package "$package_name" || {
            if [ "$database_type" = "mysql" ]; then
                install_package default-mysql-server
            else
                return 1
            fi
        }
    fi

    systemctl enable --now "$service_name" >/dev/null 2>&1 || systemctl enable --now mysql >/dev/null 2>&1 || true

    mkdir -p "$(dirname "$config_file")"
    cat > "$config_file" <<EOF
[mysqld]
bind-address=127.0.0.1
skip-name-resolve=ON
local-infile=0
symbolic-links=0
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
max_connections=200
EOF
    systemctl restart "$service_name" >/dev/null 2>&1 || systemctl restart mysql >/dev/null 2>&1 || true

    if [ -z "${MYSQL_PASSWORD:-}" ]; then
        prompt_for_rebecca_password
    fi
    MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-$(generate_secure_mysql_password)}"
    MYSQL_PASSWORD="${MYSQL_PASSWORD:-$(generate_secure_mysql_password)}"
    local escaped_password
    escaped_password=$(sql_escape_literal "$MYSQL_PASSWORD")

    local sql_file
    sql_file=$(mktemp)
    cat > "$sql_file" <<EOF
CREATE DATABASE IF NOT EXISTS \`rebecca\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'rebecca'@'127.0.0.1' IDENTIFIED BY '${escaped_password}';
CREATE USER IF NOT EXISTS 'rebecca'@'localhost' IDENTIFIED BY '${escaped_password}';
ALTER USER 'rebecca'@'127.0.0.1' IDENTIFIED BY '${escaped_password}';
ALTER USER 'rebecca'@'localhost' IDENTIFIED BY '${escaped_password}';
GRANT ALL PRIVILEGES ON \`rebecca\`.* TO 'rebecca'@'127.0.0.1';
GRANT ALL PRIVILEGES ON \`rebecca\`.* TO 'rebecca'@'localhost';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF
    if ! mysql_root_command < "$sql_file"; then
        rm -f "$sql_file"
        colorized_echo red "Failed to configure local $database_type. Make sure root can access MySQL/MariaDB through the local socket."
        exit 1
    fi
    rm -f "$sql_file"

    local mysql_password_url_encoded
    mysql_password_url_encoded=$(urlencode_value "$MYSQL_PASSWORD")
    upsert_env_assignment "REBECCA_DATABASE_FLAVOR" "$database_type"
    upsert_env_assignment "MYSQL_DATABASE" "rebecca"
    upsert_env_assignment "MYSQL_USER" "rebecca"
    upsert_env_assignment "MYSQL_PASSWORD" "$MYSQL_PASSWORD"
    upsert_env_assignment "MYSQL_ROOT_PASSWORD" "$MYSQL_ROOT_PASSWORD"
    upsert_env_assignment "SQLALCHEMY_DATABASE_URL" "mysql+pymysql://rebecca:${mysql_password_url_encoded}@127.0.0.1:3306/rebecca"
}

configure_binary_database() {
    local database_type="${1:-mysql}"
    case "$database_type" in
        sqlite|"")
            upsert_env_assignment "REBECCA_DATABASE_FLAVOR" "sqlite"
            upsert_env_assignment "SQLALCHEMY_DATABASE_URL" "sqlite:///${DATA_DIR}/db.sqlite3"
        ;;
        mysql|mariadb)
            install_host_database "$database_type"
        ;;
        *)
            colorized_echo red "Unsupported database type for binary install: $database_type"
            exit 1
        ;;
    esac
}

install_rebecca_script() {
    local temp_script
    temp_script=$(mktemp)
    SCRIPT_URL="$REBECCA_SCRIPT_BASE_URL/$REBECCA_SCRIPT_SOURCE_FILE"
    ui_spinner_run "Downloading Rebecca command script" curl -fsSL "$SCRIPT_URL" -o "$temp_script"
    if head -n 1 "$temp_script" | grep -qi "<!DOCTYPE"; then
        rm -f "$temp_script"
        colorized_echo red "Unexpected HTML response while downloading script"
        exit 1
    fi
    ui_spinner_run "Installing Rebecca command script" install -m 755 "$temp_script" "$REBECCA_SCRIPT_INSTALL_PATH"
    rm -f "$temp_script"
    colorized_echo green "rebecca script installed successfully"
}

install_command() {
    check_running_as_root

    # Always install dev version
    rebecca_version="dev"
    database_type=""
    if [ -t 0 ]; then
        database_type=$(select_database_type_interactive)
    else
        database_type="mysql"
    fi
    set_rebecca_source_ref "$rebecca_version"

    detect_os
    for package in curl jq; do
        if ! command -v "$package" >/dev/null 2>&1; then
            install_package "$package"
        fi
    done

    install_rebecca_script

    if is_rebecca_installed; then
        colorized_echo red "Rebecca is already installed at $APP_DIR"
        read -p "Do you want to override the previous installation? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            exit 1
        fi
    fi

    install_binary_rebecca "$rebecca_version" "$database_type"
    prompt_dashboard_bind_settings
    prompt_initial_admin
    prompt_ssl_setup

    if [ "$(get_configured_database_type)" != "sqlite" ]; then
        if ui_read_yes_no "Install phpMyAdmin for this database?" "n"; then
            prompt_phpmyadmin_settings
            enable_host_phpmyadmin "$PHPMYADMIN_PATH"
        fi
    fi

    create_initial_admin_if_requested
    up_rebecca
    follow_rebecca_logs
}

down_rebecca() {
    systemctl stop "$APP_NAME.service"
}

show_rebecca_logs() {
    journalctl -u "$APP_NAME.service" -o "$(journal_output_format)" --no-pager | format_rebecca_journal_logs
}

rebecca_cli() {
    REBECCA_ENV_FILE="$ENV_FILE" REBECCA_APP_DIR="$APP_DIR" REBECCA_DATA_DIR="$DATA_DIR" CLI_PROG_NAME="rebecca cli" "$BINARY_CLI" "$@"
}

is_rebecca_up() {
    systemctl is-active --quiet "$APP_NAME.service"
}

uninstall_rebecca_script() {
    if [ -f "/usr/local/bin/rebecca" ]; then
        colorized_echo yellow "Removing rebecca script"
        rm "/usr/local/bin/rebecca"
    fi
}

uninstall_rebecca() {
    if [ -f "$BINARY_SERVICE_UNIT" ]; then
        systemctl disable --now "$APP_NAME.service" >/dev/null 2>&1 || true
        rm -f "$BINARY_SERVICE_UNIT"
        systemctl daemon-reload
    fi
    if [ -f "$BINARY_CLI_LAUNCHER" ] || [ -L "$BINARY_CLI_LAUNCHER" ]; then
        rm -f "$BINARY_CLI_LAUNCHER"
    fi
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}

uninstall_rebecca_data_files() {
    if [ -d "$DATA_DIR" ]; then
        colorized_echo yellow "Removing directory: $DATA_DIR"
        rm -r "$DATA_DIR"
    fi
}

uninstall_command() {
    check_running_as_root
    local app_exists=0
    if is_rebecca_installed; then
        app_exists=1
    fi

    if [ "$app_exists" -eq 0 ]; then
        colorized_echo red "Rebecca's not installed!"
        exit 1
    fi

    read -p "Do you really want to uninstall Rebecca? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Aborted"
        exit 1
    fi

    if [ "$app_exists" -eq 1 ]; then
        if is_rebecca_up; then
            down_rebecca
        fi
    fi
    uninstall_rebecca_script

    if [ "$app_exists" -eq 1 ]; then
        uninstall_rebecca
        read -p "Do you want to remove Rebecca's data files too ($DATA_DIR)? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo green "Rebecca uninstalled successfully"
        else
            uninstall_rebecca_data_files
            colorized_echo green "Rebecca uninstalled successfully"
        fi
    else
        colorized_echo green "Legacy Rebecca script removed"
    fi
}

restart_command() {
    help() {
        colorized_echo red "Usage: rebecca restart [options]"
        echo
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs)
                no_logs=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    if ! is_rebecca_installed; then
        colorized_echo red "Rebecca's not installed!"
        exit 1
    fi
    
    if [ "$no_logs" = true ]; then
        schedule_binary_service_restart 1
        colorized_echo green "Rebecca restart scheduled."
        return
    fi
    restart_binary_service_now
    follow_rebecca_logs
}

logs_command() {
    help() {
        colorized_echo red "Usage: rebecca logs [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-follow   do not show follow logs"
    }
    
    local no_follow=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-follow)
                no_follow=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    if ! is_rebecca_installed; then
        colorized_echo red "Rebecca's not installed!"
        exit 1
    fi
    
    if ! is_rebecca_up; then
        colorized_echo red "Rebecca is not up."
        exit 1
    fi
    
    if [ "$no_follow" = true ]; then
        show_rebecca_logs
    else
        follow_rebecca_logs
    fi
}

down_command() {
    if ! is_rebecca_installed; then
        colorized_echo red "Rebecca's not installed!"
        exit 1
    fi
    
    if ! is_rebecca_up; then
        colorized_echo red "Rebecca's already down"
        exit 1
    fi
    
    down_rebecca
}

cli_command() {
    if [ $# -eq 0 ]; then
        menu_cli
        return
    fi

    # ??? ??????? ????? ??? ??? ???? ??
    if ! is_rebecca_installed; then
        colorized_echo red "Rebecca's not installed!"
        exit 1
    fi
    
    if ! is_rebecca_up; then
        colorized_echo red "Rebecca is not up."
        exit 1
    fi
    
    REBECCA_ENV_FILE="$ENV_FILE" REBECCA_APP_DIR="$APP_DIR" REBECCA_DATA_DIR="$DATA_DIR" CLI_PROG_NAME="rebecca cli" "$BINARY_CLI" "$@"
}
menu_migrate() {
    local commands=(
        "up:Apply all pending migrations"
        "down:Rollback last migration"
        "status:Show migration status"
        "back:Return to CLI menu"
    )
    local total=${#commands[@]}

    while true; do
        ui_clear
        ui_header "Database Migrations" "Choose an action"
        for i in "${!commands[@]}"; do
            local cmd="${commands[$i]%%:*}"
            local desc="${commands[$i]#*:}"
            printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$((i+1))" "$cmd" "$desc"
        done
        echo
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r choice

        case "$choice" in
            q|Q) echo; exit 0 ;;
            back|0) return ;;
            [1-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                    local sub="${commands[$((choice-1))]%%:*}"
                    case "$sub" in
                        up) cli_command migrate up; read -p "Press Enter to continue..." ;;
                        down) cli_command migrate down; read -p "Press Enter to continue..." ;;
                        status) cli_command migrate status; read -p "Press Enter to continue..." ;;
                        back) return ;;
                    esac
                else
                    colorized_echo red "Invalid choice."
                    sleep 1
                fi
                ;;
            *) colorized_echo red "Invalid choice."; sleep 1 ;;
        esac
    done
}
menu_subscription() {
    local commands=(
        "list:List all subscriptions"
        "create:Create a subscription"
        "delete:Delete a subscription"
        "back:Return to CLI menu"
    )
    local total=${#commands[@]}

    while true; do
        ui_clear
        ui_header "Subscription Management" "Choose an action"
        for i in "${!commands[@]}"; do
            local cmd="${commands[$i]%%:*}"
            local desc="${commands[$i]#*:}"
            printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$((i+1))" "$cmd" "$desc"
        done
        echo
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r choice

        case "$choice" in
            q|Q) echo; exit 0 ;;
            back|0) return ;;
            [1-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                    local sub="${commands[$((choice-1))]%%:*}"
                    case "$sub" in
                        list)
                            cli_command subscription list
                            read -p "Press Enter to continue..."
                            ;;
                        create)
                            read -p "User ID: " user_id
                            read -p "Plan: " plan
                            cli_command subscription create --user "$user_id" --plan "$plan"
                            read -p "Press Enter to continue..."
                            ;;
                        delete)
                            read -p "Subscription ID: " sub_id
                            cli_command subscription delete "$sub_id"
                            read -p "Press Enter to continue..."
                            ;;
                        back) return ;;
                    esac
                else
                    colorized_echo red "Invalid choice."
                    sleep 1
                fi
                ;;
            *) colorized_echo red "Invalid choice."; sleep 1 ;;
        esac
    done
}
menu_user() {
    local commands=(
        "create:Create a new user"
        "list:List all users"
        "delete:Delete a user"
        "reset-password:Reset user password"
        "edit:Edit user details"
        "enable:Enable a user"
        "disable:Disable a user"
        "back:Return to CLI menu"
    )
    local total=${#commands[@]}

    while true; do
        ui_clear
        ui_header "User Management" "Choose an action"
        for i in "${!commands[@]}"; do
            local cmd="${commands[$i]%%:*}"
            local desc="${commands[$i]#*:}"
            printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$((i+1))" "$cmd" "$desc"
        done
        echo
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r choice

        case "$choice" in
            q|Q) echo; exit 0 ;;
            back|0) return ;;
            [1-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                    local sub="${commands[$((choice-1))]%%:*}"
                    case "$sub" in
                        create)
                            read -p "Username: " username
                            read -s -p "Password: " password; echo
                            read -p "Data limit (MB): " limit
                            read -p "Expiry (YYYY-MM-DD): " expiry
                            cli_command user create "$username" --password "$password" --data-limit "$limit" --expiry "$expiry"
                            read -p "Press Enter to continue..."
                            ;;
                        list)
                            cli_command user list
                            read -p "Press Enter to continue..."
                            ;;
                        delete)
                            read -p "Username to delete: " username
                            cli_command user delete "$username"
                            read -p "Press Enter to continue..."
                            ;;
                        reset-password)
                            read -p "Username: " username
                            read -s -p "New password: " password; echo
                            cli_command user reset-password "$username" --password "$password"
                            read -p "Press Enter to continue..."
                            ;;
                        edit)
                            read -p "Username: " username
                            read -p "New data limit (MB, optional): " limit
                            read -p "New expiry (YYYY-MM-DD, optional): " expiry
                            cli_command user edit "$username" --data-limit "$limit" --expiry "$expiry"
                            read -p "Press Enter to continue..."
                            ;;
                        enable)
                            read -p "Username: " username
                            cli_command user enable "$username"
                            read -p "Press Enter to continue..."
                            ;;
                        disable)
                            read -p "Username: " username
                            cli_command user disable "$username"
                            read -p "Press Enter to continue..."
                            ;;
                        back) return ;;
                    esac
                else
                    colorized_echo red "Invalid choice."
                    sleep 1
                fi
                ;;
            *) colorized_echo red "Invalid choice."; sleep 1 ;;
        esac
    done
}
menu_admin() {
    local commands=(
        "create:Create a new admin"
        "list:List all admins"
        "delete:Delete an admin"
        "reset-password:Reset admin password"
        "edit:Edit admin details"
        "back:Return to CLI menu"
    )
    local total=${#commands[@]}

    while true; do
        ui_clear
        ui_header "Admin Management" "Choose an action"
        for i in "${!commands[@]}"; do
            local cmd="${commands[$i]%%:*}"
            local desc="${commands[$i]#*:}"
            printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$((i+1))" "$cmd" "$desc"
        done
        echo
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r choice

        case "$choice" in
            q|Q) echo; exit 0 ;;
            back|0) return ;;
            [1-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                    local sub="${commands[$((choice-1))]%%:*}"
                    case "$sub" in
                        create)
                            read -p "Username: " username
                            read -s -p "Password: " password; echo
                            read -p "Role (full_access|limited): " role
                            cli_command admin create "$username" --role "$role" --password "$password"
                            read -p "Press Enter to continue..."
                            ;;
                        list)
                            cli_command admin list
                            read -p "Press Enter to continue..."
                            ;;
                        delete)
                            read -p "Username to delete: " username
                            cli_command admin delete "$username"
                            read -p "Press Enter to continue..."
                            ;;
                        reset-password)
                            read -p "Username: " username
                            read -s -p "New password: " password; echo
                            cli_command admin reset-password "$username" --password "$password"
                            read -p "Press Enter to continue..."
                            ;;
                        edit)
                            read -p "Username: " username
                            read -p "New role (optional): " role
                            cli_command admin edit "$username" --role "$role"
                            read -p "Press Enter to continue..."
                            ;;
                        back) return ;;
                    esac
                else
                    colorized_echo red "Invalid choice."
                    sleep 1
                fi
                ;;
            *) colorized_echo red "Invalid choice."; sleep 1 ;;
        esac
    done
}
menu_cli() {
    local commands=(
        "admin:Manage admins"
        "user:Manage users"
        "subscription:Subscription helpers"
        "migrate:Database migrations"
        "back:Return to main menu"
    )
    local total=${#commands[@]}

    while true; do
        ui_clear
        ui_header "Rebecca CLI" "Select a CLI command"
        echo
        for i in "${!commands[@]}"; do
            local cmd="${commands[$i]%%:*}"
            local desc="${commands[$i]#*:}"
            printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$((i+1))" "$cmd" "$desc"
        done
        echo
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r choice

        case "$choice" in
            q|Q) echo; exit 0 ;;
            back|0) return ;;
            [1-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                    local selected_cmd="${commands[$((choice-1))]%%:*}"
                    case "$selected_cmd" in
                        admin) menu_admin ;;
                        user) menu_user ;;
                        subscription) menu_subscription ;;
                        migrate) menu_migrate ;;
                        back) return ;;
                    esac
                else
                    colorized_echo red "Invalid choice."
                    sleep 1
                fi
                ;;
            *) colorized_echo red "Invalid choice."; sleep 1 ;;
        esac
    done
}


up_command() {
    help() {
        colorized_echo red "Usage: rebecca up [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs)
                no_logs=true
            ;;
            -h|--help)
                help
                exit 0
            ;;
            *)
                echo "Error: Invalid option: $1" >&2
                help
                exit 0
            ;;
        esac
        shift
    done
    
    if ! is_rebecca_installed; then
        colorized_echo red "Rebecca's not installed!"
        exit 1
    fi
    
    if is_rebecca_up; then
        colorized_echo red "Rebecca's already up"
        exit 1
    fi
    
    up_rebecca
    if [ "$no_logs" = false ]; then
        follow_rebecca_logs
    fi
}

update_command() {
    check_running_as_root

    if ! is_rebecca_installed; then
        colorized_echo red "Rebecca's not installed!"
        exit 1
    fi

    # Always update to dev
    rebecca_version="dev"
    set_rebecca_source_ref "$rebecca_version"
    
    colorized_echo blue "Updating Rebecca CLI..."
    update_rebecca_script

    colorized_echo blue "Updating to dev version"
    update_rebecca "$rebecca_version"
    write_rebecca_channel "$rebecca_version"
    
    colorized_echo blue "Restarting Rebecca's services"
    schedule_binary_service_restart 1
    colorized_echo blue "Rebecca updated successfully; restart scheduled."
}

update_rebecca_script() {
    local temp_script
    temp_script=$(mktemp)
    SCRIPT_URL="$REBECCA_SCRIPT_BASE_URL/$REBECCA_SCRIPT_SOURCE_FILE"
    colorized_echo blue "Updating rebecca script"
    curl -fsSL "$SCRIPT_URL" -o "$temp_script"
    if head -n 1 "$temp_script" | grep -qi "<!DOCTYPE"; then
        rm -f "$temp_script"
        colorized_echo red "Unexpected HTML response while downloading script"
        exit 1
    fi
    install -m 755 "$temp_script" "$REBECCA_SCRIPT_INSTALL_PATH"
    rm -f "$temp_script"
    colorized_echo green "rebecca script updated successfully"
}

update_rebecca() {
    local rebecca_version="${1:-dev}"
    install_binary_rebecca "$rebecca_version" "$(get_configured_database_type)" "0"
}

write_rebecca_channel() {
    local channel="${1:-dev}"
    mkdir -p "$APP_DIR"
    echo "$channel" > "$CHANNEL_FILE"
}

edit_command() {
    detect_os
    check_editor
    if [ -f "$ENV_FILE" ]; then
        $EDITOR "$ENV_FILE"
    else
        colorized_echo red "Environment file not found at $ENV_FILE"
        exit 1
    fi
}

edit_env_command() {
    edit_command
}

menu_commands() {
    echo "up down restart status logs cli migrate backup backup-service install update uninstall script-install script-update script-uninstall core-update enable-phpmyadmin disable-phpmyadmin edit edit-env ssl help"
}

menu_category_for() {
    case "$1" in
        up|down|restart|status|logs) echo "Panel runtime" ;;
        cli|migrate|backup|backup-service) echo "Administration and data" ;;
        install|update|uninstall) echo "Install and update" ;;
        script-install|script-update|script-uninstall) echo "Script management" ;;
        core-update|enable-phpmyadmin|disable-phpmyadmin|edit|edit-env|ssl) echo "Tools and legacy" ;;
        *) echo "Help" ;;
    esac
}

menu_description_for() {
    case "$1" in
        up) echo "Start services" ;;
        down) echo "Stop services" ;;
        restart) echo "Restart services" ;;
        status) echo "Show status" ;;
        logs) echo "Show logs" ;;
        cli) echo "Rebecca CLI" ;;
        migrate) echo "Run database migrations" ;;
        backup) echo "Manual backup launch" ;;
        backup-service) echo "Backup service (Telegram + cron job)" ;;
        install) echo "Install Rebecca" ;;
        update) echo "Update to dev version" ;;
        uninstall) echo "Uninstall Rebecca" ;;
        script-install) echo "Install Rebecca script" ;;
        script-update) echo "Update Rebecca CLI script" ;;
        script-uninstall) echo "Uninstall Rebecca script" ;;
        core-update) echo "Deprecated; Xray is managed by nodes" ;;
        enable-phpmyadmin) echo "Enable phpMyAdmin on local MySQL/MariaDB" ;;
        disable-phpmyadmin) echo "Disable phpMyAdmin panel bridge" ;;
        edit) echo "Edit environment file" ;;
        edit-env) echo "Edit environment file" ;;
        ssl) echo "Issue or renew SSL certificates" ;;
        help) echo "Show this help message" ;;
        *) echo "" ;;
    esac
}

print_menu() {
    local selected="${1:-0}"
    local previous_category=""
    local idx=1
    local cmd category desc is_selected columns tip_width tip
    ui_header "Rebecca Panel" "Control center"
    ui_section "Status"
    print_menu_status_summary
    ui_section "Actions"
    for cmd in $(menu_commands); do
        category=$(menu_category_for "$cmd")
        if [ "$category" != "$previous_category" ]; then
            ui_menu_category "$category"
            previous_category="$category"
        fi
        desc=$(menu_description_for "$cmd")
        is_selected=0
        [ "$idx" -eq "$selected" ] && is_selected=1
        ui_menu_item "$idx" "$cmd" "$desc" "$is_selected"
        idx=$((idx + 1))
    done
    printf "\n"
    columns=$(ui_terminal_columns)
    tip_width=$((columns - 1))
    tip="Tip: arrow keys move, Enter selects, q exits; numbers and commands also work."
    ui_color "38;5;245" "${tip:0:$tip_width}"
    printf "\n"
    echo
}

ui_menu_lines_below_item() {
    local target="$1"
    local idx=1 lines=4 previous_category="" cmd category
    for cmd in $(menu_commands); do
        category=$(menu_category_for "$cmd")
        if [ "$idx" -gt "$target" ]; then
            [ "$category" != "$previous_category" ] && lines=$((lines + 2))
            lines=$((lines + 1))
        fi
        previous_category="$category"
        idx=$((idx + 1))
    done
    printf "%s" "$lines"
}

ui_redraw_menu_item() {
    local index="$1" selected="$2" distance
    local commands=($(menu_commands))
    local command="${commands[$((index - 1))]}"
    distance=$(ui_menu_lines_below_item "$index")
    printf "\033[%sA\r\033[2K" "$distance"
    ui_menu_item "$index" "$command" "$(menu_description_for "$command")" "$selected"
    if [ "$distance" -gt 1 ]; then
        printf "\033[%sB\r" "$((distance - 1))"
    fi
}

ui_menu_prompt() {
    local columns prompt
    columns=$(ui_terminal_columns)
    if [ "$columns" -lt 30 ]; then
        prompt="Select: "
    elif [ "$columns" -lt 55 ]; then
        prompt="Select (arrows/Enter/number): "
    else
        prompt="Select option (arrow keys, Enter, number, command): "
    fi
    prompt="${prompt:0:$((columns - 1))}"
    ui_color "38;5;45;1" "$prompt"
}

map_choice_to_command() {
    local commands=($(menu_commands))

    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le "${#commands[@]}" ]; then
        echo "${commands[$(($1 - 1))]}"
        return
    fi
    echo "$1"
}

read_menu_command() {
    local commands=($(menu_commands))
    local total=${#commands[@]}

    while true; do
        ui_clear
        print_menu
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r user_choice

        if [[ "$user_choice" == "q" || "$user_choice" == "Q" ]]; then
            echo
            exit 0
        fi

        MENU_COMMAND=$(map_choice_to_command "$user_choice")

        if [[ " ${commands[*]} " =~ " ${MENU_COMMAND} " ]] && [ -n "$MENU_COMMAND" ]; then
            echo
            return 0
        fi

        colorized_echo red "Invalid choice. Please enter a number between 1 and $total."
        sleep 1.5
    done
}

usage() {
    local script_name="${0##*/}"
    colorized_echo blue "=============================="
    colorized_echo magenta "           Rebecca Help"
    colorized_echo blue "=============================="
    colorized_echo cyan "Usage:"
    echo "  ${script_name} [command]"
    echo

    colorized_echo cyan "Commands:"
    colorized_echo yellow "  up              – Start services"
    colorized_echo yellow "  down            – Stop services"
    colorized_echo yellow "  restart         – Restart services"
    colorized_echo yellow "  status          – Show status"
    colorized_echo yellow "  logs            - Show logs"
    colorized_echo yellow "  cli             - Rebecca CLI"
    colorized_echo yellow "  migrate         - Run database migrations"
    colorized_echo yellow "  install         - Install Rebecca (always dev)"
    colorized_echo yellow "  update          - Update to dev version"
    colorized_echo yellow "  uninstall       - Uninstall Rebecca"
    colorized_echo yellow "  script-install  - Install Rebecca script"
    colorized_echo yellow "  script-update   - Update Rebecca CLI script"
    colorized_echo yellow "  script-uninstall  - Uninstall Rebecca script"
    colorized_echo yellow "  backup          - Manual backup launch"
    colorized_echo yellow "  backup-service  - Backup service to Telegram"
    colorized_echo yellow "  core-update     - Deprecated; Xray is managed by nodes"
    colorized_echo yellow "  enable-phpmyadmin - Enable phpMyAdmin for local MySQL/MariaDB"
    colorized_echo yellow "  disable-phpmyadmin - Disable phpMyAdmin"
    colorized_echo yellow "  edit            - Edit environment file"
    colorized_echo yellow "  edit-env        - Edit environment file"
    colorized_echo yellow "  ssl             - Issue or renew SSL certificates"
    colorized_echo yellow "  help            - Show this help message"
    
    echo
    colorized_echo cyan "Directories:"
    colorized_echo magenta "  App directory: $APP_DIR"
    colorized_echo magenta "  Data directory: $DATA_DIR"
    echo
    colorized_echo magenta "  This script installs binary mode only and always uses dev version."
    echo
    current_version=$(get_current_xray_core_version)
    colorized_echo cyan "Current Xray-core version: $current_version"
    colorized_echo blue "================================"
    echo
}
menu_migrate() {
    local commands=(
        "up:Apply all pending migrations"
        "down:Rollback last migration"
        "status:Show migration status"
        "back:Return to main menu"
    )
    local total=${#commands[@]}

    while true; do
        ui_clear
        ui_header "Database Migrations" "Choose an action"
        for i in "${!commands[@]}"; do
            local cmd="${commands[$i]%%:*}"
            local desc="${commands[$i]#*:}"
            printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-18s\033[0m \033[38;5;245m%s\033[0m\n" "$((i+1))" "$cmd" "$desc"
        done
        echo
        ui_color "38;5;45;1" "Select an option [1-$total] or 'q' to quit: "
        read -r choice

        case "$choice" in
            q|Q) echo; exit 0 ;;
            back|0) return ;;
            [1-9]*)
                if [ "$choice" -ge 1 ] && [ "$choice" -le "$total" ]; then
                    local sub="${commands[$((choice-1))]%%:*}"
                    case "$sub" in
                        up) cli_command migrate up; read -p "Press Enter to continue..." ;;
                        down) cli_command migrate down; read -p "Press Enter to continue..." ;;
                        status) cli_command migrate status; read -p "Press Enter to continue..." ;;
                        back) return ;;
                    esac
                else
                    colorized_echo red "Invalid choice."
                    sleep 1
                fi
                ;;
            *) colorized_echo red "Invalid choice."; sleep 1 ;;
        esac
    done
}
migrate_command() {
    if [ $# -eq 0 ]; then
        menu_migrate
    else
        cli_command migrate "$@"
    fi
}
dispatch_command() {
    local cmd="$1"
    shift || true
    case "$cmd" in
        help|install|script-install|install-script|script-update|update-script|script-uninstall|uninstall-script)
            ;;
        *)
            ;;
    esac
    case "$cmd" in
        up) up_command "$@" ;;
        down) down_command "$@" ;;
        restart) restart_command "$@" ;;
        status) status_command "$@" ;;
        logs) logs_command "$@" ;;
        cli) cli_command "$@" ;;
        migrate) migrate_command "$@" ;;
        backup) backup_command "$@" ;;
        backup-service) backup_service "$@" ;;
        install) install_command "$@" ;;
        update) update_command "$@" ;;
        uninstall) uninstall_command "$@" ;;
        script-install|install-script) install_rebecca_script "$@" ;;
        script-update|update-script) install_rebecca_script "$@" ;;
        script-uninstall|uninstall-script) uninstall_rebecca_script "$@" ;;
        core-update) update_core_command "$@" ;;
        enable-phpmyadmin) enable_phpmyadmin "$@" ;;
        disable-phpmyadmin) disable_phpmyadmin "$@" ;;
        ssl) ssl_command "$@" ;;
        edit) edit_command "$@" ;;
        edit-env) edit_env_command "$@" ;;
        help) usage ;;
        *) usage ;;
    esac
}

if [ $# -eq 0 ]; then
    read_menu_command || exit 0
    set -- $MENU_COMMAND
fi

dispatch_command "$@"