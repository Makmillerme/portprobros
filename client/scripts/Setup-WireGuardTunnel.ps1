#Requires -RunAsAdministrator
<#
.SYNOPSIS
  One-shot: install WireGuard (if missing), generate keys, write client/wg0.conf.
  You only need the VPS public key (from vps-wireguard-setup.sh output).

.PARAMETER VpsPublicKey
  Optional - if omitted, you will be prompted.

.EXAMPLE
  cd d:\Project\myprog\portprobros
  .\client\scripts\Setup-WireGuardTunnel.ps1 -VpsPublicKey 'YOUR_VPS_PUBLIC_KEY_BASE64='

Run PowerShell as Administrator. Execution policy:
  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
#>

param(
    [string] $VpsPublicKey
)

$ErrorActionPreference = 'Stop'

if (-not $VpsPublicKey) {
    $VpsPublicKey = Read-Host 'Paste VPS public key (sudo cat /etc/wireguard/vps_public.key)'
}

& "$PSScriptRoot\Install-WireGuard.ps1"

& "$PSScriptRoot\New-WireGuardClientConfig.ps1" -VpsPublicKey $VpsPublicKey

Write-Host ''
Write-Host '[*] Opening WireGuard UI - Import tunnel from file:'
Write-Host "    $(Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')) 'wg0.conf')"
$wgUi = Join-Path $env:ProgramFiles 'WireGuard\wireguard.exe'
if (Test-Path $wgUi) {
    Start-Process $wgUi
} else {
    Write-Host 'WireGuard.exe not found - start WireGuard from Start Menu and Import tunnel.'
}
