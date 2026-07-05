#!/usr/bin/env bash
# loop_publish.sh — Publish a message every N minutes, log to stdout
# Usage:
#   ./loop_publish.sh [HOST] [TOPIC] [INTERVAL_SECONDS]
#   Default: localhost:8080  yexuan-spike  300 (5 min)
#
# Pipe to a log file for later comparison:
#   ./loop_publish.sh 2>&1 | tee publish_log.txt

HOST="${1:-localhost:8080}"
TOPIC="${2:-yexuan-spike}"
INTERVAL="${3:-300}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] loop_publish started  interval=${INTERVAL}s  host=$HOST  topic=$TOPIC"

SEQ=0
while true; do
    SEQ=$((SEQ + 1))
    MSG="seq=$SEQ ts=$(date '+%H:%M:%S') interval=${INTERVAL}s"
    ./publish.sh "$HOST" "$TOPIC" "$MSG"
    sleep "$INTERVAL"
done
