#!/usr/bin/env bash
# ==============================================================================
# VPS WireGuard + iptables DNAT setup for Rust Dedicated Server
# AlmaLinux 8 version (uses dnf + firewalld)
# Run as root: sudo bash vps-wireguard-setup-alma.sh
#
# What this does:
#   1. Installs EPEL + wireguard-tools (+ ELRepo kmod fallback)
#   2. Generates VPS WG keypair
#   3. Creates /etc/wireguard/wg0.conf with PostUp/PostDown iptables rules
#   4. Enables ip_forward (kernel + sysctl)
#   5. Opens UDP 51820 via firewalld; enables masquerade
#   6. Enables and starts wg-quick@wg0
#
# After running:
#   - Print VPS public key: cat /etc/wireguard/vps_public.key
#   - Add that key to Home PC WireGuard peer config
#   - Add Home PC public key to /etc/wireguard/wg0.conf [Peer]
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

# ─── 1. Install packages ──────────────────────────────────────────────────────────────────
echo "[*] Installing EPEL + wireguard-tools..."
dnf install -y epel-release
dnf install -y wireguard-tools

# Fallback: if kernel module not found — install from ELRepo
if ! modinfo wireguard >/dev/null 2>&1; then
  echo "[*] wireguard kernel module not found; trying ELRepo (kmod-wireguard)..."
  dnf install -y https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm || true
  dnf --enablerepo=elrepo install -y kmod-wireguard || true
  modprobe wireguard || {
    echo "[ERROR] Не вдалось завантажити wireguard. Оновіть ядро: dnf update kernel && reboot, потім повторіть."
    exit 1
  }
else
  modprobe wireguard
fi
echo "[OK] WireGuard module loaded."

# ─── 2. Generate server keypair ───────────────────────────────────────────────────────────────
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

# ─── 3. Create wg0.conf ─────────────────────────────────────────────────────────────────────
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

# ── Home PC peer ─────────────────────────────────────────────────────────────────────────
# IMPORTANT: Replace <HOME_PC_PUBLIC_KEY> with the actual key from the Home PC
[Peer]
PublicKey  = <HOME_PC_PUBLIC_KEY>
AllowedIPs = ${HOME_PEER_IP}
EOF

chmod 600 "${WG_DIR}/${WG_IFACE}.conf"
echo "[OK] ${WG_DIR}/${WG_IFACE}.conf written."

# ─── 4. Enable IP forwarding ──────────────────────────────────────────────────────────────
echo "[*] Enabling ip_forward..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wg.conf
sysctl -p /etc/sysctl.d/99-wg.conf

# ─── 5. Firewalld ────────────────────────────────────────────────────────────────────────────
echo "[*] Configuring firewalld..."
systemctl enable --now firewalld

# WireGuard listen port
firewall-cmd --permanent --add-port=${WG_PORT}/udp

# Rust DS ports (forwarded via iptables DNAT in PostUp; firewalld must allow them on the public zone)
firewall-cmd --permanent --add-port=${RUST_GAME_UDP}/udp
firewall-cmd --permanent --add-port=${RUST_QUERY_UDP}/udp
firewall-cmd --permanent --add-port=${RUST_RCON_TCP}/tcp
firewall-cmd --permanent --add-port=${RUST_PLUS_TCP}/tcp

# Enable masquerade (needed for SNAT/MASQUERADE to work alongside firewalld)
firewall-cmd --permanent --add-masquerade

firewall-cmd --reload
echo "[OK] firewalld configured."

# ─── 6. Enable and start WireGuard ───────────────────────────────────────────────────────────────────
echo "[*] Starting wg-quick@${WG_IFACE}..."
systemctl enable wg-quick@${WG_IFACE}
wg-quick up ${WG_IFACE}

echo ""
echo "============================================================"
echo " WireGuard VPS setup COMPLETE (AlmaLinux 8)."
echo ""
echo " NEXT STEPS:"
echo " 1. Скопіюйте VPS PUBLIC KEY вище."
echo " 2. На Home PC: cat client/wg0-client.conf.example — створіть wg0.conf"
echo "    (або запустіть PowerShell-скрипти з client/scripts/)."
echo " 3. Вставте Home PC public key в ${WG_DIR}/${WG_IFACE}.conf [Peer]."
echo " 4. systemctl restart wg-quick@${WG_IFACE}"
echo " 5. Перевірка: wg show"
echo "============================================================"
