#!/bin/bash
find /usr/local/freeswitch/storage/http_file_cache -name "*.wav" -o -name "*.mp3" | while read file; do
    if [ $(find "$file" -mmin +720 | wc -l) -gt 0 ]; then
        # Remove the audio file and its corresponding .meta file
        rm -f "$file" "${file%.*}.meta" 2>/dev/null
    fi
done