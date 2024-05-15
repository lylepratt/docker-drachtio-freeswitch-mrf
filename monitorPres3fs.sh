#!/bin/sh

# Directory to monitor
WATCH_DIR="/var/pres3fs"
# Interval to check file size in seconds
CHECK_INTERVAL=5
# Number of checks to confirm inactivity
CHECK_COUNT=3

inotifywait -m -e close_write --format '%f' "$WATCH_DIR" | while read FILE
do
    FILE_PATH="$WATCH_DIR/$FILE"
    echo "File detected: $FILE_PATH"

    # Function to check if the file size remains the same
    is_stable_size() {
        SIZE1=$(stat -c %s "$FILE_PATH")
        sleep "$CHECK_INTERVAL"
        SIZE2=$(stat -c %s "$FILE_PATH")
        if [ "$SIZE1" -eq "$SIZE2" ]; then
            return 0
        else
            return 1
        fi
    }

    # Wait until the file size is stable for CHECK_COUNT times
    STABLE_COUNT=0
    while [ "$STABLE_COUNT" -lt "$CHECK_COUNT" ]; do
        if is_stable_size; then
            STABLE_COUNT=$((STABLE_COUNT + 1))
            echo "File size for $FILE_PATH is stable for $STABLE_COUNT/$CHECK_COUNT checks"
        else
            STABLE_COUNT=0
            echo "File size for $FILE_PATH is not stable, resetting checks"
        fi
    done

    echo "Attempting to copy $FILE_PATH to s3://vidamedia/recordings/$FILE"
    
    if aws s3 cp "$FILE_PATH" "s3://vidamedia/recordings/$FILE" --cache-control no-cache; then
        echo "File $FILE_PATH copied successfully to S3."
    else
        echo "Failed to copy file $FILE_PATH to S3"
    fi

    # Wait a bit before deleting old files to avoid immediate removal issues
    sleep 2

    # Delete files older than 3 days
    find "$WATCH_DIR" -type f -mtime +3 -exec rm {} \;
done
