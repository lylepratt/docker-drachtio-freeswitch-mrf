#!/bin/sh
inotifywait -m -e create -e close_write -e moved_to --format '%f' /var/pres3fs | while read FILE
do
    echo "file moved /var/pres3fs/$FILE -> s3://vidamedia/recordings/$FILE"
    if aws s3 cp /var/pres3fs/$FILE s3://vidamedia/recordings/$FILE --cache-control no-cache; then
        echo "File copied successfully to S3, removing original file /var/pres3fs/$FILE"
        rm /var/pres3fs/$FILE
    else
        echo "Failed to copy file /var/pres3fs/$FILE to S3"
    fi
done
