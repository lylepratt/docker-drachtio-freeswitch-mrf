#!/bin/bash
VARIANT=$1
DISTRO=$2
VERSION=$3
CLOUD=$4
RHEL_RELEASE=""

case "$VARIANT" in
  rtp|sip-rtp|mini)
    ;;
  *)
    echo "skipping rtpengine installation"
    exit 0
    ;;
esac

echo "rtpengine version to install is ${VERSION} on distribution ${DISTRO}"

if [[ "$DISTRO" == rhel* ]]; then
  if [ "$EUID" -ne 0 ]; then
    echo "Switching to root user..."
     sudo -E bash "$0" "$@"
    exit
  fi
  
  RHEL_RELEASE="${DISTRO:5}"

   # Your script continues here, as root
   echo "Now running as root user on RHEL ${RHEL_RELEASE}"
   setenforce 0
   export PATH=/usr/local/bin:$PATH
   export PATH=/usr/local/bin:$PATH
   export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
   export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH
fi

export PATH=/usr/local/bin:$PATH
cmake --version

cd /usr/local/src
git clone https://github.com/BelledonneCommunications/bcg729.git
cd bcg729
cmake . -DCMAKE_INSTALL_PREFIX=/usr && make && sudo make install chdir=/usr/local/src/bcg729

cd /usr/local/src

# Check if the libwebsockets directory does not exist
if [ ! -d "libwebsockets" ]; then
    git clone https://github.com/warmcat/libwebsockets.git -b v4.3.3
    cd libwebsockets
    # patch this until fixed - 
    cd lib/roles/ws
    echo "patching ops-ws.c to fix bug impacting bidirectional streaming"
    cp /tmp/ops-ws.c.patch .
    patch ops-ws.c < ops-ws.c.patch
    cd -
    mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLWS_WITH_NETLINK=OFF -DLWS_WITH_LIBEV=1 && make -j 8 && sudo make install
fi
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

cd /usr/local/src
git clone https://github.com/sipwise/rtpengine.git -b ${VERSION}
cd rtpengine

kernel_version=$(uname -r)

echo "build rtpengine with kernel version ${kernel_version}"
echo make with_transcoding=yes with_iptables_option=no with-kernel
make KSRC=/lib/modules/${kernel_version}/build with_transcoding=yes with_iptables_option=no with-kernel
echo "copying kernel module into /lib/modules/${kernel_version}/updates"
ls -lrt /lib/modules/
mkdir -p /lib/modules/${kernel_version}/updates
cp ./kernel-module/xt_RTPENGINE.ko /lib/modules/${kernel_version}/updates
depmod -a ${kernel_version}
echo "xt_RTPENGINE" >> /etc/modules-load.d/rtpengine.conf

cat << EOF >> /etc/modules
xt_RTPENGINE
EOF

# copy iptables extension into place
#echo "copying iptables extension into ${pkg-config xtables --variable=xtlibdir}"
#cp ./iptables-extension/libxt_RTPENGINE.so `pkg-config xtables --variable=xtlibdir`

cp /usr/local/src/rtpengine/daemon/rtpengine /usr/local/bin
cp /usr/local/src/rtpengine/recording-daemon/rtpengine-recording /usr/local/bin/

if [[ "$CLOUD" == "gcp" ]]; then
  sudo mv /tmp/rtpengine.gcp.service /etc/systemd/system/rtpengine.service
elif [[ "$CLOUD" == "ssh" ]]; then
  sudo mv /tmp/rtpengine.ssh.service /etc/systemd/system/rtpengine.service
else
  sudo mv /tmp/rtpengine.service /etc/systemd/system
fi

chmod 644 /etc/systemd/system/rtpengine.service
systemctl enable rtpengine
systemctl start rtpengine

sudo mv /tmp/rtpengine-recording.service /etc/systemd/system

sudo mv /tmp/rtpengine-recording.ini /etc/rtpengine-recording.ini
sudo chmod 644 /etc/systemd/system/rtpengine-recording.service
sudo chmod 644 /etc/rtpengine-recording.ini
mkdir -p /var/spool/recording
mkdir -p /recording
sudo systemctl enable rtpengine-recording
sudo systemctl start rtpengine-recording

