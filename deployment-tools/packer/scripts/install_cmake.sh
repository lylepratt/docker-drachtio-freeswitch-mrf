#!/bin/bash
VARIANT=$1
DISTRO=$2
ARCH=$3

# Define the required version
CMAKE_VERSION=3.28.3

# Function to compare versions
version_ge() {
  # Returns 0 (true) if the first version is greater than or equal to the second
  [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

# Check if cmake is installed and meets the required version
if command -v cmake &> /dev/null; then
  INSTALLED_VERSION=$(cmake --version | head -n 1 | awk '{print $3}')
  if version_ge "$INSTALLED_VERSION" "$CMAKE_VERSION"; then
    echo "CMake version $INSTALLED_VERSION is already installed and meets the required version ($CMAKE_VERSION). Skipping installation."
    exit 0
  fi
fi

if [[ "$DISTRO" == rhel* ]]; then
  if [ "$EUID" -ne 0 ]; then
    echo "Switching to root user..."
    sudo -E bash "$0" "$@"
    exit
  fi  
fi

# Determine the download URL and file name based on architecture
if [[ "$ARCH" == "amd64" ]]; then
  CMAKE_FILE="cmake-${CMAKE_VERSION}-linux-x86_64.sh"
  CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_FILE}"
elif [[ "$ARCH" == "arm64" ]]; then
  CMAKE_FILE="cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz"
  CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_FILE}"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# Download the CMake installer
wget "$CMAKE_URL" -O "$CMAKE_FILE"

# Install based on file type
if [[ "$CMAKE_FILE" == *.sh ]]; then
  # Add execute permissions and run the .sh installer
  chmod +x "$CMAKE_FILE"
  sudo ./"$CMAKE_FILE" --skip-license --prefix=/usr/local
elif [[ "$CMAKE_FILE" == *.tar.gz ]]; then
  # Extract the .tar.gz archive for arm64
  sudo tar -xzf "$CMAKE_FILE" -C /usr/local --strip-components=1
fi

# Clean up the downloaded file
rm "$CMAKE_FILE"

# Verify the installation
export PATH=/usr/local/bin:$PATH
cmake --version