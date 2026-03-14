#!/bin/sh
set -e

COMPOSE="docker compose"
TIMEOUT=120

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

pass() { printf "${GREEN}PASS${NC}: %s\n" "$1"; }
fail() { printf "${RED}FAIL${NC}: %s\n" "$1"; exit 1; }
info() { printf "${YELLOW}....${NC}: %s\n" "$1"; }

cleanup() {
    info "Cleaning up"
    $COMPOSE down --timeout 5 2>/dev/null
}
trap cleanup EXIT

# Wait for a caller to appear in conference room 100
wait_for_conference() {
    caller="$1"
    timeout="${2:-$TIMEOUT}"
    elapsed=0
    while [ "$elapsed" -lt "$timeout" ]; do
        if $COMPOSE exec -T test-server asterisk -rx "confbridge list 100" 2>/dev/null | grep -q "$caller"; then
            return 0
        fi
        sleep 2
        elapsed=$((elapsed + 2))
    done
    return 1
}


cd "$(dirname "$0")"

# ── Setup ──────────────────────────────────────────────────────────
info "Building and starting test-server + sip-streamer"
$COMPOSE up --build -d test-server sip-streamer

info "Waiting for sip-streamer to join conference"
if ! wait_for_conference "streamer"; then
    fail "sip-streamer did not join conference within ${TIMEOUT}s"
fi
pass "sip-streamer joined conference"

# ── Test 1: Stream failure restart ─────────────────────────────────
info "TEST 1: Killing ffmpeg inside sip-streamer (simulating stream failure)"
$COMPOSE exec -T sip-streamer killall ffmpeg 2>/dev/null || true

info "Waiting for sip-streamer to restart and rejoin conference"
sleep 5  # give container time to exit and restart
if ! wait_for_conference "streamer"; then
    fail "TEST 1 — sip-streamer did not rejoin conference after stream failure"
fi
pass "TEST 1 — sip-streamer recovered from stream failure"

# ── Test 2: SIP connection interrupted ─────────────────────────────
info "TEST 2: Hanging up streamer's call from Asterisk (simulating SIP disconnect)"
CHAN=$($COMPOSE exec -T test-server asterisk -rx "core show channels verbose" 2>/dev/null | grep "SIP/pbx" | awk '{print $1}')
if [ -z "$CHAN" ]; then
    fail "TEST 2 — could not find streamer's channel to hang up"
fi
info "Hanging up channel: $CHAN"
$COMPOSE exec -T test-server asterisk -rx "channel request hangup $CHAN" 2>/dev/null || true

# Wait for the container to restart (detect by watching it go down and come back)
info "Waiting for sip-streamer to restart and rejoin conference"
sleep 5
if ! wait_for_conference "streamer"; then
    fail "TEST 2 — sip-streamer did not rejoin conference after SIP interruption"
fi
pass "TEST 2 — sip-streamer recovered from SIP interruption"

printf "\n${GREEN}All tests passed${NC}\n"
