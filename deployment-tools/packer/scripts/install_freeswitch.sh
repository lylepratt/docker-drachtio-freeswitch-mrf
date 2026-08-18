#!/bin/bash
set -e

VARIANT=$1
DISTRO=$2
PREFERRED_CODEC_LIST=$3
MEDIA_SERVER_NAME=$4
ARCH=$5
CONTAINER_BUILD=${CONTAINER_BUILD:-0}

case "$VARIANT" in
  fs|mini)
    ;;
  *)
    echo "skipping freeswitch installation"
    exit 0
    ;;
esac

if [[ "$DISTRO" == rhel* ]]; then
    RUN_USER=ec2-user
    RHEL_RELEASE="${DISTRO:5}"
    HOME=/home/ec2-user
    sed -i "s|/home/admin|${HOME}|g" /tmp/ecosystem.config.js
else
    RUN_USER=admin
    HOME=/home/admin
fi

if [[ "$DISTRO" == rhel* ]]; then
  RUN_USER=ec2-user
  HOME=/home/ec2-user
  if [ "$EUID" -ne 0 ]; then
    echo "Switching to root user..."
     sudo -E bash "$0" "$@"
    exit
  fi  
else
  RUN_USER=admin
  HOME=/home/admin
fi

if ! id "$RUN_USER" >/dev/null 2>&1; then
  echo "user ${RUN_USER} does not exist; falling back to root"
  RUN_USER=root
  HOME=/root
fi

export HOME

FREESWITCH_VERSION=v1.10.10
SPAN_DSP_VERSION=0d2e6ac
GRPC_VERSION=v1.57.0
GOOGLE_API_VERSION=d81d0b9e6993d6ab425dff4d7c3d05fb2e59fa57
AWS_SDK_VERSION=1.11.500
LWS_VERSION=v4.3.3
MODULES_VERSION=2.5.24
AZURE_SDK_VERSION=1.45.0
HOUNDIFY_SDK_VERSION=2.0.0
ONNXRUNTIME_VERSION=1.22.0

echo "freeswitch version to install is ${FREESWITCH_VERSION}"
echo "drachtio modules version to install is ${MODULES_VERSION}"
echo "GRPC version to install is ${GRPC_VERSION}"
echo "GOOGLE_API_VERSION version to install is ${GOOGLE_API_VERSION}"
echo "AWS_SDK_VERSION version to install is ${AWS_SDK_VERSION}"
echo "LWS_VERSION version to install is ${LWS_VERSION}"
echo "DISTRO is ${DISTRO}"
echo "PREFERRED_CODEC_LIST is ${PREFERRED_CODEC_LIST}"
echo "MEDIA_SERVER_NAME is ${MEDIA_SERVER_NAME}"
echo "ARCH is ${ARCH}"

# Your script continues here, as root

export PATH=/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:$LD_LIBRARY_PATH
if [ -n "$PKG_CONFIG_PATH" ]; then
  export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH
else
  export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib64/pkgconfig
fi
echo "PKG_CONFIG_PATH is now set to: $PKG_CONFIG_PATH"

# install boost
# Check if Boost is installed
if pkg-config --exists boost; then
  echo "Boost is already installed."
else
  echo "Boost is not installed. Attempting to install..."

  # Detecting which package manager to use
  if command -v apt-get >/dev/null; then
    sudo apt-get install -y libboost-all-dev
  elif command -v yum >/dev/null; then
    sudo yum -y install boost-devel
    sudo yum -y install gcc-toolset-12
    source /opt/rh/gcc-toolset-12/enable
    echo "gcc version"
    gcc --version
  elif command -v pacman >/dev/null; then
    sudo pacman -S --noconfirm boost
  else
    echo "Package manager not detected. You must manually install Boost."
  fi
fi

echo "installing Microsoft Azure Speech SDK"

cd /tmp
tar xvfz SpeechSDK-Linux-${AZURE_SDK_VERSION}.tar.gz
cd SpeechSDK-Linux-${AZURE_SDK_VERSION}
sudo cp -r include /usr/local/include/MicrosoftSpeechSDK
sudo cp -r lib/ /usr/local/lib/MicrosoftSpeechSDK
if [ "$ARCH" == "arm64" ]; then
  echo installing Microsoft arm64 libs...
  sudo cp /usr/local/lib/MicrosoftSpeechSDK/arm64/* /usr/local/lib
  echo done
fi 
if [ "$ARCH" == "amd64" ]; then
  echo installing Microsoft x64 libs...
  sudo cp /usr/local/lib/MicrosoftSpeechSDK/x64/* /usr/local/lib
  echo done
fi

cd /usr/local/src
echo remove SpeechSDK-Linux-${AZURE_SDK_VERSION}
sudo rm -Rf /tmp/SpeechSDK-Linux-${AZURE_SDK_VERSION}.tgz /tmp/SpeechSDK-Linux-${AZURE_SDK_VERSION}
echo done

# Install ONNX Runtime for Silero VAD
echo "Installing ONNX Runtime version ${ONNXRUNTIME_VERSION}"
cd /tmp

if [ "$ARCH" == "arm64" ]; then
  ONNX_PACKAGE="onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}.tgz"
  ONNX_DIR="onnxruntime-linux-aarch64-${ONNXRUNTIME_VERSION}"
elif [ "$ARCH" == "amd64" ]; then
  ONNX_PACKAGE="onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}.tgz"
  ONNX_DIR="onnxruntime-linux-x64-${ONNXRUNTIME_VERSION}"
else
  echo "Unsupported architecture for ONNX Runtime: $ARCH"
  exit 1
fi

tar xzf ${ONNX_PACKAGE}
cd ${ONNX_DIR}

# Install headers and libraries
echo "Installing ONNX Runtime headers to /usr/local/include/"
sudo cp -r include/* /usr/local/include

echo "Installing ONNX Runtime libraries to /usr/local/lib/"
sudo cp -r lib/* /usr/local/lib

# Update library cache
sudo ldconfig

echo "ONNX Runtime installation completed"

# Clean up
cd /usr/local/src
sudo rm -Rf /tmp/${ONNX_DIR}
echo "ONNX Runtime cleanup done"

echo config git
git config --global pull.rebase true
echo done
git clone https://github.com/signalwire/freeswitch.git -b ${FREESWITCH_VERSION}

cd /tmp
tar xvfz freeswitch-modules-${MODULES_VERSION}.tar.gz
ls -lrt
echo copying freeswitch-modules-${MODULES_VERSION} to /usr/local/src/freeswitch-modules
sudo cp -r freeswitch-modules-${MODULES_VERSION} /usr/local/src/freeswitch-modules

# copy common jambonz source files into place
SOURCE_DIR="/usr/local/src/freeswitch-modules/common"
if [ -d "$SOURCE_DIR" ]; then
  echo "Copying jambonz source files from $SOURCE_DIR"
  sudo mkdir -p /usr/local/src/freeswitch/src/jambonz
  sudo mkdir -p /usr/local/src/freeswitch/src/include/jambonz
  sudo cp -r $SOURCE_DIR/src/* /usr/local/src/freeswitch/src/jambonz
  sudo cp -r $SOURCE_DIR/include/* /usr/local/src/freeswitch/src/include/jambonz
  sudo chown -R $RUN_USER:$RUN_USER /usr/local/src/freeswitch/src/jambonz
  sudo chown -R $RUN_USER:$RUN_USER /usr/local/src/freeswitch/src/include/jambonz
fi

cd /usr/local/src

echo "cloning grcp"
git clone https://github.com/grpc/grpc -b master
cd grpc && git checkout ${GRPC_VERSION} && cd ..

cd freeswitch/libs
git clone https://github.com/drachtio/nuance-asr-grpc-api.git -b main
git clone https://github.com/drachtio/riva-asr-grpc-api.git -b main
git clone https://github.com/drachtio/soniox-asr-grpc-api.git -b main
git clone https://github.com/drachtio/cobalt-asr-grpc-api.git -b main
git clone https://github.com/drachtio/verbio-asr-grpc-api.git -b main
git clone https://github.com/freeswitch/spandsp.git && cd spandsp && git checkout ${SPAN_DSP_VERSION} && cd ..
git clone https://github.com/freeswitch/sofia-sip.git -b master
git clone https://github.com/dpirch/libfvad.git
git clone https://github.com/aws/aws-sdk-cpp.git -b ${AWS_SDK_VERSION}
git clone https://github.com/googleapis/googleapis -b master 
cd googleapis && git checkout ${GOOGLE_API_VERSION} && cd ..
git clone https://github.com/awslabs/aws-c-common.git
git clone --recursive https://github.com/awslabs/aws-crt-cpp.git


cp -r /usr/local/src/freeswitch-modules/modules/* /usr/local/src/freeswitch/src/mod/applications
sudo chown -R $RUN_USER:$RUN_USER /usr/local/src/freeswitch/src/mod/applications/

# Keep the C caller and C++ glue on one checked ABI, and reject unresolved
# module-local symbols while linking rather than deferring them to dlopen().
patch -d /usr/local/src/freeswitch/src/mod/applications/mod_gptlive_s2s -p1 < /tmp/mod_gptlive_s2s.c-abi.patch

# copy Makefiles and patches into place
cp /tmp/configure.ac.extra /usr/local/src/freeswitch/configure.ac
cp /tmp/Makefile.am.extra /usr/local/src/freeswitch/Makefile.am
cp /tmp/modules.conf.in.extra /usr/local/src/freeswitch/build/modules.conf.in
cp /tmp/modules.conf.vanilla.xml.extra /usr/local/src/freeswitch/conf/vanilla/autoload_configs/modules.conf.xml
cp /tmp/avmd.conf.xml /usr/local/src/freeswitch/conf/vanilla/autoload_configs/avmd.conf.xml
cp /tmp/switch_core_media.c.patch /usr/local/src/freeswitch/src
cp /tmp/switch_rtp.c.patch /usr/local/src/freeswitch/src
cp /tmp/mod_avmd.c.patch /usr/local/src/freeswitch/src/mod/applications/mod_avmd
cp /tmp/mod_httapi.c.patch /usr/local/src/freeswitch/src/mod/applications/mod_httapi
cp /tmp/switch_core_media_bug.c.patch /usr/local/src/freeswitch/src
cp /tmp/switch_types.h.patch /usr/local/src/freeswitch/src/include
cp /tmp/mod_event_socket.c.patch /usr/local/src/freeswitch/src/mod/event_handlers/mod_event_socket

cd /usr/local/src/freeswitch/src
echo patching switch_core_media
patch < switch_core_media.c.patch
echo patching switch_rtp
patch < switch_rtp.c.patch
echo patching switch_core_media_bug
patch < switch_core_media_bug.c.patch
cd include
echo patching switch_types.h
patch < switch_types.h.patch
cd /usr/local/src/freeswitch/src/mod/applications/mod_avmd
echo patching mod_avmd
patch < mod_avmd.c.patch
cd /usr/local/src/freeswitch/src/mod/applications/mod_httapi
echo patching mod_httapi
patch < mod_httapi.c.patch
echo patching mod_event_socket
cd /usr/local/src/freeswitch/src/mod/event_handlers/mod_event_socket
patch < mod_event_socket.c.patch

# our version skinnys down the voluminous headers that freeswitch puts in every message
echo "patching switch_event.c for performance improvement and tts streaming"
cp /tmp/switch_event.c /usr/local/src/freeswitch/src/switch_event.c

# add our mod_conference patches
echo "patching mod_conference for advanced conferencing features"
cp /tmp/mod_conference.h /usr/local/src/freeswitch/src/mod/applications/mod_conference
cp /tmp/conference_api.c /usr/local/src/freeswitch/src/mod/applications/mod_conference

# Check if the libwebsockets directory does not exist
cd /usr/local/src
if [ ! -d "libwebsockets" ]; then
    echo building lws
    git clone https://github.com/warmcat/libwebsockets.git -b ${LWS_VERSION}
    cd libwebsockets
    # patch this until fixed - 
    cd lib/roles/ws
    echo "patching ops-ws.c to fix bug impacting bidirectional streaming"
    cp /tmp/ops-ws.c.patch .
    patch ops-ws.c < ops-ws.c.patch
    cd -
    mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLWS_WITH_NETLINK=OFF -DLWS_WITH_LIBEV=1 && make -j4 && sudo make install
fi

# build libfvad
cd /usr/local/src/freeswitch/libs/libfvad
# use our version of libfvad configure.ac - should only do this on debian 12
if [ "$DISTRO" == "debian-12" ]; then
  echo "patching libfvad configure.ac to remove deprecated commands"
  cp /tmp/configure.ac.libfvad configure.ac
fi
echo building libfvad
autoreconf -i && ./configure && make -j4 && sudo make install

# build Soundhound Houndify SDK
echo "installing Soundhound Houndify SDK"
cp /tmp/houndify-sdk-v${HOUNDIFY_SDK_VERSION}.tgz /usr/local/src

cd /usr/local/src
tar xvfz houndify-sdk-v${HOUNDIFY_SDK_VERSION}.tgz
cd houndify-sdk
sudo cmake -B build && cd build && sudo cmake .. -DCMAKE_CXX_FLAGS="-fPIC" -DCMAKE_C_FLAGS="-fPIC" && sudo make -j 4
sudo cp libhoundify.a /usr/local/lib
sudo cp -r /usr/local/src/houndify-sdk/include/houndify /usr/local/include
sudo cp -r /usr/local/src/houndify-sdk/build/_deps/nlohmann-src/include/nlohmann /usr/local/include


# build spandsp
echo building spandsp

# Check if the file exists before moving
if [ -f /usr/lib64/pkgconfig/spandsp.pc ]; then
  echo "Moving old spandsp.pc out of the way"
  mv /usr/lib64/pkgconfig/spandsp.pc /usr/lib64/pkgconfig/spandsp.pc.bak
fi


cd /usr/local/src/freeswitch/libs/spandsp
./bootstrap.sh && ./configure && make -j4 && sudo make install

# build sofia
echo building sofia
cd /usr/local/src/freeswitch/libs/sofia-sip
./bootstrap.sh && ./configure && make -j4 && sudo make install

cd /usr/local/src
ls -lrt
if [ ! -d "aws-sdk-cpp" ]; then
  git clone https://github.com/aws/aws-sdk-cpp -b ${AWS_SDK_VERSION}
  cd aws-sdk-cpp
  git submodule update --init --recursive
  mkdir -p build && cd build
  cmake .. -DBUILD_ONLY="s3;core;s3-crt;lexv2-runtime;transcribestreaming;monitoring;polly" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="-Wno-unused-parameter -Wno-error=nonnull -Wno-error=deprecated-declarations -Wno-error=uninitialized -Wno-error=maybe-uninitialized -Wno-error=array-bounds"
  make -j4
  sudo make install
  find /usr/local/src/aws-sdk-cpp/ -type f -name "*.pc" | sudo xargs cp -t /usr/local/lib/pkgconfig
fi

# build grpc
echo building grpc
cd /usr/local/src/grpc
git submodule update --init --recursive
mkdir -p cmake/build
cd cmake/build
cmake -DBUILD_SHARED_LIBS=ON -DgRPC_INSTALL=ON -DgRPC_SSL_PROVIDER=package -DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo ../..
make -j4
sudo make install

echo now that I have built grpc++ lets see where absl_any_invocable.pc landed
find /usr/ -name absl_any_invocable.pc
echo and the answer is above...hopefully
echo 

# build googleapis
echo building googleapis
cd /usr/local/src/freeswitch/libs/googleapis
if [ "$DISTRO" == "debian-12" ] || [ "$DISTRO" == rhel* ] ; then
  LANGUAGE=cpp FLAGS+='--experimental_allow_proto3_optional' make -j 4
else
  LANGUAGE=cpp make -j4
fi

# build nuance protobufs
echo "building protobuf stubs for Nuance asr"
cd /usr/local/src/freeswitch/libs/nuance-asr-grpc-api
LANGUAGE=cpp make -j4

# build nvidia protobufs
echo "building protobuf stubs for nvidia riva asr"
cd /usr/local/src/freeswitch/libs/riva-asr-grpc-api
LANGUAGE=cpp make -j4

# build soniox protobufs
echo "building protobuf stubs for sonioxasr"
cd /usr/local/src/freeswitch/libs/soniox-asr-grpc-api
LANGUAGE=cpp make -j4

# build cobalt protobufs
echo "building protobuf stubs for cobalt"
cd /usr/local/src/freeswitch/libs/cobalt-asr-grpc-api
LANGUAGE=cpp make -j4

# build verbio protobufs
echo "building protobuf stubs for verbio"
cd /usr/local/src/freeswitch/libs/verbio-asr-grpc-api
LANGUAGE=cpp make -j4

# patch cJSON.h to avoid conflict - https://github.com/aws/aws-sdk-cpp/issues/1829#issuecomment-1106468040
echo "patching cJSON.h to avoid conflict with aws-sdk-cpp"
sudo sed -i '/#ifndef cJSON_AS4CPP__h/i #ifndef cJSON__h\n#define cJSON__h' /usr/local/include/aws/core/external/cjson/cJSON.h
echo '#endif' | sudo tee -a /usr/local/include/aws/core/external/cjson/cJSON.h > /dev/null
echo "done patching cJSON.h"

# build freeswitch
echo "building freeswitch"
cd /usr/local/src/freeswitch
sudo cp /tmp/ax_check_compile_flag.m4 .
./bootstrap.sh -j
./configure --enable-tcmalloc=no --with-lws=yes --with-extra=yes --with-jambonz-logging=yes
make -j4
sudo make install

# Do not publish a module that defers one of its own glue functions to the
# runtime loader. This catches stale or incomplete module objects during the
# image build instead of when FreeSWITCH starts.
GPTLIVE_MODULE=/usr/local/freeswitch/mod/mod_gptlive_s2s.so
if ! nm -D --defined-only "$GPTLIVE_MODULE" | grep -q ' gptlive_s2s_read_frame$'; then
  echo "ERROR: $GPTLIVE_MODULE does not define gptlive_s2s_read_frame" >&2
  exit 1
fi

sudo make cd-sounds-install cd-moh-install
sudo cp /tmp/acl.conf.xml /usr/local/freeswitch/conf/autoload_configs
sudo cp /tmp/event_socket.conf.xml /usr/local/freeswitch/conf/autoload_configs
sudo cp /tmp/switch.conf.xml /usr/local/freeswitch/conf/autoload_configs
sudo cp /tmp/conference.conf.xml /usr/local/freeswitch/conf/autoload_configs
sudo rm -Rf /usr/local/freeswitch/conf/dialplan/*
sudo rm -Rf /usr/local/freeswitch/conf/sip_profiles/*
sudo cp /tmp/mrf_dialplan.xml /usr/local/freeswitch/conf/dialplan
sudo cp /tmp/mrf_sip_profile.xml /usr/local/freeswitch/conf/sip_profiles
sudo cp /usr/local/src/freeswitch/conf/vanilla/autoload_configs/modules.conf.xml /usr/local/freeswitch/conf/autoload_configs

sudo chown root:root -R /usr/local/freeswitch
sudo sed -i -e 's/global_codec_prefs=OPUS,G722,PCMU,PCMA,H264,VP8/global_codec_prefs=PCMU,PCMA,OPUS,G722/g' /usr/local/freeswitch/conf/vars.xml
sudo sed -i -e 's/outbound_codec_prefs=OPUS,G722,PCMU,PCMA,H264,VP8/outbound_codec_prefs=PCMU,PCMA,OPUS,G722/g' /usr/local/freeswitch/conf/vars.xml

if [ "$CONTAINER_BUILD" = "1" ]; then
  echo "skipping systemd and cron setup in container build"
else
  sudo cp /tmp/freeswitch.service /etc/systemd/system
  sudo chmod 644 /etc/systemd/system/freeswitch.service
  sudo systemctl enable freeswitch
  sudo cp /tmp/freeswitch_log_rotation /etc/cron.daily/freeswitch_log_rotation
  sudo chown root:root /etc/cron.daily/freeswitch_log_rotation
  sudo chmod a+x /etc/cron.daily/freeswitch_log_rotation
fi

echo "downloading soniox root verification certificate"
sudo mkdir /usr/local/freeswitch/certs
cd /usr/local/freeswitch/certs
sudo wget https://raw.githubusercontent.com/grpc/grpc/master/etc/roots.pem

# download silero vad model
echo "downloading silero vad model"
cd /usr/local/src/freeswitch-modules/modules/mod_vad_silero
sudo chmod +x download_model.sh
sudo ./download_model.sh
