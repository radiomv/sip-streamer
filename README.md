## Description

A Docker image to stream audio to a SIP client. 

## Building

```sh
docker build --rm  -t sip-streamer .
```

## Environment Variables
- `SIP_ID` SIP 'from' address. When using with turbobridge, this can a anything. Excample `user@example.com`.
- `SIP_ADDR` SIP destination address.
- `STREAM_URL` Location of the source stream. As this is processed through `ffmpeg`, any url can be supplied that ffmpeg can open. If if video is given, only the audio will be used.

## Running

```sh
docker run --rm \
    -e STREAM_URL=https://example.com/stream.mp3 \
    -e SIP_ID=user@example.com \
    -e SIP_ADDR=destination@example.com \
    -t  sip-streamer:latest
```

## Theory of operation
1. A fifo file is created to pipe the audio
1. `baresip` is started in the background and connects to `SIP_ADDR` and plays audio from the fifo buffer.
1. `ffmpeg` reads data from `STREAM_URL`, applies a compressor, downmixes it to mono, and sends it into the fifo as uncompressed PCM audio.
1. If the `ffmpeg` proccess exits or crashes, the whole container stops. (to be restarted by the container manager) This causes a restart if the stream is unavailable or the call ends. If a call cannot be placed, the program is stuck, and needs to be restarted manually.