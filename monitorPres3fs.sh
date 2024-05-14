#!/bin/sh
inotifywait -m -e create -e close_write -e moved_to --format '%f' /var/pres3fs | while read FILE
do
    echo "file moved /var/pres3fs/$FILE -> /var/s3fs/$FILE"
    if cp /var/pres3fs/$FILE /var/s3fs/$FILE; then
        echo "File copied successfully, removing original file /var/pres3fs/$FILE"
        rm /var/pres3fs/$FILE
    else
        echo "Failed to copy file /var/pres3fs/$FILE"
    fi
done
