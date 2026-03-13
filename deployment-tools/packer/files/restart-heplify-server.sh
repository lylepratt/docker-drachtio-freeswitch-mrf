#!/bin/bash

LOG_FILE="/var/log/restart-heplify.log"
NUM_ATTEMPTS=5
SLEEP_INTERVAL=5

log_message() {
    echo "$(date): $1" >> $LOG_FILE
}

restart_heplify() {
    systemctl restart heplify-server
    log_message "Restarted heplify-server."
}

check_connection() {
    # Get the last log line from heplify-server
    journalctl -u heplify-server.service -n 1 --no-pager | tail -n 1
}

# Restart and check the connection status
restart_heplify
for ((i = 1; i <= NUM_ATTEMPTS; i++)); do
    sleep 1  # Wait one second after restarting
    LAST_LOG=$(check_connection)
    log_message "Attempt $i: Last log line: $LAST_LOG"

    if [[ "$LAST_LOG" != *"connection refused"* ]]; then
        log_message "Heplify-server is connected successfully."
        exit 0
    fi

    # Connection failed, retry after SLEEP_INTERVAL
    if [[ $i -lt $NUM_ATTEMPTS ]]; then
        log_message "Connection failed. Retrying in $SLEEP_INTERVAL seconds..."
        sleep $SLEEP_INTERVAL
        restart_heplify
    fi
done

log_message "Heplify-server failed to connect after $NUM_ATTEMPTS attempts."
exit 1