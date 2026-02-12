FROM debian:bookworm-slim

ARG SIGNALWIRE_TOKEN

ENV DEBIAN_FRONTEND=noninteractive

# 1. Temel araçları kur
RUN apt-get update && apt-get install -y \
    curl ca-certificates git build-essential cmake pkg-config \
    libssl-dev zlib1g-dev libevent-dev libspeexdsp-dev \
    gnupg2 lsb-release \
    && rm -rf /var/lib/apt/lists/*

# 2. SignalWire Reposunu Tanıt (fsget ile)
# Not: 'install' parametresini kaldırdık, kontrolü ele alıyoruz.
RUN curl -sSL https://freeswitch.org/fsget | bash -s "${SIGNALWIRE_TOKEN}" release

# 3. FreeSWITCH Geliştirme Paketlerini Kur (Kritik Adım)
# Eğer bu adım hata verirse token yanlıştır veya repo erişimi yoktur.
# Bu adım 'libfreeswitch.so' dosyasının gelmesini GARANTİ eder.
RUN apt-get update && apt-get install -y \
    freeswitch-dev \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/*

# 4. mod_audio_stream Derle
WORKDIR /usr/src
RUN git clone https://github.com/amigniter/mod_audio_stream.git && \
    cd mod_audio_stream && \
    mkdir build && cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_INSTALL_PREFIX=/usr \
          # Header dosyaları standart yolda olacaktır
          -DFREESWITCH_INCLUDE_DIR=/usr/include/freeswitch \
          # Kütüphane yolunu (-L) vermiyoruz, apt ile kurulan paketleri
          # linker (/usr/lib/x86_64-linux-gnu altında) otomatik bulur.
          -DCMAKE_EXE_LINKER_FLAGS="-lfreeswitch" \
          .. && \
    make && make install && \
    cd /usr/src && rm -rf mod_audio_stream

# 5. Modülü Aktif Et
RUN sed -i '/mod_audio_stream/d' /etc/freeswitch/autoload_configs/modules.conf.xml 2>/dev/null || true && \
    # Dosya yoksa oluştur, varsa ekle mantığı
    mkdir -p /etc/freeswitch/autoload_configs && \
    touch /etc/freeswitch/autoload_configs/modules.conf.xml && \
    echo '<load module="mod_audio_stream"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml

# 6. Kullanıcı ve İzinler
RUN groupadd -r freeswitch 2>/dev/null || true \
    && useradd -r -g freeswitch -d /etc/freeswitch -s /bin/false freeswitch 2>/dev/null || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch /var/lib/freeswitch /var/log/freeswitch /usr/share/freeswitch 2>/dev/null || true

USER freeswitch
WORKDIR /etc/freeswitch

EXPOSE 5060 5060/udp 5080 5080/udp 8021 16384-32768/udp

ENTRYPOINT ["/usr/bin/freeswitch"]
CMD ["-nc"]
