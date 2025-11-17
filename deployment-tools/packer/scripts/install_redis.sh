#!/bin/bash
VARIANT=$1
DISTRO=$2

if [[ "$VARIANT" != "mini" ]]; then
  echo "skipping redis installation for non-mini variant"
  exit 0
fi

echo "DISTRO is $DISTRO"
if [[ "$DISTRO" == rhel* ]] ; then
  sudo dnf install -y redis
  sudo systemctl enable redis
  sudo systemctl start redis
else
  sudo apt-get install -y redis-server
  sudo systemctl enable redis-server
  sudo systemctl restart redis-server
fi

