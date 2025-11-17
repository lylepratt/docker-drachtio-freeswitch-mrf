#!/bin/bash

# Log file
LOG_FILE="/var/log/monitorPres3fs.log"

# Directory to monitor
WATCH_DIR="/var/pres3fs"

process_file() {
    local FILE_PATH="$1"
    local FILE="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Processing file: $FILE_PATH" >> "$LOG_FILE"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Attempting to copy $FILE_PATH to s3://vidamedia/recordings/$FILE" >> "$LOG_FILE"
    
    if aws s3 cp "$FILE_PATH" "s3://vidamedia/recordings/$FILE" --cache-control no-cache; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - File $FILE_PATH copied successfully to S3." >> "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Failed to copy file $FILE_PATH to S3" >> "$LOG_FILE"
    fi

    # Wait a bit before deleting old files to avoid immediate removal issues
    sleep 2

    # Delete files older than 3 days
    find "$WATCH_DIR" -type f -mtime +3 -exec rm {} \;
}

# Monitor directory for new files
inotifywait -m -e close_write --format '%f' "$WATCH_DIR" | while read -r FILE
do
    FILE_PATH="$WATCH_DIR/$FILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - File detected: $FILE_PATH" >> "$LOG_FILE"
    (process_file "$FILE_PATH" "$FILE") &
done
