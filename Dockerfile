# 1. Base İmaj: Resmi FreeSWITCH (Debian tabanlı)
FROM signalwire/freeswitch:latest

# 2. Derleme Araçlarını Kur (Modülü pişirmek için lazım)
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libssl-dev \
    libfreeswitch-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# 3. Senin Forkladığın Modülü İndir
WORKDIR /usr/src
# Buraya senin fork adresini yazabilirsin veya direkt messad kullanabilirsin
RUN git clone https://github.com/messad/mod_audio_stream.git

# 4. Modülü Derle (Make) ve Kur (Install)
WORKDIR /usr/src/mod_audio_stream
RUN make
RUN make install

# 5. Modülü FreeSWITCH Ayarlarına Ekle (Otomatik başlasın diye)
# modules.conf.xml dosyasına ekleme yapıyoruz
RUN sed -i '/<\/modules>/i <load module="mod_audio_stream"/>' /etc/freeswitch/autoload_configs/modules.conf.xml

# 6. Portları Aç (SIP ve RTP)
EXPOSE 5060/udp 5060/tcp 16384-32768/udp
