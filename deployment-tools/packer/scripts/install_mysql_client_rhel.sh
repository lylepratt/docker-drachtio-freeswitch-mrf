#!/bin/bash

# MySQL Repository URL
MYSQL_REPO_URL="https://dev.mysql.com/get/mysql80-community-release-el8-9.noarch.rpm"

# Download the MySQL repository RPM with the correct filename
echo "Downloading MySQL repository..."
sudo curl -L -o mysql80-community-release-el8-9.noarch.rpm $MYSQL_REPO_URL

# Install the MySQL repository
echo "Installing MySQL repository..."
sudo rpm -ivh mysql80-community-release-el8-9.noarch.rpm

# Clean up the downloaded RPM file
sudo rm -f mysql80-community-release-el8-9.noarch.rpm

# Disable the default MySQL module
echo "Disabling the default MySQL module..."
sudo dnf module -y disable mysql

# Update your repository cache
sudo dnf makecache

# Install the MySQL client
echo "Installing MySQL client..."
sudo dnf install -y mysql-community-client

# Verify the installation
echo "Verifying the MySQL client installation..."
mysql --version
