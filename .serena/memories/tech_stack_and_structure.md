# Tech stack and structure

## Stack

WireGuard + iptables DNAT on VPS, DuckDNS in Docker, Rust DS on home PC.

## Layout

```
portprobros/
  README.md
  client/
    start.bat
    wg0-client.conf.example
    scripts/           Install-WireGuard.ps1, New-WireGuardClientConfig.ps1, Setup-WireGuardTunnel.ps1
  server/
    install.sh
    docker-compose.yml
    vps-wireguard-setup.sh
    .env.example
```

FRP removed.

## Security

`server/.env`, `client/wg0.conf`, `*.key` — gitignored.
