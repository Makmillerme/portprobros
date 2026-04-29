# Task completion checklist

1. **Конфігурація**
   - Порти Rust на VPS (UFW) збігаються з DNAT у `server/vps-wireguard-setup.sh` / iptables.
   - `server.cfg`: `app.publicip` = публічний IP VPS; query/game порти як у тунелі.

2. **Запуск**
   - На VPS: DuckDNS контейнер працює (`docker compose logs duckdns`).
   - На ПК: WireGuard активний перед `start.bat`.

3. **Мережа**
   - DNS оновлюється (DuckDNS).
   - Гравці доходять до домашнього Rust DS через WG + DNAT.

4. **Безпека**
   - `server/.env` не в git; ключі WG (`client/wg0.conf`, `*.key`) у `.gitignore`.

5. **Документація**
   - Оновлювати `.serena/memories/` після суттєвих змін.
