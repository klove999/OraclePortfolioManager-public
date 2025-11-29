<#
repair_checksums.ps1 — Rebuild bundle_checksum.txt in strict, verifier-friendly format
Author: Oracle (for Kirk) • Date: 2025-10-26

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File automation\repair_checksums.ps1 [-BundleRoot <path>]

Behavior:
  - If -BundleRoot is not supplied, loads automation\paths_config.ps1 and uses its BundleRoot.
  - Writes UTF-8 file with CRLF and header lines followed by entries:
        <64-hex><two spaces> .\relative\path
#>
param(
  [string]$BundleRoot
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host $m -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host $m -ForegroundColor Green }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

if (-not $BundleRoot) {
  $pathsScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'paths_config.ps1'
  if (-not (Test-Path $pathsScript)) { Write-Err '[ERROR] paths_config.ps1 not found and -BundleRoot not supplied.'; exit 1 }
  $envInfo = & $pathsScript -Quiet
  $BundleRoot = $envInfo.BundleRoot
}

if (-not (Test-Path $BundleRoot)) { Write-Err ("[ERROR] BundleRoot not found: {0}" -f $BundleRoot); exit 1 }

$root = (Resolve-Path -Path $BundleRoot).Path
$checksum = Join-Path $root 'bundle_checksum.txt'

Write-Info ("[STEP] Rebuilding checksums for: {0}" -f $root)
"SHA256 Checksums`r`n================" | Set-Content -Path $checksum -Encoding UTF8

Get-ChildItem -Path $root -Recurse -File |
  Sort-Object FullName |
  ForEach-Object {
    $rel  = '.\' + $_.FullName.Substring((Resolve-Path $root).Path.Length).TrimStart('\\','/')
    $hash = (Get-FileHash -Algorithm SHA256 -Path $_.FullName).Hash.ToUpper()
    "$hash  $rel"
  } | Add-Content -Path $checksum -Encoding UTF8

Write-Ok '[OK] bundle_checksum.txt rebuilt.'
Write-Info ("       File: {0}" -f $checksum)
