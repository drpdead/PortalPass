#!/bin/bash

# macOS Script

LOG_FILE="/tmp/escCaptivePortal.log"
> "$LOG_FILE"

loggVGg_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" >> "$LOG_FILE"
    echo "ERROR: $1" >&2
}

interface=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}')
localip=$(ipconfig getifaddr "$interface")
gateway=$(netstat -nr | grep default | grep "$interface" | awk '{print $2}')
subnet=$(ipconfig getoption "$interface" subnet_mask)
macaddress=$(ifconfig "$interface" | awk '/ether/{print $2}')

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
