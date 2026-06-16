#!/bin/bash
set -euo pipefail

# deploy.sh -- deploy CoreDNS + zone files
#
# Usage:
#   ./scripts/deploy.sh
#   ./scripts/deploy.sh -u <URL> -r <REPO_URL>
#

DOWNLOAD_URL="https://s3.6l.ink/temp/coredns-linux-amd64"
FALLBACK_DOMAIN="s4.6l.ink"
REPO_URL="${REPO_URL:-https://github.com/WolfYangFan/dn42-zones.git}"
INSTALL_DIR="/usr/local/bin"
ZONES_DIR="/opt/dn42-zones"
SERVICE_FILE="/etc/systemd/system/coredns.service"

while getopts "u:r:h" opt; do
    case "$opt" in
        u) DOWNLOAD_URL="$OPTARG" ;;
        r) REPO_URL="$OPTARG" ;;
        h)
            echo "Usage: $0 [-u DOWNLOAD_URL] [-r REPO_URL]"
            echo ""
            echo "  -u   CoreDNS binary URL (default: $DOWNLOAD_URL)"
            echo "  -r   Git repository URL (or set REPO_URL env var)"
            exit 0
            ;;
        *) exit 1 ;;
    esac
done

if [ -z "$REPO_URL" ]; then
    echo "Error: provide a repo URL via -r or REPO_URL env var" >&2
    exit 1
fi

echo "==> Downloading CoreDNS ..."

downloaded=0
try_url="$DOWNLOAD_URL"

for attempt in 1 2 3; do
    if [ "$attempt" -eq 2 ]; then
        # fallback: swap domain
        if echo "$try_url" | grep -q "s3\.6l\.ink"; then
            try_url="${DOWNLOAD_URL/s3.6l.ink/$FALLBACK_DOMAIN}"
            echo "    falling back to $try_url"
        else
            echo "    no fallback available" >&2
            exit 1
        fi
    fi

    if command -v curl &>/dev/null; then
        if curl -fsSL "$try_url" -o /tmp/coredns; then
            downloaded=1
            break
        fi
    elif command -v wget &>/dev/null; then
        if wget -q "$try_url" -O /tmp/coredns; then
            downloaded=1
            break
        fi
    else
        echo "Error: neither curl nor wget found" >&2
        exit 1
    fi

    if [ "$attempt" -eq 1 ]; then
        echo "    $try_url failed, trying fallback ..."
    fi
done

if [ "$downloaded" -ne 1 ]; then
    echo "Error: all download attempts failed" >&2
    exit 1
fi

chmod +x /tmp/coredns

echo "==> Installing to $INSTALL_DIR ..."
install -m 755 /tmp/coredns "$INSTALL_DIR/coredns"
rm -f /tmp/coredns

echo "==> Cloning repo to $ZONES_DIR ..."
if [ -d "$ZONES_DIR" ]; then
    echo "    $ZONES_DIR exists, pulling latest ..."
    cd "$ZONES_DIR"
    git pull
else
    git clone "$REPO_URL" "$ZONES_DIR"
fi

echo "==> Creating systemd service ..."
cat > "$SERVICE_FILE" << 'SERVICEEOF'
[Unit]
Description=CoreDNS DNS server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/coredns -conf=/opt/dn42-zones/Corefile
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
SERVICEEOF

# ---- 5. Enable and start ----
echo "==> Enabling and starting service ..."
systemctl daemon-reload
systemctl enable --now coredns

echo "==> Deploy complete"
systemctl status coredns --no-pager
