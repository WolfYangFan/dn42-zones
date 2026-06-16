#!/bin/bash
set -euo pipefail

# add-record.sh -- add DNS records to zone files
#
# Usage:
#   ./scripts/add-record.sh -z example.dn42 -t A -n www -v 172.20.0.1
#   ./scripts/add-record.sh -z example.dn42 -t AAAA -n www -v fd42::1
#   ./scripts/add-record.sh -z example.dn42 -t CNAME -n mail -v mx.example.dn42.
#   ./scripts/add-record.sh -z 20.172.in-addr.arpa -t PTR -n 1 -v example.dn42.
#
# The script updates the SOA serial automatically.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZONES_DIR="${SCRIPT_DIR}/zones"

usage() {
    cat <<EOF
Usage: $0 -z ZONE -t TYPE -n NAME -v VALUE

Options:
  -z ZONE     DNS zone name (e.g. example.dn42)
  -t TYPE     Record type (A, AAAA, CNAME, MX, TXT, PTR, NS)
  -n NAME     Record name (relative to zone, or FQDN with trailing dot)
  -v VALUE    Record value
  -T TTL      TTL (default: 3600)
  -p PRIORITY Priority (for MX records)
  -h          Show this help
EOF
    exit 0
}

TTL=3600
PRIORITY=10
ZONE=""
TYPE=""
NAME=""
VALUE=""

while getopts "z:t:n:v:T:p:h" opt; do
    case "$opt" in
        z) ZONE="$OPTARG" ;;
        t) TYPE="${OPTARG^^}" ;;
        n) NAME="$OPTARG" ;;
        v) VALUE="$OPTARG" ;;
        T) TTL="$OPTARG" ;;
        p) PRIORITY="$OPTARG" ;;
        h) usage ;;
        *) exit 1 ;;
    esac
done

if [ -z "$ZONE" ] || [ -z "$TYPE" ] || [ -z "$NAME" ] || [ -z "$VALUE" ]; then
    usage
fi

# Find the zone file
zone_file=""
for f in "${ZONES_DIR}"/*; do
    if grep -qi "^@[[:space:]]*IN[[:space:]]*SOA" "$f" 2>/dev/null; then
        zone_name=$(grep -i "^@[[:space:]]*IN[[:space:]]*SOA" "$f" | awk '{print $5}' | sed 's/\.$//' 2>/dev/null || true)
        # Crude zone name match: check if zone appears in the file
        if grep -qi "$ZONE" "$f" 2>/dev/null; then
            zone_file="$f"
            break
        fi
    fi
done

if [ -z "$zone_file" ]; then
    echo "Error: could not find zone file for '$ZONE' in $ZONES_DIR/" >&2
    exit 1
fi

# Format the record line
case "$TYPE" in
    A|AAAA|NS) record="%-24s IN %-5s %s %s" ;;
    CNAME)     record="%-24s IN %-5s %s" ;;
    MX)        record="%-24s IN %-5s %d %s" ;;
    TXT)       record='%-24s IN %-5s "%s"' ;;
    PTR)       record="%-24s IN %-5s %s" ;;
    *)         echo "Error: unsupported type $TYPE" >&2; exit 1 ;;
esac

# Ensure name ends with dot for FQDN, or append zone for relative names
if [[ "$NAME" != *.* ]]; then
    fqdn="${NAME}.${ZONE}."
else
    fqdn="${NAME}"
fi

if [ "$TYPE" = "MX" ]; then
    line=$(printf "$record" "$NAME" "$TYPE" "$PRIORITY" "$VALUE")
else
    if [ "$TYPE" = "TXT" ]; then
        VALUE_ESC="$VALUE"
    else
        VALUE_ESC="${VALUE}"
    fi
    line=$(printf "$record" "$NAME" "$TYPE" "$TTL" "$VALUE_ESC")
fi

# Check for duplicate
if grep -qi "^${NAME}[[:space:]]" "$zone_file"; then
    echo "Warning: record '$NAME' already exists in $zone_file" >&2
    echo "Appending anyway (remove manually if duplicate)" >&2
fi

# Insert before the last line (usually a newline)
# Find a good insertion point: before any empty line at EOF, or append
sed -i '$a\' "$zone_file" 2>/dev/null || true
echo "$line" >> "$zone_file"

# Bump serial
"${SCRIPT_DIR}/scripts/serial.sh" "$zone_file"

echo "Added: $line"
echo "  to $zone_file"
