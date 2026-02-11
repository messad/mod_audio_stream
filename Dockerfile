FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

ENV DEBIAN_FRONTEND=noninteractive

# Temel araçlar
RUN apt-get update && apt-get install -y \
    curl ca-certificates git build-essential cmake pkg-config \
    && rm -rf /var/lib/apt/lists/*

# fsget ile repo + FreeSWITCH kur
RUN curl -sSL https://freeswitch.org/fsget | bash -s "${SIGNALWIRE_TOKEN}" release install

# ... fsget sonrası ...

# Dev paketi yoksa fallback: FreeSWITCH source'dan include'ları çek (hafif)
RUN if ! apt-get install -y freeswitch-dev libfreeswitch-dev 2>/dev/null; then \
      git clone --depth=1 --branch v1.10 https://github.com/signalwire/freeswitch.git /tmp/freeswitch-source && \
      mkdir -p /usr/include/freeswitch && \
      cp -r /tmp/freeswitch-source/include/* /usr/include/freeswitch/ && \
      rm -rf /tmp/freeswitch-source; \
    fi

# mod_audio_stream derle (header'lar şimdi var)
RUN git clone https://github.com/amigniter/mod_audio_stream.git /usr/src/mod_audio_stream && \
    cd /usr/src/mod_audio_stream && \
    git submodule init && git submodule update && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DFREESWITCH_INCLUDE_DIR=/usr/include/freeswitch .. && \
    make && make install && \
    rm -rf /usr/src/mod_audio_stream

# mod_audio_stream'ı autoload et
RUN sed -i '/mod_audio_stream/d' /etc/freeswitch/autoload_configs/modules.conf.xml 2>/dev/null || true && \
    echo '<load module="mod_audio_stream"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml

# İzinler
RUN groupadd -r freeswitch 2>/dev/null || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch 2>/dev/null || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/{lib,log,run,spool}/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch

EXPOSE 5060 5060/udp 5080 5080/udp 8021 16384-32768/udp

ENTRYPOINT ["/usr/bin/freeswitch"]
CMD ["-nc"]
