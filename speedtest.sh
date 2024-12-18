#!/bin/bash
# Variables
SPEEDTEST_DIR="/root/speedtest"
SPEEDTEST_URL="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
SPEEDTEST_ARCHIVE="ookla-speedtest-1.2.0-linux-x86_64.tgz"
SPEEDTEST_BIN="speedtest"

# Function to install Speedtest CLI
install_speedtest() {
    if [ ! -d "$SPEEDTEST_DIR" ]; then
        echo -e "\033[1;32mCreating Speedtest directory: $SPEEDTEST_DIR\033[0m"
        mkdir -p "$SPEEDTEST_DIR"
    else
        echo -e "\033[1;33mSpeedtest directory already exists: $SPEEDTEST_DIR\033[0m"
    fi

    echo -e "\033[1;32mDownloading Speedtest CLI...\033[0m"
    wget -q "$SPEEDTEST_URL" -O "$SPEEDTEST_DIR/$SPEEDTEST_ARCHIVE"
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31mError downloading Speedtest CLI. Exiting.\033[0m"
        exit 1
    fi

    echo -e "\033[1;32mExtracting Speedtest CLI...\033[0m"
    tar -xzf "$SPEEDTEST_DIR/$SPEEDTEST_ARCHIVE" -C "$SPEEDTEST_DIR"
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31mError extracting Speedtest CLI. Exiting.\033[0m"
        exit 1
    fi

    chmod +x "$SPEEDTEST_DIR/$SPEEDTEST_BIN"
    echo -e "\033[1;32mSpeedtest CLI installed successfully in $SPEEDTEST_DIR.\033[0m"
}

# Function to run Speedtest CLI
run_speedtest() {
clear
    echo -e "\033[1;34m--- select server ---\033[0m"

    echo -e "\n\033[1;32m1. tehran \033[0m"
    echo -e "\033[1;32m2. Vienna \033[0m"
    echo -e "\033[1;32m3. Istanbul \033[0m"
    echo -e "\033[1;32m4. Bahrain \033[0m"
    echo -e "\033[1;32m5. Frankfurt \033[0m"
    echo -e "\033[1;32m6. enter Custom server ID\033[0m"
    echo -e "\033[1;32m7. Run Automatic server selection\033[0m"

    read -p $'\033[1;36mChoose an option (1-5): \033[0m' OPTION

    case $OPTION in
        1)
            SERVER_ID=4317
            ;;
        2)
            SERVER_ID=3744
            ;;
        3)
            SERVER_ID=33376
            ;;
        4)
            SERVER_ID=52650
            ;;
        5)
            SERVER_ID=40094
            ;;
        6)
            read -p $'\033[1;36mEnter server ID: \033[0m' SERVER_ID
            if ! [[ "$SERVER_ID" =~ ^[0-9]+$ ]]; then
                echo -e "\033[1;31mInvalid server ID. Please enter a numeric value.\033[0m"
                return
            fi
            ;;
        7)
            SERVER_ID=""
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Please choose a valid option (1-5).\033[0m"
            return
            ;;
    esac

    # Check server validity if not using automatic selection
 

    echo -e "\033[1;32mRunning Speedtest...\033[0m"
    if [ -z "$SERVER_ID" ]; then
        "$SPEEDTEST_DIR/$SPEEDTEST_BIN"
    else
        "$SPEEDTEST_DIR/$SPEEDTEST_BIN" -s "$SERVER_ID"
    fi
    read -p "press enter to continue"
}


# Function to remove Speedtest CLI
remove_speedtest() {
    if [ -d "$SPEEDTEST_DIR" ]; then
        echo -e "\033[1;33mRemoving Speedtest CLI and its files...\033[0m"
        rm -rf "$SPEEDTEST_DIR"
        echo -e "\033[1;32mSpeedtest CLI has been removed.\033[0m"
    else
        echo -e "\033[1;31mSpeedtest CLI is not installed.\033[0m"
    fi
}

# Main Menu
while true; do
    clear
	echo -e "\033[1;34mSpeedtest CLI\033[0m"

    echo -e "\033[1;32m1. Install Speedtest CLI\033[0m"
    echo -e "\033[1;32m2. Run Speedtest\033[0m"
    echo -e "\033[1;32m3. Remove Speedtest CLI\033[0m"
    echo -e "\033[1;32m4. Exit\033[0m"
    read -p $'\033[1;36mChoose an option (1-4): \033[0m' MAIN_OPTION

    case $MAIN_OPTION in
        1)
            install_speedtest
	    read -p "press enter to continue"
            ;;
        2)
            if [ -f "$SPEEDTEST_DIR/$SPEEDTEST_BIN" ]; then
                run_speedtest
		
            else
                echo -e "\033[1;31mSpeedtest CLI is not installed. Please install it first.\033[0m"
            fi
	    read -p "press enter to continue"
            ;;
        3)
            remove_speedtest
	    read -p "press enter to continue"
            ;;
        4)
            echo -e "\033[1;32mExiting. Goodbye!\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Please choose again.\033[0m"
	    read -p "press enter to continue"
            ;;
    esac
done
