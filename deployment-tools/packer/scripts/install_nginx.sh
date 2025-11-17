#!/bin/bash
VARIANT=$1
DISTRO=$2

case "$VARIANT" in
  web|web-monitoring|mini)
    ;;
  *)
    echo "skipping nginx installation"
    exit 0
    ;;
esac


echo "installing nginx"

if [[ "$VARIANT" == mini ]]; then
  if [[ "$DISTRO" == rhel* ]]; then
    sudo dnf install -y nginx httpd-tools certbot python3-certbot-nginx
    cd /etc/nginx/conf.d
    sudo mv /tmp/nginx.default.mini default.conf
    sudo mv /tmp/nginx.conf.rhel /etc/nginx/nginx.conf
  else
    sudo apt-get install -y nginx apache2-utils certbot python3-certbot-nginx
    cd /etc/nginx/sites-available
    sudo mv /tmp/nginx.default.mini default
  fi
else
  if [[ "$DISTRO" == rhel* ]]; then
    sudo dnf install -y nginx httpd-tools certbot python3-certbot-nginx
    cd /etc/nginx/conf.d
    sudo mv /tmp/nginx.default default.conf
    sudo mv /tmp/nginx.conf.rhel /etc/nginx/nginx.conf
  else
    sudo apt-get install -y nginx apache2-utils certbot python3-certbot-nginx
    cd /etc/nginx/sites-available
    sudo mv /tmp/nginx.default default
  fi
fi

sudo systemctl enable nginx
sudo systemctl restart nginx

sudo systemctl status nginx


