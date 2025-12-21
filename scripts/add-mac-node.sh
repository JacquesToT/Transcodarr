#!/bin/bash
#
# Add a Mac transcode node to rffmpeg
#

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <mac-ip> <weight>"
    echo "Example: $0 192.168.1.50 2"
    exit 1
fi

MAC_IP="$1"
WEIGHT="${2:-2}"

echo "Adding Mac transcode node: $MAC_IP with weight $WEIGHT"
docker exec jellyfin rffmpeg add "$MAC_IP" --weight "$WEIGHT"

echo ""
echo "Verifying..."
docker exec jellyfin rffmpeg status
