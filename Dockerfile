FROM debian:bookworm-slim

# Install dependencies for adding repositories and basic tools
RUN apt-get update && apt-get install -y \
    gnupg \
    wget \
    ca-certificates \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Add SignalWire FreeSWITCH public repository key
RUN wget -O- https://freeswitch.signalwire.com/repo/deb/debian-release/signalwire-freeswitch-repo.gpg | gpg --dearmor > /usr/share/keyrings/signalwire-freeswitch-repo.gpg

# Add SignalWire FreeSWITCH repository
RUN echo "deb [signed-by=/usr/share/keyrings/signalwire-freeswitch-repo.gpg] https://freeswitch.signalwire.com/repo/deb/debian-release/ bookworm main" > /etc/apt/sources.list.d/freeswitch.list

# Update and install FreeSWITCH packages
RUN apt-get update && apt-get install -y \
    freeswitch \
    freeswitch-mod-sofia \
    freeswitch-mod-console \
    freeswitch-mod-event-socket \
    libfreeswitch-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and compile mod_audio_stream
RUN git clone https://github.com/henrik-me/mod_audio_stream.git /tmp/mod_audio_stream \
    && cd /tmp/mod_audio_stream \
    && make \
    && make install \
    && rm -rf /tmp/mod_audio_stream

# Create FreeSWITCH user and group if not exists, set permissions
RUN groupadd -r freeswitch || true \
    && useradd -r -g freeswitch -d /etc/freeswitch freeswitch || true \
    && chown -R freeswitch:freeswitch /etc/freeswitch \
    && chown -R freeswitch:freeswitch /var/lib/freeswitch \
    && chown -R freeswitch:freeswitch /usr/share/freeswitch \
    && chown -R freeswitch:freeswitch /var/run/freeswitch

# Set working directory
WORKDIR /etc/freeswitch

# Expose necessary ports (adjust as needed for your setup)
EXPOSE 5060 5060/udp 5080 5080/udp 8021 8080

# Run as freeswitch user
USER freeswitch

# Entrypoint to start FreeSWITCH in non-daemon mode
ENTRYPOINT ["/usr/bin/freeswitch", "-nc"]
