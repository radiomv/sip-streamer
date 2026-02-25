#!/bin/bash
#
# restart-sip-doctors.sh
#
# Periodically kills SIP doctor containers so the monitor script can
# restart them with a fresh audio stream. This works around an issue
# where the container keeps running but the audio stream silently stops
# being sent to the provider, causing no audio for listeners.
#
# Usage:
#   ./restart-sip-doctors.sh              # Run once (kill all doctor containers now)
#   ./restart-sip-doctors.sh --loop       # Run continuously, killing every 15 minutes
#
# The container name pattern can be overridden with the DOCTOR_PATTERN
# environment variable (default: "doctor").
#
# Cron example (every 15 minutes):
#   */15 * * * * /path/to/restart-sip-doctors.sh >> /var/log/sip-doctor-restart.log 2>&1
#

PATTERN="${DOCTOR_PATTERN:-doctor}"
INTERVAL="${RESTART_INTERVAL:-900}"  # 15 minutes in seconds
STAGGER_DELAY="${STAGGER_DELAY:-10}" # seconds between killing each container

kill_doctors() {
    containers=$(docker ps --filter "name=$PATTERN" --format "{{.ID}} {{.Names}}" 2>/dev/null)

    if [ -z "$containers" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No running containers matching '$PATTERN' found."
        return
    fi

    count=$(echo "$containers" | wc -l)
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Found $count doctor container(s) to restart."

    echo "$containers" | while read -r id name; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stopping container: $name ($id)"
        docker stop --time 5 "$id"

        if [ $? -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Successfully stopped: $name"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Failed to stop $name, force killing..."
            docker kill "$id" 2>/dev/null
        fi

        # Stagger kills so the monitor can restart them one at a time
        # rather than all at once
        remaining=$(echo "$containers" | tail -n +2 | wc -l)
        if [ "$remaining" -gt 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Waiting ${STAGGER_DELAY}s before next container..."
            sleep "$STAGGER_DELAY"
        fi
    done

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done. Monitor script will handle restarts."
}

# Main
if [ "$1" = "--loop" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting SIP doctor restart loop (every ${INTERVAL}s)."
    while true; do
        kill_doctors
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleeping ${INTERVAL}s until next cycle..."
        sleep "$INTERVAL"
    done
else
    kill_doctors
fi
