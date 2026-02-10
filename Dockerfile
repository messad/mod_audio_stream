# Halka açık ve stabil olan BetterVoice imajını kullanıyoruz
FROM bettervoice/freeswitch-container:latest

# Build sırasında root yetkisi al
USER root

# 1. Gerekli derleme araçlarını kur
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libssl-dev \
    zlib1g-dev \
    pkg-config \
    # Not: libfreeswitch-dev bu imajda kurulu gelebilir, gelmezse hata verebilir
    # Şimdilik temel paketlerle deneyelim
    && rm -rf /var/lib/apt/lists/*

# 2. Senin seçtiğin modülü indir
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git

# 3. Modülü Derle ve Kur
WORKDIR /usr/src/mod_audio_stream
# BetterVoice imajında FreeSWITCH kaynak kodları /usr/include altında olmayabilir
# O yüzden Makefile'da ufak bir hack gerekebilir ama önce standart deneyelim
RUN make
RUN make install

# 4. Modülü aktif et
# modules.conf.xml dosyasına ekliyoruz
RUN sed -i '/<\/modules>/i <load module="mod_audio_stream"/>' /etc/freeswitch/autoload_configs/modules.conf.xml

# 5. Portlar (Mapping yapsan da burda dursun, zararı yok)
EXPOSE 5060/udp 5060/tcp 16384-32768/udp
