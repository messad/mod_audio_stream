FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

RUN apt-get update && apt-get install -y \
    wget gnupg ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

RUN wget --http-user=signalwire --http-password="${SIGNALWIRE_TOKEN}" \
    -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
    https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg

RUN echo "machine freeswitch.signalwire.com login signalwire password ${SIGNALWIRE_TOKEN}" > /etc/apt/auth.conf \
    && chmod 600 /etc/apt/auth.conf

RUN echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" > /etc/apt/sources.list.d/freeswitch.list

RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf

RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /var/run/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch

# EXPOSE sadece temel portları (range'i compose'a bırak)
EXPOSE 5060 5060/udp 5080 5080/udp 8021

ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
