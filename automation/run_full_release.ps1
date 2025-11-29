<#
run_full_release.ps1 — Oracle Portfolio Manager
Version : v5.0.8
Author  : Oracle (for Kirk)
Date    : 2025-10-27

Purpose:
  Performs a full automated release cycle:
    1. Builds the bundle (quiet mode)
    2. Repairs bundle checksums
    3. Verifies all checksums
    4. Archives and logs results
  Automatically detects $env:BUNDLE_ROOT or defaults to D:\Documents\OraclePortfolioManager\bundles.
#>

param(
  [string]$Version = "v5.0.8",
  [string]$Date = (Get-Date -Format "yyyy-MM-dd"),
  [switch]$SkipArchive,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ if (-not $Quiet) { Write-Host $m -ForegroundColor Cyan } }
function Write-Ok($m){ if (-not $Quiet) { Write-Host $m -ForegroundColor Green } }
function Write-Warn($m){ if (-not $Quiet) { Write-Host $m -ForegroundColor Yellow } }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

Write-Host ""
Write-Host "=== Oracle Portfolio Manager — Full Release Cycle ===" -ForegroundColor Cyan
Write-Info ("Version: {0}" -f $Version)
Write-Info ("Date   : {0}" -f $Date)
Write-Host ""

# --- Resolve key paths ---
$programRoot = "C:\Program Files\Oracle Portfolio Manager"
$autoRoot    = Join-Path $programRoot "automation"
$bundleRoot  = if ($env:BUNDLE_ROOT) { $env:BUNDLE_ROOT } else { "D:\Documents\OraclePortfolioManager\bundles" }

$makePs1     = Join-Path $autoRoot "make_v5_bundle.ps1"
$repairPs1   = Join-Path $autoRoot "repair_checksums_v2.ps1"
$verifyPs1   = Join-Path $autoRoot "verify_bundle.ps1"

foreach ($req in @($makePs1,$repairPs1,$verifyPs1)) {
  if (-not (Test-Path $req)) {
    Write-Err ("[ERROR] Missing required script: {0}" -f $req)
    exit 1
  }
}

# --- 1️⃣ Build the bundle ---
Write-Info "[STEP 1] Building bundle ZIP..."
pwsh -NoProfile -ExecutionPolicy Bypass -File $makePs1 -Version $Version -Date $Date -Quiet
if ($LASTEXITCODE -ne 0) { Write-Err "[ERROR] Bundle build failed."; exit 1 }
Write-Ok "[OK] Bundle build completed."

# --- Detect newest bundle folder ---
$bundleFolder = (Get-ChildItem $bundleRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
if (-not (Test-Path $bundleFolder)) {
  Write-Err "[ERROR] No bundle folder detected in $bundleRoot"
  exit 1
}

# --- 2️⃣ Repair checksums ---
Write-Info "[STEP 2] Repairing checksums..."
pwsh -NoProfile -ExecutionPolicy Bypass -File $repairPs1 -BundleRoot $bundleFolder
if ($LASTEXITCODE -ne 0) { Write-Err "[ERROR] Checksum rebuild failed."; exit 1 }
Write-Ok "[OK] Checksum rebuild complete."

# --- 3️⃣ Verify integrity ---
Write-Info "[STEP 3] Verifying bundle integrity..."
pwsh -NoProfile -ExecutionPolicy Bypass -File $verifyPs1 -BundleRoot $bundleFolder
if ($LASTEXITCODE -ne 0) { Write-Err "[ERROR] Verification failed."; exit 1 }
Write-Ok "[OK] All files verified."

# --- 4️⃣ Archive + Log ---
$logDir = Join-Path $bundleRoot "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("Release_Log_{0}.txt" -f (Get-Date -Format "yyyy-MM-dd_HHmmss"))

$logContent = @(
  "Oracle Portfolio Manager — Full Release Log",
  "===========================================",
  "Version     : $Version",
  "Date        : $Date",
  "Bundle Root : $bundleRoot",
  "Bundle Path : $bundleFolder",
  "Status      : SUCCESS",
  "Timestamp   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
  ""
)
$logContent | Set-Content $logFile
Write-Ok ("[OK] Release log written to: {0}" -f $logFile)

# --- 5️⃣ Optional archive (ZIP copy) ---
if (-not $SkipArchive) {
  Write-Info "[STEP 4] Archiving bundle folder..."
  $archiveDir = Join-Path $bundleRoot "archives"
  if (-not (Test-Path $archiveDir)) { New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null }

  $zipName = ("Oracle_PM_{0}_{1}.zip" -f $Version, (Get-Date -Format "yyyyMMdd_HHmmss"))
  $zipPath = Join-Path $archiveDir $zipName
  Compress-Archive -Path (Join-Path $bundleFolder '*') -DestinationPath $zipPath -Force
  Write-Ok ("[OK] Bundle archived to: {0}" -f $zipPath)
} else {
  Write-Warn "[WARN] Skipped archiving per -SkipArchive flag."
}


# --- Summary ---
$archiveDisplay = if ($SkipArchive) { "(Skipped)" } else { $zipPath }

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ FULL RELEASE SUCCESSFUL — ALL CHECKS PASSED" -ForegroundColor Green
Write-Host ("Bundle Folder : {0}" -f $bundleFolder) -ForegroundColor DarkGray
Write-Host ("Version       : {0}" -f $Version) -ForegroundColor DarkGray
Write-Host ("Log File      : {0}" -f $logFile) -ForegroundColor DarkGray
Write-Host ("Archive File  : {0}" -f $archiveDisplay) -ForegroundColor DarkGray
Write-Host ("Timestamp     : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
Write-Host "===============================================" -ForegroundColor Green
exit 0
