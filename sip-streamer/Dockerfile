FROM debian:bullseye-slim

LABEL maintainer="Ilya Spivakov <ilya@spivakov.me>"

ENV BUILD_PACKAGES="ca-certificates\
                    gstreamer1.0-plugins-* \
                    baresip \
                    ffmpeg"

RUN apt-get update \
    && apt-get \
        -yqq \
        install ${BUILD_PACKAGES} 


COPY config /config
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# ENV SIP_ID="user@example.com"
# ENV SIP_ADDR="destination@example.com"
# ENV STREAM_URL="https://example.com/stream.mp3"

ENTRYPOINT /docker-entrypoint.sh