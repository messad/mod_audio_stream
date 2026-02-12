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

# ADIM 1: Sofia-SIP (DOKUNULMADI)
RUN git clone https://github.com/freeswitch/sofia-sip.git && \
    cd sofia-sip && \
    ./bootstrap.sh && \
    ./configure --prefix=/usr && \
    make -j 1 && \
    make install && \
    cd .. && rm -rf sofia-sip

# ADIM 2: Spandsp (DOKUNULMADI)
RUN git clone https://github.com/freeswitch/spandsp.git && \
    cd spandsp && \
    ./bootstrap.sh && \
    ./configure --prefix=/usr && \
    make -j 1 && \
    make install && \
    ldconfig && \
    cd .. && rm -rf spandsp

# ADIM 3: FreeSWITCH (DOKUNULMADI)
RUN git clone https://github.com/signalwire/freeswitch.git freeswitch && \
    cd freeswitch && \
    git checkout v1.10.12 && \
    ./bootstrap.sh -j && \
    sed -i 's|^applications/mod_spandsp|#applications/mod_spandsp|g' modules.conf && \
    sed -i 's|^endpoints/mod_verto|#endpoints/mod_verto|g' modules.conf && \
    sed -i 's|^endpoints/mod_skinny|#endpoints/mod_skinny|g' modules.conf && \
    sed -i 's|^endpoints/mod_dingaling|#endpoints/mod_dingaling|g' modules.conf && \
    sed -i 's|^applications/mod_voicemail|#applications/mod_voicemail|g' modules.conf && \
    sed -i 's|^applications/mod_conference|#applications/mod_conference|g' modules.conf && \
    sed -i 's|^applications/mod_fsv|#applications/mod_fsv|g' modules.conf && \
    sed -i 's|^applications/mod_valet_parking|#applications/mod_valet_parking|g' modules.conf && \
    sed -i 's|^applications/mod_signalwire|#applications/mod_signalwire|g' modules.conf && \
    sed -i 's|^applications/mod_av|#applications/mod_av|g' modules.conf && \
    sed -i 's|^applications/mod_cv|#applications/mod_cv|g' modules.conf && \
    sed -i 's|^applications/mod_mongo|#applications/mod_mongo|g' modules.conf && \
    sed -i 's|^applications/mod_redis|#applications/mod_redis|g' modules.conf && \
    sed -i 's|^databases/mod_pgsql|#databases/mod_pgsql|g' modules.conf && \
    sed -i 's|^databases/mod_mariadb|#databases/mod_mariadb|g' modules.conf && \
    sed -i 's|^languages/|#languages/|g' modules.conf && \
    sed -i 's|^asr_tts/|#asr_tts/|g' modules.conf && \
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

# --------------------------------------------------------------------------
# ADIM 4: mod_audio_stream (SYMLINK + BYPASS)
# --------------------------------------------------------------------------
WORKDIR /usr/src
RUN git clone --recursive https://github.com/amigniter/mod_audio_stream.git && \
    cd mod_audio_stream && \
    git submodule update --init --recursive && \
    # --- FIX 1: FİZİKSEL KÖPRÜ (SYMLINK) ---
    # CMake'in include path'leri bulamamasını umursamıyoruz.
    # Dosyaları derleyicinin zaten baktığı yere (/usr/include) bağlıyoruz.
    # Eğer /usr/include/event2 zaten varsa silelim, temiz olsun.
    rm -rf /usr/include/event2 && \
    ln -s /usr/include/x86_64-linux-gnu/event2 /usr/include/event2 && \
    # ---------------------------------------
    # --- FIX 2: FindLibevent.cmake Bypass (Configure Hatası İçin) ---
    rm libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_FOUND TRUE CACHE BOOL "Force found" FORCE)' > libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(Libevent_FOUND TRUE CACHE BOOL "Force found" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_VERSION "2.1.12" CACHE STRING "Force version" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    # Include dir olarak standart yolu gösteriyoruz, çünkü symlink yaptık!
    echo 'set(LIBEVENT_INCLUDE_DIR "/usr/include" CACHE PATH "Force include" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_INCLUDE_DIRS "/usr/include" CACHE PATH "Force include dirs" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    # Libraries
    echo 'set(LIBEVENT_CORE_FOUND TRUE CACHE BOOL "Force core" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_CORE_LIBRARY "/usr/lib/x86_64-linux-gnu/libevent_core.so" CACHE FILEPATH "Force core lib" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_PTHREADS_FOUND TRUE CACHE BOOL "Force pthreads" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_PTHREADS_LIBRARY "/usr/lib/x86_64-linux-gnu/libevent_pthreads.so" CACHE FILEPATH "Force pthreads lib" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_OPENSSL_FOUND TRUE CACHE BOOL "Force openssl" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_OPENSSL_LIBRARY "/usr/lib/x86_64-linux-gnu/libevent_openssl.so" CACHE FILEPATH "Force openssl lib" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_EXTRA_FOUND TRUE CACHE BOOL "Force extra" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_EXTRA_LIBRARY "/usr/lib/x86_64-linux-gnu/libevent_extra.so" CACHE FILEPATH "Force extra lib" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    echo 'set(LIBEVENT_LIBRARIES "/usr/lib/x86_64-linux-gnu/libevent.so" ${LIBEVENT_CORE_LIBRARY} ${LIBEVENT_PTHREADS_LIBRARY} ${LIBEVENT_OPENSSL_LIBRARY} ${LIBEVENT_EXTRA_LIBRARY} CACHE FILEPATH "Force libs" FORCE)' >> libs/libwsc/CMake/FindLibevent.cmake && \
    # ----------------------------------------------------
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DFREESWITCH_INCLUDE_DIR=/usr/include/freeswitch \
          .. && \
    make VERBOSE=1 && \
    make install && \
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
