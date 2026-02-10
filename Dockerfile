FROM debian:bookworm-slim

# SignalWire token'ı ARG olarak al (Coolify'de USER_TOKEN'dan geç)
ARG SIGNALWIRE_TOKEN

# Gerekli bağımlılıklar (fsget için curl, ve derleme için build-essential)
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    gnupg \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# fsget script'i ile repo'yu ekle (release branch, install yapma – biz manuel install edeceğiz)
RUN curl -sSL https://freeswitch.org/fsget | bash -s "${SIGNALWIRE_TOKEN}" release

# Repo hazır, şimdi update + spesifik paketleri kur (meta-all yerine lightweight: core + modüller + dev)
RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf  # token'ı sil güvenlik için

# mod_audio_stream'i clone + derle (hafif, OOM olmayacak)
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# FreeSWITCH kullanıcı/izinler (fsget genelde root kurar, biz düzeltelim)
RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /var/run/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

# Düşük latency için: RTP ayarlarını config'de tweak et (volume ile dışarı alacağız)

USER freeswitch
WORKDIR /etc/freeswitch
EXPOSE 5060 5060/udp 5080 5080/udp 8021
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
