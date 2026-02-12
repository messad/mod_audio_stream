FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN
ENV DEBIAN_FRONTEND=noninteractive

# 1. Temel Bağımlılıklar (Güncellenmiş Liste)
# - libtool-bin: Debian'da libtool binary'si için şart.
# - libspeex-dev: Derlemeyi durduran ana eksik.
# - uuid-dev: Loglardaki kritik uyarı için.
# - libopencore-amr*: Varsayılan ses kodeklerinin (mod_amr) patlamaması için.
RUN apt-get update && apt-get install -y \
    build-essential cmake git autoconf automake libtool libtool-bin pkg-config \
    libssl-dev zlib1g-dev libjpeg-dev libsqlite3-dev libcurl4-openssl-dev \
    libpcre3-dev libspeexdsp-dev libspeex-dev libldns-dev libedit-dev yasm \
    libopus-dev libsndfile1-dev unzip libtiff-dev uuid-dev \
    libopencore-amrnb-dev libopencore-amrwb-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# --------------------------------------------------------------------------
# ADIM 1: Sofia-SIP Derle (FreeSWITCH için özel sürüm)
# --------------------------------------------------------------------------
RUN git clone https://github.com/freeswitch/sofia-sip.git && \
    cd sofia-sip && \
    ./bootstrap.sh && \
    ./configure --prefix=/usr && \
    make -j 1 && \
    make install && \
    cd .. && rm -rf sofia-sip

# --------------------------------------------------------------------------
# ADIM 2: Spandsp Derle (FreeSWITCH 3.0 sürümünü ister)
# --------------------------------------------------------------------------
RUN git clone https://github.com/freeswitch/spandsp.git && \
    cd spandsp && \
    ./bootstrap.sh && \
    ./configure --prefix=/usr && \
    make -j 1 && \
    make install && \
    ldconfig && \
    cd .. && rm -rf spandsp

# --------------------------------------------------------------------------
# ADIM 3: FreeSWITCH Derle
# --------------------------------------------------------------------------
RUN git clone https://github.com/signalwire/freeswitch.git freeswitch && \
    cd freeswitch && \
    git checkout v1.10.12 && \
    ./bootstrap.sh -j && \
    # RAM Tasarrufu ve Hata Önleme:
    # 1. mod_av, mod_cv: Video işleme (çok RAM yer, kapattık).
    # 2. languages: Lua/Perl/Python (versiyon uyumsuzluğu çıkabilir, kapattık).
    sed -i 's|^applications/mod_av|#applications/mod_av|g' modules.conf && \
    sed -i 's|^applications/mod_cv|#applications/mod_cv|g' modules.conf && \
    sed -i 's|^languages/|#languages/|g' modules.conf && \
    # Configure:
    ./configure --prefix=/usr --sysconfdir=/etc/freeswitch --localstatedir=/var \
    --disable-debug \
    --disable-libvpx --disable-libyuv --disable-zrtp \
    --without-pgsql --without-mysql --without-odbc && \
    # Tek çekirdek derleme (RAM dostu, güvenli mod)
    make -j 1 && \
    make install && \
    ldconfig && \
    cd /usr/src && rm -rf freeswitch

# 4. mod_audio_stream Derle
WORKDIR /usr/src
RUN git clone https://github.com/amigniter/mod_audio_stream.git && \
    cd mod_audio_stream && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DFREESWITCH_INCLUDE_DIR=/usr/include/freeswitch \
          -DCMAKE_C_FLAGS="-I/usr/include/freeswitch" \
          .. && \
    make && make install && \
    cd /usr/src && rm -rf mod_audio_stream

# 5. Modül Aktivasyonu
RUN mkdir -p /etc/freeswitch/autoload_configs && \
    touch /etc/freeswitch/autoload_configs/modules.conf.xml && \
    if ! grep -q "mod_audio_stream" /etc/freeswitch/autoload_configs/modules.conf.xml; then \
        echo '<load module="mod_audio_stream"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml; \
    fi

# 6. Kullanıcı Ayarları
RUN groupadd -r freeswitch 2>/dev/null || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch 2>/dev/null || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /usr/share/freeswitch 2>/dev/null || true

USER freeswitch
WORKDIR /etc/freeswitch

EXPOSE 5060 5060/udp 5080 5080/udp 8021 16384-32768/udp

ENTRYPOINT ["/usr/bin/freeswitch"]
CMD ["-nc"]
