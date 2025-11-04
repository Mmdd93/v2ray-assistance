#!/bin/bash

# Colors for menu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to display header
show_header() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════╗"
    echo "║         SYSTEM CLEANUP MENU         ║"
    echo "║      Comprehensive Clean Tool       ║"
    echo "╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e " $(netspeed)"
}

# Function to confirm deletion
confirm_deletion() {
    local item_count="$1"
    local description="$2"
    
    if [ "$item_count" -eq 0 ]; then
        echo -e "${GREEN}No items found to delete.${NC}"
        return 1
    fi
    
    echo -e "\n${YELLOW}Found $item_count $description${NC}"
    echo -e "${RED}WARNING: This will permanently delete files!${NC}"
    read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        echo -e "${YELLOW}Deletion cancelled.${NC}"
        return 1
    fi
}

# Function to show files that will be deleted
show_files_to_delete() {
    local path="$1"
    local pattern="$2"
    local days="$3"
    
    echo -e "${CYAN}Files that will be deleted:${NC}"
    echo "────────────────────────────────────────────────────────────────"
    find "$path" -name "$pattern" -type f -mtime +$days -ls 2>/dev/null | head -20
    local total=$(find "$path" -name "$pattern" -type f -mtime +$days 2>/dev/null | wc -l)
    if [ "$total" -gt 20 ]; then
        echo -e "${YELLOW}... and $((total - 20)) more files${NC}"
    fi
    echo "────────────────────────────────────────────────────────────────"
    return $total
}

# Function to press any key to continue
press_any_key() {
    echo -e "\n${YELLOW}Press any key to continue...${NC}"
    read -n 1 -s
}

# 1. Clean temporary files
cleanup_temp_files() {
    show_header
    echo -e "${BLUE}=== TEMPORARY FILES CLEANUP ===${NC}"
    
    local temp_dirs=("/tmp" "/var/tmp" "$HOME/.tmp" "$HOME/.cache")
    local total_freed=0
    local delete_confirmed=false
    
    for dir in "${temp_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo -e "\n${CYAN}Scanning: $dir${NC}"
            
            # Calculate size before cleanup
            if command -v du &> /dev/null; then
                size_before=$(du -sh "$dir" 2>/dev/null | cut -f1) || size_before="Unknown"
                echo "Current size: $size_before"
            fi
            
            # Show files that will be deleted
            echo -e "${YELLOW}Looking for files older than 7 days...${NC}"
            local file_count=$(find "$dir" -type f -atime +7 2>/dev/null | wc -l)
            local dir_count=$(find "$dir" -type d -empty -atime +7 2>/dev/null | wc -l)
            
            if [ "$file_count" -gt 0 ]; then
                show_files_to_delete "$dir" "*" "7"
            fi
            
            if [ "$file_count" -gt 0 ] || [ "$dir_count" -gt 0 ]; then
                if [ "$delete_confirmed" = false ]; then
                    if ! confirm_deletion "$((file_count + dir_count))" "items to delete"; then
                        continue
                    else
                        delete_confirmed=true
                    fi
                fi
                
                # Actually delete files
                echo -e "${RED}Deleting files...${NC}"
                find "$dir" -type f -atime +7 -delete 2>/dev/null
                find "$dir" -type d -empty -delete 2>/dev/null
                echo -e "${GREEN}Deleted $file_count files and $dir_count empty directories${NC}"
            else
                echo -e "${GREEN}No old files found to delete.${NC}"
            fi
            
            # Calculate size after cleanup
            if command -v du &> /dev/null; then
                size_after=$(du -sh "$dir" 2>/dev/null | cut -f1) || size_after="Unknown"
                echo "Size after cleanup: $size_after"
            fi
        else
            echo -e "${YELLOW}Directory not found: $dir${NC}"
        fi
    done
    
    # Browser caches
    echo -e "\n${CYAN}Scanning browser caches...${NC}"
    if [ -d "$HOME/.cache" ]; then
        local cache_count=$(find "$HOME/.cache" -type f 2>/dev/null | wc -l)
        if [ "$cache_count" -gt 0 ]; then
            echo -e "${YELLOW}Found $cache_count files in browser cache${NC}"
            if confirm_deletion "$cache_count" "browser cache files"; then
                echo -e "${RED}Clearing browser cache...${NC}"
                rm -rf "$HOME/.cache"/* 2>/dev/null
                echo -e "${GREEN}Browser cache cleared${NC}"
            fi
        else
            echo -e "${GREEN}Browser cache is already empty${NC}"
        fi
    fi
    
    echo -e "\n${GREEN}✓ Temporary files cleanup completed!${NC}"
}

# 2. Clean package manager cache
cleanup_package_cache() {
    show_header
    echo -e "${BLUE}=== PACKAGE MANAGER CLEANUP ===${NC}"
    
    if command -v apt-get &> /dev/null; then
        echo -e "${CYAN}Found APT (Debian/Ubuntu)${NC}"
        
        # Show what will be removed
        echo -e "\n${YELLOW}Packages that can be autoremoved:${NC}"
        apt-get --dry-run autoremove | grep -E '^Remv' | head -10
        local auto_count=$(apt-get --dry-run autoremove | grep -c '^Remv')
        
        echo -e "\n${YELLOW}Cache files that can be cleaned:${NC}"
        apt-get --dry-run autoclean | grep -E '^Del' | head -10
        local cache_count=$(apt-get --dry-run autoclean | grep -c '^Del')
        
        local total_count=$((auto_count + cache_count))
        
        if [ "$total_count" -gt 0 ]; then
            if confirm_deletion "$total_count" "package manager items"; then
                echo -e "${RED}Cleaning package manager cache...${NC}"
                apt-get autoremove -y
                apt-get autoclean -y
                apt-get clean -y
                echo -e "${GREEN}Package manager cache cleaned${NC}"
            else
                echo -e "${YELLOW}Package manager cleanup cancelled${NC}"
            fi
        else
            echo -e "${GREEN}No package manager cache to clean${NC}"
        fi
        
    elif command -v dnf &> /dev/null; then
        echo -e "${CYAN}Found DNF (Fedora)${NC}"
        if confirm_deletion "1" "DNF cache"; then
            echo -e "${RED}Cleaning DNF cache...${NC}"
            dnf autoremove -y
            dnf clean all
            echo -e "${GREEN}DNF cache cleaned${NC}"
        fi
        
    elif command -v yum &> /dev/null; then
        echo -e "${CYAN}Found YUM (CentOS/RHEL)${NC}"
        if confirm_deletion "1" "YUM cache"; then
            echo -e "${RED}Cleaning YUM cache...${NC}"
            yum autoremove -y
            yum clean all
            echo -e "${GREEN}YUM cache cleaned${NC}"
        fi
        
    elif command -v pacman &> /dev/null; then
        echo -e "${CYAN}Found Pacman (Arch)${NC}"
        
        # Show orphaned packages
        local orphans=$(pacman -Qtdq 2>/dev/null | wc -l)
        if [ "$orphans" -gt 0 ]; then
            echo -e "${YELLOW}Orphaned packages that can be removed:${NC}"
            pacman -Qtdq | head -10
            if [ "$orphans" -gt 10 ]; then
                echo -e "${YELLOW}... and $((orphans - 10)) more${NC}"
            fi
        fi
        
        if confirm_deletion "1" "Pacman cache"; then
            echo -e "${RED}Cleaning Pacman cache...${NC}"
            pacman -Sc --noconfirm
            if [ "$orphans" -gt 0 ]; then
                pacman -Rns $(pacman -Qtdq) --noconfirm 2>/dev/null || true
            fi
            echo -e "${GREEN}Pacman cache cleaned${NC}"
        fi
        
    elif command -v zypper &> /dev/null; then
        echo -e "${CYAN}Found Zypper (openSUSE)${NC}"
        if confirm_deletion "1" "Zypper cache"; then
            echo -e "${RED}Cleaning Zypper cache...${NC}"
            zypper clean
            zypper rm -u
            echo -e "${GREEN}Zypper cache cleaned${NC}"
        fi
        
    else
        echo -e "${YELLOW}No supported package manager found${NC}"
    fi
    
    echo -e "\n${GREEN}✓ Package manager cleanup completed!${NC}"
}

# 3. Clean Docker images and containers
cleanup_docker() {
    show_header
    echo -e "${BLUE}=== DOCKER CLEANUP ===${NC}"
    
    if ! command -v docker &> /dev/null; then
        echo -e "${YELLOW}Docker not found, skipping Docker cleanup${NC}"
        press_any_key
        return
    fi
    
    echo -e "${CYAN}Current Docker disk usage:${NC}"
    docker system df
    
    echo -e "\n${YELLOW}Starting Docker cleanup...${NC}"
    
    # Show what will be cleaned
    local stopped_containers=$(docker ps -q -f status=exited | wc -l)
    local dangling_images=$(docker images -q -f dangling=true | wc -l)
    local unused_networks=$(docker network ls -q -f dangling=true | wc -l)
    local unused_volumes=$(docker volume ls -q -f dangling=true | wc -l)
    
    echo -e "\n${YELLOW}Items that will be removed:${NC}"
    echo "  Stopped containers: $stopped_containers"
    echo "  Dangling images: $dangling_images"
    echo "  Unused networks: $unused_networks"
    echo "  Unused volumes: $unused_volumes"
    
    local total_items=$((stopped_containers + dangling_images + unused_networks))
    
    if [ "$total_items" -eq 0 ] && [ "$unused_volumes" -eq 0 ]; then
        echo -e "${GREEN}No Docker items to clean${NC}"
        press_any_key
        return
    fi
    
    if ! confirm_deletion "$total_items" "Docker items"; then
        echo -e "${YELLOW}Docker cleanup cancelled${NC}"
        press_any_key
        return
    fi
    
    # Stop all running containers
    if [ "$(docker ps -q 2>/dev/null)" ]; then
        echo -e "\n${CYAN}Stopping running containers...${NC}"
        docker stop $(docker ps -q)
    fi
    
    # Remove stopped containers
    if [ "$stopped_containers" -gt 0 ]; then
        echo -e "\n${CYAN}Removing stopped containers...${NC}"
        docker container prune -f
    fi
    
    # Remove unused images
    if [ "$dangling_images" -gt 0 ]; then
        echo -e "\n${CYAN}Removing unused images...${NC}"
        docker image prune -a -f
    fi
    
    # Remove unused networks
    if [ "$unused_networks" -gt 0 ]; then
        echo -e "\n${CYAN}Removing unused networks...${NC}"
        docker network prune -f
    fi
    
    # Remove build cache
    echo -e "\n${CYAN}Removing build cache...${NC}"
    docker builder prune -f
    
    # Remove unused volumes (with separate confirmation)
    if [ "$unused_volumes" -gt 0 ]; then
        echo -e "\n${CYAN}Checking for unused volumes...${NC}"
        read -p "Remove $unused_volumes unused volumes? This cannot be undone! (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker volume prune -f
            echo -e "${GREEN}Unused volumes removed${NC}"
        else
            echo -e "${YELLOW}Skipping volume cleanup${NC}"
        fi
    fi
    
    echo -e "\n${CYAN}Final Docker disk usage:${NC}"
    docker system df
    echo -e "\n${GREEN}✓ Docker cleanup completed!${NC}"
}

# 4. Clean system logs
cleanup_system_logs() {
    show_header
    echo -e "${BLUE}=== SYSTEM LOGS CLEANUP ===${NC}"
    
    # Show log files that will be cleaned
    echo -e "${YELLOW}Scanning for old log files...${NC}"
    
    local old_logs=$(find /var/log -name "*.log" -type f -mtime +30 2>/dev/null | wc -l)
    local old_gz=$(find /var/log -name "*.gz" -type f -mtime +60 2>/dev/null | wc -l)
    local old_backups=$(find /var/log -name "*.old" -type f -mtime +30 2>/dev/null | wc -l)
    
    echo -e "\n${YELLOW}Log files that will be cleaned:${NC}"
    echo "  Log files older than 30 days: $old_logs"
    echo "  Compressed logs older than 60 days: $old_gz"
    echo "  Old backup logs: $old_backups"
    
    local total_logs=$((old_logs + old_gz + old_backups))
    
    if [ "$total_logs" -eq 0 ]; then
        echo -e "${GREEN}No old log files found to clean${NC}"
        press_any_key
        return
    fi
    
    if ! confirm_deletion "$total_logs" "log files"; then
        echo -e "${YELLOW}Log cleanup cancelled${NC}"
        press_any_key
        return
    fi
    
    # Clean old log files (keep last 30 days)
    if [ -d "/var/log" ]; then
        echo -e "${CYAN}Cleaning system logs older than 30 days...${NC}"
        if [ "$old_logs" -gt 0 ]; then
            find /var/log -name "*.log" -type f -mtime +30 -exec truncate -s 0 {} \; 2>/dev/null
            echo -e "${GREEN}Cleared $old_logs old log files${NC}"
        fi
        
        if [ "$old_gz" -gt 0 ]; then
            find /var/log -name "*.gz" -type f -mtime +60 -delete 2>/dev/null
            echo -e "${GREEN}Deleted $old_gz compressed logs${NC}"
        fi
        
        if [ "$old_backups" -gt 0 ]; then
            find /var/log -name "*.old" -type f -mtime +30 -delete 2>/dev/null
            echo -e "${GREEN}Deleted $old_backups old backup logs${NC}"
        fi
    fi
    
    # Clean journal logs
    if command -v journalctl &> /dev/null; then
        echo -e "\n${CYAN}Cleaning journal logs...${NC}"
        journalctl --vacuum-time=30d
        echo -e "${GREEN}Journal logs cleaned${NC}"
    fi
    
    # Clean user logs
    if [ -d "$HOME/.local/share/logs" ]; then
        echo -e "\n${CYAN}Cleaning user application logs...${NC}"
        local user_logs=$(find "$HOME/.local/share/logs" -name "*.log" -type f -mtime +30 2>/dev/null | wc -l)
        if [ "$user_logs" -gt 0 ]; then
            find "$HOME/.local/share/logs" -name "*.log" -type f -mtime +30 -delete 2>/dev/null
            echo -e "${GREEN}Deleted $user_logs user log files${NC}"
        fi
    fi
    
    echo -e "\n${GREEN}✓ System logs cleanup completed!${NC}"
}

# 5. Clean thumbnail cache and trash
cleanup_user_data() {
    show_header
    echo -e "${BLUE}=== USER DATA CLEANUP ===${NC}"
    
    # Thumbnail cache
    echo -e "${CYAN}Checking thumbnail cache...${NC}"
    local thumb_dir="$HOME/.cache/thumbnails"
    if [ -d "$thumb_dir" ]; then
        local thumb_count=$(find "$thumb_dir" -type f 2>/dev/null | wc -l)
        if [ "$thumb_count" -gt 0 ]; then
            echo -e "${YELLOW}Found $thumb_count thumbnail files${NC}"
            if confirm_deletion "$thumb_count" "thumbnail files"; then
                rm -rf "$thumb_dir"/* 2>/dev/null
                echo -e "${GREEN}Thumbnail cache cleared${NC}"
            fi
        else
            echo -e "${GREEN}Thumbnail cache is already empty${NC}"
        fi
    fi
    
    # Trash
    echo -e "\n${CYAN}Checking trash...${NC}"
    local trash_dir="$HOME/.local/share/Trash"
    if [ -d "$trash_dir" ]; then
        local trash_files=$(find "$trash_dir/files" -type f 2>/dev/null | wc -l)
        local trash_info=$(find "$trash_dir/info" -type f 2>/dev/null | wc -l)
        
        if [ "$trash_files" -gt 0 ] || [ "$trash_info" -gt 0 ]; then
            echo -e "${YELLOW}Found $trash_files files in trash${NC}"
            if confirm_deletion "$trash_files" "trash files"; then
                rm -rf "$trash_dir/files"/* 2>/dev/null
                rm -rf "$trash_dir/info"/* 2>/dev/null
                echo -e "${GREEN}Trash emptied${NC}"
            fi
        else
            echo -e "${GREEN}Trash is already empty${NC}"
        fi
    fi
    
    # Recent documents
    echo -e "\n${CYAN}Checking recent documents...${NC}"
    if [ -f "$HOME/.local/share/recently-used.xbel" ]; then
        echo -e "${YELLOW}Found recent documents file${NC}"
        if confirm_deletion "1" "recent documents file"; then
            rm -f "$HOME/.local/share/recently-used.xbel" 2>/dev/null
            echo -e "${GREEN}Recent documents cleared${NC}"
        fi
    else
        echo -e "${GREEN}No recent documents file found${NC}"
    fi
    
    echo -e "\n${GREEN}✓ User data cleanup completed!${NC}"
}

# 6. Comprehensive cleanup (all in one)
comprehensive_cleanup() {
    show_header
    echo -e "${BLUE}=== COMPREHENSIVE CLEANUP ===${NC}"
    echo -e "${YELLOW}This will perform ALL cleanup operations${NC}"
    echo -e "${RED}WARNING: This is a destructive operation!${NC}"
    
    read -p "Are you absolutely sure you want to continue? (type 'YES' to confirm): " -r
    if [[ ! $REPLY == "YES" ]]; then
        echo -e "${YELLOW}Comprehensive cleanup cancelled${NC}"
        press_any_key
        return
    fi
    
    echo -e "\n${RED}Starting comprehensive cleanup...${NC}"
    
    # Run each cleanup with forced confirmation
    cleanup_temp_files
    echo
    cleanup_package_cache
    echo
    cleanup_docker
    echo
    cleanup_system_logs
    echo
    cleanup_user_data
    
    echo -e "\n${GREEN}✓ Comprehensive cleanup completed!${NC}"
}

# 7. Show system statistics
show_statistics() {
    show_header
    echo -e "${BLUE}=== SYSTEM STATISTICS ===${NC}"
    
    # Disk usage
    echo -e "\n${CYAN}Disk Usage:${NC}"
    df -h / /home /tmp /var 2>/dev/null | grep -v "tmpfs" | tail -n +2
    
    # Docker statistics
    if command -v docker &> /dev/null; then
        echo -e "\n${CYAN}Docker Disk Usage:${NC}"
        docker system df
    fi
    
    # Temp directory sizes
    echo -e "\n${CYAN}Temp Directory Sizes:${NC}"
    for dir in "/tmp" "/var/tmp" "$HOME/.cache" "$HOME/.local/share/Trash/files"; do
        if [ -d "$dir" ]; then
            size=$(du -sh "$dir" 2>/dev/null | cut -f1) || size="Error"
            echo "  $dir: $size"
        fi
    done
    
    # Largest directories in home
    echo -e "\n${CYAN}Largest Directories in Home:${NC}"
    du -sh "$HOME"/* 2>/dev/null | sort -hr | head -10
    
    press_any_key
}

# 8. Find large files
find_large_files() {
    show_header
    echo -e "${BLUE}=== FIND LARGE FILES ===${NC}"
    
    local min_size="100M"
    local max_size="1G"
    local search_path="$HOME"
    
    echo -e "${CYAN}Current settings:${NC}"
    echo "  Minimum size: $min_size"
    echo "  Maximum size: $max_size"
    echo "  Search path: $search_path"
    echo ""
    
    # Size options
    echo -e "${YELLOW}Select size range:${NC}"
    echo "  1) 100MB - 1GB (default)"
    echo "  2) 50MB - 500MB"
    echo "  3) 200MB - 2GB"
    echo "  4) 500MB - 5GB"
    echo "  5) Custom size range"
    echo -e "  6) ${RED}1GB+ (Very large files)${NC}"
    echo -n "Enter choice [1-6]: "
    read -r size_choice
    
    case $size_choice in
        2)
            min_size="50M"
            max_size="500M"
            ;;
        3)
            min_size="200M"
            max_size="2G"
            ;;
        4)
            min_size="500M"
            max_size="5G"
            ;;
        5)
            echo -n "Enter minimum size (e.g., 100M, 1G): "
            read -r min_size
            echo -n "Enter maximum size (e.g., 500M, 2G): "
            read -r max_size
            ;;
        6)
            min_size="1G"
            max_size="100G"
            ;;
        *)
            min_size="100M"
            max_size="1G"
            ;;
    esac
    
    # Path options
    echo -e "\n${YELLOW}Select search location:${NC}"
    echo "  1) Home directory ($HOME)"
    echo "  2) Root directory (/) - requires sudo"
    echo "  3) Current directory ($(pwd))"
    echo "  4) Custom path"
    echo -n "Enter choice [1-4]: "
    read -r path_choice
    
    case $path_choice in
        2)
            search_path="/"
            ;;
        3)
            search_path="."
            ;;
        4)
            echo -n "Enter custom path: "
            read -r search_path
            if [ ! -d "$search_path" ]; then
                echo -e "${RED}Error: Path '$search_path' does not exist!${NC}"
                press_any_key
                return
            fi
            ;;
        *)
            search_path="$HOME"
            ;;
    esac
    
    # Sort options
    echo -e "\n${YELLOW}Sort by:${NC}"
    echo "  1) Size (largest first)"
    echo "  2) Location (alphabetical)"
    echo "  3) Date modified (newest first)"
    echo -n "Enter choice [1-3]: "
    read -r sort_choice
    
    local sort_cmd=""
    case $sort_choice in
        1)
            sort_cmd="sort -hr"
            echo -e "${CYAN}Sorting by size (largest first)...${NC}"
            ;;
        2)
            sort_cmd="sort"
            echo -e "${CYAN}Sorting by location (alphabetical)...${NC}"
            ;;
        3)
            sort_cmd="sort -k2,2 -r"
            echo -e "${CYAN}Sorting by date modified (newest first)...${NC}"
            ;;
        *)
            sort_cmd="sort -hr"
            echo -e "${CYAN}Sorting by size (largest first)...${NC}"
            ;;
    esac
    
    echo -e "\n${GREEN}Searching for files between $min_size and $max_size in $search_path...${NC}"
    echo -e "${YELLOW}This may take a while for large directories...${NC}"
    echo ""
    
    # Build find command based on size range
    if [ "$max_size" = "100G" ]; then
        size_condition="-size +$min_size"
    else
        size_condition="-size +$min_size -size -$max_size"
    fi
    
    # Header for output
    echo -e "${BLUE}Files found (Size | Location | Modified Date):${NC}"
    echo "────────────────────────────────────────────────────────────────"
    
    # Find and display files
    if [ "$search_path" = "/" ]; then
        sudo find "$search_path" \
            -type f \
            $size_condition \
            ! -path "/proc/*" \
            ! -path "/sys/*" \
            ! -path "/dev/*" \
            ! -path "/run/*" \
            -exec ls -lh {} + 2>/dev/null | \
            awk 'NR>1 {print $5 "\t" $9 "\t" $6 " " $7 " " $8}' | \
            $sort_cmd | \
            head -50
    else
        find "$search_path" \
            -type f \
            $size_condition \
            -exec ls -lh {} + 2>/dev/null | \
            awk 'NR>1 {print $5 "\t" $9 "\t" $6 " " $7 " " $8}' | \
            $sort_cmd | \
            head -50
    fi
    
    # Summary
    local file_count=$(find "$search_path" -type f $size_condition 2>/dev/null | wc -l)
    echo "────────────────────────────────────────────────────────────────"
    echo -e "${GREEN}Found $file_count files between $min_size and $max_size${NC}"
    
    press_any_key
}

# 9. Show folder details with subfolder sizes
show_folder_details() {
    show_header
    echo -e "${BLUE}=== FOLDER SIZE ANALYZER ===${NC}"
    
    local analyze_path="$HOME"
    local depth_level=2
    local max_items=20
    
    echo -e "${CYAN}Current settings:${NC}"
    echo "  Analyze path: $analyze_path"
    echo "  Depth level: $depth_level"
    echo "  Max items to show: $max_items"
    echo ""
    
    # Path selection
    echo -e "${YELLOW}Select folder to analyze:${NC}"
    echo "  1) Home directory ($HOME)"
    echo "  2) Root directory (/)"
    echo "  3) Current directory ($(pwd))"
    echo "  4) Custom path"
    echo "  5) Common system directories"
    echo -n "Enter choice [1-5]: "
    read -r path_choice
    
    case $path_choice in
        2)
            analyze_path="/"
            ;;
        3)
            analyze_path="."
            ;;
        4)
            echo -n "Enter custom path: "
            read -r analyze_path
            if [ ! -d "$analyze_path" ]; then
                echo -e "${RED}Error: Path '$analyze_path' does not exist!${NC}"
                press_any_key
                return
            fi
            ;;
        5)
            show_common_directories
            return
            ;;
        *)
            analyze_path="$HOME"
            ;;
    esac
    
    # Depth selection
    echo -e "\n${YELLOW}Select depth level:${NC}"
    echo "  1) Top level only (fast)"
    echo "  2) 2 levels deep (recommended)"
    echo "  3) 3 levels deep (detailed)"
    echo "  4) Unlimited depth (slow)"
    echo -n "Enter choice [1-4]: "
    read -r depth_choice
    
    case $depth_choice in
        1)
            depth_level=1
            ;;
        3)
            depth_level=3
            ;;
        4)
            depth_level=999
            echo -e "${YELLOW}Warning: Unlimited depth may be very slow on large directories!${NC}"
            ;;
        *)
            depth_level=2
            ;;
    esac
    
    # Number of items to show
    echo -e "\n${YELLOW}Number of items to display:${NC}"
    echo "  1) Top 10 (quick overview)"
    echo "  2) Top 20 (balanced)"
    echo "  3) Top 50 (detailed)"
    echo "  4) All items (comprehensive)"
    echo -n "Enter choice [1-4]: "
    read -r items_choice
    
    case $items_choice in
        1)
            max_items=10
            ;;
        3)
            max_items=50
            ;;
        4)
            max_items=9999
            ;;
        *)
            max_items=20
            ;;
    esac
    
    # Sort order
    echo -e "\n${YELLOW}Sort by:${NC}"
    echo "  1) Size (largest first)"
    echo "  2) Name (alphabetical)"
    echo "  3) Reverse size (smallest first)"
    echo -n "Enter choice [1-3]: "
    read -r sort_choice
    
    local sort_cmd="sort -hr"
    case $sort_choice in
        2)
            sort_cmd="sort"
            echo -e "${CYAN}Sorting by name (alphabetical)...${NC}"
            ;;
        3)
            sort_cmd="sort -h"
            echo -e "${CYAN}Sorting by size (smallest first)...${NC}"
            ;;
        *)
            sort_cmd="sort -hr"
            echo -e "${CYAN}Sorting by size (largest first)...${NC}"
            ;;
    esac
    
    echo -e "\n${GREEN}Analyzing folder: $analyze_path${NC}"
    echo -e "${YELLOW}This may take a while for large directories...${NC}"
    echo ""
    
    # Display folder information
    display_folder_analysis "$analyze_path" "$depth_level" "$max_items" "$sort_cmd"
    
    press_any_key
}

# Function to display common system directories
show_common_directories() {
    show_header
    echo -e "${BLUE}=== COMMON SYSTEM DIRECTORIES ANALYSIS ===${NC}"
    
    local common_dirs=(
        "/home"
        "/var"
        "/usr"
        "/opt"
        "/tmp"
        "/var/log"
        "/var/cache"
        "/usr/lib"
        "/usr/share"
    )
    
    echo -e "${CYAN}Analyzing common system directories:${NC}"
    echo "────────────────────────────────────────────────────────────────"
    
    for dir in "${common_dirs[@]}"; do
        if [ -d "$dir" ]; then
            if [ "$dir" = "/" ]; then
                continue
            fi
            
            echo -e "\n${YELLOW}Directory: $dir${NC}"
            echo "────────────────────────────────────────────────────────────────"
            
            if [ -r "$dir" ]; then
                if command -v sudo >/dev/null 2>&1 && [ ! -r "$dir" ]; then
                    sudo du -h "$dir" --max-depth=1 2>/dev/null | sort -hr | head -10
                else
                    du -h "$dir" --max-depth=1 2>/dev/null | sort -hr | head -10
                fi
            else
                echo -e "${RED}Permission denied: $dir${NC}"
            fi
        else
            echo -e "${YELLOW}Directory not found: $dir${NC}"
        fi
    done
    
    press_any_key
}

# Function to display folder analysis
display_folder_analysis() {
    local path="$1"
    local depth="$2"
    local max_items="$3"
    local sort_cmd="$4"
    
    # Total size of the folder
    echo -e "${CYAN}Total size of $path:${NC}"
    if [ -r "$path" ]; then
        if command -v sudo >/dev/null 2>&1 && [ ! -r "$path" ]; then
            total_size=$(sudo du -sh "$path" 2>/dev/null | cut -f1)
        else
            total_size=$(du -sh "$path" 2>/dev/null | cut -f1)
        fi
        echo -e "${GREEN}$total_size${NC}"
    else
        echo -e "${RED}Permission denied${NC}"
    fi
    
    echo ""
    
    # Subfolder sizes
    echo -e "${CYAN}Subfolder sizes (sorted by size):${NC}"
    echo "────────────────────────────────────────────────────────────────"
    
    if [ "$depth" -eq 1 ]; then
        # Top level only
        if command -v sudo >/dev/null 2>&1 && [ ! -r "$path" ]; then
            sudo du -h "$path" --max-depth=1 2>/dev/null | sort -hr | head -n $((max_items + 1))
        else
            du -h "$path" --max-depth=1 2>/dev/null | sort -hr | head -n $((max_items + 1))
        fi
    elif [ "$depth" -eq 999 ]; then
        # Unlimited depth - be more selective
        echo -e "${YELLOW}Showing largest items recursively (this may take time)...${NC}"
        if command -v sudo >/dev/null 2>&1 && [ ! -r "$path" ]; then
            sudo du -h "$path" 2>/dev/null | sort -hr | head -n $max_items
        else
            du -h "$path" 2>/dev/null | sort -hr | head -n $max_items
        fi
    else
        # Specific depth
        if command -v sudo >/dev/null 2>&1 && [ ! -r "$path" ]; then
            sudo du -h "$path" --max-depth=$depth 2>/dev/null | sort -hr | head -n $max_items
        else
            du -h "$path" --max-depth=$depth 2>/dev/null | sort -hr | head -n $max_items
        fi
    fi
    
    # File count information
    echo ""
    echo -e "${CYAN}File and folder count:${NC}"
    if [ -r "$path" ]; then
        local file_count=0
        local dir_count=0
        
        if command -v sudo >/dev/null 2>&1 && [ ! -r "$path" ]; then
            file_count=$(sudo find "$path" -type f 2>/dev/null | wc -l)
            dir_count=$(sudo find "$path" -type d 2>/dev/null | wc -l)
        else
            file_count=$(find "$path" -type f 2>/dev/null | wc -l)
            dir_count=$(find "$path" -type d 2>/dev/null | wc -l)
        fi
        
        echo "  Files: $file_count"
        echo "  Folders: $dir_count"
    else
        echo -e "${RED}Permission denied - cannot count files${NC}"
    fi
    
    # Largest files in the directory
    echo ""
    echo -e "${CYAN}Top 10 largest files in $path:${NC}"
    echo "────────────────────────────────────────────────────────────────"
    
    if [ -r "$path" ]; then
        if command -v sudo >/dev/null 2>&1 && [ ! -r "$path" ]; then
            sudo find "$path" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -10
        else
            find "$path" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -10
        fi
    else
        echo -e "${RED}Permission denied - cannot list files${NC}"
    fi
    
    # Cleanup recommendations
    echo ""
    echo -e "${YELLOW}Cleanup Recommendations:${NC}"
    
    if [[ "$path" == *"cache"* ]] || [[ "$path" == *"temp"* ]] || [[ "$path" == *"tmp"* ]]; then
        echo "  ⚠️  This appears to be a cache/temp directory - safe to clean"
    fi
    
    if [[ "$path" == *"log"* ]]; then
        echo "  ⚠️  This appears to be a log directory - check for old logs"
    fi
    
    if [[ "$path" == *"download"* ]] || [[ "$path" == *"Downloads"* ]]; then
        echo "  ������ Downloads folder - consider archiving old files"
    fi
    
    # Show disk usage for context
    echo ""
    echo -e "${CYAN}Overall disk usage:${NC}"
    df -h "$path" 2>/dev/null || df -h | grep -v "tmpfs"
}

# Update the main menu function
show_menu() {
    show_header
    
    # Menu options
    echo -e "${CYAN}Please select an option:${NC}"
    echo -e "  ${GREEN}1${NC}) Temporary Files Cleanup"
    echo -e "  ${GREEN}2${NC}) Package Manager Cleanup"
    echo -e "  ${GREEN}3${NC}) Docker Cleanup"
    echo -e "  ${GREEN}4${NC}) System Logs Cleanup"
    echo -e "  ${GREEN}5${NC}) User Data Cleanup (Trash, Thumbnails)"
    echo -e "  ${GREEN}6${NC}) Comprehensive Cleanup (All-in-One)"
    echo -e "  ${GREEN}7${NC}) System Statistics"
    echo -e "  ${GREEN}8${NC}) Find Large Files"
    echo -e "  ${GREEN}9${NC}) Folder Size Analyzer"
    echo -e "  ${RED}0${NC}) Exit"
    echo
    echo -e "${YELLOW}Enter your choice [0-9]: ${NC}"
}

# Update the main function to handle the new option
main() {
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                cleanup_temp_files
                press_any_key
                ;;
            2)
                cleanup_package_cache
                press_any_key
                ;;
            3)
                cleanup_docker
                press_any_key
                ;;
            4)
                cleanup_system_logs
                press_any_key
                ;;
            5)
                cleanup_user_data
                press_any_key
                ;;
            6)
                comprehensive_cleanup
                press_any_key
                ;;
            7)
                show_statistics
                ;;
            8)
                find_large_files
                press_any_key
                ;;
            9)
                show_folder_details
                ;;
            0)
                echo -e "\n${GREEN}Thank you for using System Cleanup Menu!${NC}"
                exit 0
                ;;
            *)
                echo -e "\n${RED}Invalid option! Please enter a number between 0-9${NC}"
                sleep 2
                ;;
        esac
    done
}
netspeed() {
    local iface rx1 tx1 rx2 tx2 rx_speed tx_speed
    cpu=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    mem=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
    disk=$(df / | awk 'NR==2 {print $5}' | cut -d'%' -f1)
    
    # Get network interface
    iface=$(ip route | grep default | awk '{print $5}')
    if [ -z "$iface" ]; then
        echo "CPU: ${cpu}% | RAM: ${mem}% | DISK: ${disk}% | NET: No interface"
        return 1
    fi
    
    # First measurement - ADD COLON to interface name
    rx1=$(grep "$iface:" /proc/net/dev | awk '{print $2}')
    tx1=$(grep "$iface:" /proc/net/dev | awk '{print $10}')
    
    # Wait 1 second
    sleep 1
    
    # Second measurement - ADD COLON to interface name
    rx2=$(grep "$iface:" /proc/net/dev | awk '{print $2}')
    tx2=$(grep "$iface:" /proc/net/dev | awk '{print $10}')
    
    # Calculate speeds
    rx_speed=$(echo "scale=1; ($rx2 - $rx1) / 1048576" | bc 2>/dev/null || echo "0")
    tx_speed=$(echo "scale=1; ($tx2 - $tx1) / 1048576" | bc 2>/dev/null || echo "0")
    
   echo -e "${GREEN}CPU: ${cpu}%${NC} ${YELLOW}RAM: ${mem}%${NC} ${RED}DISK: ${disk}%${NC} ${CYAN}NET: ↓${rx_speed}MB/s ↑${tx_speed}MB/s${NC}"
}
# If script is executed directly, run the main function
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
