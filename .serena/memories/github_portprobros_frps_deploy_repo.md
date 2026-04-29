## GitHub deploy repo (legacy)

Окремий репозиторій **`portprobros-frps-deploy`** раніше містив Docker Compose з **frps + DuckDNS**.

У **цьому** репозиторії (`portprobros`) сервіс **frps прибрано** — використовується **WireGuard + iptables** (`server/vps-wireguard-setup.sh`).

На VPS застарілий clone можна:
- залишити лише якщо там все ще крутиться старий frps — тоді **узгодь окремо**;
- або мігрувати на поточний `server/docker-compose.yml` (тільки DuckDNS) із цього репо.

Колишня вимога «однаковий `auth.token` у frps і frpc» **неактуальна** — `client/frpc.toml` видалено.
