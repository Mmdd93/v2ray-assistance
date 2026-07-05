#!/bin/bash

# Variables
SPEEDTEST_DIR="/root/speedtest"
SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
SPEEDTEST_ARCHIVE="ookla-speedtest-1.2.0-linux-x86_64.tgz"
SPEEDTEST_BIN="speedtest"

# Function to install dependencies
install_speedtest() {
    echo -e "\033[1;32mChecking dependencies (curl, jq, wget, iperf3)...\033[0m"
    if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v wget &> /dev/null || ! command -v iperf3 &> /dev/null; then
        echo -e "\033[1;33mInstalling missing dependencies...\033[0m"
        apt-get update -y && apt-get install curl jq wget iperf3 -y
    fi

    if [ ! -d "$SPEEDTEST_DIR" ]; then
        echo -e "\033[1;32mCreating Speedtest directory: $SPEEDTEST_DIR\033[0m"
        mkdir -p "$SPEEDTEST_DIR"
    fi

    echo -e "\033[1;32mDownloading Speedtest CLI...\033[0m"
    curl -sL "$SPEEDTEST_URL" -o "$SPEEDTEST_DIR/$SPEEDTEST_ARCHIVE"
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31mError downloading Speedtest CLI. Exiting.\033[0m"
        exit 1
    fi

    echo -e "\033[1;32mExtracting Speedtest CLI...\033[0m"
    tar -xzf "$SPEEDTEST_DIR/$SPEEDTEST_ARCHIVE" -C "$SPEEDTEST_DIR"
    chmod +x "$SPEEDTEST_DIR/$SPEEDTEST_BIN"
    echo -e "\033[1;32mSpeedtest CLI installed successfully.\033[0m"
}

# Function to run Speedtest CLI (Ookla)
run_speedtest() {
    if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
        echo -e "\033[1;33mRequired tools (curl/jq) missing for Live API. Installing now...\033[0m"
        apt-get update -y && apt-get install curl jq -y
    fi

    local countries=(
        "Iran" "Germany" "Turkey" "Austria" "France" "Netherlands" 
        "United Kingdom" "United States" "Canada" "Singapore" "Japan" 
        "Bahrain" "United Arab Emirates" "Saudi Arabia" "Qatar" "Oman" 
        "Kuwait" "Finland" "Sweden" "Norway" "Italy" "Spain" 
        "Switzerland" "Poland" "Australia" "South Africa" "Egypt"
    )

    while true; do
        clear
        echo -e "\033[1;34m--- Speedtest Server Selection (GLOBAL LIVE API) ---\033[0m"
        echo -e "\033[1;32m1. Show Nearest Local Servers\033[0m"
        echo -e "\033[1;32m2. Select Server by Country Number\033[0m"
        echo -e "\033[1;32m3. Custom Text Search (Country/City Name)\033[0m"
        echo -e "\033[1;32m4. Automatic Best Server Selection\033[0m"
        echo -e "\033[1;31m0. Return to Main Menu\033[0m"
        read -p $'\033[1;36mChoose an option (0-4): \033[0m' OPTION

        case $OPTION in
            0) return ;;
            1)
                echo -e "\n\033[1;33mFetching nearest local online servers...\033[0m"
                echo -e "------------------------------------------------------------"
                "$SPEEDTEST_DIR/$SPEEDTEST_BIN" --accept-license --accept-gdpr --servers
                echo -e "------------------------------------------------------------"
                read -p $'\033[1;36mEnter Server ID from the list above (or 0 to back): \033[0m' SERVER_ID
                if [ "$SERVER_ID" = "0" ] || [ -z "$SERVER_ID" ]; then continue; fi
                break
                ;;
            2)
                clear
                echo -e "\033[1;34m--- Select a Country by Number ---\033[0m"
                for i in "${!countries[@]}"; do
                    printf "\033[1;32m%2d) %-20s\033[0m" $((i+1)) "${countries[$i]}"
                    if (( (i+1) % 3 == 0 )); then echo ""; fi
                done
                echo -e "\n------------------------------------------------------------"
                echo -e "\033[1;31m0) Back to Selection Menu\033[0m"
                read -p $'\033[1;36mEnter country number: \033[0m' COUNTRY_NUM
                
                if [ "$COUNTRY_NUM" = "0" ] || [ -z "$COUNTRY_NUM" ]; then continue; fi
                if ! [[ "$COUNTRY_NUM" =~ ^[0-9]+$ ]] || [ "$COUNTRY_NUM" -lt 1 ] || [ "$COUNTRY_NUM" -gt "${#countries[@]}" ]; then
                    echo -e "\033[1;31mInvalid country number.\033[0m"
                    read -p "Press Enter to continue..."
                    continue
                fi
                SEARCH_TERM="${countries[$((COUNTRY_NUM-1))]}"
                ;;
            3)
                read -p $'\033[1;36mEnter Country or City name manually (or 0 to back): \033[0m' SEARCH_TERM
                if [ "$SEARCH_TERM" = "0" ] || [ -z "$SEARCH_TERM" ]; then continue; fi
                ;;
            4)
                SERVER_ID=""
                break
                ;;
            *)
                echo -e "\033[1;31mInvalid option.\033[0m"; read -p "Press Enter to return..."; continue ;;
        esac

        if [ -n "$SEARCH_TERM" ]; then
            echo -e "\n\033[1;33mConnecting to global network registry for '$SEARCH_TERM'...\033[0m"
            echo -e "------------------------------------------------------------"
            printf "\033[1;34m%-10s %-30s %-20s\033[0m\n" "ID" "Name/Sponsor" "Location"
            echo -e "------------------------------------------------------------"
            
            local encoded_term=$(echo "$SEARCH_TERM" | sed 's/ /%20/g')
            curl -s "https://www.speedtest.net/api/js/servers?search=$encoded_term&limit=15" | \
            jq -r '.[] | "\(.id)\t\(.sponsor)\t\(.name) (\(.country))"' | while IFS=$'\t' read -r id sponsor location; do
                if [ -n "$id" ]; then
                    printf "\033[1;32m%-10s %-30.30s %-20.20s\033[0m\n" "$id" "$sponsor" "$location"
                fi
            done
            echo -e "------------------------------------------------------------"
            read -p $'\033[1;36mEnter Server ID from the list above (or 0 to back): \033[0m' SERVER_ID
            if [ "$SERVER_ID" = "0" ] || [ -z "$SERVER_ID" ]; then continue; fi
            break
        fi
    done

    echo -e "\n\033[1;32mRunning Speedtest...\033[0m"
    if [ -z "$SERVER_ID" ]; then
        "$SPEEDTEST_DIR/$SPEEDTEST_BIN" --accept-license --accept-gdpr
    else
        "$SPEEDTEST_DIR/$SPEEDTEST_BIN" --accept-license --accept-gdpr -s "$SERVER_ID"
    fi
    echo ""
    read -p "Press Enter to continue..."
}

# Function to run Wget Speedtest
run_wget_speedtest() {
    clear
    echo -e "\033[1;34m--- Direct HTTP Download Test (wget) ---\033[0m"
    echo -e "  1. Frankfurt, Germany (Linode)"
    echo -e "  2. Amsterdam, Netherlands (Linode)"
    echo -e "  3. Newark, USA (Linode)"
    echo -e "------------------------------------------------------------"
    echo -e "\033[1;31m0. Back to Main Menu\033[0m"
    read -p $'\033[1;36mSelect a server (0-3): \033[0m' WGET_OPT

    case $WGET_OPT in
        0) return ;;
        1) wget -O /dev/null http://speedtest.frankfurt.linode.com/100MB-frankfurt.bin ;;
        2) wget -O /dev/null http://speedtest.amsterdam.linode.com/100MB-amsterdam.bin ;;
        3) wget -O /dev/null http://speedtest.newark.linode.com/100MB-newark.bin ;;
        *) echo -e "\033[1;31mInvalid option.\033[0m"; sleep 1; return ;;
    esac
    read -p "Press Enter to continue..."
}

# NEW EXTENSIVE FUNCTION: Advanced iPerf3 Expert Panel
run_iperf3_advanced() {
    if ! command -v iperf3 &> /dev/null; then apt-get install iperf3 -y; fi

    # Array of highly stable worldwide public iPerf3 servers
    local servers=(
        "speedtest.wtnet.de" "paris.iperf3.fr" "iperf.worldstream.nl" 
        "iperf.biznetnetworks.com" "speedtest.uztelecom.uz" "iperf3.cc.columbia.edu"
        "bouygues.testdebit.fr" "iperf3.velocityonline.net" "lon.iperf.hostkey.com"
    )
    local labels=(
        "WilhelmTel (Germany)" "NextGen (Paris, France)" "Worldstream (Netherlands)"
        "Biznet (Indonesia)" "UzTelecom (Uzbekistan)" "Columbia University (New York, USA)"
        "Bouygues Telecom (France)" "Velocity Online (Florida, USA)" "Hostkey (London, UK)"
    )

    while true; do
        clear
        echo -e "\033[1;34m============================================================\033[0m"
        echo -e "\033[1;34m               iPerf3 ADVANCED EXPERT PANEL                 \033[0m"
        echo -e "\033[1;34m============================================================\033[0m"
        echo -e "\033[1;35m[ AVAILABLE GLOBAL HIGH-SPEED SERVERS ]\033[0m"
        for i in "${!servers[@]}"; do
            printf "\033[1;32m%2d) %-30s -> %-25s\033[0m\n" $((i+1)) "${labels[$i]}" "${servers[$i]}"
        done
        echo -e "------------------------------------------------------------"
        echo -e "\033[1;33mM1. [MULTI-SERVER] Dual-Server Simultaneous Test (Germany + France)\033[0m"
        echo -e "\033[1;33mM2. [MULTI-SERVER] Triple-Server Stress Test (Germany + France + NL)\033[0m"
        echo -e "------------------------------------------------------------"
        echo -e "\033[1;31m0. Return to Main Menu\033[0m"
        echo -e "------------------------------------------------------------"
        read -p $'\033[1;36mSelect Server Number or Custom Option (0-9 / M1 / M2): \033[0m' CHOICE

        if [ "$CHOICE" = "0" ]; then return; fi

        # Advanced Tweak Variables (Defaults)
        local mode="-R"      # Default to Upload test (Server to Client / Reverse)
        local streams="4"    # Default 4 parallel threads
        local time="10"      # Default 10 seconds duration
        local proto=""       # Default TCP
        local port="5201"    # Default iPerf port

        # Multi-Server Core Engines
        if [ "$CHOICE" = "M1" ] || [ "$CHOICE" = "m1" ] || [ "$CHOICE" = "M2" ] || [ "$CHOICE" = "m2" ]; then
            echo -e "\n\033[1;35m--- Configure Multi-Server Tweak Parameters ---\033[0m"
            read -p "1. Enter Direction [1: Upload(Pure Pump) / 2: Download] (Default 1): " DIRECT
            [ "$DIRECT" = "2" ] && mode=""
            
            read -p "2. Enter Parallel Threads per server (1-10) (Default 4): " STRM
            [[ "$STRM" =~ ^[0-9]+$ ]] && streams="$STRM"

            read -p "3. Enter Duration in seconds (Default 10): " SEC
            [[ "$SEC" =~ ^[0-9]+$ ]] && time="$SEC"

            echo -e "\n\033[1;32mLaunching Multi-Server parallel pipelines. Splitting terminal views...\033[0m"
            echo -e "----------------------------------------------------------------------"
            
            if [ "$CHOICE" = "M1" ] || [ "$CHOICE" = "m1" ]; then
                echo -e "\033[1;33m[Job 1] Pumping to Germany (${servers[0]})\033[0m"
                echo -e "\033[1;36m[Job 2] Pumping to France (${servers[1]})\033[0m"
                iperf3 -c "${servers[0]}" $mode -P "$streams" -t "$time" --json | jq '.end.sum_received.bits_per_second / 1024 / 1024' | sed 's/^/Germany Output: /' &
                PID1=$!
                iperf3 -c "${servers[1]}" $mode -P "$streams" -t "$time" --json | jq '.end.sum_received.bits_per_second / 1024 / 1024' | sed 's/^/France Output: /' &
                PID2=$!
                wait $PID1 $PID2
            else
                echo -e "\033[1;33m[Job 1] Pumping to Germany (${servers[0]})\033[0m"
                echo -e "\033[1;36m[Job 2] Pumping to France (${servers[1]})\033[0m"
                echo -e "\033[1;35m[Job 3] Pumping to Netherlands (${servers[2]})\033[0m"
                iperf3 -c "${servers[0]}" $mode -P "$streams" -t "$time" &
                PID1=$!
                iperf3 -c "${servers[1]}" $mode -P "$streams" -t "$time" &
                PID2=$!
                iperf3 -c "${servers[2]}" $mode -P "$streams" -t "$time" &
                PID3=$!
                wait $PID1 $PID2 $PID3
            fi
            echo -e "\n\033[1;32mParallel Multi-Server benchmark finalized.\033[0m"
            read -p "Press Enter to continue..."
            continue
        fi

        # Single Server Custom Engine Configurator
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#servers[@]}" ]; then
            local target_server="${servers[$((CHOICE-1))]}"
            
            clear
            echo -e "\033[1;34m--- Tweak Performance Options for: $target_server ---\033[0m"
            echo -e "\033[1;32m1. Test Mode:\033[0m [U] Upload (Reverse Network Pump) | [D] Download"
            read -p "   Choose Mode (Default U): " TM
            [ "$TM" = "D" ] || [ "$TM" = "d" ] && mode=""

            echo -e "\033[1;32m2. Protocol Mode:\033[0m [T] TCP (Standard) | [U] UDP (Raw Stress)"
            read -p "   Choose Protocol (Default T): " PM
            [ "$PM" = "U" ] || [ "$PM" = "u" ] && proto="-u -b 1000M" # 1G bandwidth allocation for UDP

            read -p "3. Enter Parallel Streams/Threads count (1-16) (Default 4): " THREADS
            [[ "$THREADS" =~ ^[0-9]+$ ]] && streams="$THREADS"

            read -p "4. Enter Test Time Frame/Duration (Seconds) (Default 10): " DUR
            [[ "$DUR" =~ ^[0-9]+$ ]] && time="$DUR"

            read -p "5. Custom Server Port (Hit Enter for Default 5201): " PRT
            [[ "$PRT" =~ ^[0-9]+$ ]] && port="$PRT"

            echo -e "\n\033[1;33mExecuting Custom Pipeline: iperf3 -c $target_server -p $port $mode -P $streams -t $time $proto\033[0m\n"
            echo -e "------------------------------------------------------------"
            iperf3 -c "$target_server" -p "$port" $mode -P "$streams" -t "$time" $proto
            echo -e "------------------------------------------------------------"
            read -p "Press Enter to continue..."
        else
            echo -e "\033[1;31mInvalid index choice.\033[0m"; sleep 1
        fi
    done
}

# Function to remove Speedtest CLI Safely
remove_speedtest() {
    if [ -d "$SPEEDTEST_DIR" ]; then
        echo -e "\033[1;33mRemoving Speedtest CLI directory and files...\033[0m"
        rm -rf "$SPEEDTEST_DIR"
        echo -e "\033[1;32mSpeedtest CLI has been successfully removed.\033[0m"
    else
        echo -e "\033[1;31mSpeedtest CLI is not installed.\033[0m"
    fi
}

# Main Menu
while true; do
    clear
    echo -e "\033[1;34mSpeedtest & Network Infrastructure Tool\033[0m"
    echo -e "\033[1;32m1. Install/Update Global Dependencies\033[0m"
    echo -e "\033[1;32m2. Ookla Speedtest Engine (Official API / Global Search)\033[0m"
    echo -e "\033[1;32m3. Direct Wget HTTP Speedtest (Download - 0MB Disk Allocation)\033[0m"
    echo -e "\033[1;32m4. iPerf3 Advanced Expert Panel (Multi-Server, Custom TCP/UDP)\033[0m"
    echo -e "\033[1;32m5. Uninstall Speedtest CLI\033[0m"
    echo -e "------------------------------------------------------------"
    echo -e "\033[1;31m0. Exit\033[0m"
    read -p $'\033[1;36mChoose an option (0-5): \033[0m' MAIN_OPTION

    case $MAIN_OPTION in
        1) install_speedtest; read -p "Press Enter to continue..." ;;
        2) if [ -f "$SPEEDTEST_DIR/$SPEEDTEST_BIN" ]; then run_speedtest; else echo -e "\033[1;31mPlease run Option 1 first.\033[0m"; read -p "Press Enter..."; fi ;;
        3) run_wget_speedtest ;;
        4) run_iperf3_advanced ;;
        5) remove_speedtest; read -p "Press Enter to continue..." ;;
        0) echo -e "\033[1;32mExiting. Goodbye!\033[0m"; exit 0 ;;
        *) echo -e "\033[1;31mInvalid option.\033[0m"; read -p "Press Enter to continue..." ;;
    esac
done
