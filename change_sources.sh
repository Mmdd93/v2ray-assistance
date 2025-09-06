change_sources_list() {
    while true; do
        # Detect codename and distribution with better error handling
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            distro_id=${ID:-ubuntu}
            distro_codename=$(lsb_release -cs 2>/dev/null || echo "${VERSION_CODENAME:-jammy}")
        else
            distro_id="ubuntu"
            distro_codename="jammy"
        fi

        # Check for new Ubuntu sources location
        local sources_file="/etc/apt/sources.list"
        local ubuntu_sources_file="/etc/apt/sources.list.d/ubuntu.sources"
        
        if [ -f "$ubuntu_sources_file" ]; then
            sources_file="$ubuntu_sources_file"
            echo -e "\033[1;33mℹ️  Detected new Ubuntu sources format at $ubuntu_sources_file\033[0m"
        fi

        # Create backup with better error handling
        timestamp=$(date +"%Y%m%d_%H%M%S")
        if [ -f "$sources_file" ]; then
            sudo cp "$sources_file" "${sources_file}.bak.$timestamp" 2>/dev/null
            echo -e "\033[1;32m✓ Backup created: ${sources_file}.bak.$timestamp\033[0m"
        else
            echo -e "\033[1;33m⚠️  No sources file found, will create new one\033[0m"
        fi

        echo -e "\n\033[1;36m╔══════════════════════════════════════════════════════════════╗\033[0m"
        echo -e "\033[1;36m║                   APT MIRROR SELECTION                      ║\033[0m"
        echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════╝\033[0m"
        echo
        echo -e "\033[1;33m┌──────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[1;33m│                     AVAILABLE OPTIONS                       │\033[0m"
        echo -e "\033[1;33m├──────────────────────────────────────────────────────────────┤\033[0m"
        echo -e "\033[1;32m│  1. Test and select fastest mirror (ping + download)       │\033[0m"
        echo -e "\033[1;34m│  2. Set mirror manually (offline selection)                 │\033[0m"
        echo -e "\033[1;33m│  3. View current sources                                    │\033[0m"
        echo -e "\033[1;35m│  4. Restore from backup                                     │\033[0m"
        echo -e "\033[1;36m│  5. Test specific mirror                                    │\033[0m"
        echo -e "\033[1;33m├──────────────────────────────────────────────────────────────┤\033[0m"
        echo -e "\033[1;31m│  0. Return to main menu                                     │\033[0m"
        echo -e "\033[1;33m└──────────────────────────────────────────────────────────────┘\033[0m"
        echo
        echo -e "\033[1;35m📋 Detected: $distro_id $distro_codename\033[0m"
        echo -e "\033[1;35m📁 Using: $sources_file\033[0m"

        read -p "$(echo -e '\033[1;32mSelect an option [0-5]: \033[0m')" main_choice

        case $main_choice in
            1) test_and_select_fastest_mirror "$sources_file" ;;
            2) set_mirror_manually "$sources_file" ;;
            3) view_current_sources "$sources_file" ;;
            4) restore_from_backup "$sources_file" ;;
            5) test_specific_mirror "$sources_file" ;;
            0) echo -e "\033[1;33mReturning to main menu...\033[0m"; return ;;
            *) echo -e "\033[1;31m❌ Invalid option. Please try again.\033[0m"; continue ;;
        esac

        echo -e "\n\033[1;34m⏎ Press Enter to continue...\033[0m"
        read
    done
}

test_and_select_fastest_mirror() {
    local sources_file="$1"
    
    echo -e "\n\033[1;36m🔄 Testing mirror availability and speed...\033[0m"
    
    # Comprehensive mirror list with global options
    local mirrors=(
        # Iranian Mirrors
        "http://mirror.arvancloud.ir/$distro_id"
        "https://ir.ubuntu.sindad.cloud/$distro_id"
        "https://ir.archive.ubuntu.com/$distro_id"
        "http://ubuntu.byteiran.com/$distro_id"
        "http://mirror.faraso.org/$distro_id"
        "http://mirror.aminidc.com/$distro_id"
        "https://mirror.iranserver.com/$distro_id"
        "https://ubuntu.pars.host"
        "http://linuxmirrors.ir/pub/$distro_id"
        "http://repo.iut.ac.ir/repo/$distro_id"
        "https://mirror.0-1.cloud/$distro_id"
        "https://ubuntu.hostiran.ir/ubuntuarchive"
        "https://archive.ubuntu.petiak.ir/$distro_id"
        "https://mirrors.pardisco.co/$distro_id"
        "https://ubuntu.shatel.ir/$distro_id"
        
        # Global Mirrors
        "http://archive.ubuntu.com/ubuntu"
        "http://ports.ubuntu.com/ubuntu-ports"
        "http://security.ubuntu.com/ubuntu"
        "https://ftp.halifax.rwth-aachen.de/ubuntu"
        "http://ftp.tu-chemnitz.de/pub/linux/ubuntu"
        "http://mirror.koddos.net/ubuntu"
        "https://mirror.enzu.com/ubuntu"
        
        # Debian Mirrors
        "https://deb.debian.org/debian"
        "https://ftp.debian.org/debian"
        "http://ftp.us.debian.org/debian"
    )

    declare -A mirror_ping_times
    declare -A mirror_download_speeds
    local available_mirrors=()

    echo -e "\033[1;33mTesting ${#mirrors[@]} mirrors...\033[0m"
    
    # First pass: Ping test
    for mirror in "${mirrors[@]}"; do
        local domain=$(echo "$mirror" | awk -F/ '{print $3}')
        echo -ne "\033[1;34mPinging: $domain ... \033[0m"
        
        if ping -c 2 -W 2 "$domain" &>/dev/null; then
            # Measure ping time
            local ping_time=$(ping -c 4 -W 2 "$domain" | tail -1 | awk -F'/' '{print $5}')
            mirror_ping_times["$mirror"]=${ping_time:-999}
            echo -e "\033[1;32m✓ ${ping_time}ms\033[0m"
            available_mirrors+=("$mirror")
        else
            mirror_ping_times["$mirror"]=999
            echo -e "\033[1;31m✗ unreachable\033[0m"
        fi
    done

    if [ ${#available_mirrors[@]} -eq 0 ]; then
        echo -e "\033[1;31m❌ No mirrors available! Check internet connection.\033[0m"
        return 1
    fi

    # Second pass: Download speed test for top 5 fastest ping
    echo -e "\n\033[1;36m📊 Testing download speeds for fastest mirrors...\033[0m"
    
    # Sort by ping time and take top 5
    local sorted_by_ping=($(
        for mirror in "${available_mirrors[@]}"; do
            echo "$mirror ${mirror_ping_times[$mirror]}"
        done | sort -k2 -n | head -5 | awk '{print $1}'
    ))

    for mirror in "${sorted_by_ping[@]}"; do
        local domain=$(echo "$mirror" | awk -F/ '{print $3}')
        echo -ne "\033[1;34mTesting download: $domain ... \033[0m"
        
        # Test download speed with 1MB file
        local test_url="${mirror}/dists/${distro_codename}/Release"
        local start_time=$(date +%s%N)
        
        if curl -s --max-time 10 "$test_url" | head -c 1048576 > /dev/null 2>&1; then
            local end_time=$(date +%s%N)
            local duration_ms=$(( (end_time - start_time) / 1000000 ))
            local speed_mbps=$(echo "scale=2; 8 / ($duration_ms / 1000)" | bc -l)
            mirror_download_speeds["$mirror"]=$speed_mbps
            echo -e "\033[1;32m✓ ${speed_mbps} Mbps\033[0m"
        else
            mirror_download_speeds["$mirror"]=0
            echo -e "\033[1;31m✗ failed\033[0m"
        fi
    done

    # Display results
    echo -e "\n\033[1;36m🏆 Top Mirrors (Ping + Download Speed):\033[0m"
    echo -e "\033[1;33m┌──────────────────────────────────────────────────────────────┐\033[0m"
    
    local index=1
    for mirror in "${sorted_by_ping[@]}"; do
        local domain=$(echo "$mirror" | awk -F/ '{print $3}')
        local ping_time=${mirror_ping_times[$mirror]}
        local download_speed=${mirror_download_speeds[$mirror]:-0}
        
        if [ "$download_speed" != "0" ]; then
            echo -e "\033[1;32m│ $index. $domain [Ping: ${ping_time}ms | Speed: ${download_speed} Mbps]\033[0m"
        else
            echo -e "\033[1;33m│ $index. $domain [Ping: ${ping_time}ms | Speed: failed]\033[0m"
        fi
        ((index++))
    done
    echo -e "\033[1;33m└──────────────────────────────────────────────────────────────┘\033[0m"

    # Selection
    read -p "$(echo -e '\033[1;32mSelect mirror (1-${#sorted_by_ping[@]}, 0 to cancel): \033[0m')" choice
    
    if [[ $choice -eq 0 ]]; then
        echo -e "\033[1;33mCancelled.\033[0m"
        return
    elif [[ $choice -ge 1 && $choice -le ${#sorted_by_ping[@]} ]]; then
        selected_mirror="${sorted_by_ping[$((choice - 1))]}"
        apply_mirror "$selected_mirror" "$sources_file"
    else
        echo -e "\033[1;31m❌ Invalid option. Using fastest mirror.\033[0m"
        selected_mirror="${sorted_by_ping[0]}"
        apply_mirror "$selected_mirror" "$sources_file"
    fi
}

apply_mirror() {
    local selected_mirror="$1"
    local sources_file="$2"
    
    # Clean up mirror URL
    selected_mirror=$(echo "$selected_mirror" | sed 's/\/$//')
    
    echo -e "\n\033[1;32m✅ Selected: $selected_mirror\033[0m"
    echo -e "\033[1;32m📁 Updating: $sources_file\033[0m"

    # Determine repository components based on distribution
    local main_components="main"
    local extra_components="restricted universe multiverse"
    
    if [[ "$distro_id" == "debian" ]]; then
        main_components="main contrib non-free"
        extra_components="non-free-firmware"
    fi

    # Check if using new Ubuntu sources format
    if [[ "$sources_file" == "/etc/apt/sources.list.d/ubuntu.sources" ]]; then
        # Create new Ubuntu sources format
        sudo bash -c "cat > '$sources_file' <<EOF
# Generated by Network Optimizer Tool - $(date)
# See https://manpages.ubuntu.com/manpages/noble/man5/sources.list.5.html for details

Types: deb
URIs: $selected_mirror
Suites: $distro_codename $distro_codename-updates $distro_codename-security $distro_codename-backports
Components: $main_components $extra_components
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

# Additional security updates
Types: deb
URIs: $selected_mirror
Suites: $distro_codename-security
Components: $main_components $extra_components
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF"
        echo -e "\033[1;32m✓ Updated new Ubuntu sources format!\033[0m"
        
    else
        # Create traditional sources.list format
        sudo bash -c "cat > '$sources_file' <<EOF
# Generated by Network Optimizer Tool - $(date)
deb $selected_mirror $distro_codename $main_components $extra_components
deb $selected_mirror $distro_codename-updates $main_components $extra_components
deb $selected_mirror $distro_codename-security $main_components $extra_components
deb $selected_mirror $distro_codename-backports $main_components $extra_components
EOF"
        echo -e "\033[1;32m✓ Updated traditional sources.list format!\033[0m"
    fi

    read -p "$(echo -e '\033[1;32mRun apt update now? (Y/n): \033[0m')" update_now
    if [[ "$update_now" != "n" && "$update_now" != "N" ]]; then
        echo -e "\033[1;33m🔄 Running apt update...\033[0m"
        sudo apt update
    fi
}

view_current_sources() {
    local sources_file="$1"
    
    echo -e "\n\033[1;36m📄 CURRENT SOURCES ($sources_file):\033[0m"
    echo -e "\033[1;33m┌──────────────────────────────────────────────────────────────┐\033[0m"
    
    if [ -f "$sources_file" ]; then
        if [[ "$sources_file" == "/etc/apt/sources.list.d/ubuntu.sources" ]]; then
            # Pretty print for new format
            cat "$sources_file" | while read -r line; do
                if [[ "$line" =~ ^# ]]; then
                    echo -e "\033[1;90m│ $line\033[0m"
                elif [[ "$line" =~ ^Types: ]]; then
                    echo -e "\033[1;36m│ $line\033[0m"
                elif [[ "$line" =~ ^URIs: ]]; then
                    echo -e "\033[1;32m│ $line\033[0m"
                elif [[ "$line" =~ ^Suites: ]]; then
                    echo -e "\033[1;33m│ $line\033[0m"
                elif [[ "$line" =~ ^Components: ]]; then
                    echo -e "\033[1;35m│ $line\033[0m"
                else
                    echo -e "\033[1;37m│ $line\033[0m"
                fi
            done
        else
            # Traditional format
            cat "$sources_file" | while read -r line; do
                echo -e "\033[1;37m│ $line\033[0m"
            done
        fi
    else
        echo -e "\033[1;31m│ No sources file found at $sources_file!\033[0m"
    fi
    
    echo -e "\033[1;33m└──────────────────────────────────────────────────────────────┘\033[0m"
}

restore_from_backup() {
    local sources_file="$1"
    local backup_pattern="${sources_file}.bak.*"
    
    local backups=($(ls -t $backup_pattern 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "\033[1;31m❌ No backups found for $sources_file!\033[0m"
        echo -e "\033[1;33mℹ️  Looking for backups in alternative locations...\033[0m"
        
        # Check for backups in other possible locations
        if [ "$sources_file" == "/etc/apt/sources.list.d/ubuntu.sources" ]; then
            backups=($(ls -t /etc/apt/sources.list.bak.* 2>/dev/null))
        else
            backups=($(ls -t /etc/apt/sources.list.d/ubuntu.sources.bak.* 2>/dev/null))
        fi
        
        if [ ${#backups[@]} -eq 0 ]; then
            echo -e "\033[1;31m❌ No backups found anywhere!\033[0m"
            return
        fi
    fi

    echo -e "\n\033[1;36m📦 Available Backups:\033[0m"
    for i in "${!backups[@]}"; do
        backup_date=$(echo "${backups[i]}" | grep -oE '[0-9]{8}_[0-9]{6}')
        human_date=$(echo "$backup_date" | sed 's/\(....\)\(..\)\(..\)_\(..\)\(..\)\(..\)/\1-\2-\3 \4:\5:\6/')
        echo -e "\033[1;32m$((i+1)). ${backups[i]} ($human_date)\033[0m"
    done

    read -p "$(echo -e '\033[1;32mSelect backup to restore (1-${#backups[@]}, 0 to cancel): \033[0m')" choice

    if [[ $choice -eq 0 ]]; then
        echo -e "\033[1;33mCancelled.\033[0m"
        return
    elif [[ $choice -ge 1 && $choice -le ${#backups[@]} ]]; then
        selected_backup="${backups[$((choice - 1))]}"
        sudo cp "$selected_backup" "$sources_file"
        echo -e "\033[1;32m✓ Restored from $selected_backup\033[0m"
        
        read -p "$(echo -e '\033[1;32mRun apt update now? (Y/n): \033[0m')" update_now
        if [[ "$update_now" != "n" && "$update_now" != "N" ]]; then
            sudo apt update
        fi
    else
        echo -e "\033[1;31m❌ Invalid option.\033[0m"
    fi
}


test_specific_mirror() {
    read -p "$(echo -e '\033[1;32mEnter mirror URL to test: \033[0m')" test_mirror
    
    # Validate URL format
    if [[ ! "$test_mirror" =~ ^https?:// ]]; then
        test_mirror="http://$test_mirror"
    fi
    
    echo -e "\n\033[1;36m🧪 Testing mirror: $test_mirror\033[0m"
    
    # Ping test
    local domain=$(echo "$test_mirror" | awk -F/ '{print $3}')
    echo -ne "\033[1;34mPing test: \033[0m"
    if ping -c 4 -W 2 "$domain" &>/dev/null; then
        local ping_time=$(ping -c 4 -W 2 "$domain" | tail -1 | awk -F'/' '{print $5}')
        echo -e "\033[1;32m✓ ${ping_time}ms\033[0m"
    else
        echo -e "\033[1;31m✗ unreachable\033[0m"
        return 1
    fi
    
    # Download test
    echo -ne "\033[1;34mDownload test: \033[0m"
    local test_url="${test_mirror}/dists/${distro_codename}/Release"
    local start_time=$(date +%s%N)
    
    if curl -s --max-time 10 "$test_url" | head -c 524288 > /dev/null 2>&1; then
        local end_time=$(date +%s%N)
        local duration_ms=$(( (end_time - start_time) / 1000000 ))
        local speed_mbps=$(echo "scale=2; 4 / ($duration_ms / 1000)" | bc -l)
        echo -e "\033[1;32m✓ ${speed_mbps} Mbps (512KB test)\033[0m"
    else
        echo -e "\033[1;31m✗ download failed\033[0m"
        return 1
    fi
    
    read -p "$(echo -e '\033[1;32mUse this mirror? (y/N): \033[0m')" use_mirror
    if [[ "$use_mirror" =~ ^[Yy]$ ]]; then
        apply_mirror "$test_mirror"
    fi
}

set_mirror_manually() {
    local offline_mirrors=(
        "http://mirror.arvancloud.ir/ubuntu"
        "https://ir.ubuntu.sindad.cloud/ubuntu"
        "https://ir.archive.ubuntu.com/ubuntu"
        "http://ubuntu.byteiran.com/ubuntu"
        "http://mirror.faraso.org/ubuntu"
        "http://mirror.aminidc.com/ubuntu"
        "https://mirror.iranserver.com/ubuntu"
        "https://ubuntu.pars.host"
        "http://linuxmirrors.ir/pub/ubuntu"
        "http://repo.iut.ac.ir/repo/ubuntu"
        "https://mirror.0-1.cloud/ubuntu"
        "https://ubuntu.hostiran.ir/ubuntuarchive"
        "https://archive.ubuntu.petiak.ir/ubuntu"
        "https://mirrors.pardisco.co/ubuntu"
        "https://ubuntu.shatel.ir/ubuntu"
        "http://archive.ubuntu.com/ubuntu"
        "https://deb.debian.org/debian"
        "https://ftp.debian.org/debian"
        "http://ftp.us.debian.org/debian"
        "https://ftp.fr.debian.org/debian"
        "https://ftp.de.debian.org/debian"
    )

    echo -e "\n\033[1;36m🌐 Available Mirrors:\033[0m"
    echo -e "\033[1;33m┌──────────────────────────────────────────────────────────────┐\033[0m"
    
    for i in "${!offline_mirrors[@]}"; do
        mirror_domain=$(echo "${offline_mirrors[i]}" | cut -d'/' -f3)
        echo -e "\033[1;32m│ $((i+1)). $mirror_domain\033[0m"
    done
    echo -e "\033[1;33m├──────────────────────────────────────────────────────────────┤\033[0m"
    echo -e "\033[1;34m│ 99. Enter custom mirror URL                                  │\033[0m"
    echo -e "\033[1;33m└──────────────────────────────────────────────────────────────┘\033[0m"

    read -p "$(echo -e '\033[1;32mSelect mirror (1-${#offline_mirrors[@]}, 99 for custom): \033[0m')" choice

    case $choice in
        99)
            read -p "$(echo -e '\033[1;32mEnter custom mirror URL: \033[0m')" custom_mirror
            apply_mirror "$custom_mirror"
            ;;
        [1-9]|[1-9][0-9])
            if [[ $choice -le ${#offline_mirrors[@]} ]]; then
                selected_mirror="${offline_mirrors[$((choice - 1))]}"
                apply_mirror "$selected_mirror"
            else
                echo -e "\033[1;31m❌ Invalid selection.\033[0m"
            fi
            ;;
        *)
            echo -e "\033[1;31m❌ Invalid option.\033[0m"
            ;;
    esac
}
change_sources_list