#!/bin/bash
set -euo pipefail
# git-pull.sh -- pull latest zone files, retry up to 3 times, no output
ZONES_DIR="/opt/dn42-zones"
for i in 1 2 3; do
    if cd "$ZONES_DIR" && git pull >/dev/null 2>&1; then
        exit 0
    fi
    [ "$i" -eq 3 ] || sleep 5
done
exit 1
