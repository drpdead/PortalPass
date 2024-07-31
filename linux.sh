#!/bin/bash

# Linux Script

LOG_FILE="/tmp/escCaptivePortal.log"
> "$LOG_FILE"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    echo "ERROR: $1" >&2
}

interface=$(ip -o -4 route show to default | awk '/dev/ {print $5}' | head -n1)
localip=$(ip -o -4 route get 1 | awk '/src/ {print $7}')
wifissid=$(iw dev "$interface" link | awk '/SSID/ {print $NF}')
gateway=$(ip -o -4 route show to default | awk '/via/ {print $3}')
broadcast=$(ip -o -4 addr show dev "$interface" | awk '/brd/ {print $6}')
ipmask=$(ip -o -4 addr show dev "$interface" | awk '/inet/ {print $4}')
netmask=$(printf "%s\n" "$ipmask" | cut -d "/" -f 2)
netaddress=$(sipcalc "$ipmask" | awk '/Network address/ {print $NF}')
network="$netaddress/$netmask"
macaddress=$(ip -0 addr show dev "$interface" | awk '/link/ && /ether/ {print $2}' | tr '[:upper:]' '[:lower:]')
routermac=$(nmap -n -sn -PR -PS -PA -PU -T5 "$gateway" | grep -E -o '[A-Z0-9:]{17}' | tr '[:upper:]' '[:lower:]')

log_message "Exploring network on interface $interface"

verify_connectivity() {
    if ping -c1 -W1 8.8.8.8 > /dev/null 2>&1 &&
       curl -s --head http://www.google.com | head -n 1 | grep "HTTP/[12][.][01] [23].." > /dev/null 2>&1 &&
       nslookup www.google.com > /dev/null 2>&1; then
        log_message "Network connectivity verified."
        return 0
    else
        log_error "Network connectivity check failed."
        return 1
    fi
}

set_random_mac() {
    local mac=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/.$//')
    sudo ifconfig "$interface" ether "$mac"
    log_message "MAC address changed to $mac"
}

log_message "Starting captive portal circumvention attempts..."

attempts=0
max_attempts=10

while [ $attempts -lt $max_attempts ]; do
    ((attempts++))
    log_message "Attempt $attempts of $max_attempts"

    set_random_mac
    sleep 2

    sudo ipconfig set "$interface" DHCP
    sleep 5

    if verify_connectivity; then
        log_message "Success! Captive Portal circumvented."
        break
    fi
done

if [ $attempts -ge $max_attempts ]; then
    log_error "Unable to circumvent Captive Portal after $max_attempts attempts."
fi

log_message "Restoring original MAC address: $macaddress"
sudo ifconfig "$interface" ether "$macaddress"

echo "Log file available at: $LOG_FILE"
