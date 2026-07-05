#!/bin/bash

# Variables
SPEEDTEST_DIR="/root/speedtest"
SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
SPEEDTEST_ARCHIVE="ookla-speedtest-1.2.0-linux-x86_64.tgz"
SPEEDTEST_BIN="speedtest"

# Function to install dependencies and Speedtest CLI
install_speedtest() {
    echo -e "\033[1;32mChecking dependencies (curl, jq, wget)...\033[0m"
    if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null || ! command -v wget &> /dev/null; then
        echo -e "\033[1;33mInstalling missing dependencies...\033[0m"
        apt-get update -y && apt-get install curl jq wget -y
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

# Function to run Speedtest CLI
run_speedtest() {
    if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
        echo -e "\033[1;33mRequired tools (curl/jq) missing for Live API. Installing now...\033[0m"
        apt-get update -y && apt-get install curl jq -y
        if [ $? -ne 0 ]; then
            echo -e "\033[1;31mFailed to install jq/curl. Cannot perform global search.\033[0m"
            read -p "Press Enter to return..."
            return
        fi
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
                echo -e "\033[1;31mInvalid option.\033[0m"
                read -p "Press Enter to return..."
                continue
                ;;
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

    if [ -n "$SERVER_ID" ] && ! [[ "$SERVER_ID" =~ ^[0-9]+$ ]]; then
        echo -e "\033[1;31mInvalid server ID. Must be a number.\033[0m"
        read -p "Press Enter to return..."
        return
    fi

    echo -e "\n\033[1;32mRunning Speedtest...\033[0m"
    
    if [ -z "$SERVER_ID" ]; then
        "$SPEEDTEST_DIR/$SPEEDTEST_BIN" --accept-license --accept-gdpr
    else
        echo -e "\033[1;33mTrying selected Server ID: $SERVER_ID...\033[0m"
        "$SPEEDTEST_DIR/$SPEEDTEST_BIN" --accept-license --accept-gdpr -s "$SERVER_ID"
        
        if [ $? -ne 0 ]; then
            echo -e "\n\033[1;31mTarget server timed out or network port is blocked.\033[0m"
            echo -e "\033[1;35mBench.sh Fallback: Auto-routing to the best responsive server...\033[0m"
            echo -e "------------------------------------------------------------"
            "$SPEEDTEST_DIR/$SPEEDTEST_BIN" --accept-license --accept-gdpr
        fi
    fi
    echo ""
    read -p "Press Enter to continue..."
}

# NEW FUNCTION: Direct Wget Speedtest (No Disk Space Used)
run_wget_speedtest() {
    clear
    echo -e "\033[1;34m--- Direct HTTP Speedtest (wget to /dev/null) ---\033[0m"
    echo -e "\033[1;32m1. Frankfurt, Germany (Linode)\033[0m"
    echo -e "\033[1;32m2. Amsterdam, Netherlands (Linode)\033[0m"
    echo -e "\033[1;32m3. London, United Kingdom (Linode)\033[0m"
    echo -e "\033[1;32m4. Newark, USA (Linode)\033[0m"
    echo -e "\033[1;32m5. Singapore (Linode)\033[0m"
    echo -e "\033[1;31m0. Back to Main Menu\033[0m"
    read -p $'\033[1;36mSelect a test server (0-5): \033[0m' WGET_OPT

    local url=""
    case $WGET_OPT in
        0) return ;;
        1) url="http://speedtest.frankfurt.linode.com/100MB-frankfurt.bin" ;;
        2) url="http://speedtest.amsterdam.linode.com/100MB-amsterdam.bin" ;;
        3) url="http://speedtest.london.linode.com/100MB-london.bin" ;;
        4) url="http://speedtest.newark.linode.com/100MB-newark.bin" ;;
        5) url="http://speedtest.singapore.linode.com/100MB-singapore.bin" ;;
        *) echo -e "\033[1;31mInvalid option.\033[0m"; sleep 1; return ;;
    esac

    echo -e "\n\033[1;33mStarting download test... (Output routed to /dev/null)\033[0m"
    echo -e "\033[1;35mPlease check the progress and final speed below:\033[0m\n"
    
    # Run wget, saving to /dev/null so it consumes 0 bytes of disk space
    wget -O /dev/null "$url"
    
    echo -e "\n\033[1;32mTest completed. Disk space remained untouched.\033[0m"
    read -p "Press Enter to continue..."
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
    echo -e "\033[1;34mSpeedtest CLI Manager\033[0m"
    echo -e "\033[1;32m1. Install/Update Speedtest CLI\033[0m"
    echo -e "\033[1;32m2. Run Ookla Speedtest Benchmark (Official CLI)\033[0m"
    echo -e "\033[1;32m3. Run Direct HTTP Speedtest (wget - No Disk Space)\033[0m"
    echo -e "\033[1;31m4. Remove Speedtest CLI\033[0m"
    echo -e "\033[1;31m0. Exit\033[0m"
    read -p $'\033[1;36mChoose an option (0-4): \033[0m' MAIN_OPTION

    case $MAIN_OPTION in
        1)
            install_speedtest
            read -p "Press Enter to continue..."
            ;;
        2)
            if [ -f "$SPEEDTEST_DIR/$SPEEDTEST_BIN" ]; then
                run_speedtest
            else
                echo -e "\033[1;31mSpeedtest CLI is not installed. Please install it first.\033[0m"
                read -p "Press Enter to continue..."
            fi
            ;;
        3)
            run_wget_speedtest
            ;;
        4)
            remove_speedtest
            read -p "Press Enter to continue..."
            ;;
        0)
            echo -e "\033[1;32mExiting. Goodbye!\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Please choose again.\033[0m"
            read -p "Press Enter to continue..."
            ;;
    esac
done
