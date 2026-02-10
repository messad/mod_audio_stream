# 1. Base Image: Topluluk dostu Safarov
FROM safarov/freeswitch:latest

# Root yetkisiyle işlem yap (Paket kurulumu için şart)
USER root

# 2. Derleme Araçlarını Kur
# mod_audio_stream'i derlemek için bu paketler şart.
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libssl-dev \
    zlib1g-dev \
    pkg-config \
    libjpeg-dev \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libpcre3-dev \
    libspeexdsp-dev \
    libldns-dev \
    libedit-dev \
    libopus-dev \
    libsndfile1-dev \
    libtiff-dev \
    # FreeSWITCH geliştirme dosyalarını bulmaya çalışalım
    # Eğer bu paket depoda yoksa kaynak koddan devam edeceğiz
    && rm -rf /var/lib/apt/lists/*

# 3. Modülü İndir (Messad Fork'u - Grok'un önerdiği)
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git

# 4. Modülü Derle ve Kur
WORKDIR /usr/src/mod_audio_stream
# Safarov imajında header dosyaları standart yollarda olmayabilir
# Bu yüzden Makefile'ı çalıştırmadan önce basit bir derleme deniyoruz
RUN make
RUN make install

# 5. Modülü Aktif Et
# modules.conf.xml dosyasının sonuna ekle
RUN sed -i '/<\/modules>/i <load module="mod_audio_stream"/>' /etc/freeswitch/autoload_configs/modules.conf.xml

# 6. Portlar (Mapping yapsan da burda dursun)
EXPOSE 5060/udp 5060/tcp 16384-32768/udp
