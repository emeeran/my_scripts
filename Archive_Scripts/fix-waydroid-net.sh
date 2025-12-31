```
#!/usr/bin/env bash
set -euo pipefail

log(){ echo -e "[fix-waydroid-net] $*"; }

# --- Pre-checks ---
if [[ $EUID -ne 0 ]]; then
  log "Please run as root: sudo $0"; exit 1
fi

# Ensure the container service is up (creates the bridge if missing)
systemctl enable --now waydroid-container >/dev/null 2>&1 || true

# --- Detect Waydroid/LXC bridge ---
log "Detecting Waydroid bridge…"
BRIDGE_IF="$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(waydroid0|lxcbr0|virbr0)$' | head -n1 || true)"
if [[ -z "${BRIDGE_IF:-}" ]]; then
  # Fallback by subnet commonly used by Waydroid (192.168.240.0/24)
  BRIDGE_IF="$(ip -o -4 addr show | awk '/192\\.168\\.240\\./{print $2; exit}' || true)"
fi

if [[ -z "${BRIDGE_IF:-}" ]]; then
  log "Bridge not found; restarting container to create it…"
  systemctl restart waydroid-container
  sleep 2
  BRIDGE_IF="$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(waydroid0|lxcbr0|virbr0)$' | head -n1 || true)"
fi

if [[ -z "${BRIDGE_IF:-}" ]]; then
  log "ERROR: Could not find Waydroid bridge (waydroid0/lxcbr0/virbr0). Start Waydroid once, then re-run."
  exit 1
fi
log "Bridge interface: ${BRIDGE_IF}"

SUBNET="$(ip -o -4 addr show "$BRIDGE_IF" | awk '{print $4}')"
if [[ -z "${SUBNET:-}" ]]; then
  log "ERROR: Could not detect IPv4 subnet on ${BRIDGE_IF}"; exit 1
fi
log "Bridge subnet: ${SUBNET}"

# --- Detect egress (internet) interface ---
EGRESS_IF="$(ip route get 8.8.8.8 | awk '{for (i=1;i<=NF;i++) if ($i=="dev") {print $(i+1); exit}}')"
if [[ -z "${EGRESS_IF:-}" ]]; then
  log "ERROR: Could not determine egress interface"; exit 1
fi
log "Egress interface: ${EGRESS_IF}"

# --- Handle Docker conflicts (same-subnet bridge) ---
if ip -o link show docker0 >/dev/null 2>&1; then
  DOCKER_SUBNET="$(ip -o -4 addr show docker0 | awk '{print $4}' || true)"
  if [[ -n "${DOCKER_SUBNET:-}" && "${DOCKER_SUBNET%%/*}" =~ ^192\.168\.240\. ]]; then
    log "Docker bridge conflicts with Waydroid subnet (192.168.240.0/24). Temporarily stopping Docker…"
    systemctl stop docker docker.socket || true
    ip link delete docker0 || true
  fi
fi

# --- Enable IPv4 forwarding (persistent) ---
log "Enabling IPv4 forwarding…"
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-waydroid-ipforward.conf
sysctl --system >/dev/null

# --- Ensure nftables installed & running ---
if ! command -v nft >/dev/null 2>&1; then
  log "Installing nftables…"
  apt-get update -y
  apt-get install -y nftables
fi
systemctl enable --now nftables >/dev/null 2>&1 || true

# --- Configure nftables NAT/forwarding in a dedicated table (idempotent) ---
log "Configuring nftables rules…"
nft list tables | grep -q 'table inet waydroid_nat' || nft add table inet waydroid_nat
nft list table inet waydroid_nat 2>/dev/null | grep -q 'chain postrouting' || nft add chain inet waydroid_nat postrouting '{ type nat hook postrouting priority 100 ; }'
nft list table inet waydroid_nat 2>/dev/null | grep -q 'chain forward'     || nft add chain inet waydroid_nat forward     '{ type filter hook forward priority 0 ; policy accept ; }'

# Remove existing rules we added earlier (safe if none)
nft list ruleset 2>/dev/null | awk '/table inet waydroid_nat/ && /masquerade/ {print "nft delete rule "$0}' 2>/dev/null \
  | sed 's/^.*nft delete/nft delete/' | bash || true
nft list ruleset 2>/dev/null | awk '/table inet waydroid_nat/ && /iifname/ {print "nft delete rule "$0}' 2>/dev/null \
  | sed 's/^.*nft delete/nft delete/' | bash || true

# Add fresh rules
nft add rule inet waydroid_nat postrouting ip saddr "$SUBNET" oif "$EGRESS_IF" masquerade
nft add rule inet waydroid_nat forward iifname "$BRIDGE_IF" oifname "$EGRESS_IF" accept
nft add rule inet waydroid_nat forward iifname "$EGRESS_IF" oifname "$BRIDGE_IF" ct state related,established accept
log "nftables rules applied."

# --- Set DNS properties for Waydroid (helps when DNS fails) ---
log "Setting Waydroid DNS properties…"
waydroid prop set persist.waydroid.net.dns1 8.8.8.8 || true
waydroid prop set persist.waydroid.net.dns2 1.1.1.1 || true

# --- Restart container (session must be started by user later) ---
log "Restarting waydroid-container…"
systemctl restart waydroid-container

# --- Quick connectivity sanity from inside container (no GUI needed) ---
log "Container-side quick test (ICMP & DNS)…"
waydroid shell sh -c 'ping -c1 -W2 8.8.8.8 >/dev/null && echo "ICMP_OK" || echo "ICMP_FAIL"'
waydroid shell sh -c 'ping -c1 -W3 google.com >/dev/null && echo "DNS_OK" || echo "DNS_FAIL"'

log "Done. Now start session as your normal user: 'waydroid session start' and test networking in Browser/Play Store."

```

