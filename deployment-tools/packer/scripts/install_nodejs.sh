#!/bin/bash
VARIANT=$1
DISTRO=$2

if [[ "$VARIANT" == "monitoring" ]]; then
  echo "skipping nodejs installation for monitoring ami"
  exit 0
fi

if [[ "$DISTRO" == rhel* ]]; then
  # Import the GPG key
  sudo curl -fsSL https://rpm.nodesource.com/gpgkey/ns-operations-public.key -o /tmp/ns-operations-public.key
  sudo rpm --import /tmp/ns-operations-public.key
  sudo rm -f /tmp/ns-operations-public.key

  # Create the repository file (no leading spaces in heredoc!)
  sudo tee /etc/yum.repos.d/nodesource-nodejs.repo > /dev/null <<'EOF'
[nodesource-nodejs]
name=Node.js Packages for Linux RPM based distros - x86_64
baseurl=https://rpm.nodesource.com/pub_24.x/nodistro/nodejs/x86_64
priority=9
enabled=1
gpgcheck=1
gpgkey=https://rpm.nodesource.com/gpgkey/ns-operations-public.key
module_hotfixes=1
EOF

  # Clean cache and install
  sudo yum clean all
  sudo yum makecache --disablerepo="*" --enablerepo="nodesource-nodejs"
  sudo yum install -y nodejs
else
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl gnupg
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
  echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
  sudo apt-get update
  sudo apt-get install -y nodejs
#  sudo apt-get install -y npm
fi

node -v
npm -v

#sudo ls -lrt /root/.npm/ || true
#sudo ls -lrt /root/.npm/_logs || true
#sudo ls -lrt /root/.npm/_cacache || true
#sudo chmod -R a+wx /root || true
#sudo chown -R 1000:1000 /root/.npm || true
#ls -lrt /root/.npm/ || true
#ls -lrt /root/.npm/_logs || true
#ls -lrt /root/.npm/_cacache || true