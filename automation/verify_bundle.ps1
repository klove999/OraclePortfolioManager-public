<#
verify_bundle.ps1 — strict & safe SHA256 verifier (no over-trimming)
Author: Oracle (for Kirk)
Date: 2025-10-26
#>

param(
  [Parameter(Mandatory = $true)]
  [string]$BundleRoot
)

$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host $m -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host $m -ForegroundColor Green }
function Write-Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

$root = (Resolve-Path -Path $BundleRoot -ErrorAction Stop).Path
$checksumPath = Join-Path $root 'bundle_checksum.txt'
if (-not (Test-Path $checksumPath)) {
  Write-Err "[ERROR] bundle_checksum.txt not found at: $checksumPath"
  exit 1
}

Write-Info "[INFO] Verifying bundle at: $root"
Write-Info "[INFO] Using checksums from: $checksumPath"

$raw = Get-Content -Path $checksumPath -Encoding UTF8
$entries = @()

foreach ($line in $raw) {
  $l = $line.Trim()
  if (-not $l) { continue }
  if ($l -match '^(sha256|=+|[- ]*checksums?[- ]*)$') { continue }  # skip header lines

  if ($l -match '^\s*([0-9A-Fa-f]{64})\s+(.+)$') {
    $hash = $matches[1].ToUpper()
    $rel  = $matches[2].Trim()

    # Only remove a single leading .\ or ./ if present. Do not TrimStart arbitrary chars.
    if ($rel.StartsWith('.\')) { $rel = $rel.Substring(2) }
    elseif ($rel.StartsWith('./')) { $rel = $rel.Substring(2) }

    # Normalize to Windows separators; do NOT remove first character after that.
    $rel = $rel -replace '/', '\'

    # Reject absolute paths (manifest must be relative)
    if ([System.IO.Path]::IsPathRooted($rel)) {
      Write-Err "[ERROR] Manifest contains an absolute path: $rel"
      exit 1
    }

    $entries += [pscustomobject]@{ Hash = $hash; RelativePath = $rel }
  }
}

if ($entries.Count -eq 0) {
  Write-Err "[ERROR] No checksum entries parsed from bundle_checksum.txt"
  exit 1
}

# Verify
$mismatches = @()
$missing    = @()
$verified   = 0

foreach ($e in $entries) {
  $full = Join-Path $root $e.RelativePath
  if (-not (Test-Path $full)) {
    $missing += $e.RelativePath
    continue
  }
  $calc = (Get-FileHash -Algorithm SHA256 -Path $full).Hash.ToUpper()
  if ($calc -ne $e.Hash) {
    $mismatches += [pscustomobject]@{ RelativePath = $e.RelativePath; Expected = $e.Hash; Actual = $calc }
  } else {
    $verified++
  }
}

# Informational: extras not in manifest (ignore checksum file itself)
$allFiles = Get-ChildItem -Path $root -Recurse -File | Where-Object { $_.Name -ne 'bundle_checksum.txt' } | ForEach-Object { $_.FullName }
$manifestSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($e in $entries) { [void]$manifestSet.Add((Join-Path $root $e.RelativePath)) }
$extras = @()
foreach ($f in $allFiles) { if (-not $manifestSet.Contains($f)) { $extras += $f.Substring($root.Length).TrimStart('\') } }

Write-Info ("[INFO] Files verified: {0}" -f $verified)
if ($missing.Count -gt 0)   { Write-Err  ("[ERROR] Missing files: {0}" -f $missing.Count) }
if ($mismatches.Count -gt 0){ Write-Err  ("[ERROR] Hash mismatches: {0}" -f $mismatches.Count) }
if ($extras.Count -gt 0)    { Write-Warn ("[WARN] Extra files not in manifest: {0}" -f $extras.Count) }

if ($missing.Count -gt 0) {
  Write-Host "`nMissing:"
  $missing | ForEach-Object { Write-Host ("  - {0}" -f $_) }
}
if ($mismatches.Count -gt 0) {
  Write-Host "`nMismatches:"
  foreach ($m in $mismatches) {
    Write-Host ("  - {0}" -f $m.RelativePath)
    Write-Host ("      expected: {0}" -f $m.Expected)
    Write-Host ("      actual  : {0}" -f $m.Actual)
  }
}
if ($extras.Count -gt 0) {
  Write-Host "`nExtras (not in bundle_checksum.txt):"
  $extras | ForEach-Object { Write-Host ("  - {0}" -f $_) }
}

if (($missing.Count -eq 0) -and ($mismatches.Count -eq 0)) {
  Write-Ok "`n[OK] All files match checksums. Bundle integrity verified."
  exit 0
} else {
  Write-Err "`n[FAILED] Integrity check failed. See details above."
  exit 1
}
