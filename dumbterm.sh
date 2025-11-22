#!/bin/bash

# Auto-detect local subnet (e.g. 192.168.1.0/24)
SUBNET=$(ip route | awk '/src/ {print $1}')
INTERFACE=$(ip route | awk '/src/ {print $3}')
[ -z "$SUBNET" ] && SUBNET="192.168.1.0/24"

resolve_hostname() {
    local ip="$1"

    # Try mDNS (Avahi) first
    local mdns
    mdns=$(avahi-resolve -a "$ip" 2>/dev/null | awk '{print $2}')
    if [ -n "$mdns" ]; then
        echo "$mdns"
        return
    fi

    # Try SSH banner
    # We send nothing (-n) and timeout quickly
    local banner
    banner=$(timeout 1 bash -c "echo -n | nc $ip 22" 2>/dev/null | head -n1)

    # SSH banner example:
    # SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.1
    if [[ "$banner" =~ SSH- ]]; then
        # Try extracting hostname from "Ubuntu" or similar — not reliable,
        # so instead use the IP as fallback.
        echo "$ip"
        return
    fi

    # Fallback: raw IP
    echo "$ip"
}

while true; do
    clear
    echo " ██████████                              █████         █████                                      
░░███░░░░███                            ░░███         ░░███                                       
 ░███   ░░███ █████ ████ █████████████   ░███████     ███████    ██████  ████████  █████████████  
 ░███    ░███░░███ ░███ ░░███░░███░░███  ░███░░███   ░░░███░    ███░░███░░███░░███░░███░░███░░███ 
 ░███    ░███ ░███ ░███  ░███ ░███ ░███  ░███ ░███     ░███    ░███████  ░███ ░░░  ░███ ░███ ░███ 
 ░███    ███  ░███ ░███  ░███ ░███ ░███  ░███ ░███     ░███ ███░███░░░   ░███      ░███ ░███ ░███ 
 ██████████   ░░████████ █████░███ █████ ████████      ░░█████ ░░██████  █████     █████░███ █████
░░░░░░░░░░     ░░░░░░░░ ░░░░░ ░░░ ░░░░░ ░░░░░░░░        ░░░░░   ░░░░░░  ░░░░░     ░░░░░ ░░░ ░░░░░ 
                                                                                                  
                                   Simple SSH browser by Jason Darby                              
                                                                                                  "
    echo "Scanning $SUBNET for port 22..."

    # nmap scan
    MAP=$(nmap -n -p22 --open "$SUBNET" -oG - 2>/dev/null)
    HOSTS=($(echo "$MAP" | awk '/22\/open/ {print $2}'))

    if [ ${#HOSTS[@]} -eq 0 ]; then
        echo "No SSH servers found."
    else
        echo "Discovered SSH servers:"
        i=1
        for h in "${HOSTS[@]}"; do
            HOSTNAME=$(resolve_hostname "$h")
            echo "  $i) $HOSTNAME ($h)"
            ((i++))
        done
    fi

    echo
    echo "Press number to connect, or r to rescan..."

    read -t 5 -n 1 CHOICE

    [ -z "$CHOICE" ] && continue
    [[ "$CHOICE" == "r" ]] && continue
    [[ "$CHOICE" =~ ^[0-9]+$ ]] || continue

    INDEX=$((CHOICE - 1))

    if [ $INDEX -ge 0 ] && [ $INDEX -lt ${#HOSTS[@]} ]; then
        TARGET=${HOSTS[$INDEX]}
        clear
        echo "Connecting to $TARGET..."
        echo
        read -p "Username: " USERNAME
        clear
        exec ssh "${USERNAME}@${TARGET}"
    fi
done
