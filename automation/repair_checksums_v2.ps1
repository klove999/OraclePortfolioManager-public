<#
repair_checksums_v2.ps1 — Hardened bundle checksum builder (2025-10-26)
Author: Oracle (for Kirk)

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File automation\repair_checksums_v2.ps1 [-BundleRoot <path>]

Behavior:
  • Auto-detects BundleRoot via automation\paths_config.ps1 if not supplied.
  • Excludes bundle_checksum.txt from hashing.
  • Writes UTF-8 file with CRLF endings and consistent relative paths:
        <64-hex><two spaces> .\relative\path
#>

param(
  [string]$BundleRoot
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host $m -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host $m -ForegroundColor Green }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

# --- Resolve bundle root ---
if (-not $BundleRoot) {
  $pathsScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'paths_config.ps1'
  if (-not (Test-Path $pathsScript)) {
    Write-Err '[ERROR] paths_config.ps1 not found and -BundleRoot not supplied.'
    exit 1
  }
  $envInfo = & $pathsScript -Quiet
  $BundleRoot = $envInfo.BundleRoot
}

if (-not (Test-Path $BundleRoot)) {
  Write-Err ("[ERROR] BundleRoot not found: {0}" -f $BundleRoot)
  exit 1
}

$root = (Resolve-Path -Path $BundleRoot).Path
$checksum = Join-Path $root 'bundle_checksum.txt'

Write-Info ("[STEP] Rebuilding checksums for: {0}" -f $root)
"SHA256 Checksums`r`n================" | Set-Content -Path $checksum -Encoding UTF8

# --- Build manifest using robust .NET path APIs ---
Get-ChildItem -Path $root -Recurse -File |
  Where-Object { $_.Name -ne 'bundle_checksum.txt' } |
  Sort-Object FullName |
  ForEach-Object {
    $relCore = [System.IO.Path]::GetRelativePath($root, $_.FullName)
    $rel = '.\' + ($relCore -replace '/', '\')
    $hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash.ToUpper()
    "$hash  $rel"
  } | Add-Content -Path $checksum -Encoding UTF8

Write-Ok '[OK] bundle_checksum.txt rebuilt successfully.'
Write-Info ("       File: {0}" -f $checksum)
