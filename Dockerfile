# Dockerfile
FROM debian:bookworm-slim

# SignalWire token'ı build arg olarak al (Coolify'de env var USER_TOKEN olarak geç)
ARG SIGNALWIRE_TOKEN

# Gerekli paketleri kur
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

# GPG key'i token ile indir
RUN wget --http-user=signalwire --http-password="${SIGNALWIRE_TOKEN}" \
    -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
    https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg

# APT auth.conf oluştur (apt update için token'ı kullan)
RUN echo "machine freeswitch.signalwire.com login signalwire password ${SIGNALWIRE_TOKEN}" > /etc/apt/auth.conf \
    && chmod 600 /etc/apt/auth.conf

# Sources list ekle
RUN echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" > /etc/apt/sources.list.d/freeswitch.list

# FreeSWITCH ve modülleri kur
RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf  # Güvenlik için token'ı sil

# mod_audio_stream'i clone edip derle (hafif, düşük latency için optimize)
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# FreeSWITCH kullanıcı ve izinleri ayarla
RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /usr/share/freeswitch /var/run/freeswitch /usr/lib/freeswitch/mod

# Düşük latency için RTP port range'i sınırlı tut (config'de ayarlanabilir)
# Config dosyalarını volume ile dışarı al, düşük latency için: rtp-timer-mult=1, rtp-autoflush=true gibi ayarlar ekle (autoload_configs/switch.conf.xml)

# Portlar
EXPOSE 5060 5060/udp 5080 5080/udp 8021 10000-20000/udp  # RTP için geniş range, ama düşük latency için host network kullan

# User ve entrypoint
USER freeswitch
WORKDIR /etc/freeswitch
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
