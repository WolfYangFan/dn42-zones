#!/bin/bash
set -euo pipefail

# list.sh -- pretty-print zone records
#
# Usage:
#   ./scripts/list.sh                    # list all zones
#   ./scripts/list.sh example.dn42       # list specific zone
#   ./scripts/list.sh --type A           # filter by record type

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZONES_DIR="${SCRIPT_DIR}/zones"

FILTER_TYPE=""
TARGET=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --type|-t) FILTER_TYPE="${2^^}"; shift 2 ;;
        --help|-h) echo "Usage: $0 [--type TYPE] [zone_name]"; exit 0 ;;
        *) TARGET="$1"; shift ;;
    esac
done

for f in "${ZONES_DIR}"/*; do
    [ -f "$f" ] || continue

    # Detect zone name from file
    zone_name=$(basename "$f")

    if [ -n "$TARGET" ]; then
        case "$zone_name" in
            *"$TARGET"*) ;;  *) continue ;;
        esac
    fi

    echo "=== $zone_name ==="
    while IFS= read -r line; do
        # Skip comments, SOA, blank lines, and $ORIGIN/$TTL directives
        [[ "$line" =~ ^[[:space:]]*(;|@|$) ]] && continue
        [[ "$line" =~ ^\$ ]] && continue

        if [ -n "$FILTER_TYPE" ]; then
            if echo "$line" | grep -qi "IN[[:space:]]*${FILTER_TYPE}\b"; then
                echo "  $line"
            fi
        else
            echo "  $line"
        fi
    done < "$f"
    echo ""
done
