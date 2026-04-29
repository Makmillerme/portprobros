# portprobros

| Каталог | Призначення |
|---------|-------------|
| **`client/`** | Домашній ПК (Windows): WireGuard `scripts/*.ps1`, шаблон `wg0-client.conf.example`, запуск Rust DS `start.bat`. |
| **`server/`** | VPS: `install.sh` (одним проходом DuckDNS + WireGuard), `docker-compose.yml`, `vps-wireguard-setup.sh`, `.env.example`. |

Rust Dedicated лежить на домашній машині; VPS дає публічну адресу, DNS і DNAT у WG-тунель до ПК.

**VPS:** після `git clone`: `sudo bash server/install.sh` (або `sudo DUCKDNS_SUBDOMAIN=… DUCKDNS_TOKEN=… bash server/install.sh`, або заповнений `server/.env`).
