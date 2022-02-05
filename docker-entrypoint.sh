#!/bin/sh

rm -f stream.wav
mkfifo stream.wav

baresip -d -f / \
    -e "/uanew <sip:$SIP_ID>;regint=0" \
    -e u \
    -e "d sip:$SIP_ADDR"

ffmpeg -y -re -i "$STREAM_URL" -ac 1 -af "acompressor" stream.wav -hide_banner -nostats
