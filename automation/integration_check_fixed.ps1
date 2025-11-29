<# 
integration_check.ps1 â€” Environment diagnostic for Options Oracle Portfolio Manager v5
Version: v5.0.1
Author: Oracle (for Kirk)
Date: 2025-10-26
#>

$ErrorActionPreference = 'Stop'

function Write-Info($m){ Write-Host $m -ForegroundColor Cyan }
function Write-Ok($m){ Write-Host $m -ForegroundColor Green }
function Write-Warn($m){ Write-Host $m -ForegroundColor Yellow }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

Write-Info '[STEP] Loading environment configuration...'
$pathsScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'paths_config.ps1'
if (-not (Test-Path $pathsScript)) {
    Write-Err '[ERROR] paths_config.ps1 missing from automation folder.'
    exit 1
}

$envInfo = & $pathsScript -Quiet
$programRoot = $envInfo.ProgramRoot
$dataRoot    = $envInfo.DataRoot
$bundleRoot  = $envInfo.BundleRoot

Write-Info ('[INFO] Program Root : {0}' -f $programRoot)
Write-Info ('[INFO] Data Root    : {0}' -f $dataRoot)
Write-Info ('[INFO] Bundle Root  : {0}' -f $bundleRoot)
Write-Host ''

# --- File existence checks ---
$checks = @(
    @{ Name = 'paths_config.ps1'   ; Path = $pathsScript },
    @{ Name = 'release_bundle.ps1' ; Path = (Join-Path $programRoot 'automation\release_bundle.ps1') },
    @{ Name = 'verify_bundle.ps1'  ; Path = (Join-Path $programRoot 'verify_bundle.ps1') },
    @{ Name = 'docs_refresh.py'    ; Path = (Join-Path $programRoot 'automation\docs_refresh.py') },
    @{ Name = 'bundle_checksum.txt'; Path = (Join-Path $bundleRoot  'bundle_checksum.txt') }
)

$missing = @()
foreach ($c in $checks) {
    if (Test-Path $c.Path) {
        Write-Ok ('[PASS] Found {0}: {1}' -f $c.Name, $c.Path)
    } else {
        Write-Err ('[FAIL] Missing {0}: {1}' -f $c.Name, $c.Path)
        $missing += $c
    }
}

# --- Final result summary ---
Write-Host ''
if ($null -ne $missing -and $missing.Count -eq 0) {
    Write-Ok '[RESULT] Integration check PASSED â€” environment configured correctly.'
    Write-Host 'You can now run: make -f Makefile.win release-bundle-now'
} else {
    $missCount = if ($null -eq $missing) { 0 } else { $missing.Count }
    Write-Err '[RESULT] Integration check FAILED.'
    Write-Warn ('Missing {0} component(s). Please review the list above.' -f $missCount)
}
