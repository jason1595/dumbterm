#!/bin/bash

# Auto-detect interface
INTERFACE=$(ip route | awk '/src/ {print $3}')
# Auto-detect subnet of that interface
SUBNET=$(ip -4 addr show "$INTERFACE" | awk '/inet /{print $2}')
[ -z "$SUBNET" ] && SUBNET="10.0.0.0/24"  # fallback

resolve_hostname() {
    local ip="$1"

    # 1. Try standard DNS (getent hosts)
    local dns
    dns=$(getent hosts "$ip" | awk '{print $2}')
    if [ -n "$dns" ]; then
        echo "$dns"
        return
    fi

    # 2. Try mDNS (Avahi)
    local mdns
    mdns=$(avahi-resolve -a "$ip" 2>/dev/null | awk '{print $2}')
    if [ -n "$mdns" ]; then
        echo "$mdns"
        return
    fi

    # 3. Fallback to raw IP
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
    echo "Scanning $SUBNET for SSH (port 22)..."

    # Run nmap
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

    read -t 10 -n 1 CHOICE
    [ -z "$CHOICE" ] && continue
    [[ "$CHOICE" == "r" ]] && continue
    [[ "$CHOICE" =~ ^[0-9]+$ ]] || continue

    INDEX=$((CHOICE - 1))
    if [ $INDEX -ge 0 ] && [ $INDEX -lt ${#HOSTS[@]} ]; then
        TARGET=${HOSTS[$INDEX]}
        clear
        echo "Connecting to $TARGET..."
        read -p "Username: " USERNAME
        clear
        exec ssh "${USERNAME}@${TARGET}"
    fi
done
