FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    asterisk \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY conf/ /etc/asterisk/

EXPOSE 5060/udp 5060/tcp 10000-10100/udp

CMD ["asterisk", "-f", "-vvv"]
