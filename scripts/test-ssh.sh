#!/bin/bash
#
# Test SSH connection from Jellyfin container to Mac
#

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <mac-user> <mac-ip>"
    echo "Example: $0 'Your Username' 192.168.1.50"
    exit 1
fi

MAC_USER="$1"
MAC_IP="$2"

echo "Testing SSH connection to ${MAC_USER}@${MAC_IP}..."
docker exec -u abc jellyfin ssh \
    -o StrictHostKeyChecking=no \
    -i /config/rffmpeg/.ssh/id_rsa \
    "${MAC_USER}@${MAC_IP}" \
    "/opt/homebrew/bin/ffmpeg -version"

if [[ $? -eq 0 ]]; then
    echo ""
    echo "✓ SSH connection successful!"
else
    echo ""
    echo "✗ SSH connection failed. Check:"
    echo "  1. Mac Remote Login is enabled"
    echo "  2. SSH public key is in ~/.ssh/authorized_keys"
    echo "  3. Firewall allows SSH (port 22)"
fi
