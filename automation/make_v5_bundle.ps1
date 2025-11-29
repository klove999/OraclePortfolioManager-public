<#
make_v5_bundle.ps1 — Oracle Portfolio Manager
Version: v5.0.1 (BUNDLE_ROOT + Quiet + Self-Source Safe)
Author: Oracle (for Kirk)
Date: 2025-10-27

Purpose:
  Build a release bundle from the newest stable folder.
  - Uses BUNDLE_ROOT if set; otherwise defaults to D:\...\bundles
  - Prefers newest stable SOURCE from bundles\ (fallback to data root)
  - Copies into versioned TARGET under bundles\ (unless source == target)
  - Creates a timestamped ZIP under bundles\
#>

param(
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$Date,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ if (-not $Quiet) { Write-Host $m -ForegroundColor Cyan } }
function Write-Ok($m){ if (-not $Quiet) { Write-Host $m -ForegroundColor Green } }
function Write-Warn($m){ if (-not $Quiet) { Write-Host $m -ForegroundColor Yellow } }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

if (-not $Quiet) { Write-Info "[STEP] Starting bundle build process..." }

# --- Bases ---
$dataRoot   = "D:\Documents\OraclePortfolioManager"
$bundleRoot = if ($env:BUNDLE_ROOT) { $env:BUNDLE_ROOT } else { Join-Path $dataRoot 'bundles' }
if (-not (Test-Path $bundleRoot)) { New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null }

# --- Detect newest stable SOURCE (prefer bundles\; fallback to data root) ---
$sourceRoot =
  (Get-ChildItem $bundleRoot -Directory -ErrorAction SilentlyContinue |
     Where-Object { $_.Name -like "Options_Oracle_Portfolio_Manager_*_Stable" } |
     Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName

if (-not $sourceRoot) {
  $sourceRoot =
    (Get-ChildItem $dataRoot -Directory -ErrorAction SilentlyContinue |
       Where-Object { $_.Name -like "Options_Oracle_Portfolio_Manager_*_Stable" } |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}

if (-not (Test-Path $sourceRoot)) {
  Write-Err "[ERROR] No stable source folder found under $bundleRoot or $dataRoot"
  exit 1
}
if (-not $Quiet) { Write-Info ("[INFO] Using source folder: {0}" -f $sourceRoot) }

# --- Target (ALWAYS under bundles\) ---
$targetRoot = Join-Path $bundleRoot ("Options_Oracle_Portfolio_Manager_{0}_Stable" -f $Version)

# --- Detect self-source condition ---
$didCopy = $false
if ($sourceRoot -eq $targetRoot) {
  if (-not $Quiet) { Write-Warn "[WARN] Source and target are identical — skipping file copy." }
} else {
  if (-not (Test-Path $targetRoot)) {
    New-Item -ItemType Directory -Path $targetRoot | Out-Null
    if (-not $Quiet) { Write-Info "[INFO] Created target bundle directory: $targetRoot" }
  }

  # --- Copy core documents ---
  $docs = @('README.md','CHANGELOG.md','VERSION_addendum.json','README_EXPORT.txt')
  foreach ($doc in $docs) {
    $src = Join-Path $sourceRoot $doc
    if (Test-Path $src) {
      Copy-Item $src $targetRoot -Force
      if (-not $Quiet) { Write-Info ("[INFO] Copied {0}" -f $doc) }
    } else {
      if (-not $Quiet) { Write-Warn ("[WARN] Missing document: {0}" -f $src) }
    }
  }

  # --- Copy docs\ and logs\ subfolders if present ---
  foreach ($sub in @('docs','logs')) {
    $srcDir = Join-Path $sourceRoot $sub
    $dstDir = Join-Path $targetRoot $sub
    if (Test-Path $srcDir) {
      Copy-Item $srcDir $dstDir -Recurse -Force
      if (-not $Quiet) { Write-Info ("[INFO] Copied {0} directory." -f $sub) }
    } else {
      if (-not $Quiet) { Write-Warn ("[WARN] Missing source directory: {0}" -f $srcDir) }
    }
  }
  $didCopy = $true
}

# --- Create timestamped ZIP under bundles\ ---
$zipName = ("Options_Oracle_Portfolio_Manager_{0}_{1}.zip" -f $Version, (Get-Date -Format "yyyyMMdd_HHmmss"))
$zipPath = Join-Path $bundleRoot $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

# ZIP what? If we copied to target, zip target; else zip source
$zipSource = if ($didCopy) { $targetRoot } else { $sourceRoot }
Compress-Archive -Path (Join-Path $zipSource '*') -DestinationPath $zipPath -Force
if (-not $Quiet) { Write-Ok ("[OK] Bundle ZIP created: {0}" -f $zipPath) }

if (-not $Quiet) { Write-Info "[STEP] Bundle build process complete." }
exit 0
