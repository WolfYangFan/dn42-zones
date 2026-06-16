# dn42-zones

Manage DN42 zone files with CoreDNS and Git.

## Structure

```
├── Corefile                 # CoreDNS config (reload plugin enabled)
├── zones/
│   ├── db.YOUR-DOMAIN       # Forward zone file (replace with yours)
│   └── db.YOUR-REVERSE      # Reverse zone file (replace with yours)
└── scripts/
    └── deploy.sh            # One-click deploy script
```

## Deploy

```bash
# Specify repo URL, use default CoreDNS binary URL
./scripts/deploy.sh -r git@github.com:your/dn42-zones.git

# Custom binary URL
./scripts/deploy.sh \
  -u https://example.com/path/coredns-linux-amd64 \
  -r git@github.com:your/dn42-zones.git
```

The deploy script will:

1. Download CoreDNS (auto fallback to mirror on failure)
2. Install to `/usr/local/bin`
3. Clone repo to `/opt/dn42-zones`
4. Create and enable systemd service

## Reloading

The CoreDNS `file` plugin reads zone files periodically, so changes to `zones/db.*` are picked up automatically.

## Validate locally

```bash
named-checkzone example.dn42 zones/db.example
named-checkzone 0.0.0.0.in-addr.arpa zones/db.0.0.0.0
```
