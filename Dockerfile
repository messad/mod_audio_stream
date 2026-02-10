# Dockerfile
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies (fixed package names)
RUN apt-get update && apt-get install -y \
    git curl wget gnupg2 ca-certificates \
    build-essential cmake autoconf automake libtool pkg-config \
    libssl-dev zlib1g-dev libdb-dev libncurses5-dev \
    libexpat1-dev libgdbm-dev bison libedit-dev \
    libpcre3-dev libspeexdsp-dev libldns-dev \
    libsqlite3-dev libcurl4-openssl-dev nasm \
    libogg-dev libvorbis-dev libopus-dev libsndfile1-dev \
    liblua5.2-dev libavformat-dev libswscale-dev \
    python3 python3-dev uuid-dev libspeex-dev \
    libshout3-dev libmpg123-dev libmp3lame-dev yasm \
    libsrtp2-dev libspandsp-dev libmemcached-dev \
    libpq-dev unixodbc-dev libmariadb-dev-compat \
    && rm -rf /var/lib/apt/lists/*

# Build FreeSWITCH
WORKDIR /usr/src
RUN git clone https://github.com/signalwire/freeswitch.git -b v1.10 && \
    cd freeswitch && \
    ./bootstrap.sh -j && \
    ./configure --disable-debug --disable-libyuv && \
    make -j$(nproc) && \
    make install && \
    make sounds-install moh-install && \
    ldconfig

# Build mod_audio_stream
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git && \
    cd mod_audio_stream && \
    export PKG_CONFIG_PATH=/usr/local/freeswitch/lib/pkgconfig && \
    make && \
    make install

# Enable module
RUN sed -i '/<load module="mod_console"\/>/a <load module="mod_audio_stream"\/>' \
    /usr/local/freeswitch/conf/autoload_configs/modules.conf.xml

EXPOSE 5060/tcp 5060/udp 16384-32768/udp

RUN echo '#!/bin/bash\nexec /usr/local/freeswitch/bin/freeswitch -nonat -nf' > /start.sh && \
    chmod +x /start.sh

CMD ["/start.sh"]
