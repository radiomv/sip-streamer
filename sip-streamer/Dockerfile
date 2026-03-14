# -- Build stage: compile libre + baresip from source --------------------
FROM debian:trixie-slim AS builder

ARG BARESIP_VERSION=4.6.0
ARG LIBRE_VERSION=4.6.0

RUN apt-get update && apt-get install --no-install-recommends -y \
    clang cmake make pkg-config git ca-certificates \
    libssl-dev zlib1g-dev libopus-dev libspandsp-dev \
    libgstreamer1.0-dev libglib2.0-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Build libre
RUN git clone -b v${LIBRE_VERSION} --depth=1 https://github.com/baresip/re.git \
    && cd re \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang \
    && cmake --build build -j$(nproc) \
    && cmake --install build

# Build baresip (only the modules we need)
# FindGST.cmake hardcodes x86_64 paths; pass the correct dirs for the host arch
RUN MULTIARCH=$(basename $(find /usr/lib -maxdepth 1 -name '*-linux-gnu*' | head -1)) \
    && git clone -b v${BARESIP_VERSION} --depth=1 https://github.com/baresip/baresip.git \
    && cd baresip \
    && sed -i "s|x86_64-linux-gnu|${MULTIARCH}|g" cmake/FindGST.cmake \
    && sed -i "s|/usr/lib/include/glib-2.0|/usr/include/glib-2.0|g" cmake/FindGST.cmake \
    && cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=clang \
        -DMODULES="account;aufile;auresamp;cons;contact;ctrl_tcp;debug_cmd;g711;g722;gst;ice;menu;opus;stdio;stun;turn;uuid" \
    && cmake --build build -j$(nproc) \
    && cmake --install build

# -- Runtime stage -------------------------------------------------------
FROM debian:trixie-slim

RUN apt-get update && apt-get -yqq install --no-install-recommends \
    ca-certificates \
    ffmpeg \
    python3 \
    python3-pip \
    python3-pexpect \
    libssl3t64 \
    libopus0 \
    libspandsp2 \
    libgstreamer1.0-0 \
    libglib2.0-0t64 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    && rm -rf /var/lib/apt/lists/*

# Copy libre + baresip from builder
COPY --from=builder /usr/local/lib/ /usr/local/lib/
COPY --from=builder /usr/local/bin/baresip /usr/local/bin/baresip.real
RUN printf '#!/bin/sh\nexec /usr/local/bin/baresip.real -f /root/.baresip "$@"\n' \
        > /usr/local/bin/baresip \
    && chmod +x /usr/local/bin/baresip \
    && ldconfig

RUN pip3 install --break-system-packages audioop-lts baresipy

COPY config /root/.baresip/config
COPY app.py /app.py

ENTRYPOINT ["python3", "-u", "/app.py"]
