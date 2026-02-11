FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

ENV DEBIAN_FRONTEND=noninteractive

# Gerekli paketler + mod_audio_stream bağımlılıkları
RUN apt-get update && apt-get install -y \
    curl ca-certificates git build-essential \
    pkg-config libfreeswitch-dev libssl-dev zlib1g-dev libevent-dev libspeexdsp-dev \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# fsget ile FreeSWITCH repo ve paketleri kur (önceki adımın çalıştığı kısım)
RUN curl -sSL https://freeswitch.org/fsget | bash -s "${SIGNALWIRE_TOKEN}" release install

# mod_audio_stream (amigniter fork - daha güncel)
WORKDIR /usr/src
RUN git clone https://github.com/amigniter/mod_audio_stream.git && \
    cd mod_audio_stream && \
    git submodule init && \
    git submodule update && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release .. && \
    make && \
    make install && \
    cd /usr/src && rm -rf mod_audio_stream

# mod_audio_stream'ı autoload et (eğer modules.conf.xml otomatik yüklemiyorsa)
RUN sed -i '/<load module="mod_audio_stream"/d' /etc/freeswitch/autoload_configs/modules.conf.xml || true && \
    echo '<load module="mod_audio_stream"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml

# Kullanıcı ve izinler
RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/{lib,log,run,spool}/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch

EXPOSE 5060 5060/udp 5080 5080/udp 8021 16384-32768/udp

ENTRYPOINT ["/usr/bin/freeswitch"]
CMD ["-nc"]
