check_and_run_script_with_progress() {
    local domain="$1"
    local script="$2"
    local total_pings=20
    local success_count=0

    echo -e "\033[1;33mPinging domain: $domain\033[0m"

    for ((i = 1; i <= total_pings; i++)); do
        if ping -c 1 -W 1 "$domain" >/dev/null 2>&1; then
            ((success_count++))
        fi
        local progress=$((i * 100 / total_pings))
        echo -ne "\033[1;34mProgress: $progress% ($i/$total_pings)\033[0m\r"
        sleep 0.1
    done
    echo -ne "\n"  # Move to a new line after progress.

    if ((success_count > 0)); then
        echo -e "\033[1;32mPing successful. $success_count/$total_pings responses received. No action needed.\033[0m"
    else
        echo -e "\033[1;31mPing failed. Executing script: $script\033[0m"
        if [[ -x "$script" ]]; then
            "$script"
        else
            echo -e "\033[1;31mScript not found or not executable: $script\033[0m"
        fi
    fi
}

# Example usage:
check_and_run_script_with_progress "google.com" "/root/check_url.sh"
