#!/usr/bin/env bash
# publish.sh — POST a test message to ntfy and log timestamp
# Usage:
#   ./publish.sh [HOST] [TOPIC] [MESSAGE]
#   HOST defaults to localhost:8080
#   TOPIC defaults to mychar-spike
#   MESSAGE defaults to "ping $(date)"

HOST="${1:-localhost:8080}"
TOPIC="${2:-mychar-spike}"
MSG="${3:-ping $(date '+%H:%M:%S')}"
PRIORITY="${PRIORITY:-default}"   # low / default / high / urgent

TS=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TS] Publishing to http://$HOST/$TOPIC  →  \"$MSG\""

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Title: mychar-spike" \
  -H "Priority: $PRIORITY" \
  -H "Tags: bell" \
  -d "$MSG" \
  "http://$HOST/$TOPIC")

echo "[$TS] HTTP $HTTP_CODE"
