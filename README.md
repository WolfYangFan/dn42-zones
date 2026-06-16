# dn42-zones

Manage DN42 zone files with CoreDNS and Git.

## Structure

```
├── Corefile            # CoreDNS config
├── zones/
│   └── ...             # Zone files (db.*)
└── scripts/
    ├── deploy.sh       # One-click deploy script
    ├── add-record.sh   # Add DNS records to zone files
    ├── list.sh         # Pretty-print zone records
    ├── serial.sh       # Update SOA serial numbers
    └── git-pull.sh     # Pull latest zones on the server
```

## Deploy

Just use one-click script:

```sh
bash <(curl -sSL https://raw.githubusercontent.com/WolfYangFan/dn42-zones/refs/heads/main/scripts/deploy.sh
```

or:

```sh
# Specify repo URL, use default CoreDNS binary URL
./scripts/deploy.sh -r https://github.com/WolfYangFan/dn42-zones.git

# Custom binary URL
./scripts/deploy.sh \
  -u https://example.com/path/coredns-linux-amd64 \
  -r https://github.com/WolfYangFan/dn42-zones.git
```

The deploy script will:

1. Download CoreDNS (auto fallback to mirror on failure)
2. Install to `/usr/local/bin`
3. Clone repo to `/opt/dn42-zones`
4. Create and enable systemd service

## Scripts

### add-record.sh

Add DNS records to zone files. Supports A, AAAA, CNAME, MX, TXT, PTR, NS types. Auto-updates SOA serial.

```sh
./scripts/add-record.sh -z wyf.dn42 -t A -n www -v 172.21.104.50
./scripts/add-record.sh -z wyf.dn42 -t AAAA -n www -v fd3b:ed51:c993::50
./scripts/add-record.sh -z wyf.dn42 -t CNAME -n mail -v ns1
```

### list.sh

Pretty-print zone records. Filter by type or target a specific zone.

```sh
./scripts/list.sh                    # List all zones
./scripts/list.sh wyf.dn42           # List records in a specific zone
./scripts/list.sh --type A           # Filter by record type
./scripts/list.sh wyf.dn42 --type AAAA
```

### serial.sh

Update SOA serial to `YYYYMMDDNN` format. Useful after manual edits.

```sh
./scripts/serial.sh                  # Bump serial for all zone files
./scripts/serial.sh --date 20260401  # Use a specific date
```

### git-pull.sh

Silently pull latest zone files on the server (used by cron/systemd timers).

```sh
./scripts/git-pull.sh
```

## Reloading

The CoreDNS `file` plugin reads zone files periodically, so changes to `zones/db.*` are picked up automatically.

## Validate locally

```sh
named-checkzone wyf.dn42 zones/db.wyf.dn42
named-checkzone 32-27.104.21.172.in-addr.arpa zones/db.32-27.104.21.172.in-addr.arpa
```
