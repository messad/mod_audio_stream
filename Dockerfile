FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN
ENV DEBIAN_FRONTEND=noninteractive

# 1. Temel Bağımlılıklar
RUN apt-get update && apt-get install -y \
    build-essential cmake git autoconf automake libtool libtool-bin pkg-config \
    libssl-dev zlib1g-dev libjpeg-dev libsqlite3-dev libcurl4-openssl-dev \
    libpcre3-dev libspeexdsp-dev libspeex-dev libldns-dev libedit-dev yasm \
    libopus-dev libsndfile1-dev unzip libtiff-dev uuid-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src

# --------------------------------------------------------------------------
# ADIM 1: Sofia-SIP (Çekirdek Bağımlılığı - ŞART)
# --------------------------------------------------------------------------
RUN git clone https://github.com/freeswitch/sofia-sip.git && \
    cd sofia-sip && \
    ./bootstrap.sh && \
    ./configure --prefix=/usr && \
    make -j 1 && \
    make install && \
    cd .. && rm -rf sofia-sip

# --------------------------------------------------------------------------
# ADIM 2: Spandsp (Çekirdek Bağımlılığı - ŞART)
# DİKKAT: Core'un çalışması için libspandsp KÜTÜPHANESİ şarttır.
# Bunu kuruyoruz ki Core "header not found" demesin.
# Ancak aşağıda modülünü (mod_spandsp) kapatacağız ki "versiyon uyuşmazlığı" çıkmasın.
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
# ADIM 3: FreeSWITCH (Güvenli Derleme)
# --------------------------------------------------------------------------
RUN git clone https://github.com/signalwire/freeswitch.git freeswitch && \
    cd freeswitch && \
    git checkout v1.10.12 && \
    ./bootstrap.sh -j && \
    # ----------------------------------------------------------------------
    # MODULES.CONF TEMİZLİĞİ (Compiler'ın klasöre girmesini engeller)
    # Bu adım, "Import" hatalarını kökten çözer. Klasör derlenmezse, hata oluşmaz.
    # ----------------------------------------------------------------------
    # 1. Hatalı Modül: mod_spandsp (Lib var ama modülü kapatıyoruz)
    sed -i 's|^applications/mod_spandsp|#applications/mod_spandsp|g' modules.conf && \
    # 2. Gereksiz WebRTC ve Endpointler
    sed -i 's|^endpoints/mod_verto|#endpoints/mod_verto|g' modules.conf && \
    sed -i 's|^endpoints/mod_skinny|#endpoints/mod_skinny|g' modules.conf && \
    sed -i 's|^endpoints/mod_dingaling|#endpoints/mod_dingaling|g' modules.conf && \
    # 3. Ağır Uygulamalar (Video, Konferans, Voicemail)
    sed -i 's|^applications/mod_voicemail|#applications/mod_voicemail|g' modules.conf && \
    sed -i 's|^applications/mod_conference|#applications/mod_conference|g' modules.conf && \
    sed -i 's|^applications/mod_fsv|#applications/mod_fsv|g' modules.conf && \
    sed -i 's|^applications/mod_valet_parking|#applications/mod_valet_parking|g' modules.conf && \
    sed -i 's|^applications/mod_signalwire|#applications/mod_signalwire|g' modules.conf && \
    sed -i 's|^applications/mod_av|#applications/mod_av|g' modules.conf && \
    sed -i 's|^applications/mod_cv|#applications/mod_cv|g' modules.conf && \
    # 4. Veritabanı ve Cache (Dış bağımlılık isteyenler)
    sed -i 's|^applications/mod_mongo|#applications/mod_mongo|g' modules.conf && \
    sed -i 's|^applications/mod_redis|#applications/mod_redis|g' modules.conf && \
    sed -i 's|^databases/mod_pgsql|#databases/mod_pgsql|g' modules.conf && \
    sed -i 's|^databases/mod_mariadb|#databases/mod_mariadb|g' modules.conf && \
    # 5. Diller ve TTS
    sed -i 's|^languages/|#languages/|g' modules.conf && \
    sed -i 's|^asr_tts/|#asr_tts/|g' modules.conf && \
    # ----------------------------------------------------------------------
    # CONFIGURE AYARLARI (Core'un header çağırmasını engeller)
    # --without-pgsql: Core koduna "postgres.h include etme" der.
    # --without-odbc: Core koduna "sql.h include etme" der.
    # ----------------------------------------------------------------------
    ./configure --prefix=/usr --sysconfdir=/etc/freeswitch --localstatedir=/var \
    --disable-debug \
    --disable-libvpx --disable-libyuv --disable-zrtp \
    --without-pgsql --without-mysql --without-odbc \
    --disable-core-pgsql-support \
    --disable-core-odbc-support && \
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
