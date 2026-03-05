#!/bin/sh

# Setup config directory with pre-created account
mkdir -p /baresip
cp /config /baresip/config
echo "<sip:listener@$SIP_SERVER>;regint=0" > /baresip/accounts

# Create a silent WAV file for the audio source (must be longer than recording)
DURATION=$((RECORD_SECONDS + 30))
ffmpeg -y -f lavfi -i anullsrc=r=48000:cl=mono -t "$DURATION" -c:a pcm_s16le /tmp/silence.wav -hide_banner -loglevel error

# Create named pipe for recording
rm -f /tmp/listen_pipe.wav
mkfifo /tmp/listen_pipe.wav

# Start baresip in foreground, feeding dial command via stdin
# The sleep keeps stdin open so baresip doesn't exit
(sleep 3 && echo "d sip:$SIP_ADDR" && sleep $((RECORD_SECONDS + 10))) | baresip -f /baresip &

# Give call time to establish
sleep 10

# Record from the pipe for the specified duration
ffmpeg -y -t "${RECORD_SECONDS:-30}" \
    -f s16le -ar 48000 -ac 1 -i /tmp/listen_pipe.wav \
    /output/listen.wav \
    -hide_banner -nostats

echo "Recording saved to /output/listen.wav"
