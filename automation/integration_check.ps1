<#
integration_check.ps1 — Environment diagnostic for Oracle Portfolio Manager v5
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
$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$pathsScript = Join-Path $scriptDir 'paths_config.ps1'
if (-not (Test-Path $pathsScript)) {
    Write-Err '[ERROR] paths_config.ps1 missing from automation folder.'
    exit 1
}

$envInfo = & $pathsScript -Quiet

# Robust fallbacks
$projRoot    = Split-Path -Parent $scriptDir              # parent of automation\
$programRoot = if ($envInfo.ProgramRoot) { $envInfo.ProgramRoot } else { $projRoot }
$dataRoot    = if ($envInfo.DataRoot)    { $envInfo.DataRoot }    else { $projRoot }
$bundleRoot  = if ($envInfo.BundleRoot)  { $envInfo.BundleRoot }  else { Join-Path $dataRoot 'Options_OraclePortfolioManager.0.1_Stable' }

Write-Info ('[INFO] Program Root : {0}' -f $programRoot)
Write-Info ('[INFO] Data Root    : {0}' -f $dataRoot)
Write-Info ('[INFO] Bundle Root  : {0}' -f $bundleRoot)
Write-Host ''

# Helper: find first existing path from a candidate list
function Find-First([string[]]$candidates) {
    foreach ($p in $candidates) {
        if ($null -ne $p -and $p.Trim().Length -gt 0 -and (Test-Path $p)) { return $p }
    }
    return $null
}

# Build candidate paths for each required file in both locations (program root and project root)
$releaseBundleCandidates = @(
    (Join-Path $programRoot 'automation\release_bundle.ps1'),
    (Join-Path $projRoot    'automation\release_bundle.ps1')
)
$verifyBundleCandidates = @(
    (Join-Path $programRoot 'verify_bundle.ps1'),
    (Join-Path $projRoot    'verify_bundle.ps1')
)
$docsRefreshCandidates = @(
    (Join-Path $programRoot 'automation\docs_refresh.py'),
    (Join-Path $projRoot    'automation\docs_refresh.py')
)

$releaseBundlePath = Find-First $releaseBundleCandidates
$verifyBundlePath  = Find-First $verifyBundleCandidates
$docsRefreshPath   = Find-First $docsRefreshCandidates
$checksumPath      = Join-Path $bundleRoot 'bundle_checksum.txt'

# --- File existence checks ---
$checks = @(
    @{ Name = 'paths_config.ps1'    ; Path = $pathsScript },
    @{ Name = 'release_bundle.ps1'  ; Path = $releaseBundlePath },
    @{ Name = 'verify_bundle.ps1'   ; Path = $verifyBundlePath },
    @{ Name = 'docs_refresh.py'     ; Path = $docsRefreshPath },
    @{ Name = 'bundle_checksum.txt' ; Path = $checksumPath }
)

$missing = @()
foreach ($c in $checks) {
    if ($c.Path -and (Test-Path $c.Path)) {
        Write-Ok ('[PASS] Found {0}: {1}' -f $c.Name, $c.Path)
    } else {
        # Show the main expected path when missing
        $exp = switch ($c.Name) {
            'release_bundle.ps1'  { ($releaseBundleCandidates -join '; ') }
            'verify_bundle.ps1'   { ($verifyBundleCandidates  -join '; ') }
            'docs_refresh.py'     { ($docsRefreshCandidates   -join '; ') }
            default               { $c.Path }
        }
        Write-Err ('[FAIL] Missing {0}: {1}' -f $c.Name, $exp)
        $missing += $c
    }
}

# --- Final result summary ---
Write-Host ''
if ($null -ne $missing -and $missing.Count -eq 0) {
    Write-Ok '[RESULT] Integration check PASSED — environment configured correctly.'
    Write-Host 'You can now run: make -f Makefile.win release-bundle-now'
} else {
    $missCount = if ($null -eq $missing) { 0 } else { $missing.Count }
    Write-Err '[RESULT] Integration check FAILED.'
    Write-Warn ('Missing {0} component(s). Please review the list above.' -f $missCount)
}
