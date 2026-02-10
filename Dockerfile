# 1. Base Image: Debian Bookworm (Standart Linux)
FROM debian:bookworm

# Etkileşimsiz mod
ENV DEBIAN_FRONTEND=noninteractive

# 2. Bağımlılıkları Kur (Build Tools)
RUN apt-get update && apt-get install -y \
    git curl wget gnupg2 build-essential cmake autoconf automake \
    libtool pkg-config libssl-dev zlib1g-dev libdb-dev \
    libncurses5-dev libexpat1-dev libgdbm-dev bison \
    libedit-dev libpcre3-dev libspeexdsp-dev libldns-dev \
    libsqlite3-dev libcurl4-openssl-dev nasm libogg-dev \
    libvorbis-dev libopus-dev libsndfile1-dev liblua5.2-dev \
    libavformat-dev libswscale-dev libavresample-dev \
    python3 python3-dev uuid-dev libspeex-dev \
    libsndfile1-dev libshout3-dev libmpg123-dev \
    libmp3lame-dev yasm libsrtp2-dev libspandsp-dev \
    libmemcached-dev libpq-dev unixodbc-dev libmariadb-dev \
    && rm -rf /var/lib/apt/lists/*

# 3. FreeSWITCH Kaynağını Çek ve Derle (CRASH-PROOF MODE)
WORKDIR /usr/src
# Depoyu sığ (shallow) çekiyoruz, indirirken vakit kaybetmeyelim
RUN git clone --depth 1 -b v1.10 https://github.com/signalwire/freeswitch.git && \
    cd freeswitch && \
    ./bootstrap.sh -j && \
    # Gereksiz video modüllerini kapatıp derlemeyi hafifletiyoruz
    ./configure --disable-debug --disable-libyuv --enable-core-pgsql-support && \
    # DİKKAT: -j2 komutu RAM kullanımını sınırlar. Yavaş ama güvenli.
    make -j2 && \
    make install && \
    make sounds-install moh-install && \
    ldconfig

# 4. mod_audio_stream (Pipecat Köprüsü) Kurulumu
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git && \
    cd mod_audio_stream && \
    export PKG_CONFIG_PATH=/usr/local/freeswitch/lib/pkgconfig:$PKG_CONFIG_PATH && \
    make && \
    make install

# 5. Modülü Aktif Et
RUN echo '<load module="mod_audio_stream"/>' >> /usr/local/freeswitch/conf/autoload_configs/modules.conf.xml

# 6. Sembolik Linkler (Kolaylık olsun)
RUN ln -s /usr/local/freeswitch/bin/freeswitch /usr/bin/freeswitch && \
    ln -s /usr/local/freeswitch/bin/fs_cli /usr/bin/fs_cli

# 7. Başlatma Scripti
RUN echo '#!/bin/bash\n\
ulimit -c unlimited\n\
ulimit -n 100000\n\
# FreeSWITCH başlat
exec /usr/local/freeswitch/bin/freeswitch -nonat -nf -nc' > /start.sh && \
chmod +x /start.sh

CMD ["/start.sh"]
