FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

# Gerekli araçlar (curl için fsget, diğerleri için)
RUN apt-get update && apt-get install -y \
    curl ca-certificates gnupg git build-essential \
    && rm -rf /var/lib/apt/lists/*

# fsget ile repo'yu ekle (token'ı geçir, release branch)
# Script auth.conf'u otomatik kurar, 401'leri handle eder
RUN curl -sSL https://freeswitch.org/fsget | bash -s "${SIGNALWIRE_TOKEN}" release || \
    (echo "fsget FAILED – token'ı kontrol et veya SignalWire support'a yaz" && exit 1)

# Repo hazır, update + install (meta-all yerine lightweight paketler)
RUN apt-get update || (echo "apt update FAILED after fsget – log yukarıda" && exit 1)

RUN apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/* /etc/apt/auth.conf /etc/apt/auth.conf.d/*  # token kalıntılarını sil

# mod_audio_stream derle
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# Kullanıcı/izinler
RUN groupadd -r freeswitch 2>/dev/null || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch 2>/dev/null || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/{lib,log,run,spool}/freeswitch /usr/share/freeswitch /usr/lib/freeswitch/mod

USER freeswitch
WORKDIR /etc/freeswitch
EXPOSE 5060 5060/udp 5080 5080/udp 8021
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
