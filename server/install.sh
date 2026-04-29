#!/usr/bin/env bash
# VPS: clone repo → sudo bash server/install.sh
# Опційно передайте секрети одним рядком (не зберігайте в історії bash):
#   sudo DUCKDNS_SUBDOMAIN=myhost DUCKDNS_TOKEN=xxxxx bash server/install.sh
#
# Якщо змінні не передані — очікується заповнений server/.env (скопіюйте з .env.example).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

require_root() {
  if [[ "${EUID:-0}" -ne 0 ]]; then
    echo "Запустіть від root: sudo bash server/install.sh"
    exit 1
  fi
}

ensure_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    return 0
  fi
  echo "[*] Встановлення Docker та Compose (apt)..."
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io
  if ! docker compose version >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-plugin \
      || DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-v2 \
      || true
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "[ERROR] docker compose недоступний після встановлення. Встановіть Docker Compose v2 вручну."
    exit 1
  fi
  systemctl enable docker >/dev/null 2>&1 || true
  systemctl start docker
}

write_env_from_env_vars() {
  if [[ -n "${DUCKDNS_TOKEN:-}" ]] && [[ -n "${DUCKDNS_SUBDOMAIN:-}" ]]; then
    umask 077
    printf 'DUCKDNS_SUBDOMAIN=%s\nDUCKDNS_TOKEN=%s\n' "$DUCKDNS_SUBDOMAIN" "$DUCKDNS_TOKEN" >"$SCRIPT_DIR/.env"
    echo "[OK] Записано server/.env з змінних середовища."
  fi
}

ensure_env_file() {
  write_env_from_env_vars
  if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
    if [[ -f "$SCRIPT_DIR/.env.example" ]]; then
      cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
      chmod 600 "$SCRIPT_DIR/.env"
    fi
    echo "[ERROR] Немає server/.env. Заповніть DUCKDNS_SUBDOMAIN і DUCKDNS_TOKEN або запустіть:"
    echo "  sudo DUCKDNS_SUBDOMAIN=... DUCKDNS_TOKEN=... bash server/install.sh"
    exit 1
  fi
  # shellcheck disable=SC1091
  set -a
  source "$SCRIPT_DIR/.env"
  set +a
  if [[ "${DUCKDNS_TOKEN:-}" == your-token-from-duckdns-website ]] || [[ -z "${DUCKDNS_TOKEN:-}" ]] \
    || [[ "${DUCKDNS_SUBDOMAIN:-}" == your_subdomain ]] || [[ -z "${DUCKDNS_SUBDOMAIN:-}" ]]; then
    echo "[ERROR] У server/.env все ще плейсхолдери або порожні значення. Виправте й повторіть."
    exit 1
  fi
}

run_duckdns() {
  echo "[*] DuckDNS (docker compose)..."
  docker compose -f "$SCRIPT_DIR/docker-compose.yml" --env-file "$SCRIPT_DIR/.env" up -d
}

run_wireguard_once() {
  local wg_conf="/etc/wireguard/wg0.conf"
  if [[ -f "$wg_conf" ]]; then
    echo "[i] $wg_conf уже є — пропускаємо vps-wireguard-setup.sh (щоб не перегенерувати ключі)."
    echo "    Перезапуск WG: systemctl restart wg-quick@wg0"
    return 0
  fi
  echo "[*] WireGuard + iptables..."
  bash "$SCRIPT_DIR/vps-wireguard-setup.sh"
}

require_root
ensure_docker
ensure_env_file
run_duckdns
run_wireguard_once

echo ""
echo "[OK] Готово: DuckDNS контейнер і WireGuard (якщо ще не було). Перевірка: docker compose ps ; wg show"
