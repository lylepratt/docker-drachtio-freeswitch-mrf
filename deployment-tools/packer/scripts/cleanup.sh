#! /bin/bash
VARIANT=$1
DISTRO=$2
LEAVE_SOURCE=$3
REMOVE_KEYS=$4

set -e
set -x

echo "running cleanup.sh on $DISTRO, leaving source: $LEAVE_SOURCE"

if [[ "$DISTRO" == rhel* ]]; then
  sudo dnf install -y iptables-services
else
  echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
  echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
  sudo apt-get -y install iptables-persistent
fi

if [ -d "/home/admin/.npm" ]; then
    sudo chown -R 1000:1000 "/home/admin/.npm"
fi

if [[ "$CLOUD" == "ssh" ]]; then
  if [[ "$VARIANT" == "mini" ]]; then
    mv /tmp/setup_mini.sh ~/admin/setup.sh
  fi
fi

sudo rm -Rf /tmp/*
if [ "$LEAVE_SOURCE" = 'no' ]; then 
  echo "removing source files"
  sudo rm -Rf /usr/local/src/*; 
fi
