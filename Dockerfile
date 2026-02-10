# 1. Base Image: Safarov (Grok'un önerisi, minimal ve hızlı)
FROM safarov/freeswitch:latest

# 2. Root yetkisi al (İsme değil ID'ye güveniyoruz)
USER 0

# 3. Gerekli paketleri kur
# Safarov Debian tabanlıdır, apt-get çalışır.
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    libssl-dev \
    pkg-config \
    zlib1g-dev \
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
    && rm -rf /var/lib/apt/lists/*

# 4. Modül Derleme Hazırlığı
# Safarov imajında FreeSWITCH kaynak kodları (headerlar) olmayabilir.
# Bu yüzden sadece headerları kullanmak için kaynağı çekiyoruz.
WORKDIR /usr/src
RUN git clone --depth 1 -b v1.10 https://github.com/signalwire/freeswitch.git

# 5. mod_audio_stream'i İndir
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git

# 6. Derle ve Kur
WORKDIR /usr/src/mod_audio_stream
# Header dosyalarının yerini göstererek derliyoruz
RUN make INCLUDES="-I/usr/src/freeswitch/src/include -I/usr/src/freeswitch/libs/libteletone/src"
RUN make install

# 7. Modülü Aktif Et
# Config dosyası varsa ekle, yoksa oluştur
RUN if [ -f /etc/freeswitch/autoload_configs/modules.conf.xml ]; then \
      sed -i '/<\/modules>/i <load module="mod_audio_stream"/>' /etc/freeswitch/autoload_configs/modules.conf.xml; \
    else \
      mkdir -p /etc/freeswitch/autoload_configs && \
      echo '<configuration name="modules.conf" description="Modules"><modules><load module="mod_audio_stream"/></modules></configuration>' > /etc/freeswitch/autoload_configs/modules.conf.xml; \
    fi

# 8. Portlar
EXPOSE 5060/udp 5060/tcp 16384-32768/udp
