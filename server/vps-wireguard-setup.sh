#!/usr/bin/env bash
# ==============================================================================
# VPS WireGuard + iptables DNAT setup for Rust Dedicated Server
# Run as root on the VPS (e.g.: sudo bash vps-wireguard-setup.sh)
#
# What this does:
#   1. Installs wireguard-tools and iptables-persistent
#   2. Generates VPS WG keypair
#   3. Creates /etc/wireguard/wg0.conf with PostUp/PostDown iptables rules
#   4. Enables ip_forward (kernel + sysctl)
#   5. Opens INPUT (iptables): WG + Rust ports — saves via netfilter-persistent if present
#      (On Ubuntu Noble, apt may remove ufw when installing iptables-persistent.)
#   6. Enables and starts wg-quick@wg0
#
# After running this script:
#   - Print VPS public key: sudo cat /etc/wireguard/vps_public.key
#   - Add that key to the Home PC WireGuard peer config
#   - Add Home PC public key to /etc/wireguard/wg0.conf [Peer] block
# ==============================================================================

set -euo pipefail

WG_IFACE="wg0"
WG_DIR="/etc/wireguard"
VPS_WG_IP="10.8.0.1/24"
HOME_PEER_IP="10.8.0.2/32"
WG_PORT=51820

# Rust DS ports to forward to home peer
RUST_GAME_UDP=28015
RUST_QUERY_UDP=28017
RUST_RCON_TCP=28016
RUST_PLUS_TCP=28082

# Detect main network interface (eth0, ens3, etc.)
IFACE=$(ip route get 1.1.1.1 | awk '{print $5; exit}')
echo "[*] Detected main interface: $IFACE"

# ─── 1. Install packages ──────────────────────────────────────────────────────
echo "[*] Installing wireguard-tools and iptables-persistent..."
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard-tools iptables-persistent

# ─── 2. Generate server keypair ───────────────────────────────────────────────
echo "[*] Generating WireGuard keypair..."
install -d -m 0700 "$WG_DIR"
wg genkey | tee "${WG_DIR}/vps_private.key" | wg pubkey > "${WG_DIR}/vps_public.key"
chmod 600 "${WG_DIR}/vps_private.key"
VPS_PRIVATE=$(cat "${WG_DIR}/vps_private.key")

echo ""
echo "============================================================"
echo " VPS PUBLIC KEY (paste into Home PC wg0.conf [Peer]):"
echo " $(cat ${WG_DIR}/vps_public.key)"
echo "============================================================"
echo ""

# ─── 3. Create wg0.conf ───────────────────────────────────────────────────────
echo "[*] Writing ${WG_DIR}/${WG_IFACE}.conf..."

cat > "${WG_DIR}/${WG_IFACE}.conf" <<EOF
[Interface]
Address    = ${VPS_WG_IP}
ListenPort = ${WG_PORT}
PrivateKey = ${VPS_PRIVATE}

# DNAT: forward Rust DS ports from VPS public IP to home peer (10.8.0.2)
PostUp   = iptables -t nat -A PREROUTING -i ${IFACE} -p udp --dport ${RUST_GAME_UDP}  -j DNAT --to-destination 10.8.0.2:${RUST_GAME_UDP}
PostUp   = iptables -t nat -A PREROUTING -i ${IFACE} -p udp --dport ${RUST_QUERY_UDP} -j DNAT --to-destination 10.8.0.2:${RUST_QUERY_UDP}
PostUp   = iptables -t nat -A PREROUTING -i ${IFACE} -p tcp --dport ${RUST_RCON_TCP}  -j DNAT --to-destination 10.8.0.2:${RUST_RCON_TCP}
PostUp   = iptables -t nat -A PREROUTING -i ${IFACE} -p tcp --dport ${RUST_PLUS_TCP}  -j DNAT --to-destination 10.8.0.2:${RUST_PLUS_TCP}
PostUp   = iptables -t nat -A POSTROUTING -o ${WG_IFACE} -j MASQUERADE
PostUp   = iptables -A FORWARD -i ${IFACE} -o ${WG_IFACE} -j ACCEPT
PostUp   = iptables -A FORWARD -i ${WG_IFACE} -o ${IFACE} -j ACCEPT

PostDown = iptables -t nat -D PREROUTING -i ${IFACE} -p udp --dport ${RUST_GAME_UDP}  -j DNAT --to-destination 10.8.0.2:${RUST_GAME_UDP}
PostDown = iptables -t nat -D PREROUTING -i ${IFACE} -p udp --dport ${RUST_QUERY_UDP} -j DNAT --to-destination 10.8.0.2:${RUST_QUERY_UDP}
PostDown = iptables -t nat -D PREROUTING -i ${IFACE} -p tcp --dport ${RUST_RCON_TCP}  -j DNAT --to-destination 10.8.0.2:${RUST_RCON_TCP}
PostDown = iptables -t nat -D PREROUTING -i ${IFACE} -p tcp --dport ${RUST_PLUS_TCP}  -j DNAT --to-destination 10.8.0.2:${RUST_PLUS_TCP}
PostDown = iptables -t nat -D POSTROUTING -o ${WG_IFACE} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${IFACE} -o ${WG_IFACE} -j ACCEPT
PostDown = iptables -D FORWARD -i ${WG_IFACE} -o ${IFACE} -j ACCEPT

# ── Home PC peer ──────────────────────────────────────────────────────────────
# IMPORTANT: Replace <HOME_PC_PUBLIC_KEY> with the actual public key
# from the Home PC after running wg genkey | tee home_private.key | wg pubkey
[Peer]
PublicKey  = <HOME_PC_PUBLIC_KEY>
AllowedIPs = ${HOME_PEER_IP}
EOF

chmod 600 "${WG_DIR}/${WG_IFACE}.conf"
echo "[OK] ${WG_DIR}/${WG_IFACE}.conf written."

# ─── 4. Enable IP forwarding ──────────────────────────────────────────────────
echo "[*] Enabling ip_forward..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wg.conf
sysctl -p /etc/sysctl.d/99-wg.conf

# ─── 5. Host firewall: INPUT (iptables, not ufw) ────────────────────────────
# Ubuntu Noble: installing iptables-persistent removes ufw — use iptables directly.
echo "[*] iptables INPUT: WireGuard + Rust ports..."
iptables_allow_input() {
  local args=("$@")
  iptables -C INPUT "${args[@]}" 2>/dev/null || iptables -I INPUT 1 "${args[@]}"
}
iptables_allow_input -p udp --dport "${WG_PORT}"        -j ACCEPT
iptables_allow_input -p udp --dport "${RUST_GAME_UDP}"  -j ACCEPT
iptables_allow_input -p udp --dport "${RUST_QUERY_UDP}" -j ACCEPT
iptables_allow_input -p tcp --dport "${RUST_RCON_TCP}"  -j ACCEPT
iptables_allow_input -p tcp --dport "${RUST_PLUS_TCP}"  -j ACCEPT
if command -v netfilter-persistent >/dev/null 2>&1; then
  netfilter-persistent save
  echo "[OK] Правила збережено (netfilter-persistent)."
elif command -v iptables-save >/dev/null 2>&1 && [[ -d /etc/iptables ]]; then
  iptables-save > /etc/iptables/rules.v4
  echo "[OK] Збережено /etc/iptables/rules.v4"
else
  echo "[i] netfilter-persistent не знайдено — INPUT правила активні до перезавантаження; встановіть iptables-persistent."
fi

# ─── 6. Enable and start WireGuard ───────────────────────────────────────────
echo "[*] Starting wg-quick@${WG_IFACE}..."
systemctl enable wg-quick@${WG_IFACE}
wg-quick up ${WG_IFACE}

echo ""
echo "============================================================"
echo " WireGuard VPS setup COMPLETE."
echo ""
echo " NEXT STEPS:"
echo " 1. Copy the VPS public key above."
echo " 2. On the Home PC: generate keys and create WireGuard client config"
echo "    (see repo client/wg0-client.conf.example)."
echo " 3. Paste the Home PC public key into ${WG_DIR}/${WG_IFACE}.conf [Peer]."
echo " 4. Run: wg set ${WG_IFACE} peer <HOME_PC_PUBLIC_KEY> allowed-ips 10.8.0.2/32"
echo "    OR: systemctl restart wg-quick@${WG_IFACE}"
echo " 5. Verify tunnel: wg show"
echo "============================================================"
