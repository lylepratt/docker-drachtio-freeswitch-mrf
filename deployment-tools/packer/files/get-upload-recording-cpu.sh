#!/bin/bash

# Configuration
NAMESPACE="MyApp/UploadRecordings"
METRIC_NAME="MaxThreadCPU"
REGION="us-east-1"  # Change this to your AWS region

get_upload_recordings_cpu() {
    # Get the PID of upload_recordings process
    PID=$(pgrep -f upload_recordings | head -1)

    if [ -z "$PID" ]; then
        echo "upload_recordings process not found"
        return 1
    fi

    echo "Found upload_recordings PID: $PID" >&2

    # Run top for 3 iterations with 2-second intervals to get accurate CPU readings
    # Skip the first few lines which are headers, then extract CPU values
    MAX_CPU=$(top -H -p $PID -b -n 3 -d 2 | \
              grep "^ *[0-9]" | \
              awk '{print $9}' | \
              grep -E '^[0-9]+\.?[0-9]*$' | \
              sort -nr | \
              head -1)

    # Handle empty result
    if [ -z "$MAX_CPU" ] || [ "$MAX_CPU" = "0" ]; then
        # Fallback: try a different approach with a longer sampling period
        MAX_CPU=$(top -H -p $PID -b -n 2 -d 3 | \
                  tail -n +8 | \
                  awk 'NF >= 9 && $9 ~ /^[0-9]+\.?[0-9]*$/ {print $9}' | \
                  sort -nr | \
                  head -1)
    fi

    if [ -z "$MAX_CPU" ]; then
        MAX_CPU=0
    fi

    echo "$MAX_CPU"
}

send_to_cloudwatch() {
    local cpu_value=$1
    
    # Check if AWS CLI is available and configured
    if ! command -v aws &> /dev/null; then
        echo "AWS CLI not found. Please install AWS CLI." >&2
        return 1
    fi
    
    # Test AWS credentials
    if ! aws sts get-caller-identity &>/dev/null; then
        echo "AWS credentials not configured. Skipping CloudWatch upload." >&2
        return 1
    fi
    
    # Send metric to CloudWatch
    aws cloudwatch put-metric-data \
        --namespace "$NAMESPACE" \
        --metric-data MetricName="$METRIC_NAME",Value="$cpu_value",Unit=Percent \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        echo "Successfully sent metric $cpu_value% to CloudWatch" >&2
        return 0
    else
        echo "Failed to send metric to CloudWatch" >&2
        return 1
    fi
}

# Main execution
CPU_VALUE=$(get_upload_recordings_cpu)

if [ $? -eq 0 ]; then
    echo "Highest thread CPU usage: $CPU_VALUE%"
    
    # Send to CloudWatch
    send_to_cloudwatch "$CPU_VALUE"
else
    echo "Failed to get CPU metric"
    exit 1
fi
