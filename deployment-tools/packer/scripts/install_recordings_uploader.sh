#!/bin/bash
VARIANT=$1
DISTRO=$2
VERSION=1.7.0

echo "VARIANT is $VARIANT"
echo "DISTRO is $DISTRO"

case "$VARIANT" in
  mini|web|web-monitoring|recording)
    ;;
  *)
    echo "skipping upload_recordings"
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

AWS_SDK_VERSION=1.11.500

export PATH=/usr/local/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib64:$LD_LIBRARY_PATH

sudo chmod 0777 /usr/local/src
cd /usr/local/src

if [[ "$DISTRO" == "debian-12" ]]; then
  sudo apt-get update
  sudo apt install -y libcjson-dev libmp3lame-dev libmysqlcppconn-dev libspdlog-dev \
  libfmt-dev libssl-dev libgoogle-perftools-dev 
elif [[ "$DISTRO" == rhel* ]]; then
  # For RHEL-based systems
  cd /tmp
  wget https://repo.mysql.com/mysql80-community-release-el9.rpm
  sudo rpm -ivh mysql80-community-release-el9.rpm
  dnf update -y
  dnf install -y cjson-devel lame-devel mysql-connector-c++-devel openssl-devel gperftools-devel
  rm mysql80-community-release-el9.rpm

  # Build fmt from source if not already built
  cd /usr/local/src
  if [ ! -d "fmt" ]; then
    git clone https://github.com/fmtlib/fmt.git
  fi
  cd fmt
  if [ ! -d "build" ]; then
    mkdir build
  fi
  cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release -DFMT_TEST=OFF
  make -j8 && make install && ldconfig

  # Build spdlog from source if not already built
  cd /usr/local/src
  if [ ! -d "spdlog" ]; then
    git clone https://github.com/gabime/spdlog.git
  fi
  cd spdlog
  if [ ! -d "build" ]; then
    mkdir build
  fi
  cd build
  cmake .. -DSPDLOG_BUILD_EXAMPLES=OFF -DSPDLOG_BUILD_TESTS=OFF -DSPDLOG_FMT_EXTERNAL=ON
  make -j8 && make install && ldconfig

  # Fix mysql-connector-c++ header files
  mkdir -p /usr/include/cppconn
  # Create symbolic links for all the header files
  for file in /usr/include/mysql-cppconn/jdbc/cppconn/*.h; do
      filename=$(basename "$file")
      if [ ! -f "/usr/include/cppconn/$filename" ]; then
          ln -s "$file" "/usr/include/cppconn/$filename"
      fi
  done

  # Create necessary links for spdlog and fmt
  mkdir -p /usr/local/include/spdlog/fmt/bundled
  ln -s /usr/local/include/fmt/core.h /usr/local/include/spdlog/fmt/bundled/core.h
  ln -s /usr/local/include/fmt/format.h /usr/local/include/spdlog/fmt/bundled/format.h
  ln -s /usr/local/include/fmt/format-inl.h /usr/local/include/spdlog/fmt/bundled/format-inl.h

  ln -s /usr/local/include/fmt/base.h /usr/local/include/spdlog/fmt/bundled/base.h
  ln -s /usr/local/include/fmt/ranges.h /usr/local/include/spdlog/fmt/bundled/ranges.h
  ln -s /usr/local/include/fmt/os.h /usr/local/include/spdlog/fmt/bundled/os.h
  
  # Make sure pkg-config can find libwebsockets
  export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
fi

cd /usr/local/src

# Check if the libwebsockets directory does not exist
cd /usr/local/src
if [ ! -d "libwebsockets" ]; then
    echo building lws
    git clone https://github.com/warmcat/libwebsockets.git -b v4.3.3
    cd libwebsockets
    # patch this until fixed - 
    cd lib/roles/ws
    echo "patching ops-ws.c to fix bug impacting bidirectional streaming"
    cp /tmp/ops-ws.c.patch .
    patch ops-ws.c < ops-ws.c.patch
    cd -
    mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=RelWithDebInfo -DLWS_WITH_NETLINK=OFF -DLWS_WITH_LIBEV=1 && make -j8 && sudo make install
fi

cd /usr/local/src
if [ ! -d "aws-sdk-cpp" ]; then
  git clone https://github.com/aws/aws-sdk-cpp -b ${AWS_SDK_VERSION}
  cd aws-sdk-cpp
  git submodule update --init --recursive
  mkdir -p build && cd build
  cmake .. -DBUILD_ONLY="s3;core;s3-crt;lexv2-runtime;transcribestreaming;monitoring;polly" -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_SHARED_LIBS=ON -DCMAKE_CXX_FLAGS="-Wno-unused-parameter -Wno-error=nonnull -Wno-error=deprecated-declarations -Wno-error=uninitialized -Wno-error=maybe-uninitialized -Wno-error=array-bounds"
  make -j8
  sudo make install
  find /usr/local/src/aws-sdk-cpp/ -type f -name "*.pc" | sudo xargs cp -t /usr/local/lib/pkgconfig/
fi

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH

cd /usr/local/src
git clone https://github.com/jambonz/upload-recordings.git -b ${VERSION}
cd upload-recordings
git log --oneline --decorate
autoreconf -fi
mkdir build && cd $_
../configure  --enable-tcmalloc=yes CXXFLAGS='-g -O2'
make -j${nproc}
sudo make install

sudo mv /tmp/upload_recordings.service /etc/systemd/system/upload_recordings.service
sudo chmod 644 /etc/systemd/system/upload_recordings.service
