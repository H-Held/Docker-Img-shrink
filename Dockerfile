FROM debian:stable-slim

RUN apt-get update && apt-get install -y \
    git \
    bash \
    sudo \
    util-linux \
    parted \
    e2fsprogs \
    mount \
    kpartx \
    bzip2 \
    gzip \
    xz-utils \
    zip \
    pigz \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone https://github.com/Drewsif/PiShrink.git
WORKDIR /opt/PiShrink
RUN chmod +x pishrink.sh

COPY scripts/expand-root.sh /opt/expand-root.sh
RUN chmod +x /opt/expand-root.sh

COPY scripts/expand-root.service /opt/expand-root.service
RUN chmod 644 /opt/expand-root.service

COPY scripts/run.sh /opt/run.sh
RUN chmod +x /opt/run.sh
