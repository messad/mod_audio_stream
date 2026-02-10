FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

# Gerekli paketler
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

# GPG key indirme - ilk deneme 401 verebiliyor, retry ekliyoruz
RUN for i in 1 2 3; do \
        echo "Deneme $$i: wget ile GPG key çekiliyor..." && \
        wget --http-user=signalwire --http-password="${SIGNALWIRE_TOKEN}" \
            -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
            https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg && \
        break || echo "Deneme $$i başarısız (muhtemelen 401), tekrar deneniyor..." && sleep 2; \
    done || (echo "Tüm denemeler başarısız - Token'ı kontrol et!" && exit 1)

# Auth conf (apt için)
RUN echo "machine freeswitch.signalwire.com login signalwire password ${SIGNALWIRE_TOKEN}" > /etc/apt/auth.conf \
    && chmod 600 /etc/apt/auth.conf

# Sources
RUN echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" > /etc/apt/sources.list.d/freeswitch.list

# Install
RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf

# mod_audio_stream
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# İzinler
RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /var/run/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch
EXPOSE 5060 5060/udp 5080 5080/udp 8021
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
