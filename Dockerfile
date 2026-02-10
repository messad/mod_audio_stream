FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Base dependencies
RUN apt-get update && apt-get install -y \
    git curl wget gnupg2 ca-certificates lsb-release \
    build-essential pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Add FreeSWITCH official repo (USER_TOKEN Coolify'dan gelecek)
RUN --mount=type=secret,id=USER_TOKEN \
    TOKEN=$(cat /run/secrets/USER_TOKEN) && \
    wget --http-user=signalwire --http-password=${TOKEN} \
    -O /usr/share/keyrings/signalwire-freeswitch-repo.gpg \
    https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] \
    https://freeswitch.signalwire.com/repo/deb/debian-release/ $(lsb_release -sc) main" \
    > /etc/apt/sources.list.d/freeswitch.list

# Install FreeSWITCH
RUN apt-get update && apt-get install -y \
    freeswitch-meta-all freeswitch-mod-dev \
    && rm -rf /var/lib/apt/lists/*

# Build mod_audio_stream
WORKDIR /usr/src
RUN git clone https://github.com/messad/mod_audio_stream.git && \
    cd mod_audio_stream && \
    make && \
    cp mod_audio_stream.so /usr/lib/freeswitch/mod/

# Enable module
RUN echo 'mod_audio_stream' >> /etc/freeswitch/modules.conf

EXPOSE 5060/tcp 5060/udp 16384-32768/udp

CMD ["freeswitch", "-nonat", "-nf"]
