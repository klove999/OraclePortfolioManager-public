<#
paths_config.ps1 - Environment path configuration for Oracle Portfolio Manager
Version: v5.0.1
Author: Oracle (for Kirk)
Date: 2025-10-26
#>
param(
  [switch]$Quiet
)
$ErrorActionPreference = 'Stop'
# --- Detect roots ---
$programRoot = 'C:\Program Files\Oracle Portfolio Manager'
$dataRoot    = 'D:\Documents\OraclePortfolioManager'
# --- Derived paths ---
$bundleRoot  = Join-Path $dataRoot 'Options_OraclePortfolioManager.0.1_Stable'
$logsPath    = Join-Path $dataRoot 'logs'
$dataPath    = Join-Path $dataRoot 'data'
$configPath  = Join-Path $dataRoot 'config'
$exportsPath = Join-Path $dataRoot 'exports'
$bundlesPath = Join-Path $dataRoot 'bundles'
# --- Build object ---
$envInfo = [pscustomobject]@{
  ProgramRoot = $programRoot
  DataRoot    = $dataRoot
  BundleRoot  = $bundleRoot
  LogsPath    = $logsPath
  DataPath    = $dataPath
  ConfigPath  = $configPath
  ExportsPath = $exportsPath
  BundlesPath = $bundlesPath
}
# --- Validate and warn ---
$paths = @(
  @{ Label = 'Program Root' ; Path = $programRoot },
  @{ Label = 'Data Root'    ; Path = $dataRoot },
  @{ Label = 'Bundle Root'  ; Path = $bundleRoot },
  @{ Label = 'Logs Path'    ; Path = $logsPath },
  @{ Label = 'Data Path'    ; Path = $dataPath },
  @{ Label = 'Config Path'  ; Path = $configPath }
)
foreach ($p in $paths) {
  if (-not (Test-Path $p.Path)) {
    Write-Host ('[WARN] {0} missing: {1}' -f $p.Label, $p.Path) -ForegroundColor Yellow
  }
}
if (-not $Quiet) {
  Write-Host ''
  Write-Host 'Oracle Portfolio Manager Environment Summary' -ForegroundColor Cyan
  Write-Host '------------------------------------------------------'
  Write-Host ('Program Root : {0}' -f $programRoot)
  Write-Host ('Data Root    : {0}' -f $dataRoot)
  Write-Host ('Active Bundle: {0}' -f (Split-Path $bundleRoot -Leaf))
  Write-Host ('Logs Path    : {0}' -f $logsPath)
  Write-Host ('Data Path    : {0}' -f $dataPath)
  Write-Host ('Config Path  : {0}' -f $configPath)
  Write-Host ('Exports Path : {0}' -f $exportsPath)
  Write-Host ('Bundles Path : {0}' -f $bundlesPath)
  Write-Host '------------------------------------------------------'
  Write-Host 'All paths validated (warnings shown above if any).'
}
return $envInfo
