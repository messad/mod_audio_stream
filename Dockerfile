FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    gnupg2 wget ca-certificates lsb-release \
    build-essential git pkg-config libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/*

# Debian main + contrib repo (FreeSWITCH paketleri contrib'ta)
RUN echo "deb http://deb.debian.org/debian bullseye main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list && \
    echo "deb http://security.debian.org/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list

RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    && rm -rf /var/lib/apt/lists/*

# mod_audio_stream (orijinal repo, henrik-me'nin fork'u stabil)
WORKDIR /usr/src
RUN git clone https://github.com/henrik-me/mod_audio_stream.git && \
    cd mod_audio_stream && \
    make && \
    make install && \
    rm -rf /usr/src/mod_audio_stream

# mod_audio_stream'ı autoload et (eğer modules.conf.xml'de yoksa)
RUN echo 'loadmodule mod_audio_stream' >> /etc/freeswitch/autoload_configs/modules.conf.xml || true

# Kullanıcı ve izinler
RUN groupadd -r freeswitch && \
    useradd -r -g freeswitch -d /etc/freeswitch freeswitch && \
    chown -R freeswitch:freeswitch /etc/freeswitch /var/{lib,log,run,spool}/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch

EXPOSE 5060 5060/udp 5080 5080/udp 8021 16384-32768/udp

ENTRYPOINT ["/usr/bin/freeswitch"]
CMD ["-nc"]
