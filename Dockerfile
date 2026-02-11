FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

# Temel paketler
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

# GPG key'i retry ile çek (401'i aşmak için 5 deneme – çalışan yöntem)
RUN for attempt in {1..5}; do \
        echo "GPG key deneme $$attempt / 5..." && \
        wget --http-user=signalwire --http-password="${SIGNALWIRE_TOKEN}" \
            --tries=1 --timeout=10 \
            -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
            https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg && \
        [ -s /usr/share/keyrings/signalwire-freeswitch-repo.gpg ] && echo "GPG key başarıyla indirildi!" && break || \
        (echo "Deneme $$attempt başarısız (401 olabilir), 5 sn bekleniyor..." && sleep 5); \
    done || (echo "GPG key indirilemedi – token'ı kontrol et veya SignalWire support'a yaz!" && exit 1)

# APT auth modern şekilde (auth.conf.d altına dosya)
RUN mkdir -p /etc/apt/auth.conf.d && \
    echo "machine freeswitch.signalwire.com login signalwire password ${SIGNALWIRE_TOKEN}" > /etc/apt/auth.conf.d/signalwire.conf && \
    chmod 600 /etc/apt/auth.conf.d/signalwire.conf

# Repo sources
RUN echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" > /etc/apt/sources.list.d/freeswitch.list

# Debug için apt update'ı ayrı tut + verbose
RUN apt-get update || (echo "apt-get update FAILED – log yukarıda, 401 varsa token/auth sorunu" && exit 1)

# Paketleri kur
RUN apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf.d/signalwire.conf

# mod_audio_stream derle (hafif, sorun olmaz)
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# Kullanıcı ve izinler
RUN groupadd -r freeswitch 2>/dev/null || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch 2>/dev/null || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/{lib,log,run,spool}/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch
EXPOSE 5060 5060/udp 5080 5080/udp 8021
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
