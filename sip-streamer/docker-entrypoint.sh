#!/bin/sh

rm -f stream.wav
mkfifo stream.wav

baresip -d -f / \
    -e "/uanew <sip:$SIP_ID>;regint=0" \
    -e u \
    -e "d sip:$SIP_ADDR"

ffmpeg -y -re -i "$STREAM_URL" -ac 1 -ar 48000 -af "\
highpass=f=250,\
lowpass=f=3500,\
equalizer=f=1000:t=q:w=0.8:g=3,\
equalizer=f=2500:t=q:w=1.0:g=2,\
acompressor=threshold=-20dB:ratio=4:attack=5:release=50:makeup=2,\
alimiter=limit=0.95:attack=5:release=50,\
loudnorm=I=-16:TP=-1.5:LRA=11\
" stream.wav -hide_banner -nostats
