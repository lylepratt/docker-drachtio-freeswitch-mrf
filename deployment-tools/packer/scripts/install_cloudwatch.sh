#!/bin/bash
VARIANT=$1
DISTRO=$2
ARCH=$3


case "$VARIANT" in
  fs|mini|sip|sip-rtp|web|web-monitoring|recording)
    ;;
  *)
    echo "skipping cloudwatch installation"
    exit 0
    ;;
esac

# Determine the correct CloudWatch Agent URL based on architecture
if [[ "$ARCH" == "amd64" ]]; then
  if [[ "$DISTRO" == rhel* ]]; then
    CLOUDWATCH_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/redhat/amd64/latest/amazon-cloudwatch-agent.rpm"
  else
    CLOUDWATCH_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/debian/amd64/latest/amazon-cloudwatch-agent.deb"
  fi
elif [[ "$ARCH" == "arm64" ]]; then
  if [[ "$DISTRO" == rhel* ]]; then
    CLOUDWATCH_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/redhat/arm64/latest/amazon-cloudwatch-agent.rpm"
  else
    CLOUDWATCH_URL="https://s3.amazonaws.com/amazoncloudwatch-agent/debian/arm64/latest/amazon-cloudwatch-agent.deb"
  fi
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Install CloudWatch Agent
if [[ "$DISTRO" == rhel* ]]; then
  sudo wget "$CLOUDWATCH_URL" -O /tmp/amazon-cloudwatch-agent.rpm
  sudo dnf install -y /tmp/amazon-cloudwatch-agent.rpm
  sudo rm -rf /tmp/amazon-cloudwatch-agent.rpm
else
  sudo wget "$CLOUDWATCH_URL" -O /home/admin/amazon-cloudwatch-agent.deb
  sudo dpkg -i -E /home/admin/amazon-cloudwatch-agent.deb
  sudo rm -rf /home/admin/amazon-cloudwatch-agent.deb
fi

# Install config file for jambonz
sudo cp -r /tmp/cloudwatch-config.json /opt/aws/amazon-cloudwatch-agent/bin/config.json

