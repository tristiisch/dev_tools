#!/bin/bash
set -u

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <DNS_SERVER(s)> <DOMAIN> [INTERVAL]"
    exit 1
fi

SERVER="$1"
DOMAIN="$2"
INTERVAL="${3:-60}"
TYPE="${4:-A}"

IFS=',' read -r -a SERVERS <<< "$SERVER"
SERVER_ARGS=""
for ip in "${SERVERS[@]}"; do
    SERVER_ARGS="$SERVER_ARGS @$ip"
done


while true; do
    TIMESTAMP=$(date +"%d/%m/%Y %H:%M:%S")
    echo "[$TIMESTAMP] Querying $DOMAIN on DNS servers $SERVER_ARGS"
    dig +time=1 +retry=1 +tries=1 +nocmd +noall +answer +ttlid $SERVER_ARGS $DOMAIN $TYPE

    sleep $INTERVAL
done
