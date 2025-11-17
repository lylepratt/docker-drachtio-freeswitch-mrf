#!/bin/bash
VARIANT=$1
DISTRO=$2

case "$VARIANT" in
  mini|web-monitoring|web|sip|sip-rtp)
    ;;
  *)
    echo "skipping certbot installation"
    exit 0
    ;;
esac

if [ "$3" == "yes" ]; then

if [[ "$DISTRO" == rhel* ]]; then
  echo "Installing Certbot on RHEL using dnf..."
  dnf install -y certbot python3-certbot-nginx
else
  # Install core and certbot snaps
  sudo snap install core
  sudo snap install --classic certbot

  # Symlink certbot to the expected location
  sudo ln -sf /snap/bin/certbot /usr/bin/certbot
fi

# Check certbot installation
which certbot
certbot --version
fi