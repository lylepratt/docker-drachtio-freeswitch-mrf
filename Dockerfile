ARG DISTRO_IMAGE=debian:12
FROM ${DISTRO_IMAGE} AS builder

# Copy the necessary Packer files and scripts.
COPY deployment-tools/packer/files/* /tmp/
COPY deployment-tools/packer/scripts/install_autoconf.sh /tmp/install_autoconf.sh
COPY deployment-tools/packer/scripts/install_cmake.sh /tmp/install_cmake.sh
COPY deployment-tools/packer/scripts/install_freeswitch.sh /tmp/install_freeswitch.sh

# Install FreeSWITCH.
RUN set -ex; \
    # Prepare the build environment.
    apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y automake \
                       build-essential \
                       ca-certificates \
                       curl \
                       git \
                       gnupg2 \
                       liba52-0.7.4-dev \
                       libapr1-dev \
                       libasound2-dev \
                       libavcodec-dev \
                       libavfilter-dev \
                       libavformat-dev \
                       libavutil-dev \
                       libcurl4-openssl-dev \
                       libedit-dev \
                       libev-dev \
                       libjpeg-dev \
                       libjson-glib-dev \
                       liblua5.1-0-dev \
                       libmp3lame-dev \
                       libmpg123-dev \
                       libogg-dev \
                       libopus-dev \
                       libopusfile-dev \
                       libpcre3-dev \
                       libpng-dev \
                       libpng16-16 \
                       libpq-dev \
                       libre2-dev \
                       libshout3-dev \
                       libsndfile-dev \
                       libspandsp-dev \
                       libspeex-dev \
                       libspeexdsp-dev \
                       libsqlite3-dev \
                       libssl-dev \
                       libswresample-dev \
                       libswscale-dev \
                       libtiff-dev \
                       libtiff6 \
                       libtool \
                       libtool-bin \
                       libxmlrpc-core-c3-dev \
                       libxtables-dev \
                       libz-dev \
                       make \
                       markdown \
                       php-dev \
                       pkg-config \
                       sudo \
                       uuid-dev \
                       wget \
                       yasm; \
    # Set the executable flag for Dave's install scripts.
    chmod +x /tmp/install_autoconf.sh; \
    chmod +x /tmp/install_cmake.sh; \
    chmod +x /tmp/install_freeswitch.sh; \
    # Build and install FreeSWITCH.
    bash /tmp/install_autoconf.sh fs; \
    bash /tmp/install_cmake.sh fs debian-12 arm64; \
    bash /tmp/install_freeswitch.sh fs debian-12 PCMU,PCMA,G722,OPUS media-gateway arm64; \
    # Re-build the /etc/ld.so.cache with all the new libraries included.
    ldconfig;

FROM ${DISTRO_IMAGE} AS final

COPY --from=builder /usr/local/freeswitch/ /usr/local/freeswitch/
COPY --from=builder /usr/local/bin/ /usr/local/bin/
COPY --from=builder /usr/local/lib/ /usr/local/lib/

# bring in arch‑specific libs
RUN apt-get update && apt-get install -y rsync \
 && if [ "$TARGETARCH" = "arm64" ]; then \
      rsync -a --ignore-existing /usr/lib/aarch64-linux-gnu/ /usr/lib/; \
    elif [ "$TARGETARCH" = "amd64" ]; then \
      rsync -a --ignore-existing /usr/lib/x86_64-linux-gnu/ /usr/lib/; \
    fi \
 && apt-get remove --purge -y rsync && apt-get autoremove -y && apt-get autoclean -y

# runtime libs + tools we actually need
RUN apt-get update; \
    apt-get upgrade -y; \
    apt-get install -y --quiet --no-install-recommends \
        awscli \
        ca-certificates \
        curl \
        init-system-helpers \
        inotify-tools \
        libcurl4 \
        libedit2 \
        libev4 \
        libopus0 \
        libpcre3 \
        libshout3 \
        libsndfile1 \
        libspeex1 \
        libspeexdsp1 \
        libsqlite3-0 \
        libtiff6 \
        rsyslog \
        s3fs; \
    ldconfig && rm -rf /var/lib/apt/lists/*;

COPY files/freeswitch.xml /usr/local/freeswitch/conf/freeswitch.xml
COPY files/vars_diff.xml /usr/local/freeswitch/conf/vars_diff.xml
COPY files/dialplan/* /usr/local/freeswitch/conf/dialplan/
COPY files/sip_profiles/* /usr/local/freeswitch/conf/sip_profiles/

# --- custom env + node toolchain ---
ENV COPY_POINT=/var/pres3fs
ENV NODE_VERSION=18
ENV NVM_DIR=/root/.nvm
ENV NODE_PATH=/root/.nvm/versions/node/v${NODE_VERSION}/lib/node_modules
ENV PATH="/usr/local/freeswitch/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/lib"

RUN mkdir -p "$COPY_POINT"

RUN bash -c "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash; \
 . \"$NVM_DIR/nvm.sh\"; \
 nvm install ${NODE_VERSION}; \
 nvm use ${NODE_VERSION}; \
 nvm alias default ${NODE_VERSION}; \
 node --version && npm --version; \
 npm install -g axios@^1.5.0";

 # custom monitoring script
COPY files/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY files/monitorPres3fs.sh /usr/local/bin/monitorPres3fs.sh
RUN chmod +x /usr/local/bin/monitorPres3fs.sh && chmod +x /usr/local/bin/entrypoint.sh

VOLUME ["/usr/local/freeswitch/log", "/usr/local/freeswitch/recordings", "/usr/local/freeswitch/sounds"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["freeswitch"]