# 1. Base Image: Standart Debian Bookworm
FROM debian:bookworm

# 2. FreeSWITCH'i Debian'ın Kendi Deposundan Kur
# SignalWire veya Safarov ile uğraşmıyoruz. Debian repository'si en temizidir.
RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-logfile \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    git \
    build-essential \
    cmake \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 3. mod_audio_stream'i İndir ve Derle
# Sadece bu küçük modülü derliyoruz (Saniyeler sürer, RAM yemez)
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git

WORKDIR /usr/src/mod_audio_stream
# Debian paketlerinde header dosyaları /usr/include/freeswitch altındadır
RUN make
# make install, dosyayı /usr/lib/freeswitch/mod/ altına atar
RUN make install

# 4. Modülü Otomatik Yükle
# Debian'da config dosyaları /etc/freeswitch altındadır
RUN echo '<load module="mod_audio_stream"/>' >> /etc/freeswitch/autoload_configs/modules.conf.xml

# 5. SIP Profilini Düzelt (Local IP sorununu çözer)
# Varsayılan ayarlarda bazen ses gitmez, bu komut onu düzeltir.
RUN sed -i 's/$${local_ip_v4}/0.0.0.0/g' /etc/freeswitch/sip_profiles/internal.xml || true
RUN sed -i 's/$${local_ip_v4}/0.0.0.0/g' /etc/freeswitch/sip_profiles/external.xml || true

# 6. Başlatma Komutu
# Debian paketleri /usr/bin/freeswitch kullanır
CMD ["/usr/bin/freeswitch", "-nc", "-nf"]
