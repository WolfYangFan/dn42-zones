#!/bin/bash
set -euo pipefail

# serial.sh -- update SOA serial in zone files to YYYYMMDDNN format
#
# Usage:
#   ./scripts/serial.sh                    # auto-bump serial in all db.* files
#   ./scripts/serial.sh zones/db.example   # bump a specific file
#   ./scripts/serial.sh --date 20260401 zones/db.example  # set specific serial

SERIAL_DATE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --date) SERIAL_DATE="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: $0 [--date YYYYMMDD] [zone_file ...]"
            exit 0
            ;;
        *) break ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZONES_DIR="${SCRIPT_DIR}/zones"

if [ -z "${SERIAL_DATE}" ]; then
    SERIAL_DATE="$(date +%Y%m%d)"
fi

if [ $# -gt 0 ]; then
    files=("$@")
else
    files=("${ZONES_DIR}"/db.*)
fi

for file in "${files[@]}"; do
    [ -f "$file" ] || continue

    current=$(grep -E '^[[:space:]]*[0-9]+[[:space:]]*;[[:space:]]*Serial' "$file" | awk '{print $1}' || true)
    if [ -z "$current" ]; then
        current=$(sed -n '/SOA/,/)/p' "$file" | grep -oE '[0-9]{10,}' | head -1 || true)
    fi
    if [ -z "$current" ]; then
        echo "  skip $file (no serial found)" >&2
        continue
    fi

    today_serial="${SERIAL_DATE}00"
    if [ "$current" -ge "${today_serial}" ] 2>/dev/null; then
        new_serial=$((current + 1))
    else
        new_serial="${today_serial}"
    fi

    sed -i "s/\b${current}\b/${new_serial}/" "$file"
    echo "  $file: $current -> $new_serial"
done
