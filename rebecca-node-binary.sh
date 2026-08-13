#!/usr/bin/env bash
set -e

APP_NAME_FROM_ARG=0
INSTALL_DIR="/opt"
NODE_DISCOVERY_BASE="/opt"
SKIP_SERVICE_UPDATE=0
NODE_VERSION_REQUESTED=""
NODE_VERSION_SET=0
REBECCA_NODE_SCRIPT_SOURCE_FILE="${REBECCA_NODE_SCRIPT_SOURCE_FILE:-rebecca-node-binary.sh}"

SCRIPT_DEFAULT_APP_NAME="${REBECCA_NODE_DEFAULT_APP_NAME:-rebecca-node}"

declare -a DISCOVERED_NODE_PATHS=()
declare -a DISCOVERED_NODE_NAMES=()

ensure_valid_app_name() {
    local candidate="${APP_NAME:-$SCRIPT_DEFAULT_APP_NAME}"
    
    if [[ "$candidate" != rebecca-node* ]]; then
        candidate="rebecca-node-${candidate}"
    fi
    
    if ! [[ "$candidate" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]]; then
        candidate="rebecca-node"
        echo "Invalid app name detected. Falling back to default: $candidate"
    fi
    APP_NAME="$candidate"
}

set_app_context() {
    if [ -z "$APP_NAME" ]; then
        APP_NAME="$SCRIPT_DEFAULT_APP_NAME"
    fi
    ensure_valid_app_name

    if [ -z "${APP_DIR:-}" ] || [ ! -d "$APP_DIR" ]; then
        if [ -d "$INSTALL_DIR/$APP_NAME" ]; then
            APP_DIR="$INSTALL_DIR/$APP_NAME"
        elif [ -d "$INSTALL_DIR/Rebecca-node" ]; then
            APP_DIR="$INSTALL_DIR/Rebecca-node"
        else
            APP_DIR="$INSTALL_DIR/$APP_NAME"
        fi
    fi

    DATA_DIR="/var/lib/$APP_NAME"
    DATA_MAIN_DIR="/var/lib/$APP_NAME"
    BRANCH_FILE="$APP_DIR/.branch"
    CERT_FILE="$DATA_DIR/cert.pem"
    CERT_KEY_FILE="$DATA_DIR/cert.key"
    ENV_FILE="$APP_DIR/.env"

    BINARY_BIN_DIR="$APP_DIR/bin"
    BINARY_NODE="$BINARY_BIN_DIR/rebecca-node"
    BINARY_METADATA_FILE="$APP_DIR/.binary-release.json"
    BINARY_SERVICE_UNIT="/etc/systemd/system/${APP_NAME}.service"
}

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        install|update|uninstall|up|down|restart|status|logs|core-update|install-script|update-script|uninstall-script|edit|script-install|script-update|script-uninstall|help)
            COMMAND="$1"
            shift
        ;;
        --name)
            if [[ "$COMMAND" == "install" || "$COMMAND" == "install-script" || "$COMMAND" == "script-install" ]]; then
                APP_NAME="$2"
                APP_NAME_FROM_ARG=1
                shift
            else
                echo "Error: --name parameter is only allowed with 'install' or 'install-script' commands."
                exit 1
            fi
            shift
        ;;
        *)
            shift
        ;;
    esac
done

NODE_IP=$(curl -s -4 ifconfig.io)
if [ -z "$NODE_IP" ]; then
    NODE_IP=$(curl -s -6 ifconfig.io)
fi

INVOKED_CMD="$(basename "$0")"

if [ "$APP_NAME_FROM_ARG" -eq 0 ]; then
    if [ -n "${REBECCA_NODE_APP_NAME:-}" ]; then
        APP_NAME="$REBECCA_NODE_APP_NAME"
    elif [[ "$INVOKED_CMD" != *.sh && "$INVOKED_CMD" != "bash" && "$INVOKED_CMD" != "sh" && "$INVOKED_CMD" != "curl" && "$INVOKED_CMD" != "wget" && "$INVOKED_CMD" != "rebecca-node" ]]; then
        APP_NAME="$INVOKED_CMD"
    elif [[ "$COMMAND" == "install" || "$COMMAND" == "install-script" || "$COMMAND" == "script-install" ]]; then
        APP_NAME="$SCRIPT_DEFAULT_APP_NAME"
    elif [ -z "${APP_NAME:-}" ]; then
        APP_NAME="$SCRIPT_DEFAULT_APP_NAME"
    fi
fi
ensure_valid_app_name

LAST_XRAY_CORES=5
REBECCA_REPO="${REBECCA_REPO:-rebeccapanel/Rebecca}"
REBECCA_REF="${REBECCA_REF:-master}"
REBECCA_SCRIPT_BASE_URL="${REBECCA_SCRIPT_BASE_URL:-https://raw.githubusercontent.com/${REBECCA_REPO}/${REBECCA_REF}/scripts/rebecca}"
REBECCA_NODE_RELEASE_REPO="${REBECCA_NODE_RELEASE_REPO:-rebeccapanel/Rebecca-node}"
REBECCA_NODE_BINARY_DEV_BRANCH="${REBECCA_NODE_BINARY_DEV_BRANCH:-dev}"
REBECCA_NODE_BINARY_DEV_RELEASE_TAG="${REBECCA_NODE_BINARY_DEV_RELEASE_TAG:-dev-binaries}"
REBECCA_NODE_BINARY_WORKFLOW_NAME="${REBECCA_NODE_BINARY_WORKFLOW_NAME:-binary-build}"
REBECCA_NODE_BINARY_ARTIFACT_PREFIX="${REBECCA_NODE_BINARY_ARTIFACT_PREFIX:-rebecca-node-binaries}"
DEFAULT_XRAY_CORE_VERSION="${DEFAULT_XRAY_CORE_VERSION:-v26.7.11}"

BRANCH="dev"
SCRIPT_URL="$REBECCA_SCRIPT_BASE_URL/$REBECCA_NODE_SCRIPT_SOURCE_FILE"

colorized_echo() {
    local color=$1
    local text=$2
    local style=${3:-0}

    case $color in
        "red") printf "\e[${style};91m${text}\e[0m\n" ;;
        "green") printf "\e[${style};92m${text}\e[0m\n" ;;
        "yellow") printf "\e[${style};93m${text}\e[0m\n" ;;
        "blue") printf "\e[${style};94m${text}\e[0m\n" ;;
        "magenta") printf "\e[${style};95m${text}\e[0m\n" ;;
        "cyan") printf "\e[${style};96m${text}\e[0m\n" ;;
        *) echo "${text}" ;;
    esac
}

ui_is_tty() { [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; }

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
    ui_color "38;5;39" "────────────────────────────────────────────────────────────"
    printf "\n"
}

ui_header() {
    local title="$1"
    local subtitle="${2:-}"
    printf "\n"
    ui_color "38;5;45;1" "╭──────────────────────────────────────────────────────────╮"
    printf "\n  "
    ui_color "38;5;231;1" "$title"
    printf "\n"
    if [ -n "$subtitle" ]; then
        printf "  "
        ui_color "38;5;117" "$subtitle"
        printf "\n"
    fi
    ui_color "38;5;45;1" "╰──────────────────────────────────────────────────────────╯"
    printf "\n"
}

ui_section() {
    printf "\n"
    ui_color "38;5;45;1" "◆ $1"
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

ui_menu_category() {
    printf "\n"
    ui_color "38;5;117;1" "  $1"
    printf "\n"
}

ui_clear() {
    if ui_is_tty; then printf "\033[H\033[2J"; fi
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
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
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
        ui_color "38;5;82;1" "✓"
        printf " %s\n" "$message"
        rm -f "$log_file"
        return 0
    fi

    ui_color "38;5;196;1" "✗"
    printf " %s\n" "$message"
    tail -n 80 "$log_file" >&2 || true
    rm -f "$log_file"
    return "$status"
}

ensure_env_file() {
    mkdir -p "$(dirname "$ENV_FILE")"
    touch "$ENV_FILE"
}

set_env_value() {
    local key="$1"
    local value="$2"
    value=$(echo "$value" | sed 's/^"//;s/"$//')
    ensure_env_file
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = \"${value}\"|" "$ENV_FILE"
    else
        echo "${key} = \"${value}\"" >> "$ENV_FILE"
    fi
}

get_env_value() {
    local key="$1"
    if [ ! -f "$ENV_FILE" ]; then return; fi

    grep -E "^[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" 2>/dev/null \
        | tail -n 1 \
        | sed -E 's/^[^=]+=//; s/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//'
}

add_discovered_node_instance() {
    local dir="$1"
    local name="$2"
    local existing

    for existing in "${DISCOVERED_NODE_PATHS[@]}"; do
        if [ "$existing" = "$dir" ]; then return; fi
    done

    if [ -z "$name" ]; then name=$(basename "$dir"); fi
    DISCOVERED_NODE_PATHS+=("$dir")
    DISCOVERED_NODE_NAMES+=("$name")
}



set_app_context

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
    if [ -z "$matches" ]; then return 1; fi
    colorized_echo yellow "Removing broken XanMod apt source entries"
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        case "$file" in
            /etc/apt/sources.list) sed -i.bak '/deb\.xanmod\.org/d;/xanmod\.org/d' "$file" ;;
            /etc/apt/sources.list.d/*) rm -f "$file" ;;
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
        ui_spinner_run "Updating package index" apt_update_with_repo_repair
    elif [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]]; then
        PKG_MANAGER="yum"
        ui_spinner_run "Updating package index" "$PKG_MANAGER" update -y -q
        ui_spinner_run "Installing EPEL repository" "$PKG_MANAGER" install -y -q epel-release
    elif [[ "$OS" == "Fedora"* ]]; then
        PKG_MANAGER="dnf"
        ui_spinner_run "Updating package index" "$PKG_MANAGER" update -q -y
    elif [[ "$OS" == "Arch"* ]]; then
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
    elif [[ "$OS" == "Fedora"* ]]; then
        $PKG_MANAGER install -y -q "$PACKAGE"
    elif [[ "$OS" == "Arch"* ]]; then
        $PKG_MANAGER -S --noconfirm --quiet "$PACKAGE"
    elif [[ "$OS" == "openSUSE"* ]]; then
        PKG_MANAGER="zypper"
        $PKG_MANAGER --quiet install -y "$PACKAGE"
    else
        colorized_echo red "Unsupported operating system"
        exit 1
    fi
}

install_package () {
    if [ -z "$PKG_MANAGER" ]; then detect_and_update_package_manager; fi
    local PACKAGE="$1"
    ui_spinner_run "Installing $PACKAGE" install_package_impl "$PACKAGE"
}

ensure_ov_binary_prerequisites() {
    detect_os
    local packages=()
    if ! command -v openvpn >/dev/null 2>&1; then packages+=("openvpn"); fi
    if ! command -v nft >/dev/null 2>&1; then packages+=("nftables"); fi
    if ! command -v ip >/dev/null 2>&1; then
        if [[ "$OS" == "CentOS"* ]] || [[ "$OS" == "AlmaLinux"* ]] || [[ "$OS" == "Fedora"* ]]; then
            packages+=("iproute")
        else
            packages+=("iproute2")
        fi
    fi
    for package in "${packages[@]}"; do
        install_package "$package"
    done
    if command -v modprobe >/dev/null 2>&1 && [ ! -c /dev/net/tun ]; then
        modprobe tun >/dev/null 2>&1 || colorized_echo yellow "Unable to load tun module automatically; OpenVPN needs /dev/net/tun."
    fi
}

detect_node_binary_arch() {
    case "$(uname -m)" in
        amd64|x86_64) echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        i386|i486|i586|i686) echo "386" ;;
        armv5l|armv5tel|armv5tejl) echo "armv5" ;;
        armv6l|armv6) echo "armv6" ;;
        armv7l|armv7) echo "armv7" ;;
        s390x) echo "s390x" ;;
        *)
            colorized_echo red "Architecture not supported: $(uname -m)" >&2
            exit 1
        ;;
    esac
}

get_node_binary_dev_artifact_metadata() {
    local binary_arch="$1"
    local release_api
    local release_payload
    local release_asset_name
    local release_asset_url
    local release_target
    local workflow_runs_api
    local workflow_runs_payload
    local matching_runs
    local run_json
    local run_id
    local head_sha
    local artifacts_api
    local artifacts_payload
    local artifact_name
    local artifact_url
    local nightly_workflow
    local workflow_path

    release_asset_name="rebecca-node-dev-linux-${binary_arch}"
    release_api="https://api.github.com/repos/${REBECCA_NODE_RELEASE_REPO}/releases/tags/${REBECCA_NODE_BINARY_DEV_RELEASE_TAG}"
    if release_payload=$(curl -fsSL "$release_api" 2>/dev/null); then
        release_asset_url=$(echo "$release_payload" | jq -r --arg name "$release_asset_name" '
            .assets[]?
            | select(.name == $name)
            | .browser_download_url
        ' | head -n 1)
        if [ -n "$release_asset_url" ] && [ "$release_asset_url" != "null" ]; then
            release_target=$(echo "$release_payload" | jq -r '.target_commitish // empty')
            if [[ "$release_target" =~ ^[0-9a-fA-F]{7,40}$ ]]; then
                printf '%s|%s\n' "dev-${release_target:0:7}" "$release_asset_url"
            else
                printf '%s|%s\n' "dev-${REBECCA_NODE_BINARY_DEV_BRANCH}" "$release_asset_url"
            fi
            return 0
        fi
    fi

    nightly_workflow="$REBECCA_NODE_BINARY_WORKFLOW_NAME"
    case "$nightly_workflow" in
        *.yml|*.yaml) ;;
        *) nightly_workflow="${nightly_workflow}.yml" ;;
    esac
    workflow_path=".github/workflows/${nightly_workflow}"
    workflow_runs_api="https://api.github.com/repos/${REBECCA_NODE_RELEASE_REPO}/actions/runs?per_page=50"
    workflow_runs_payload=$(curl -fsSL "$workflow_runs_api") || {
        colorized_echo red "Unable to read workflow metadata: $workflow_runs_api" >&2
        exit 1
    }

    matching_runs=$(echo "$workflow_runs_payload" | jq -c --arg branch "$REBECCA_NODE_BINARY_DEV_BRANCH" --arg workflow_path "$workflow_path" '
        .workflow_runs[]?
        | select(
            .head_branch == $branch
            and (.event == "push" or .event == "workflow_dispatch")
            and .conclusion == "success"
            and .path == $workflow_path
        )
    ')

    if [ -z "$matching_runs" ]; then
        colorized_echo red "No successful workflow run found on branch ${REBECCA_NODE_BINARY_DEV_BRANCH}." >&2
        exit 1
    fi

    while IFS= read -r run_json; do
        [ -n "$run_json" ] || continue

        run_id=$(echo "$run_json" | jq -r '.id // empty')
        head_sha=$(echo "$run_json" | jq -r '.head_sha // empty')
        artifacts_api="https://api.github.com/repos/${REBECCA_NODE_RELEASE_REPO}/actions/runs/${run_id}/artifacts"
        if ! artifacts_payload=$(curl -fsSL "$artifacts_api"); then
            continue
        fi

        artifact_name=$(echo "$artifacts_payload" | jq -r --arg preferred "${REBECCA_NODE_BINARY_ARTIFACT_PREFIX}-linux-${binary_arch}" --arg arch "linux-${binary_arch}" '
            [
                .artifacts[]?
                | select((.expired | not) and (.name == $preferred or ((.name | startswith("rebecca-node")) and (.name | contains($arch)))))
            ]
            | sort_by(if .name == $preferred then 0 else 1 end, .created_at)
            | .[0].name // empty
        ')

        if [ -n "$artifact_name" ]; then
            artifact_url="https://nightly.link/${REBECCA_NODE_RELEASE_REPO}/workflows/${nightly_workflow}/${REBECCA_NODE_BINARY_DEV_BRANCH}/${artifact_name}.zip"
            printf '%s|%s\n' "dev-${head_sha:0:7}" "$artifact_url"
            return 0
        fi
    done <<< "$matching_runs"

    colorized_echo red "No usable dev artifact found." >&2
    exit 1
}

write_node_binary_release_metadata() {
    local resolved_version="$1"
    local binary_arch="$2"
    local asset_url="$3"

    jq -n \
        --arg image "rebecca-node (binary)" \
        --arg tag "$resolved_version" \
        --arg asset_url "$asset_url" \
        --arg arch "linux-${binary_arch}" \
        --arg node_binary "$BINARY_NODE" \
        --arg installed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            install_mode: "binary",
            image: $image,
            tag: $tag,
            asset_url: $asset_url,
            arch: $arch,
            node_binary: $node_binary,
            installed_at: $installed_at
        }' > "$BINARY_METADATA_FILE"
}

create_binary_rebecca_node_service() {
    cat > "$BINARY_SERVICE_UNIT" <<EOF
[Unit]
Description=$APP_NAME
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$APP_DIR
Environment=REBECCA_NODE_APP_NAME=$APP_NAME
Environment=REBECCA_NODE_APP_DIR=$APP_DIR
Environment=REBECCA_NODE_DATA_DIR=$DATA_DIR
Environment=REBECCA_DATA_DIR=$DATA_DIR
Environment=REBECCA_NODE_INSTALL_MODE=binary
Environment=REBECCA_NODE_BINARY_METADATA_FILE=$BINARY_METADATA_FILE
ExecStart=$BINARY_NODE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
}

install_latest_xray_for_binary_node() {
    mkdir -p "$APP_DIR/scripts" "$DATA_DIR/xray-core"
    colorized_echo blue "Installing Xray core for node"
    curl -fsSL "$REBECCA_SCRIPT_BASE_URL/install_latest_xray.sh" -o "$APP_DIR/scripts/install_latest_xray.sh"
    sed -i 's/\r$//' "$APP_DIR/scripts/install_latest_xray.sh"
    chmod +x "$APP_DIR/scripts/install_latest_xray.sh"
    REBECCA_DATA_DIR="$DATA_DIR" XRAY_INSTALL_DIR="$DATA_DIR/xray-core" XRAY_ASSETS_DIR="$DATA_DIR/xray-core" XRAY_CORE_VERSION="${XRAY_CORE_VERSION:-$DEFAULT_XRAY_CORE_VERSION}" bash "$APP_DIR/scripts/install_latest_xray.sh"
}

read_node_certificate_bundle() {
    local bundle_file
    local bundle_started=0
    local bundle_completed=0
    local line=""
    bundle_file=$(mktemp)
    : > "$bundle_file"

    echo -e "Paste the Node install bundle from the panel, press ENTER on a new line when finished: "
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%$'\r'}"
        if [[ -z $line ]]; then
            if [ "$bundle_started" -eq 0 ]; then break; fi
            if grep -q -- "-----END CERTIFICATE-----" "$bundle_file" && grep -Eq -- "-----END( [^-]+)? PRIVATE KEY-----" "$bundle_file"; then
                bundle_completed=1
                break
            fi
            continue
        fi
        bundle_started=1
        echo "$line" >>"$bundle_file"
        if grep -q -- "-----END CERTIFICATE-----" "$bundle_file" && grep -Eq -- "-----END( [^-]+)? PRIVATE KEY-----" "$bundle_file"; then
            bundle_completed=1
            break
        fi
    done

    if [ "$bundle_completed" -ne 1 ]; then
        colorized_echo red "Node install bundle is incomplete. Paste the full bundle shown by the panel."
        rm -f "$bundle_file"
        exit 1
    fi

    awk 'BEGIN{capture=0} /-----BEGIN CERTIFICATE-----/{capture=1} capture{print} /-----END CERTIFICATE-----/{exit}' "$bundle_file" >"$CERT_FILE"
    awk 'BEGIN{capture=0} /-----BEGIN( [^-]+)? PRIVATE KEY-----/{capture=1} capture{print} /-----END( [^-]+)? PRIVATE KEY-----/{exit}' "$bundle_file" >"$CERT_KEY_FILE"
    rm -f "$bundle_file"

    if ! grep -q -- "-----END CERTIFICATE-----" "$CERT_FILE"; then
        colorized_echo red "The bundle does not contain a valid PEM certificate."
        rm -f "$CERT_FILE" "$CERT_KEY_FILE"
        exit 1
    fi
    if ! grep -Eq -- "-----END( [^-]+)? PRIVATE KEY-----" "$CERT_KEY_FILE"; then
        colorized_echo red "The bundle does not contain a valid PEM private key."
        rm -f "$CERT_FILE" "$CERT_KEY_FILE"
        exit 1
    fi

    chmod 600 "$CERT_KEY_FILE"
    colorized_echo green "Node certificate bundle saved to $CERT_FILE and $CERT_KEY_FILE"
}

get_occupied_ports() {
    if command -v ss &>/dev/null; then
        OCCUPIED_PORTS=$(ss -tuln | awk '{print $5}' | grep -Eo '[0-9]+$' | sort | uniq)
    elif command -v netstat &>/dev/null; then
        OCCUPIED_PORTS=$(netstat -tuln | awk '{print $4}' | grep -Eo '[0-9]+$' | sort | uniq)
    else
        detect_os
        install_package net-tools
        OCCUPIED_PORTS=$(netstat -tuln | awk '{print $4}' | grep -Eo '[0-9]+$' | sort | uniq)
    fi
}

is_port_occupied() {
    if echo "$OCCUPIED_PORTS" | grep -q -w "$1"; then
        return 0
    else
        return 1
    fi
}

prompt_node_port_setting() {
    local key="$1"
    local label="$2"
    local fallback="$3"
    local other_port="${4:-}"
    local current_port
    local value

    current_port=$(get_env_value "$key")
    fallback="${current_port:-$fallback}"

    while true; do
        printf "Enter the %s (default %s): " "$label" "$fallback" >&2
        IFS= read -r value
        value="${value:-$fallback}"
        if ! [[ "$value" =~ ^[0-9]+$ ]] || [ "$value" -lt 1 ] || [ "$value" -gt 65535 ]; then
            colorized_echo red "Invalid port. Please enter a port between 1 and 65535." >&2
        elif [ -n "$other_port" ] && [ "$value" -eq "$other_port" ]; then
            colorized_echo red "Port $value cannot be the same as SERVICE_PORT." >&2
        elif is_port_occupied "$value" && [ "$value" != "$current_port" ]; then
            colorized_echo red "Port $value is already in use." >&2
        else
            echo "$value"
            return 0
        fi
    done
}

configure_binary_node_env() {
    mkdir -p "$DATA_DIR" "$APP_DIR"
    echo "dev" > "$BRANCH_FILE"

    if [ ! -s "$CERT_FILE" ] || [ ! -s "$CERT_KEY_FILE" ]; then
        rm -f "$CERT_FILE" "$CERT_KEY_FILE"
        read_node_certificate_bundle
    fi

    get_occupied_ports

    SERVICE_PORT=$(prompt_node_port_setting "SERVICE_PORT" "SERVICE_PORT" "62050")
    set_env_value "SERVICE_PORT" "$SERVICE_PORT"

    XRAY_API_PORT=$(prompt_node_port_setting "XRAY_API_PORT" "XRAY_API_PORT" "62051" "$SERVICE_PORT")
    set_env_value "XRAY_API_PORT" "$XRAY_API_PORT"

    set_env_value "REBECCA_DATA_DIR" "$DATA_DIR"
    set_env_value "SSL_CLIENT_CERT_FILE" "$CERT_FILE"
    set_env_value "SSL_CERT_FILE" "$CERT_FILE"
    set_env_value "SSL_KEY_FILE" "$CERT_KEY_FILE"
    set_env_value "XRAY_EXECUTABLE_PATH" "$DATA_DIR/xray-core/xray"
    set_env_value "XRAY_ASSETS_PATH" "$DATA_DIR/xray-core"
    set_env_value "SERVICE_PROTOCOL" "rest"
}

normalize_node_dev_artifact() {
    local tmp_dir="$1"
    local binary_arch="$2"
    local candidate

    if [ -f "$tmp_dir/rebecca-node" ]; then
        chmod +x "$tmp_dir/rebecca-node"
        return 0
    fi

    while IFS= read -r archive; do
        [ -n "$archive" ] || continue
        tar -xzf "$archive" -C "$tmp_dir" >/dev/null 2>&1 || true
    done < <(find "$tmp_dir" -maxdepth 3 -type f \( -name "*.tar.gz" -o -name "*.tgz" \) 2>/dev/null)

    candidate=$(
        find "$tmp_dir" -maxdepth 5 -type f \
            \( -name "rebecca-node" -o -name "rebecca-node*linux-${binary_arch}" -o -name "rebecca-node-*" \) \
            ! -name "*.sha256" ! -name "*.zip" ! -name "*.tar.gz" ! -name "*.tgz" 2>/dev/null \
        | while IFS= read -r file; do
            size=$(wc -c < "$file" 2>/dev/null || echo 0)
            printf '%s\t%s\n' "$size" "$file"
        done \
        | sort -nr \
        | cut -f2- \
        | head -n 1
    )

    if [ -n "$candidate" ]; then
        install -m 755 "$candidate" "$tmp_dir/rebecca-node"
    fi
}

install_binary_rebecca_node() {
    local configure="${1:-1}"
    local binary_arch
    local resolved_version
    local artifact_url
    local tmp_dir
    local package_path

    detect_os
    for package in curl jq unzip; do
        if ! command -v "$package" >/dev/null 2>&1; then install_package "$package"; fi
    done
    ensure_ov_binary_prerequisites

    binary_arch=$(detect_node_binary_arch)
    tmp_dir=$(mktemp -d)

    IFS='|' read -r resolved_version artifact_url < <(get_node_binary_dev_artifact_metadata "$binary_arch")
    if [[ "$artifact_url" == *.zip ]]; then
        package_path="$tmp_dir/rebecca-node-binaries.zip"
        ui_spinner_run "Downloading dev binary artifact" curl -fL "$artifact_url" -o "$package_path"
        ui_spinner_run "Extracting dev artifact" unzip -j -o "$package_path" -d "$tmp_dir"
        normalize_node_dev_artifact "$tmp_dir" "$binary_arch"
    else
        ui_spinner_run "Downloading dev binary" curl -fL "$artifact_url" -o "$tmp_dir/rebecca-node"
        chmod +x "$tmp_dir/rebecca-node"
    fi

    if [ ! -f "$tmp_dir/rebecca-node" ]; then
        colorized_echo red "Downloaded binary package is incomplete." >&2
        rm -rf "$tmp_dir"
        exit 1
    fi

    mkdir -p "$BINARY_BIN_DIR" "$DATA_DIR" "$APP_DIR"
    install -m 755 "$tmp_dir/rebecca-node" "$BINARY_NODE"

    if [ "$configure" = "1" ]; then
        configure_binary_node_env
        install_latest_xray_for_binary_node
    elif [ ! -x "$DATA_DIR/xray-core/xray" ]; then
        install_latest_xray_for_binary_node
    fi

    write_node_binary_release_metadata "${resolved_version:-dev}" "$binary_arch" "$artifact_url"
    create_binary_rebecca_node_service
    rm -rf "$tmp_dir"
    colorized_echo green "Rebecca-node installed successfully"
}

install_rebecca_node_script() {
    TARGET_PATH="/usr/local/bin/$APP_NAME"
    TEMP_SCRIPT=$(mktemp)
    if ! ui_spinner_run "Downloading $APP_NAME command script" curl -fsSL "$SCRIPT_URL" -o "$TEMP_SCRIPT"; then
        colorized_echo red "Failed to download script from $SCRIPT_URL"
        rm -f "$TEMP_SCRIPT"
        exit 1
    fi
    ui_spinner_run "Installing $APP_NAME command script" install -m 755 "$TEMP_SCRIPT" "$TARGET_PATH"
    rm -f "$TEMP_SCRIPT"
    colorized_echo green "$APP_NAME script installed at $TARGET_PATH"
}

uninstall_rebecca_node_script() {
    if [ -f "/usr/local/bin/$APP_NAME" ]; then
        colorized_echo yellow "Removing $APP_NAME script"
        rm "/usr/local/bin/$APP_NAME"
    fi
}

uninstall_rebecca_node() {
    if [ -f "$BINARY_SERVICE_UNIT" ]; then
        systemctl disable --now "$APP_NAME.service" >/dev/null 2>&1 || true
        rm -f "$BINARY_SERVICE_UNIT"
        systemctl daemon-reload
    fi
    if [ -d "$APP_DIR" ]; then
        colorized_echo yellow "Removing directory: $APP_DIR"
        rm -r "$APP_DIR"
    fi
}

uninstall_rebecca_node_data_files() {
    if [ -d "$DATA_DIR" ]; then
        colorized_echo yellow "Removing directory: $DATA_DIR"
        rm -r "$DATA_DIR"
    fi
}

up_rebecca_node() {
    systemctl enable --now "$APP_NAME.service"
}

down_rebecca_node() {
    systemctl stop "$APP_NAME.service"
}

show_rebecca_node_logs() {
    journalctl -u "$APP_NAME.service" --no-pager
}

follow_rebecca_node_logs() {
    journalctl -u "$APP_NAME.service" -f
}

update_rebecca_node_script() {
    colorized_echo blue "Updating $APP_NAME script from $SCRIPT_URL"
    install_rebecca_node_script
}

reexec_updated_node_script() {
    local target_path="/usr/local/bin/$APP_NAME"
    local args=("update")

    if [ "${REBECCA_NODE_SKIP_REEXEC:-0}" = "1" ]; then return; fi
    if [ ! -x "$target_path" ]; then return; fi

    colorized_echo blue "Reloading updated $APP_NAME script"
    REBECCA_NODE_SKIP_REEXEC=1 exec "$target_path" "${args[@]}"
}

is_rebecca_node_installed() {
    if [ -d "$APP_DIR" ]; then return 0; else return 1; fi
}

is_rebecca_node_up() {
    systemctl is-active --quiet "$APP_NAME.service"
}

identify_the_operating_system_and_architecture() {
    if [[ "$(uname)" == 'Linux' ]]; then
        case "$(uname -m)" in
            'i386' | 'i686') ARCH='32' ;;
            'amd64' | 'x86_64') ARCH='64' ;;
            'armv5tel') ARCH='arm32-v5' ;;
            'armv6l') ARCH='arm32-v6'; grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5' ;;
            'armv7' | 'armv7l') ARCH='arm32-v7a'; grep Features /proc/cpuinfo | grep -qw 'vfp' || ARCH='arm32-v5' ;;
            'armv8' | 'aarch64') ARCH='arm64-v8a' ;;
            'mips') ARCH='mips32' ;;
            'mipsle') ARCH='mips32le' ;;
            'mips64') ARCH='mips64'; lscpu | grep -q "Little Endian" && ARCH='mips64le' ;;
            'mips64le') ARCH='mips64le' ;;
            'ppc64') ARCH='ppc64' ;;
            'ppc64le') ARCH='ppc64le' ;;
            'riscv64') ARCH='riscv64' ;;
            's390x') ARCH='s390x' ;;
            *) echo "error: Architecture not supported."; exit 1 ;;
        esac
    else
        echo "error: Operating system not supported."; exit 1
    fi
}

install_command() {
    check_running_as_root

    if [[ "$APP_NAME_FROM_ARG" -eq 0 ]]; then
        echo
        colorized_echo cyan "Do you want to install this node with a custom name? (Useful for multi-node on one server)"
        read -p "Enter node name (e.g., node-2) or press Enter to use default [$SCRIPT_DEFAULT_APP_NAME]: " custom_app_name
        if [[ -n "$custom_app_name" ]]; then
            APP_NAME="$custom_app_name"
            APP_NAME_FROM_ARG=1
            set_app_context
        fi
    fi

    if is_rebecca_node_installed; then
        colorized_echo red "$APP_NAME is already installed at $APP_DIR"
        read -p "Do you want to override the previous installation? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo red "Aborted installation"
            return 1
        fi
    fi

    detect_os
    if ! command -v jq >/dev/null 2>&1; then install_package jq; fi
    if ! command -v curl >/dev/null 2>&1; then install_package curl; fi

    install_rebecca_node_script
    install_binary_rebecca_node "1"
    up_rebecca_node

    SERVICE_PORT="${SERVICE_PORT:-$(get_env_value "SERVICE_PORT")}"
    XRAY_API_PORT="${XRAY_API_PORT:-$(get_env_value "XRAY_API_PORT")}"
    echo "Use your IP: $NODE_IP and selected ports: $SERVICE_PORT and $XRAY_API_PORT to setup your Rebecca Main Panel"
    colorized_echo yellow "Run '$APP_NAME logs' if you want to follow live node logs."
}

uninstall_command() {
    check_running_as_root
    local node_exists=0
    if is_rebecca_node_installed; then node_exists=1; fi

    local service_exists=0
    if [ -f "$BINARY_SERVICE_UNIT" ]; then service_exists=1; fi

    if [ "$node_exists" -eq 0 ] && [ "$service_exists" -eq 0 ]; then
        colorized_echo red "$APP_NAME not installed!"
        return 1
    fi

    read -p "Do you really want to uninstall $APP_NAME? (y/n) "
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        colorized_echo red "Aborted"
        return 1
    fi

    if [ "$node_exists" -eq 1 ] && is_rebecca_node_up; then
        down_rebecca_node
    fi

    uninstall_rebecca_node_script

    if [ "$node_exists" -eq 1 ]; then
        uninstall_rebecca_node
        read -p "Do you want to remove $APP_NAME data files too ($DATA_DIR)? (y/n) "
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            colorized_echo green "$APP_NAME uninstalled successfully"
        else
            uninstall_rebecca_node_data_files
            colorized_echo green "$APP_NAME uninstalled successfully"
        fi
    else
        colorized_echo green "$APP_NAME service/scripts removed"
    fi
}

down_command() {
    if ! is_rebecca_node_installed; then
        colorized_echo red "$APP_NAME not installed!"
        return 1
    fi
    if ! is_rebecca_node_up; then
        colorized_echo red "$APP_NAME already down"
        return 1
    fi
    down_rebecca_node
}

restart_command() {
    help() {
        colorized_echo red "Usage: $APP_NAME restart [options]"
        echo
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs) no_logs=true ;;
            -h|--help) help; return 0 ;;
            *) echo "Error: Invalid option: $1" >&2; help; return 0 ;;
        esac
        shift
    done
    
    if ! is_rebecca_node_installed; then
        colorized_echo red "$APP_NAME not installed!"
        return 1
    fi
    down_rebecca_node
    up_rebecca_node
}

status_command() {
    if ! is_rebecca_node_installed; then
        echo -n "Status: "
        colorized_echo red "Not Installed"
        return 1
    fi
    if ! is_rebecca_node_up; then
        echo -n "Status: "
        colorized_echo blue "Down"
        return 1
    fi
    
    echo -n "Status: "
    colorized_echo green "Up"
    
    systemctl status "$APP_NAME.service" --no-pager
    return 0
}

logs_command() {
    help() {
        colorized_echo red "Usage: $APP_NAME logs [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-follow   do not show follow logs"
    }
    
    local no_follow=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-follow) no_follow=true ;;
            -h|--help) help; return 0 ;;
            *) echo "Error: Invalid option: $1" >&2; help; return 0 ;;
        esac
        shift
    done
    
    if ! is_rebecca_node_installed; then
        colorized_echo red "$APP_NAME's not installed!"
        return 1
    fi
    if ! is_rebecca_node_up; then
        colorized_echo red "$APP_NAME is not up."
        return 1
    fi
    
    if [ "$no_follow" = true ]; then
        show_rebecca_node_logs
    else
        follow_rebecca_node_logs
    fi
}

update_command() {
    check_running_as_root

    if ! is_rebecca_node_installed; then
        colorized_echo red "$APP_NAME not installed!"
        return 1
    fi

    update_rebecca_node_script

    colorized_echo blue "Updating $APP_NAME binary files"
    install_binary_rebecca_node "0"

    colorized_echo blue "Restarting $APP_NAME services"
    down_rebecca_node
    up_rebecca_node

    colorized_echo blue "$APP_NAME updated successfully"
}

edit_command() {
    detect_os
    check_editor
    ensure_env_file
    $EDITOR "$ENV_FILE"
    return 0
}

up_command() {
    help() {
        colorized_echo red "Usage: $APP_NAME up [options]"
        echo ""
        echo "OPTIONS:"
        echo "  -h, --help        display this help message"
        echo "  -n, --no-logs     do not follow logs after starting"
    }
    
    local no_logs=false
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            -n|--no-logs) no_logs=true ;;
            -h|--help) help; return 0 ;;
            *) echo "Error: Invalid option: $1" >&2; help; return 0 ;;
        esac
        shift
    done
    
    if ! is_rebecca_node_installed; then
        colorized_echo red "$APP_NAME's not installed!"
        return 1
    fi
    
    if is_rebecca_node_up; then
        colorized_echo red "$APP_NAME's already up"
        return 1
    fi
    
    up_rebecca_node
    if [ "$no_logs" = false ]; then
        follow_rebecca_node_logs
    fi
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
    
    print_xray_menu() {
        clear
        echo -e "\033[1;32m==============================\033[0m"
        echo -e "\033[1;32m      Xray-core Installer     \033[0m"
        echo -e "\033[1;32m==============================\033[0m"
        current_version=$(get_current_xray_core_version)
        echo -e "\033[1;33m>>>> Current Xray-core version: \033[1;1m$current_version\033[0m"
        echo -e "\033[1;32m==============================\033[0m"
        echo -e "\033[1;33mAvailable Xray-core versions:\033[0m"
        for ((i=0; i<${#versions[@]}; i++)); do
            echo -e "\033[1;34m$((i + 1)):\033[0m ${versions[i]}"
        done
        echo -e "\033[1;32m==============================\033[0m"
        echo -e "\033[1;35mM:\033[0m Enter a version manually"
        echo -e "\033[1;31mQ:\033[0m Quit"
        echo -e "\033[1;32m==============================\033[0m"
    }
    
    latest_releases=$(curl -s "https://api.github.com/repos/XTLS/Xray-core/releases?per_page=$LAST_XRAY_CORES")
    versions=($(echo "$latest_releases" | grep -oP '"tag_name": "\K(.*?)(?=")'))
    
    while true; do
        print_xray_menu
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
            selected_version=""
            return 0
        else
            echo -e "\033[1;31mInvalid choice. Please try again.\033[0m"
            sleep 2
        fi
    done
    
    if ! dpkg -s unzip >/dev/null 2>&1; then
        echo -e "\033[1;33mInstalling required packages...\033[0m"
        detect_os
        install_package unzip
    fi

    mkdir -p $DATA_MAIN_DIR/xray-core
    cd $DATA_MAIN_DIR/xray-core
    
    xray_filename="Xray-linux-$ARCH.zip"
    xray_download_url="https://github.com/XTLS/Xray-core/releases/download/${selected_version}/${xray_filename}"
    
    wget "${xray_download_url}" -q &
    wait
    unzip -o "${xray_filename}" >/dev/null 2>&1 &
    wait
    rm "${xray_filename}"
}

get_current_xray_core_version() {
    XRAY_BINARY="$DATA_MAIN_DIR/xray-core/xray"
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
    check_running_as_root
    selected_version=""
    get_xray_core
    
    if [ -z "$selected_version" ]; then return 0; fi

    set_env_value "XRAY_EXECUTABLE_PATH" "$DATA_MAIN_DIR/xray-core/xray"
    set_env_value "XRAY_ASSETS_PATH" "$DATA_MAIN_DIR/xray-core"
    colorized_echo red "Restarting $APP_NAME..."
    systemctl restart "$APP_NAME.service"
    colorized_echo blue "Installation of XRAY-CORE version $selected_version completed."
    return 0
}

check_editor() {
    if [ -z "$EDITOR" ]; then
        if command -v nano >/dev/null 2>&1; then
            EDITOR="nano"
        elif command -v vi >/dev/null 2>&1; then
            EDITOR="vi"
        else
            detect_os
            install_package nano
            EDITOR="nano"
        fi
    fi
}

get_node_current_version() {
    local version=""
    if [ -f "$BINARY_METADATA_FILE" ]; then
        version=$(sed -nE 's/.*"tag"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$BINARY_METADATA_FILE" | head -n 1)
    fi
    printf '%s\n' "${version:-dev}"
}

get_node_service_status() {
    if is_rebecca_node_up; then echo "running"; else echo "stopped"; fi
}

print_node_menu_status_summary() {
    local service_port xray_api_port
    service_port=$(get_env_value "SERVICE_PORT")
    xray_api_port=$(get_env_value "XRAY_API_PORT")
    service_port="${service_port:-62050}"
    xray_api_port="${xray_api_port:-62051}"
    ui_status_row "Version" "$(get_node_current_version)"
    ui_status_row "Service" "$(get_node_service_status)"
    ui_status_row "Node IP" "${NODE_IP:-unknown}"
    ui_status_row "Service port" "$service_port"
    ui_status_row "Xray API" "$xray_api_port"
    ui_status_row "Cert" "$CERT_FILE"
}

usage() {
    colorized_echo blue "================================"
    colorized_echo magenta "       $APP_NAME Node CLI Help"
    colorized_echo blue "================================"
    colorized_echo cyan "Usage:"
    echo "  $APP_NAME [command]"
    echo
    colorized_echo cyan "Commands:"
    colorized_echo yellow "  up              – Start services"
    colorized_echo yellow "  down            – Stop services"
    colorized_echo yellow "  restart         – Restart services"
    colorized_echo yellow "  status          – Show status"
    colorized_echo yellow "  logs            – Show logs"
    colorized_echo yellow "  install         - Install/reinstall node"
    colorized_echo yellow "  update          - Update node"
    colorized_echo yellow "  uninstall       - Uninstall node"
    colorized_echo blue "  script-install  - Install node script"
    colorized_echo blue "  script-update   - Update node CLI script"
    colorized_echo blue "  script-uninstall  - Uninstall node script"
    colorized_echo yellow "  edit            - Edit binary .env"
    colorized_echo yellow "  core-update     – Update/Change Xray core"
    echo
    colorized_echo cyan "Node Information:"
    colorized_echo magenta "  Cert file path: $CERT_FILE"
    colorized_echo magenta "  Node IP: $NODE_IP"
    echo
    colorized_echo blue "================================="
    echo
}

menu_commands() {
    echo "up down restart status logs install update uninstall script-install script-update script-uninstall core-update edit help"
}

menu_category_for() {
    case "$1" in
        up|down|restart|status|logs) echo "Node runtime" ;;
        install|update|uninstall) echo "Install and update" ;;
        script-install|script-update|script-uninstall) echo "Script management" ;;
        core-update|edit) echo "Tools" ;;
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
        install) echo "Install/reinstall $APP_NAME" ;;
        update) echo "Update node" ;;
        uninstall) echo "Uninstall $APP_NAME" ;;
        script-install) echo "Install CLI script" ;;
        script-update) echo "Update CLI script" ;;
        script-uninstall) echo "Uninstall CLI script" ;;
        core-update) echo "Update/Change Xray core" ;;
        edit) echo "Edit binary .env" ;;
        help) echo "Show this help message" ;;
        *) echo "" ;;
    esac
}

print_menu() {
    ui_header "$APP_NAME" "$APP_NAME control center"
    ui_section "Status"
    print_node_menu_status_summary
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

map_choice_to_command() {
    local commands=($(menu_commands))
    if [[ "$1" =~ ^[0-9]+$ ]] && [ "$1" -ge 1 ] && [ "$1" -le "${#commands[@]}" ]; then
        echo "${commands[$(($1 - 1))]}"
        return
    fi
    echo "$1"
}


discover_node_instances() {
    DISCOVERED_NODE_PATHS=()
    DISCOVERED_NODE_NAMES=()

    # فقط نودهای باینری را شناسایی کن (نادیده گرفتن پوشه‌های دارای docker-compose.yml)
    if [ -d "$NODE_DISCOVERY_BASE" ]; then
        # 1. جستجوی مستقیم بر اساس فایل متادیتا .binary-release.json
        while IFS= read -r -d '' metadata_file; do
            local dir name
            dir=$(dirname "$metadata_file")
            name=$(basename "$dir")
            # اطمینان از اینکه پوشه داکر نیست (فایل docker-compose.yml نداشته باشد)
            if [ ! -f "$dir/docker-compose.yml" ]; then
                add_discovered_node_instance "$dir" "$name"
            fi
        done < <(find "$NODE_DISCOVERY_BASE" -mindepth 2 -maxdepth 3 -type f -name ".binary-release.json" -print0 2>/dev/null || true)

        # 2. جستجوی پشتیبان: پوشه‌هایی که bin/rebecca-node یا .env دارند ولی فایل متادیتا ندارند
        while IFS= read -r -d '' dir; do
            local name
            name=$(basename "$dir")
            # فقط پوشه‌هایی که docker-compose.yml ندارند و دارای نشانه‌های باینری هستند
            # حذف شرط name="rebecca" چون ممکن است پنل اصلی باشد و نود نباشد
            if [ ! -f "$dir/docker-compose.yml" ] && ( [ -f "$dir/.env" ] || [ -f "$dir/bin/rebecca-node" ] ); then
                # بررسی کنیم که قبلاً اضافه نشده باشد
                local already_added=0
                for existing in "${DISCOVERED_NODE_PATHS[@]}"; do
                    if [ "$existing" = "$dir" ]; then
                        already_added=1
                        break
                    fi
                done
                if [ "$already_added" -eq 0 ]; then
                    add_discovered_node_instance "$dir" "$name"
                fi
            fi
        done < <(find "$NODE_DISCOVERY_BASE" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null || true)
    fi
}

startup_node_selection() {
    discover_node_instances

    while true; do
        ui_clear
        ui_header "Node Selection" "Select an existing binary node or create a new one"

        local count=${#DISCOVERED_NODE_PATHS[@]}
        local idx=2  # discovered nodes start from 2

        if [ "$count" -gt 0 ]; then
            colorized_echo yellow "   Discovered Binary Nodes:"
            for i in "${!DISCOVERED_NODE_PATHS[@]}"; do
                local name="${DISCOVERED_NODE_NAMES[$i]}"
                local path="${DISCOVERED_NODE_PATHS[$i]}"
                local extra_info=""
                # اگر نام پوشه 'rebecca' باشد، احتمالاً پنل اصلی است
                if [[ "${name,,}" == "rebecca" ]]; then
                    extra_info=" \033[38;5;214m(Probably the main panel)\033[0m"
                fi
                printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-22s\033[0m \033[38;5;245m(%s)\033[0m%b\n" "$idx" "$name" "$path" "$extra_info"
                ((idx++))
            done
            echo
        else
            colorized_echo red "   No binary Rebecca node installations detected."
            echo
        fi

        printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-25s\033[0m\n" "0" "Exit"
        printf "   \033[38;5;45;1m%2s)\033[0m \033[38;5;231;1m%-25s\033[0m\n" "1" "Create a new node"
        printf "   \033[38;5;117;1m%2s)\033[0m \033[38;5;231;1m%-25s\033[0m\n" "S" "Search custom directory"
        echo
        colorized_echo cyan "Select an option: "
        read -r choice

        case "$choice" in
            0)
                echo
                exit 0
                ;;
            1)
                echo
                colorized_echo cyan "Enter a suffix for the new node."
                colorized_echo yellow "Example: typing 'newname' creates 'rebecca-node-newname'"
                read -p "Suffix (leave empty for default 'rebecca-node'): " suffix
                suffix=$(echo "$suffix" | tr -cd 'a-zA-Z0-9_-')
                if [[ -n "$suffix" ]]; then
                    APP_NAME="rebecca-node-${suffix}"
                else
                    APP_NAME="rebecca-node"
                fi
                APP_NAME_FROM_ARG=1
                set_app_context
                return 0
                ;;
            [Ss])
                echo
                colorized_echo cyan "Enter the directory path to search for binary node installations (e.g., /root):"
                read -p "Path: " search_path
                if [ -d "$search_path" ]; then
                    local found_any=0
                    while IFS= read -r -d '' dir; do
                        local name
                        name=$(basename "$dir")
                        # فقط پوشه‌های بدون docker-compose.yml و دارای نشانه‌های باینری
                        if [ ! -f "$dir/docker-compose.yml" ] && ( [ -f "$dir/.env" ] || [ -f "$dir/bin/rebecca-node" ] || [ -f "$dir/.binary-release.json" ] ); then
                            add_discovered_node_instance "$dir" "$name"
                            found_any=1
                        fi
                    done < <(find "$search_path" -mindepth 1 -maxdepth 2 -type d -print0 2>/dev/null || true)
                    if [ "$found_any" -eq 0 ]; then
                        colorized_echo yellow "No binary Rebecca node installations found under $search_path."
                        sleep 2
                    else
                        colorized_echo green "Found new nodes. Refreshing list..."
                        sleep 1
                    fi
                else
                    colorized_echo red "Directory does not exist: $search_path"
                    sleep 2
                fi
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 2 ] && [ "$choice" -le "$((count+1))" ]; then
                    local chosen=$((choice - 2))
                    if [ "$chosen" -ge 0 ] && [ "$chosen" -lt "$count" ]; then
                        APP_NAME="${DISCOVERED_NODE_NAMES[$chosen]}"
                        APP_DIR="${DISCOVERED_NODE_PATHS[$chosen]}"
                        DATA_DIR="/var/lib/$APP_NAME"
                        set_app_context
                        return 0
                    fi
                else
                    colorized_echo red "Invalid choice."
                    sleep 1
                fi
                ;;
        esac
    done
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

dispatch_command() {
    local cmd="$1"
    shift || true
    case "$cmd" in
        install)
            if [ ! -t 0 ] && [ -r /dev/tty ]; then install_command </dev/tty; else install_command; fi ;;
        update) update_command ;;
        uninstall) uninstall_command ;;
        up) up_command ;;
        down) down_command ;;
        restart) restart_command ;;
        status) status_command ;;
        logs) logs_command ;;
        core-update) update_core_command ;;
        install-script|script-install) install_rebecca_node_script ;;
        update-script|script-update) install_rebecca_node_script ;;
        uninstall-script|script-uninstall) uninstall_rebecca_node_script ;;
        edit) edit_command ;;
        help) usage ;;
        *) usage ;;
    esac
}

if [ -z "${COMMAND:-}" ]; then
    startup_node_selection
    
    while true; do
        read_menu_command || exit 0
        dispatch_command "$MENU_COMMAND" || true
        echo
        colorized_echo cyan "Press Enter to return to the menu..."
        read -r
    done
else
    dispatch_command "$COMMAND" || true
fi