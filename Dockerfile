# 1. Base Image: Debian 11 Bullseye (FreeSWITCH deposunda var)
FROM debian:bullseye-slim

# Etkileşimsiz kurulum
ENV DEBIAN_FRONTEND=noninteractive

# 2. FreeSWITCH ve Gerekli Araçları Kur (Resmi Depodan)
# Derleme yok, sadece kurulum.
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    libssl-dev \
    pkg-config \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-logfile \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/*

# 3. mod_audio_stream Modülünü İndir
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git

# 4. Modülü Derle (Sadece 500KB, RAM harcamaz)
WORKDIR /usr/src/mod_audio_stream
# Debian paketlerinde headerlar standart yoldadır
RUN make
RUN make install

# 5. Modülü Aktif Et
# Debian 11'de config yolu: /etc/freeswitch
RUN if [ -f /etc/freeswitch/autoload_configs/modules.conf.xml ]; then \
      sed -i '/<\/modules>/i <load module="mod_audio_stream"/>' /etc/freeswitch/autoload_configs/modules.conf.xml; \
    else \
      # Dosya yoksa bile kritik değil ama garanti olsun
      mkdir -p /etc/freeswitch/autoload_configs && \
      echo '<configuration name="modules.conf" description="Modules"><modules><load module="mod_audio_stream"/></modules></configuration>' > /etc/freeswitch/autoload_configs/modules.conf.xml; \
    fi

# 6. Ses/RTP Sorununu Çöz (IP Ayarı)
# Bu ayar olmadan ses tek taraflı gidebilir
RUN sed -i 's/$${local_ip_v4}/0.0.0.0/g' /etc/freeswitch/sip_profiles/internal.xml || true
RUN sed -i 's/$${local_ip_v4}/0.0.0.0/g' /etc/freeswitch/sip_profiles/external.xml || true

# 7. Başlatma
CMD ["/usr/bin/freeswitch", "-nc", "-nf"]
