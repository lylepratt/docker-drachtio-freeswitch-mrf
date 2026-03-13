#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <redis-host>"
  exit 1
fi

REDIS_HOST="$1"

echo "stopping apps"
pm2 delete ~/apps/ecosystem.config.js

echo "stopping drachtio"
sudo systemctl stop drachtio

echo "stopping rtpenine"
sudo systemctl stop rtpengine

echo "clearing inbound call counts"
redis-cli -h "$REDIS_HOST" --scan --pattern "incalls:*" | xargs redis-cli -h "$REDIS_HOST" del

echo "clearing outbound call counts"
redis-cli -h "$REDIS_HOST" --scan --pattern "outcalls:*" | xargs redis-cli -h "$REDIS_HOST" del

echo "done, now checking that no call keys exist after that"
redis-cli -h "$REDIS_HOST" --scan --pattern "incalls:*"
redis-cli -h "$REDIS_HOST" --scan --pattern "outcalls:*"

echo "all done"