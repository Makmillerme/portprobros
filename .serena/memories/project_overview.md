# PortProBros overview

Infra repo: Rust Dedicated at home, reachable via WireGuard + iptables DNAT on VPS; DuckDNS for domain.

- **`client/`** — Windows: WG scripts, `start.bat`, `wg0-client.conf.example`.
- **`server/`** — VPS: `docker-compose.yml` (duckdns), `vps-wireguard-setup.sh`, `.env.example`.

Game files: `D:\RustServer\Server` (outside repo).
