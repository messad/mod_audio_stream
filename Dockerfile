FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN
ENV DEBIAN_FRONTEND=noninteractive

# 1. Bağımlılıklar (Build + Runtime)
# DÜZELTME: 'libtool-bin' eklendi. Debian'da binary dosyası bu pakettedir.
RUN apt-get update && apt-get install -y \
    build-essential cmake git autoconf automake libtool libtool-bin pkg-config \
    libssl-dev zlib1g-dev libjpeg-dev libsqlite3-dev libcurl4-openssl-dev \
    libpcre3-dev libspeexdsp-dev libldns-dev libedit-dev yasm \
    libopus-dev libsndfile1-dev unzip \
    && rm -rf /var/lib/apt/lists/*

# 2. FreeSWITCH Kaynak Kodunu Çek
WORKDIR /usr/src
RUN git clone https://github.com/signalwire/freeswitch.git freeswitch && \
    cd freeswitch && \
    git checkout v1.10.12 && \
    # Bootstrap (libtool-bin kurulduğu için artık hata vermeyecek)
    ./bootstrap.sh -j && \
    # RAM TASARRUFU ADIM 1: Ağır modülleri kapat
    sed -i 's|^applications/mod_av|#applications/mod_av|g' modules.conf && \
    sed -i 's|^applications/mod_cv|#applications/mod_cv|g' modules.conf && \
    sed -i 's|^languages/|#languages/|g' modules.conf && \
    # Configure: Standart yollar + Gereksizleri kapat
    ./configure --prefix=/usr --sysconfdir=/etc/freeswitch --localstatedir=/var \
    --disable-debug \
    --disable-libvpx --disable-libyuv --disable-zrtp \
    --without-pgsql --without-mysql --without-odbc && \
    # RAM TASARRUFU ADIM 2: Tek Çekirdek (Single Core)
    make -j 1 && \
    make install && \
    ldconfig && \
    cd /usr/src && rm -rf freeswitch

# 3. mod_audio_stream Derleme
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

# 4. Modülü Aktif Et
RUN mkdir -p /etc/freeswitch/autoload_configs && \
    touch /etc/freeswitch/autoload_configs/modules.conf.xml && \
    if ! grep -q "mod_audio_stream" /etc/freeswitch/autoload_configs/modules.conf.xml; then \
        echo '<load module="mod_audio_stream"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml; \
    fi

# 5. Kullanıcı ve İzinler
RUN groupadd -r freeswitch 2>/dev/null || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch 2>/dev/null || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /usr/share/freeswitch 2>/dev/null || true

USER freeswitch
WORKDIR /etc/freeswitch

EXPOSE 5060 5060/udp 5080 5080/udp 8021 16384-32768/udp

ENTRYPOINT ["/usr/bin/freeswitch"]
CMD ["-nc"]
