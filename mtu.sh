#!/bin/bash

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color

pause() {
    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
}

select_interface() {
    interfaces=($(ls /sys/class/net | grep -v lo))
    echo -e "\n${BLUE}Available interfaces:${NC}"
    for i in "${!interfaces[@]}"; do
        echo -e "  ${YELLOW}$((i+1)))${NC} ${interfaces[$i]}"
    done
    echo -e "  ${YELLOW}a)${NC} All interfaces"
    read -rp "Select interface [1-${#interfaces[@]} or a]: " choice

    if [[ "$choice" == "a" ]]; then
        iface="ALL"
        echo -e "?? Selected: ${GREEN}All interfaces${NC}"
        return 0
    elif ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#interfaces[@]} )); then
        echo -e "${RED}? Invalid selection.${NC}"
        return 1
    fi

    iface=${interfaces[$((choice-1))]}
    echo -e "?? Selected interface: ${GREEN}$iface${NC}"
    return 0
}

set_mtu() {
    select_interface || { pause; return; }

    read -rp "Enter MTU size (e.g. 1420): " mtu
    if [[ ! "$mtu" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}? MTU must be a number.${NC}"
        pause
        return
    fi

    if [[ "$iface" == "ALL" ]]; then
        for ifc in $(ls /sys/class/net | grep -v lo); do
            sudo ip link set dev "$ifc" mtu "$mtu"
            echo -e "? MTU for ${GREEN}$ifc${NC} set to ${YELLOW}$mtu${NC}"
        done
    else
        sudo ip link set dev "$iface" mtu "$mtu"
        echo -e "? MTU for ${GREEN}$iface${NC} set to ${YELLOW}$mtu${NC}"
    fi

    read -rp "Do you want to persist this change at reboot? (yes/no): " choice
    if [[ "$choice" == "yes" ]]; then
        if [[ "$iface" == "ALL" ]]; then
            cron_line='@reboot for i in $(ls /sys/class/net | grep -v lo); do ip link set dev $i mtu '"$mtu"'; done'
            (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
            echo -e "?? Persisted MTU=${YELLOW}$mtu${NC} for ${GREEN}ALL interfaces${NC} at reboot."
        else
            (crontab -l 2>/dev/null; echo "@reboot ip link set dev $iface mtu $mtu") | crontab -
            echo -e "?? Persisted MTU=${YELLOW}$mtu${NC} for ${GREEN}$iface${NC} at reboot."
        fi
    fi
    pause
}

# Store original MTU for all interfaces at script start
declare -A ORIGINAL_MTU
for ifc in $(ls /sys/class/net | grep -v lo); do
    ORIGINAL_MTU[$ifc]=$(cat /sys/class/net/$ifc/mtu)
done

reset_mtu() {
    select_interface || { pause; return; }

    if [[ "$iface" == "ALL" ]]; then
        for ifc in $(ls /sys/class/net | grep -v lo); do
            sudo ip link set dev "$ifc" mtu "${ORIGINAL_MTU[$ifc]}"
            echo -e "?? MTU for ${GREEN}$ifc${NC} reset to ${YELLOW}${ORIGINAL_MTU[$ifc]}${NC}"
        done
        # Remove all MTU cron jobs
        crontab -l 2>/dev/null | grep -v "ip link set dev" | crontab -
        echo -e "?? Removed ${YELLOW}ALL MTU cron jobs${NC}."
    else
        sudo ip link set dev "$iface" mtu "${ORIGINAL_MTU[$iface]}"
        echo -e "?? MTU for ${GREEN}$iface${NC} reset to ${YELLOW}${ORIGINAL_MTU[$iface]}${NC}"
        # Remove cron job for this interface
        crontab -l 2>/dev/null | grep -v "ip link set dev $iface mtu" | crontab -
        echo -e "?? Removed MTU cron job for ${GREEN}$iface${NC}."
    fi

    pause
}


show_mtu() {
    echo -e "\n${BLUE}Current MTU values:${NC}"
    for iface in $(ls /sys/class/net | grep -v lo); do
        mtu=$(cat /sys/class/net/$iface/mtu)
        echo -e "  ${GREEN}$iface${NC} ? ${YELLOW}$mtu${NC}"
    done
    pause
}

cron_management() {
    while true; do
        echo -e "\n${BLUE}=== Cron Management Menu ===${NC}"
        echo -e "${YELLOW}1)${NC} View MTU cron jobs"
        echo -e "${YELLOW}2)${NC} Add MTU cron job"
        echo -e "${YELLOW}3)${NC} Remove MTU cron job"
        echo -e "${YELLOW}4)${NC} Back to main menu"
        read -rp "Select an option: " opt

        case $opt in
            1)
                echo -e "\n?? ${BLUE}Current MTU cron jobs:${NC}"
                crontab -l 2>/dev/null | grep "ip link set dev\|for i in" || echo -e "${RED}No MTU cron jobs found.${NC}"
                pause
                ;;
            2) set_mtu ;;
            3) reset_mtu ;;
            4) break ;;
            *) echo -e "${RED}? Invalid option.${NC}" ;;
        esac
    done
}

find_best_mtu() {
    select_interface || { pause; return; }

    read -rp "Enter a host to test against (default: 8.8.8.8): " host
    host=${host:-8.8.8.8}

    test_mtu() {
        local dev=$1

        # Skip if no IP assigned
        if ! ip addr show "$dev" | grep -q "inet "; then
            echo -e "??  Skipping ${YELLOW}$dev${NC} (no IP assigned)"
            return
        fi

        local lower=1200
        local upper=1500
        local best=0

        while (( lower <= upper )); do
            mid=$(((lower + upper) / 2))
            if ping -I "$dev" -M do -s "$mid" -c 1 -W 1 "$host" >/dev/null 2>&1; then
                best=$mid
                lower=$((mid + 1))
            else
                upper=$((mid - 1))
            fi
        done

        local mtu=$((best + 28))
        echo -e "? Best MTU for ${GREEN}$dev${NC} ? ${YELLOW}$mtu${NC} (payload=$best)"
    }

    if [[ "$iface" == "ALL" ]]; then
        echo -e "${BLUE}?? Testing all interfaces via $host...${NC}"
        for ifc in $(ls /sys/class/net | grep -v lo); do
            test_mtu "$ifc"
        done
    else
        echo -e "${BLUE}?? Finding best MTU for $iface via $host...${NC}"
        test_mtu "$iface"
    fi

    pause
}



menu() {

    while true; do
    clear
        echo -e "\n${BLUE}=== MTU Management Menu ===${NC}"
        echo -e "${YELLOW}1)${NC} Show MTU values"
        echo -e "${YELLOW}2)${NC} Set MTU"
        echo -e "${YELLOW}3)${NC} Reset MTU to default"
        echo -e "${YELLOW}4)${NC} Cron Management"
        echo -e "${YELLOW}5)${NC} Find Best MTU"
        echo -e "${YELLOW}6)${NC} Exit"
        read -rp "Select an option: " opt

        case $opt in
            1) show_mtu ;;
            2) set_mtu ;;
            3) reset_mtu ;;
            4) cron_management ;;
            5) find_best_mtu ;;
            6) exit 0 ;;
            *) echo -e "${RED}? Invalid option.${NC}" ;;
        esac
    done
}

menu
