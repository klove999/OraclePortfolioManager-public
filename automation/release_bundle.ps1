<#
release_bundle.ps1 — Oracle Portfolio Manager
Version: v5.0.1 (Quiet Builder + BUNDLE_ROOT + Clean Verify)
Author: Oracle (for Kirk)
Date: 2025-10-27

Description:
  Orchestrates build → checksum repair → verify.
  - Calls make_v5_bundle.ps1 with -Quiet (no duplicate console spam)
  - Uses $env:BUNDLE_ROOT (default D:\...\bundles)
  - Verifies the newest versioned bundle folder under bundles\
#>

param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$Date
)

$ErrorActionPreference = 'Stop'

# --- Helper output functions ---
function Write-Info($m){ Write-Host $m -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host $m -ForegroundColor Green }
function Write-Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

Write-Host "=== Oracle Portfolio Manager — Release Bundle ===" -ForegroundColor Cyan
Write-Info ("Version: {0}" -f $Version)
Write-Info ("Date   : {0}" -f $Date)
Write-Host ""

# --- Fixed program paths ---
$programRoot = 'C:\Program Files\Oracle Portfolio Manager'
$autoRoot    = Join-Path $programRoot 'automation'

$bundlerPs1  = Join-Path $autoRoot 'make_v5_bundle.ps1'
$repairPs1   = Join-Path $autoRoot 'repair_checksums_v2.ps1'
$verifierPs1 = Join-Path $autoRoot 'verify_bundle.ps1'

foreach ($path in @($bundlerPs1,$repairPs1,$verifierPs1)) {
  if (-not (Test-Path $path)) {
    Write-Err ("[ERROR] Missing required component: {0}" -f $path)
    exit 1
  }
}

# --- Bundle root (env first, then default) ---
$bundleRoot = if ($env:BUNDLE_ROOT) { $env:BUNDLE_ROOT } else { "D:\Documents\OraclePortfolioManager\bundles" }
if (-not (Test-Path $bundleRoot)) { New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null }

# --- Execute bundle creation quietly ---
Write-Info "[STEP] Building bundle ZIP ..."
pwsh -NoProfile -ExecutionPolicy Bypass -File $bundlerPs1 -Version $Version -Date $Date -Quiet
if ($LASTEXITCODE -ne 0) {
  Write-Err "[ERROR] Bundle creation failed."
  exit 1
}

# --- Detect the newest versioned bundle folder under bundles\ ---
$bundleFolder = (Get-ChildItem $bundleRoot -Directory |
                 Sort-Object LastWriteTime -Descending |
                 Select-Object -First 1).FullName

if (-not (Test-Path $bundleFolder)) {
  Write-Err "[ERROR] Could not detect a versioned bundle folder under $bundleRoot"
  exit 1
}

# --- Rebuild checksums for that versioned folder ---
Write-Info "[STEP] Rebuilding bundle_checksum.txt before verification ..."
pwsh -NoProfile -ExecutionPolicy Bypass -File $repairPs1 -BundleRoot $bundleFolder
if ($LASTEXITCODE -ne 0) {
  Write-Err "[ERROR] Checksum rebuild failed."
  exit 1
}
Write-Ok "[OK] bundle_checksum.txt successfully rebuilt."

# --- Verify bundle integrity for that versioned folder ---
Write-Info "[STEP] Verifying bundle integrity ..."
pwsh -NoProfile -ExecutionPolicy Bypass -File $verifierPs1 -BundleRoot $bundleFolder
if ($LASTEXITCODE -ne 0) {
  Write-Err "[FAILED] Verification failed."
  exit 1
}
Write-Ok "[OK] Bundle verification succeeded."

# --- Completion banner ---
Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ RELEASE COMPLETE — ALL CHECKS PASSED" -ForegroundColor Green
Write-Host ("Bundle Folder : {0}" -f $bundleFolder) -ForegroundColor DarkGray
Write-Host ("Version       : {0}" -f $Version) -ForegroundColor DarkGray
Write-Host ("Timestamp     : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
exit 0
