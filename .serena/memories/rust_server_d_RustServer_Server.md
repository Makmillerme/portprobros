## D:\RustServer\Server (Facepunch Rust DS)

### Launch
- `Run_DS.bat` — `cd /d "%~dp0"`, SteamCMD update, then:
  `RustDedicated.exe -batchmode +server.ip "0.0.0.0" +app.listenip "0.0.0.0" +server.identity "my_server" -logfile "output.txt"`
- Loop with `timeout /t 5` before `goto start` to prevent SteamCMD hammering on crash.
- Started from `portprobros/client/start.bat` (WireGuard tunnel check included).

### Ports
| Port  | Proto | Purpose                     |
|-------|-------|-----------------------------|
| 28015 | UDP   | Game traffic                |
| 28017 | UDP   | Steam query / server browser|
| 28016 | TCP   | RCON (WebSocket mode)       |
| 28082 | TCP   | Rust+ Companion Server      |

### server.cfg keys (rustds/server/my_server/cfg/server.cfg)
- `server.ip "0.0.0.0"`, `server.maxplayers 50`, `server.tags "monthly,vanilla,UA"`
- `app.port 28082`, `app.publicip "91.239.232.91"` (VPS IP — Facepunch wiki)
- `app.listenip "0.0.0.0"`
- RCON password ≥ 8 chars, `rcon.web 1`

### Tunnel: WireGuard + iptables DNAT (replaces old FRP UDP)
- VPS script: `portprobros/server/vps-wireguard-setup.sh`
- WG subnet: VPS = 10.8.0.1, Home PC = 10.8.0.2; UDP 51820.
- VPS iptables DNAT: 28015/udp, 28017/udp, 28016/tcp, 28082/tcp → 10.8.0.2.
- Home WG template: `portprobros/client/wg0-client.conf.example`
- PowerShell automation: `portprobros/client/scripts/*.ps1`

### VPS: DuckDNS only (repo `server/docker-compose.yml`)
- No frps in repo — DNS updater container only.

### Home PC automation (repo)
- `client/scripts/Install-WireGuard.ps1`, `New-WireGuardClientConfig.ps1`, `Setup-WireGuardTunnel.ps1`
- Secrets: `.gitignore` covers `client/wg0.conf`, `client/*.key`

### Verification after start
- `wg show` on VPS — handshake timestamps.
- `iptables -t nat -L PREROUTING -n -v` — packet counters on DNAT rules.
- Rust console `app.info` — port/IP match server.cfg.
- Players in log as `10.8.0.1:<port>` (not `127.0.0.1`).
- Two Steam accounts connect without Auth Failed.
