fix_update_issue() {
    echo -e "\033[1;36m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;36m║                 APT PROBLEM RESOLUTION TOOL                 ║\033[0m"
    echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo

    # Check if we have internet connection first
    if ! ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo -e "\033[1;31m❌ No internet connection detected!\033[0m"
        echo -e "\033[1;33mPlease check your network connection and try again.\033[0m"
        return 1
    fi

    local success=true

    echo -e "\033[1;34m🔧 Step 1: Checking and configuring packages...\033[0m"
    sudo dpkg --configure -a
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m❌ Failed to configure packages\033[0m"
        success=false
    fi

    echo -e "\033[1;34m🔧 Step 2: Fixing broken dependencies...\033[0m"
    sudo apt --fix-broken install -y
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m❌ Failed to fix broken packages\033[0m"
        success=false
    fi

    echo -e "\033[1;34m🔧 Step 3: Cleaning package cache...\033[0m"
    sudo apt-get clean
    sudo apt-get autoclean -y

    echo -e "\033[1;34m🔧 Step 4: Removing unnecessary packages...\033[0m"
    sudo apt-get autoremove -y

    echo -e "\033[1;34m🔧 Step 5: Updating package lists...\033[0m"
    sudo apt-get update
    if [ $? -ne 0 ]; then
        echo -e "\033[1;31m❌ Failed to update package lists\033[0m"
        
        # Try alternative approach if update fails
        echo -e "\033[1;33m🔄 Trying alternative update method...\033[0m"
        sudo rm -f /var/lib/apt/lists/lock
        sudo rm -f /var/cache/apt/archives/lock
        sudo rm -f /var/lib/dpkg/lock*
        sudo dpkg --configure -a
        sudo apt-get update -y
    fi

    echo -e "\033[1;34m🔧 Step 6: Fixing missing dependencies...\033[0m"
    sudo apt-get install -f -y

    echo -e "\033[1;34m🔧 Step 7: Checking package consistency...\033[0m"
    sudo apt-get check

    # Additional fixes for common issues
    echo -e "\033[1;34m🔧 Step 8: Fixing lock files and permissions...\033[0m"
    sudo fuser -vki /var/lib/dpkg/lock
    sudo fuser -vki /var/lib/apt/lists/lock
    sudo fuser -vki /var/cache/apt/archives/lock

    # Remove lock files if they're stale
    sudo rm -f /var/lib/apt/lists/lock
    sudo rm -f /var/cache/apt/archives/lock
    sudo rm -f /var/lib/dpkg/lock
    sudo rm -f /var/lib/dpkg/lock-frontend

    # Fix permissions
    sudo chmod 644 /var/lib/dpkg/status
    sudo chown root:root /var/lib/dpkg/status

    echo -e "\033[1;34m🔧 Step 9: Rebuilding package cache...\033[0m"
    sudo apt-get update --fix-missing

    # Final check
    echo -e "\033[1;34m🔧 Step 10: Final system check...\033[0m"
    if sudo apt-get check; then
        echo -e "\033[1;32m✅ System package consistency verified\033[0m"
    else
        echo -e "\033[1;31m❌ Package consistency check failed\033[0m"
        success=false
    fi

    if $success; then
        echo -e "\n\033[1;32m🎉 APT issues resolved successfully!\033[0m"
        echo -e "\033[1;33mYou can now run 'sudo apt upgrade' to update your system.\033[0m"
    else
        echo -e "\n\033[1;31m⚠️  Some issues may require manual intervention.\033[0m"
        echo -e "\033[1;33mCheck the output above for specific error messages.\033[0m"
    fi

    # Offer to run upgrade
    read -p "$(echo -e '\033[1;32mRun apt upgrade now? (y/N): \033[0m')" run_upgrade
    if [[ "$run_upgrade" =~ ^[Yy]$ ]]; then
        echo -e "\033[1;33m🔄 Running apt upgrade...\033[0m"
        sudo apt upgrade -y
		read -p "Press Enter to continue..."
    fi
}

# Additional specialized fix functions
fix_specific_issues() {
while true; do
    echo -e "\033[1;36m╔══════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;36m║                 SPECIFIC PROBLEM SOLVER                     ║\033[0m"
    echo -e "\033[1;36m╚══════════════════════════════════════════════════════════════╝\033[0m"
    echo

    echo -e "\033[1;33m┌──────────────────────────────────────────────────────────────┐\033[0m"
    echo -e "\033[1;33m│                     AVAILABLE FIXES                         │\033[0m"
    echo -e "\033[1;33m├──────────────────────────────────────────────────────────────┤\033[0m"
    echo -e "\033[1;32m│  1. Fix held packages                                      │\033[0m"
    echo -e "\033[1;34m│  2. Fix repository errors                                  │\033[0m"
    echo -e "\033[1;35m│  3. Fix GPG key errors                                     │\033[0m"
    echo -e "\033[1;36m│  4. Fix dependency hell                                    │\033[0m"
    echo -e "\033[1;33m│  5. Clean package cache completely                         │\033[0m"
	echo -e "\033[1;34m│  6. Auto fix                                               │\033[0m"
    echo -e "\033[1;33m├──────────────────────────────────────────────────────────────┤\033[0m"
    echo -e "\033[1;31m│  0. Return to main menu                                    │\033[0m"
    echo -e "\033[1;33m└──────────────────────────────────────────────────────────────┘\033[0m"

    read -p "$(echo -e '\033[1;32mSelect fix option [0-5]: \033[0m')" fix_choice

    case $fix_choice in
        1) fix_held_packages ;;
        2) fix_repository_errors ;;
        3) fix_gpg_errors ;;
        4) fix_dependency_hell ;;
        5) clean_package_cache ;;
		6) fix_update_issue ;;
        0) return ;;
        *) echo -e "\033[1;31m❌ Invalid option\033[0m" ;;
    esac
	done
}

fix_held_packages() {
    echo -e "\033[1;34m🔧 Fixing held packages...\033[0m"
    # List held packages
    local held_packages=$(apt-mark showhold)
    if [ -n "$held_packages" ]; then
        echo -e "\033[1;33mHeld packages found:\033[0m"
        echo "$held_packages"
        read -p "$(echo -e '\033[1;32mUnhold these packages? (y/N): \033[0m')" unhold_choice
        if [[ "$unhold_choice" =~ ^[Yy]$ ]]; then
            sudo apt-mark unhold $held_packages
            echo -e "\033[1;32m✅ Packages unheld\033[0m"
        fi
    else
        echo -e "\033[1;32m✅ No held packages found\033[0m"
		read -p "Press Enter to continue..."
    fi
}

fix_repository_errors() {
    echo -e "\033[1;34m🔧 Fixing repository errors...\033[0m"
    # Remove problematic repository lists
    sudo rm -f /var/lib/apt/lists/*_Packages
    sudo rm -f /var/lib/apt/lists/*_Translation-*
    sudo rm -f /var/lib/apt/lists/*_InRelease
    sudo rm -f /var/lib/apt/lists/*_Release
    sudo rm -f /var/lib/apt/lists/*_Release.gpg
    
    # Clean and update
    sudo apt-get clean
    sudo apt-get update --fix-missing
	read -p "Press Enter to continue..."
}

fix_gpg_errors() {
    echo -e "\033[1;34m🔧 Fixing GPG key errors...\033[0m"
    # Update keyring
    sudo apt-get install -y ubuntu-keyring
    sudo apt-key update
    # Fix common GPG errors
    sudo rm -f /etc/apt/trusted.gpg.d/*.gpg~
    sudo rm -f /etc/apt/trusted.gpg.d/*.gpg.*
	read -p "Press Enter to continue..."
}

fix_dependency_hell() {
    echo -e "\033[1;34m🔧 Fixing dependency issues...\033[0m"
    # Use aptitude for better dependency resolution if available
    if command -v aptitude &>/dev/null; then
        sudo aptitude install -f -y
    else
        sudo apt-get install -f -y
        # Try dist-upgrade for major dependency issues
        read -p "$(echo -e '\033[1;32mRun dist-upgrade to resolve complex dependencies? (y/N): \033[0m')" dist_upgrade_choice
        if [[ "$dist_upgrade_choice" =~ ^[Yy]$ ]]; then
            sudo apt-get dist-upgrade -y
        fi
		read -p "Press Enter to continue..."
    fi
}

clean_package_cache() {
    echo -e "\033[1;34m🔧 Deep cleaning package cache...\033[0m"
    sudo apt-get clean
    sudo apt-get autoclean
    # Remove all cached packages
    sudo rm -rf /var/cache/apt/archives/*
    sudo rm -rf /var/lib/apt/lists/*
    # Recreate necessary directories
    sudo mkdir -p /var/cache/apt/archives/partial
    sudo mkdir -p /var/lib/apt/lists/partial
    sudo chmod 755 /var/cache/apt/archives/partial
    sudo chmod 755 /var/lib/apt/lists/partial
    # Update
    sudo apt-get update
	read -p "Press Enter to continue..."
}

fix_specific_issues