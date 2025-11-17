#!/bin/bash
VARIANT=$1
DISTRO=$2
ROLE=

case "$VARIANT" in
  mini)
    ROLE=mini
    ;;
  fs)
    ROLE=fs
    ;;
  sip)
    ROLE=sip
    ;;
  rtp)
    ROLE=rtp
    ;;
  sip-rtp)
    ROLE=sbc
    ;;
  recording)
    ROLE=recording
    ;;
  web|web-monitoring)
    ROLE=web
    ;;
  monitoring)
    ROLE=monitoring
    ;;
  *)
    echo "skipping telegraf installation"
    exit 0
    ;;
esac

cd /tmp

if [[ "$DISTRO" == rhel* ]]; then
  cat <<EOF | sudo tee /etc/yum.repos.d/influxdata.repo
[influxdata]
name = InfluxData Repository
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdata-archive_compat.key
EOF
  echo checking disk space
  df -h
  dnf clean packages
  echo after cleaning packages
  df -h
  sudo dnf install -y telegraf
else
  wget -q https://repos.influxdata.com/influxdata-archive_compat.key
  gpg --with-fingerprint --show-keys ./influxdata-archive_compat.key
  cat influxdata-archive_compat.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
  echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | sudo tee /etc/apt/sources.list.d/influxdata.list

  sudo apt-get update 
  sudo apt-get install -y telegraf
fi

if [ "$ROLE" == "recording" ]; then
  echo "copying telegraf.conf.recording to /etc/telegraf/telegraf.conf to enable udp statsd listener"
  sudo cp /tmp/telegraf.conf.recording /etc/telegraf/telegraf.conf
else
  sudo cp /tmp/telegraf.conf /etc/telegraf/telegraf.conf
fi

# Change the role in the telegraf.conf file
sudo sed -i "s/role = \"insert-role-here\"/role = \"$ROLE\"/" /etc/telegraf/telegraf.conf

sudo systemctl enable telegraf
sudo systemctl start telegraf
