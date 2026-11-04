FROM debian:stable-slim

RUN apt-get update && apt-get install -y \
    git \
    bash \
    util-linux \
    parted \
    e2fsprogs \
    mount \
    kpartx \
    bzip2 \
    gzip \
    xz-utils \
    pigz \
    pv \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Pinned commit for reproducible builds
RUN git clone https://github.com/Drewsif/PiShrink.git \
 && git -C PiShrink checkout 5f358d03eed4b7334657ee93867826a2b42f112a
WORKDIR /opt/PiShrink
RUN chmod +x pishrink.sh

COPY scripts/expand-root.sh /opt/expand-root.sh
RUN chmod +x /opt/expand-root.sh

COPY scripts/expand-root.service /opt/expand-root.service
RUN chmod 644 /opt/expand-root.service

COPY scripts/run.sh /opt/run.sh
RUN chmod +x /opt/run.sh

# Strip Windows line endings (CRLF) in case the repo was checked out or unzipped on Windows
RUN sed -i 's/\r$//' /opt/run.sh /opt/expand-root.sh /opt/expand-root.service
