#!/bin/bash
VARIANT=$1
DISTRO=$2
VERSION=$3
CLOUD=$4

case "$VARIANT" in
  mini|fs|sip|rtp|sip-rtp)
    ;;
  *)
    echo "skipping drachtio installation"
    exit 0
    ;;
esac

if [[ "$DISTRO" == rhel* ]]; then
  if [ "$EUID" -ne 0 ]; then
    echo "Switching to root user..."
     sudo -E bash "$0" "$@"
    exit
  fi  
fi

echo "drachtio version to install is ${VERSION} on ${DISTRO} ${CLOUD}"
export PATH=/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:$LD_LIBRARY_PATH

chmod 0777 /usr/local/src
cd /usr/local/src

git clone https://github.com/drachtio/drachtio-server.git -b ${VERSION}
cd drachtio-server
git submodule update --init --recursive
./autogen.sh && mkdir -p build && cd $_ 
../configure --enable-tcmalloc=yes CXXFLAGS='-g -O2' CPPFLAGS='-DNDEBUG' 
make -j 4 
echo make complete now make install drachtio
sudo make install
echo done installing drachtio
find /usr/local -name drachtio
ls -lrt /usr/local/bin/

if [[ "$VARIANT" == "mini" ]]; then
  if [[ "$CLOUD" == "gcp" ]]; then
    sudo mv /tmp/drachtio.gcp.service /etc/systemd/system/drachtio.service
    sudo mv /tmp/drachtio-5070.gcp.service /etc/systemd/system/drachtio-5070.service
  elif [[ "$CLOUD" == "ssh" ]]; then
    sudo mv /tmp/drachtio.ssh.service /etc/systemd/system/drachtio.service
    sudo mv /tmp/drachtio-5070.ssh.service /etc/systemd/system/drachtio-5070.service
  else
    sudo mv /tmp/drachtio.service /etc/systemd/system
    sudo mv /tmp/drachtio-5070.service /etc/systemd/system
  fi
  sudo mv /tmp/drachtio.conf.xml /etc
  sudo mv /tmp/drachtio-5070.conf.xml /etc
  sudo chmod 644 /etc/drachtio-5070.conf.xml
  sudo chmod 644 /etc/systemd/system/drachtio-5070.service
  sudo systemctl enable drachtio-5070
  sudo systemctl restart drachtio-5070
elif [[ "$VARIANT" == "fs" ]]; then
  if [[ "$CLOUD" == "gcp" ]]; then
    sudo mv /tmp/drachtio-feature-server.gcp.service /etc/systemd/system/drachtio.service
  else
    sudo mv /tmp/drachtio-feature-server.service /etc/systemd/system/drachtio.service
  fi
  sudo mv /tmp/drachtio-feature-server.conf.xml /etc/drachtio.conf.xml
elif [[ "$VARIANT" == "sip-rtp" ||  "$VARIANT" == "sip" ]]; then
  if [[ "$CLOUD" == "gcp" ]]; then
    sudo mv /tmp/drachtio.gcp.service /etc/systemd/system/drachtio.service
  else
    sudo mv /tmp/drachtio.service /etc/systemd/system
    sudo cp /tmp/auto-assign-elastic-ip.sh /usr/local/bin
    sudo chmod +x /usr/local/bin/auto-assign-elastic-ip.sh
  fi
  sudo mv /tmp/drachtio.conf.xml /etc
elif [[ "$VARIANT" == "rtp" ]]; then
  if [[ "$CLOUD" == "gcp" ]]; then
    sudo mv /tmp/drachtio.conf.xml /etc
    sudo mv /tmp/drachtio.gcp.service /etc/systemd/system/drachtio.service
  else
    sudo mv /tmp/drachtio.conf.xml /etc
    sudo mv /tmp/drachtio.service /etc/systemd/system
    sudo cp /tmp/auto-assign-elastic-ip.sh /usr/local/bin
    sudo chmod +x /usr/local/bin/auto-assign-elastic-ip.sh
  fi
fi

sudo chmod 644 /etc/drachtio.conf.xml
sudo chmod 644 /etc/systemd/system/drachtio.service
sudo systemctl enable drachtio
sudo systemctl restart drachtio
