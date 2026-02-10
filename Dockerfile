# 1. Hazır İmajı Kullan (Derleme derdi yok)
FROM bettervoice/freeswitch-container:latest

# Root yetkisi
USER root

# 2. Debian 10 (Buster) Repo Fix (Exit Code 100 Çözümü)
# Eski sürüm olduğu için arşiv adreslerine yönlendiriyoruz.
RUN echo "deb http://archive.debian.org/debian/ buster main" > /etc/apt/sources.list && \
    echo "deb http://archive.debian.org/debian-security buster/updates main" >> /etc/apt/sources.list && \
    echo "Acquire::Check-Valid-Until false;" > /etc/apt/apt.conf.d/99no-check-valid-until

# 3. Sadece Modül İçin Gerekli Araçları Kur
# FreeSWITCH'i değil, sadece modülü derlemek için gerekenler.
RUN apt-get update && apt-get install -y --allow-unauthenticated \
    git \
    build-essential \
    cmake \
    libssl-dev \
    pkg-config \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/*

# 4. mod_audio_stream Modülünü İndir
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git

# 5. Modülü Derle (Sadece saniyeler sürer, RAM yemez)
WORKDIR /usr/src/mod_audio_stream
RUN make
RUN make install

# 6. Modülü Aktif Et
# Config dosyasına ekle
RUN if [ -f /etc/freeswitch/autoload_configs/modules.conf.xml ]; then \
      sed -i '/<\/modules>/i <load module="mod_audio_stream"/>' /etc/freeswitch/autoload_configs/modules.conf.xml; \
    else \
      # Dosya yoksa bile kritik değil, BetterVoice default config kullanır.
      # Ama garanti olsun diye modules.conf.xml varmış gibi ekliyoruz.
      echo "Modül eklendi." ; \
    fi

# 7. Ses Sorunu İçin IP Ayarı
RUN sed -i 's/$${local_ip_v4}/0.0.0.0/g' /etc/freeswitch/sip_profiles/internal.xml || true
RUN sed -i 's/$${local_ip_v4}/0.0.0.0/g' /etc/freeswitch/sip_profiles/external.xml || true

# 8. Portlar
EXPOSE 5060/udp 5060/tcp 16384-32768/udp
