#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Installs WireGuard for Windows from the project folder context (no manual browser download).
  Uses winget if available; otherwise downloads the latest amd64 MSI from GitHub releases.

.NOTES
  Windows still installs the Wintun driver — this cannot be avoided for a real WG tunnel.
  Run: PowerShell (Admin) -> cd repo -> .\client\scripts\Install-WireGuard.ps1
#>

$ErrorActionPreference = 'Stop'

function Get-WgExePath {
    $candidates = @(
        Join-Path $env:ProgramFiles 'WireGuard\wg.exe'
        Join-Path ${env:ProgramFiles(x86)} 'WireGuard\wg.exe'
    )
    foreach ($p in $candidates) {
        if (Test-Path $p) { return $p }
    }
    return $null
}

if (Get-WgExePath) {
    Write-Host '[OK] WireGuard already installed:' (Get-WgExePath)
    exit 0
}

Write-Host '[*] Installing WireGuard for Windows...'

$winget = Get-Command winget -ErrorAction SilentlyContinue
if ($winget) {
    try {
        & winget install --id WireGuard.WireGuard -e --accept-package-agreements --accept-source-agreements --silent 2>&1 | Write-Host
        for ($i = 0; $i -lt 30; $i++) {
            if (Get-WgExePath) {
                Write-Host '[OK] WireGuard installed via winget.'
                exit 0
            }
            Start-Sleep -Seconds 1
        }
        Write-Warning 'winget finished but wg.exe not found yet — trying MSI fallback...'
    }
    catch {
        Write-Warning "winget failed: $_ — trying MSI fallback..."
    }
}

Write-Host '[*] Downloading latest WireGuard MSI from GitHub (WireGuard/wireguard-windows)...'
$releasesUri = 'https://api.github.com/repos/WireGuard/wireguard-windows/releases/latest'
$rel = Invoke-RestMethod -Uri $releasesUri -Headers @{ 'User-Agent' = 'portprobros-setup' }
$msi = $rel.assets | Where-Object { $_.name -match '^wireguard-amd64-.+\.msi$' } | Select-Object -First 1
if (-not $msi) {
    throw 'Could not find wireguard-amd64-*.msi in latest GitHub release.'
}

$toolsDir = Join-Path $PSScriptRoot '..\tools\downloads'
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
$msiPath = Join-Path $toolsDir $msi.name
Invoke-WebRequest -Uri $msi.browser_download_url -OutFile $msiPath -UseBasicParsing

Write-Host '[*] Running silent MSI install (needs Admin — you already elevated)...'
$p = Start-Process -FilePath 'msiexec.exe' -ArgumentList @('/i', "`"$msiPath`"", '/qn', '/norestart') -Wait -PassThru
if ($p.ExitCode -ne 0) {
    throw "msiexec exited with $($p.ExitCode)"
}

Start-Sleep -Seconds 2
if (-not (Get-WgExePath)) {
    throw 'WireGuard wg.exe still not found after MSI install. Reboot and run again, or install manually.'
}

Write-Host '[OK] WireGuard installed from MSI:' (Get-WgExePath)
