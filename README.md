# portprobros

Rust Dedicated Server вдома → WireGuard-тунель → VPS (DuckDNS + DNAT) → гравці.

| Каталог | Призначення |
|---------|-------------|
| **`client/`** | Домашній ПК (Windows): WireGuard `scripts/*.ps1`, шаблон `wg0-client.conf.example`, запуск Rust DS `start.bat`. |
| **`server/`** | VPS: скрипти установки, `docker-compose.yml` (DuckDNS), `.env.example`. |

Rust Dedicated лежить на домашній машині; VPS дає публічну адресу, DNS і DNAT у WG-тунель до ПК.

---

## Deploy — VPS (server/)

### Debian / Ubuntu

```bash
git clone https://github.com/Makmillerme/portprobros.git && cd portprobros
sudo DUCKDNS_SUBDOMAIN=ваш_піддомен DUCKDNS_TOKEN=ваш_токен bash server/install.sh
```

### AlmaLinux 8 / RHEL 8-сумісні (dnf + firewalld)

```bash
git clone https://github.com/Makmillerme/portprobros.git && cd portprobros
sudo DUCKDNS_SUBDOMAIN=ваш_піддомен DUCKDNS_TOKEN=ваш_токен bash server/install-alma.sh
```

Перевірка після запуску:
```bash
docker compose -f server/docker-compose.yml ps   # DuckDNS контейнер
sudo wg show                                      # WireGuard інтерфейс
```

Записати секрети вручну (без передачі в рядку):
```bash
sudo cp server/.env.example server/.env
sudo nano server/.env    # заповніть DUCKDNS_SUBDOMAIN і DUCKDNS_TOKEN
sudo chmod 600 server/.env
sudo bash server/install-alma.sh
```

---

## Обмін ключами WireGuard (VPS ↔ дом Home PC)

1. Після запуску скрипта на VPS: скопіюйте **VPS public key** із виводу.
2. На Home PC: виконайте `client/scripts/New-WireGuardClientConfig.ps1` — отримаєте `client/wg0.conf` з ключем ПК.
3. Вставте Home PC public key у `/etc/wireguard/wg0.conf` на VPS у блок `[Peer]`.
4. `sudo systemctl restart wg-quick@wg0` на VPS.
5. На Home PC: `client/scripts/Setup-WireGuardTunnel.ps1`.
6. Перевірка: `sudo wg show` (VPS) і `ping 10.8.0.1` (з ПК).
