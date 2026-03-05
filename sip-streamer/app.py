#!/usr/bin/env python3
"""SIP streamer: dials into a SIP conference and streams audio from a URL."""

import os
import signal
import subprocess
import sys
import time
import logging
from baresipy import BareSIP

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
LOG = logging.getLogger("sip-streamer")

SIP_ID = os.environ["SIP_ID"]
SIP_ADDR = os.environ["SIP_ADDR"]
STREAM_URL = os.environ["STREAM_URL"]


class Streamer(BareSIP):
    def __init__(self):
        super().__init__(
            user=SIP_ID.split("@")[0],
            pwd="",
            gateway=SIP_ID.split("@")[1],
            block=False,
        )
        self.ffmpeg = None
        self._call_ended = False

    def handle_ready(self):
        LOG.info("Baresip is ready")
        self.ready = True

    def handle_call_established(self):
        LOG.info("Call established")
        self._call_ended = False

    def handle_call_ended(self, reason="unknown", number=""):
        LOG.info("Call ended: %s (number: %s)", reason, number)
        self._call_ended = True
        self._stop_ffmpeg()

    def handle_error(self, error):
        LOG.error("Error: %s", error)
        self._call_ended = True
        self._stop_ffmpeg()

    def start_stream(self):
        """Start ffmpeg to stream audio into the named pipe."""
        LOG.info("Starting audio stream from %s", STREAM_URL)
        self.ffmpeg = subprocess.Popen(
            [
                "ffmpeg", "-y", "-re",
                "-i", STREAM_URL,
                "-ac", "1", "-ar", "48000",
                "-af", (
                    "highpass=f=250,"
                    "lowpass=f=3500,"
                    "equalizer=f=1000:t=q:w=0.8:g=3,"
                    "equalizer=f=2500:t=q:w=1.0:g=2,"
                    "acompressor=threshold=-20dB:ratio=4:attack=5:release=50:makeup=2,"
                    "alimiter=limit=0.95:attack=5:release=50,"
                    "loudnorm=I=-16:TP=-1.5:LRA=11"
                ),
                "/stream.wav",
                "-hide_banner", "-nostats",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )

    def _stop_ffmpeg(self):
        if self.ffmpeg and self.ffmpeg.poll() is None:
            LOG.info("Stopping ffmpeg")
            self.ffmpeg.terminate()
            try:
                self.ffmpeg.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.ffmpeg.kill()


def main():
    # Create named pipe for audio
    try:
        os.remove("/stream.wav")
    except FileNotFoundError:
        pass
    os.mkfifo("/stream.wav")

    streamer = Streamer()

    def shutdown(sig, frame):
        LOG.info("Shutting down (signal %s)", sig)
        streamer._stop_ffmpeg()
        streamer.quit()
        sys.exit(0)

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)

    # Start ffmpeg first (it blocks on the pipe until baresip reads)
    streamer.start_stream()

    # Wait for baresip to be ready
    LOG.info("Waiting for baresip to be ready")
    for _ in range(30):
        if streamer.ready:
            break
        time.sleep(1)
    else:
        LOG.error("baresip did not become ready in 30s")
        streamer._stop_ffmpeg()
        sys.exit(1)

    time.sleep(5)
    LOG.info("Dialing %s", SIP_ADDR)
    streamer.call(SIP_ADDR)

    # Main loop: exit when call drops or ffmpeg dies
    while True:
        time.sleep(2)

        # Check if ffmpeg died
        if streamer.ffmpeg and streamer.ffmpeg.poll() is not None:
            LOG.error("ffmpeg exited with code %d", streamer.ffmpeg.returncode)
            break

        # Check if call ended
        if streamer._call_ended:
            LOG.error("Call ended, exiting")
            break

        # Check if baresip stopped
        if not streamer.running:
            LOG.error("baresip stopped running")
            break

    LOG.info("Exiting — container will restart")
    streamer._stop_ffmpeg()
    streamer.quit()
    sys.exit(1)


if __name__ == "__main__":
    main()
