FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

ENV DEBIAN_FRONTEND=noninteractive
ENV PKG_CONFIG_PATH=/usr/lib/freeswitch/pkgconfig:/usr/local/freeswitch/lib/pkgconfig:$PKG_CONFIG_PATH

# Temel araçlar ve bağımlılıklar
RUN apt-get update && apt-get install -y \
    curl ca-certificates git build-essential cmake pkg-config \
    libssl-dev zlib1g-dev libevent-dev libspeexdsp-dev \
    && rm -rf /var/lib/apt/lists/*

# fsget ile SignalWire repo + FreeSWITCH paketleri kur
RUN curl -sSL https://freeswitch.org/fsget | bash -s "${SIGNALWIRE_TOKEN}" release install

# Dev paket yoksa fallback: FreeSWITCH source'dan header dosyalarını çek
RUN if ! apt-cache policy freeswitch-dev | grep -q Candidate; then \
        echo "Dev paketi repo'da yok, source'dan include'ları çekiyoruz..." && \
        git clone https://github.com/signalwire/freeswitch.git /tmp/freeswitch-source && \
        cd /tmp/freeswitch-source && \
        git checkout v1.10.12 && \
        git submodule update --init --recursive && \
        mkdir -p /usr/include/freeswitch && \
        # Header'ları bul ve kopyala (src/include, libs/include vs.)
        find . -type d -name include -exec cp -r {}/freeswitch/* /usr/include/freeswitch/ \; 2>/dev/null || true && \
        find . -type d -name include -exec cp -r {}/ * /usr/include/freeswitch/ \; 2>/dev/null || true && \
        find . -name '*.h' -exec cp {} /usr/include/freeswitch/ \; 2>/dev/null || true && \
        cd / && rm -rf /tmp/freeswitch-source || true; \
    fi

# mod_audio_stream derle (amigniter fork)
WORKDIR /usr/src
RUN git clone https://github.com/amigniter/mod_audio_stream.git && \
    cd mod_audio_stream && \
    git submodule init && git submodule update && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr \
          -DFREESWITCH_INCLUDE_DIR=/usr/include/freeswitch \
          -DCMAKE_C_FLAGS="-I/usr/include/freeswitch" \
          .. && \
    make && make install && \
    cd /usr/src && rm -rf mod_audio_stream

# mod_audio_stream'ı autoload et (modules.conf.xml'e ekle)
RUN sed -i '/mod_audio_stream/d' /etc/freeswitch/autoload_configs/modules.conf.xml 2>/dev/null || true && \
    echo '<load module="mod_audio_stream"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml

# Kullanıcı ve izinler
RUN groupadd -r freeswitch 2>/dev/null || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch 2>/dev/null || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /var/run/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch

EXPOSE 5060 5060/udp 5080 5080/udp 8021 16384-32768/udp

ENTRYPOINT ["/usr/bin/freeswitch"]
CMD ["-nc"]
