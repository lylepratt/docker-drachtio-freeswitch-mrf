#!/bin/bash

# Script to delete audio files older than specified minutes in specified directories
# Extensions: .mp3 .wav .r8 .r16 .r24 .r44 .r48 .r96
# Usage: ./cleanup-temp-audiofiles.sh [minutes] [path]
# Example: ./cleanup-temp-audiofiles.sh 60 /mytemp

# Check if help parameter is provided
if  [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    echo "Usage: $0 [minutes] [path]"
    echo "Example: $0  60 /mytemp"
    echo "Default: 300 minutes if not specified"
    echo "Default path is /tmp"
    exit 1
fi



# If the JAMBONZ_TMP_FOLDER is set in ecosystem.config use that otherwise default /tmp
ENV_DIR=`cat /home/admin/apps/ecosystem.config.js | grep JAMBONES_TMP_FOLDER | grep -oP "'\K[^']+(?=')" | uniq`
CLI_DIR=${2:-$ENV_DIR}
BASE_DIR=${CLI_DIR:-/tmp}
# Set access time threshold (default to 300 minutes if not provided)
MINUTES=${1:-300}

# Define the directories to clean (base directory and its tts-cache-file subdirectory)
DIRECTORIES=("$BASE_DIR" "$BASE_DIR/tts-cache-files")

# Define the file extensions to target
EXTENSIONS=("mp3" "wav" "r8" "r16" "r24" "r44" "r48" "r96")

echo "Starting cleanup of audio files older than ${MINUTES} minutes..."

# Loop through each directory
for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist, skipping..."
        continue
    fi
    
    echo "Cleaning directory: $dir"
    
    # Loop through each extension
    for ext in "${EXTENSIONS[@]}"; do
        # Find and delete files with the specified extension that haven't been accessed in $MINUTES+ minutes
        find "$dir" -maxdepth 1 -name "tts*.${ext}" -type f -amin +${MINUTES} -print0 | while IFS= read -r -d '' file; do
            echo "Deleting: $file"
            rm "$file"
        done
    done
done

echo "Cleanup completed."