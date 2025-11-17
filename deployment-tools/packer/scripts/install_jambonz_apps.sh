#!/bin/bash
VARIANT=$1
DISTRO=$2
VERSION=$3

if [[ "$VARIANT" == "monitoring" || "$VARIANT" == "recording" ]]; then
  echo "skipping jambonz apps installation for $VARIANT ami"
  exit 0
fi

if [[ "$DISTRO" == rhel* ]]; then
    RUN_USER=ec2-user
    RHEL_RELEASE="${DISTRO:5}"
    HOME=/home/ec2-user
    sed -i "s|/home/admin|${HOME}|g" /tmp/ecosystem.config.js
else
    RUN_USER=admin
    HOME=/home/admin
fi

mkdir -p $HOME/scripts
mkdir -p $HOME/apps && cd $_
git config --global advice.detachedHead false

ALIAS_LINE="alias gl='git log --oneline --decorate'"
echo "$ALIAS_LINE" >> ~/.bash_aliases

cd $HOME
mkdir -p $HOME/apps && cd $_

# clone the necessary apps
case "$VARIANT" in
    mini)
      cp /tmp/ecosystem.config.js $HOME/apps
      git clone https://github.com/jambonz/sbc-call-router.git -b $VERSION
      git clone https://github.com/jambonz/sbc-outbound.git -b $VERSION
      git clone https://github.com/jambonz/sbc-inbound.git -b $VERSION
      git clone https://github.com/jambonz/sbc-sip-sidecar.git -b $VERSION
      git clone https://github.com/jambonz/sbc-rtpengine-sidecar.git -b $VERSION
      git clone https://github.com/jambonz/jambonz-api-server.git -b $VERSION
      git clone https://github.com/jambonz/jambonz-webapp.git -b $VERSION
      git clone https://github.com/jambonz/jambonz-smpp-esme.git -b $VERSION
      git clone https://github.com/jambonz/jambonz-feature-server.git -b $VERSION
      git clone https://github.com/jambonz/fsw-clear-old-calls.git -b $VERSION
      git clone https://github.com/jambonz/public-apps.git
      echo "installed full set of apps for jambonz mini"
      ls -lrt $HOME/apps
      sudo cp /tmp/cleanup-freeswitch-cache.sh /usr/local/bin
      sudo chmod +x /usr/local/bin/cleanup-freeswitch-cache.sh
      sudo cp /tmp/cleanup-temp-audiofiles.sh /usr/local/bin
      sudo chmod +x /usr/local/bin/cleanup-temp-audiofiles.sh
      ;;
    fs)
      git clone https://github.com/jambonz/jambonz-feature-server.git -b $VERSION
      git clone https://github.com/jambonz/fsw-clear-old-calls.git -b $VERSION

      sudo cp /tmp/fs-start-all.sh $HOME/scripts
      sudo cp /tmp/fs-stop-all.sh $HOME/scripts
      sudo cp /tmp/system-diagnostics.sh $HOME/scripts
      sudo chmod +x $HOME/scripts/fs-start-all.sh
      sudo chmod +x $HOME/scripts/fs-stop-all.sh
      sudo chmod +x $HOME/scripts/system-diagnostics.sh
      sudo chown $RUN_USER:$RUN_USER $HOME/scripts/fs-start-all.sh
      sudo chown $RUN_USER:$RUN_USER $HOME/scripts/fs-stop-all.sh
      sudo chown $RUN_USER:$RUN_USER $HOME/scripts/system-diagnostics.sh
      sudo cp /tmp/cleanup-freeswitch-cache.sh /usr/local/bin
      sudo chmod +x /usr/local/bin/cleanup-freeswitch-cache.sh
      sudo cp /tmp/cleanup-temp-audiofiles.sh /usr/local/bin
      sudo chmod +x /usr/local/bin/cleanup-temp-audiofiles.sh
      ;;
    sip)
      git clone https://github.com/jambonz/sbc-call-router.git -b $VERSION
      git clone https://github.com/jambonz/sbc-outbound.git -b $VERSION
      git clone https://github.com/jambonz/sbc-inbound.git -b $VERSION
      git clone https://github.com/jambonz/sbc-sip-sidecar.git -b $VERSION
      git clone https://github.com/jambonz/sbc-rtpengine-sidecar.git -b $VERSION
      git clone https://github.com/jambonz/jambonz-smpp-esme.git -b $VERSION
      ;;
    rtp)
      git clone https://github.com/jambonz/sbc-rtpengine-sidecar.git -b $VERSION
      ;;
    sip-rtp)
      git clone https://github.com/jambonz/sbc-call-router.git -b $VERSION
      git clone https://github.com/jambonz/sbc-outbound.git -b $VERSION
      git clone https://github.com/jambonz/sbc-inbound.git -b $VERSION
      git clone https://github.com/jambonz/sbc-sip-sidecar.git -b $VERSION
      git clone https://github.com/jambonz/sbc-rtpengine-sidecar.git -b $VERSION
      git clone https://github.com/jambonz/jambonz-smpp-esme.git -b $VERSION
      ;;
    web|web-monitoring)
      git clone https://github.com/jambonz/jambonz-api-server.git -b $VERSION
      git clone https://github.com/jambonz/jambonz-webapp.git -b $VERSION
      git clone https://github.com/jambonz/public-apps.git
      sudo cp /tmp/auto-assign-elastic-ip.sh /usr/local/bin
      sudo chmod +x /usr/local/bin/auto-assign-elastic-ip.sh
      ;;
    *)
      echo "Invalid variant. Please specify 'mini', 'fs', 'sip', 'rtp', 'sip-rtp', 'web', 'web-monitoring'."
      exit 2
      ;;
esac

sleep 5

## install the apps
cd "$HOME/apps"
# Verify current directory to avoid path issues
echo "Current directory: $(pwd)"
ls -lrt

# Loop through each sub-directory
for dir in */; do
    # Remove trailing slash for consistency
    dir=${dir%/}

    # Check if the directory actually exists
    if [ ! -d "$dir" ]; then
        echo "Directory $dir does not exist, skipping..."
        continue
    fi

    echo "Installing $dir..."
    # Enter the directory
    if cd "$dir"; then
        # Check if the directory is jambonz-webapp and perform specific actions
        if [[ "$dir" == "jambonz-webapp" ]]; then
            echo "Running npm ci and build in $dir..."
            npm ci && npm run build
        elif [[ "$dir" == "fsw-clear-old-calls" ]]; then
            echo "Running npm ci in $dir..."
            npm ci
            echo "Installing $dir globally..."
            sudo npm install -g .
        else
            echo "Running npm ci in $dir..."
            npm ci
        fi

        # Go back to the apps directory
        cd ..
        # Just to ensure we're back to the correct directory
        echo "Returned to $(pwd)"
    else
        echo "Failed to enter directory $dir, skipping..."
    fi
done

echo "All installations completed."

sudo npm install -g pino-pretty pm2 pm2-logrotate

sudo chown -R 1000:1000 "$HOME/.npm"

sudo -u ${RUN_USER} bash -c "pm2 install pm2-logrotate"
sudo -u ${RUN_USER} bash -c "pm2 set pm2-logrotate:max_size 1G"
sudo -u  ${RUN_USER} bash -c "pm2 set pm2-logrotate:retain 5"
sudo -u  ${RUN_USER} bash -c "pm2 set pm2-logrotate:compress true"
sudo chown -R  ${RUN_USER}:${RUN_USER}  $HOME/apps

if [[ "$VARIANT" == "mini" || "$VARIANT" == "fs" ]]; then
  echo "0 * * * * root fsw-clear-old-calls --password JambonzR0ck\$ >> /var/log/fsw-clear-old-calls.log 2>&1" | sudo tee -a /etc/crontab > /dev/null
  echo "0 1 * * * root /usr/local/bin/cleanup-temp-audiofiles.sh" | sudo tee -a /etc/crontab > /dev/null
  echo "0 */12 * * * root /usr/local/bin/cleanup-freeswitch-cache.sh  > /dev/null 2>&1" | sudo tee -a /etc/crontab > /dev/null
fi