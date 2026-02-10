FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

# Gerekli paketler (apt-transport-https vs. için ca-certificates zaten var)
RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

# GPG key'i retry ile çek (önceki sorun için)
RUN for i in 1 2 3; do \
        wget --http-user=signalwire --http-password="${SIGNALWIRE_TOKEN}" \
            -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
            https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg && break || \
        (echo "Deneme $$i failed, retrying..." && sleep 2); \
    done || (echo "GPG download failed after retries" && exit 1)

# APT auth conf'u MODERN YÖNTEMLE oluştur (/etc/apt/auth.conf.d/ altında)
RUN mkdir -p /etc/apt/auth.conf.d/ && \
    echo "machine freeswitch.signalwire.com login signalwire password ${SIGNALWIRE_TOKEN}" > /etc/apt/auth.conf.d/signalwire.conf && \
    chmod 600 /etc/apt/auth.conf.d/signalwire.conf

# Sources list (signed-by ile)
RUN echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" > /etc/apt/sources.list.d/freeswitch.list

# Update + install (burada auth.conf.d sayesinde token gitmeli)
RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf.d/signalwire.conf  # token'ı sil (güvenlik)

# mod_audio_stream derle
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# Kullanıcı/izinler
RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /var/run/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch
EXPOSE 5060 5060/udp 5080 5080/udp 8021
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
