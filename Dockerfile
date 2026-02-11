FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

# Gerekli paketler
RUN apt-get update && apt-get install -y \
    curl ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

# fsget ile repo kur (dokümanlara göre önerilen, auth'u otomatik yönetir)
RUN curl -sSL https://freeswitch.org/fsget | bash -s "${SIGNALWIRE_TOKEN}" release install

# mod_audio_stream derle
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# Kullanıcı/izinler
RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /var/run/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch
EXPOSE 5060 5060/udp 5080 5080/udp 8021
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
