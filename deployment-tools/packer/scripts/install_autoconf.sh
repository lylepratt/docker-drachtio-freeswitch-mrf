#!/bin/bash
VARIANT=$1

# Function to compare versions
version_lt() {
    [ "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

# Check if autoconf is installed and get its version
if command -v autoconf &> /dev/null; then
    INSTALLED_VERSION=$(autoconf --version | head -n1 | awk '{print $NF}')
    REQUIRED_VERSION="2.71"
    echo "Installed Autoconf version: $INSTALLED_VERSION"

    # Compare the installed version with the required version
    if version_lt $INSTALLED_VERSION $REQUIRED_VERSION; then
        echo "Upgrading Autoconf to version $REQUIRED_VERSION..."

        # Download and extract Autoconf
        cd /tmp
        wget https://ftp.gnu.org/gnu/autoconf/autoconf-$REQUIRED_VERSION.tar.gz
        tar xvf autoconf-$REQUIRED_VERSION.tar.gz
        cd autoconf-$REQUIRED_VERSION

        # Compile and install
        ./configure
        make
        sudo make install

        # Clean up
        cd ..
        rm -rf autoconf-$REQUIRED_VERSION*
        echo "Autoconf has been upgraded to version $(autoconf --version | head -n1 | awk '{print $NF}')"
    else
        echo "Autoconf is already up to date."
    fi
else
    echo "Autoconf is not installed."
fi
