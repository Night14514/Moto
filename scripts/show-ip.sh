#!/usr/bin/env bash
# Show LAN IPv4 addresses for phones to use in MotoTalk settings.
set -euo pipefail
echo "=== MotoTalk: IP addresses for app settings ==="
echo "Enter in app as: http://IP:3000"
echo

if command -v ip >/dev/null 2>&1; then
  ip -4 -o addr show scope global | awk '{print $2, $4}' | while read -r iface cidr; do
    ipaddr="${cidr%/*}"
    echo "  $iface  →  http://$ipaddr:3000"
  done
elif command -v hostname >/dev/null 2>&1; then
  hostname -I 2>/dev/null | tr ' ' '\n' | grep -v '^$' | while read -r ipaddr; do
    echo "  →  http://$ipaddr:3000"
  done
else
  echo "Install iproute2 or check Settings → Network"
fi

echo
echo "Health check (local):"
curl -s "http://127.0.0.1:3000/health" 2>/dev/null || echo "(server not running)"
echo
