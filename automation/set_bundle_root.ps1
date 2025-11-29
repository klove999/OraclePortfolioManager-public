<#
set_bundle_root.ps1 — Oracle Portfolio Manager Helper
Version : v5.0.7
Author  : Oracle (for Kirk)
Date    : 2025-10-27

Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File set_bundle_root.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File set_bundle_root.ps1 -CustomRoot "D:\Alt\Bundles"
  pwsh -NoProfile -ExecutionPolicy Bypass -File set_bundle_root.ps1 -ValidateStructure
#>

param(
  [string]$CustomRoot,
  [switch]$ValidateStructure
)

$ErrorActionPreference = 'Stop'

# ── Resolve bundle root
if ($CustomRoot) {
  $bundleRoot = $CustomRoot
  Write-Host ("[INFO] Using custom bundle root: {0}" -f $bundleRoot) -ForegroundColor Cyan
} elseif ($env:BUNDLE_ROOT) {
  $bundleRoot = $env:BUNDLE_ROOT
  Write-Host ("[INFO] Using existing BUNDLE_ROOT: {0}" -f $bundleRoot) -ForegroundColor Cyan
} else {
  $bundleRoot = "D:\Documents\OraclePortfolioManager\bundles"
  Write-Host ("[INFO] Defaulting to standard bundle root: {0}" -f $bundleRoot) -ForegroundColor Cyan
}

# ── Ensure root directory
if (-not (Test-Path $bundleRoot)) {
  Write-Host "[STEP] Creating bundle root directory..." -ForegroundColor Yellow
  New-Item -ItemType Directory -Force -Path $bundleRoot | Out-Null
  Write-Host ("[OK] Created: {0}" -f $bundleRoot) -ForegroundColor Green
} else {
  Write-Host "[OK] Bundle root exists." -ForegroundColor DarkGray
}

# ── Ensure baseline checksum file
$checksumFile = Join-Path $bundleRoot "bundle_checksum.txt"
if (-not (Test-Path $checksumFile)) {
  @(
    "SHA256 Checksums",
    "================",
    "# Baseline generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  ) | Set-Content $checksumFile -Encoding UTF8
  Write-Host ("[OK] Created baseline: {0}" -f $checksumFile) -ForegroundColor Green
} else {
  Write-Host "[OK] bundle_checksum.txt present." -ForegroundColor DarkGray
}

# ── Persist env var
[Environment]::SetEnvironmentVariable("BUNDLE_ROOT", $bundleRoot, "User")
$env:BUNDLE_ROOT = $bundleRoot
Write-Host ("[OK] BUNDLE_ROOT set to: {0}" -f $bundleRoot) -ForegroundColor Green

# ── Optional: validate structure of each versioned bundle
if ($ValidateStructure) {
  Write-Host "[STEP] Validating bundle folder structures..." -ForegroundColor Yellow
  $needed = @('docs','logs','exports','automation')
  $bundles = Get-ChildItem $bundleRoot -Directory -ErrorAction SilentlyContinue

  if (-not $bundles) {
    Write-Host "[WARN] No versioned bundle folders found to validate." -ForegroundColor Yellow
  } else {
    foreach ($b in $bundles) {
      # Only validate folders that look like versioned bundles
      if ($b.Name -like "Options_Oracle_Portfolio_Manager_*") {
        Write-Host ("[INFO] Checking: {0}" -f $b.FullName) -ForegroundColor Cyan
        foreach ($sub in $needed) {
          $p = Join-Path $b.FullName $sub
          if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Force -Path $p | Out-Null
            # .keep so git/zip keep empty dirs if needed
            New-Item -ItemType File -Force -Path (Join-Path $p ".keep") | Out-Null
            Write-Host ("  [FIX] Created: {0}" -f $p) -ForegroundColor Green
          } else {
            Write-Host ("  [OK] {0}" -f $p) -ForegroundColor DarkGray
          }
        }
      }
    }
  }
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ Bundle Root Configuration Complete" -ForegroundColor Green
Write-Host ("Bundle Root : {0}" -f $bundleRoot) -ForegroundColor DarkGray
Write-Host ("Checksum    : {0}" -f $checksumFile) -ForegroundColor DarkGray
Write-Host ("Timestamp   : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
Write-Host "===============================================" -ForegroundColor Green
exit 0
