FROM debian:bookworm-slim

RUN apt-get update && apt-get -yqq install \
    ca-certificates \
    gstreamer1.0-plugins-* \
    baresip \
    ffmpeg \
    python3 \
    python3-pip \
    python3-pexpect \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages baresipy

COPY config /root/.baresip/config

# baresip 1.0.0 on bookworm can't auto-detect ~/.baresip; wrap it with -f
RUN mv /usr/bin/baresip /usr/bin/baresip.real \
    && printf '#!/bin/sh\nexec /usr/bin/baresip.real -f /root/.baresip "$@"\n' > /usr/bin/baresip \
    && chmod +x /usr/bin/baresip

COPY app.py /app.py

ENTRYPOINT ["python3", "-u", "/app.py"]
