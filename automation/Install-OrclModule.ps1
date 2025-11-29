<#
Install-OrclModule.ps1 — Installer for Oracle Portfolio Manager PowerShell Module
Version : v5.0.5
Author  : Oracle (for Kirk)
Date    : 2025-10-27

Usage:
  System-wide install (Admin required):
    pwsh -NoProfile -ExecutionPolicy Bypass -File Install-OrclModule.ps1

  User-only install (no admin required):
    pwsh -NoProfile -ExecutionPolicy Bypass -File Install-OrclModule.ps1 -User

Options:
  -User     Installs into user module directory instead of system
  -Quiet    Suppresses non-critical console output
  -Force    Replaces any existing module installation
#>

param(
    [switch]$User,
    [switch]$Quiet,
    [switch]$Force,
	[string]$AutomationPath
)

# --- Detect automation folder ---
if (-not $AutomationPath) {
    if (Test-Path (Join-Path $PSScriptRoot 'automation')) {
        $AutomationPath = Join-Path $PSScriptRoot 'automation'
    } elseif (Test-Path 'C:\Program Files\Options Oracle Portfolio Manager\automation') {
        $AutomationPath = 'C:\Program Files\Options Oracle Portfolio Manager\automation'
    }
}

if (-not (Test-Path $AutomationPath)) {
    Write-Host "[ERROR] Automation folder not found at $AutomationPath" -ForegroundColor Red
    exit 2
}

$automationSrc = $AutomationPath

$ErrorActionPreference = 'Stop'

function Write-Info($m){ if(-not $Quiet){Write-Host $m -ForegroundColor Cyan} }
function Write-Ok($m){ if(-not $Quiet){Write-Host $m -ForegroundColor Green} }
function Write-Warn($m){ if(-not $Quiet){Write-Host $m -ForegroundColor Yellow} }
function Write-Err($m){ Write-Host $m -ForegroundColor Red }

$moduleName = 'OraclePortfolioManager'
$moduleVersion = '5.0.5'

# ─────────────────────────────
# Determine source and destination
# ─────────────────────────────
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

$automationSrc = if (Test-Path (Join-Path $scriptRoot 'automation')) {
    Join-Path $scriptRoot 'automation'
} elseif (Test-Path 'C:\Program Files\Options Oracle Portfolio Manager\automation') {
    'C:\Program Files\Options Oracle Portfolio Manager\automation'
} else {
    Write-Warn "[WARN] Could not locate automation folder automatically."
    $null
}

$filesToCopy = @(
    'OraclePortfolioManager.psd1',
    'OraclePortfolioManager.psm1'
)

$targetRoot = if ($User) {
    Join-Path $env:USERPROFILE "Documents\PowerShell\Modules\$moduleName"
} else {
    "C:\Program Files\WindowsPowerShell\Modules\$moduleName"
}

$autoDst = Join-Path $targetRoot 'automation'

Write-Info ("[STEP] Installing {0} PowerShell module..." -f $moduleName)
Write-Info ("Destination: {0}" -f $targetRoot)

# ─────────────────────────────
# Check permissions
# ─────────────────────────────
if (-not $User) {
    try {
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Err "[ERROR] Administrator privileges required for system-wide installation. Use -User for per-user install."
            exit 2
        }
    } catch {
        Write-Err "[ERROR] Unable to check administrative privileges."
        exit 2
    }
}

# ─────────────────────────────
# Prepare directories
# ─────────────────────────────
if (Test-Path $targetRoot) {
    if ($Force) {
        Write-Warn "[WARN] Existing module found. Removing due to -Force."
        Remove-Item -Recurse -Force $targetRoot
    } else {
        Write-Warn "[WARN] Existing module directory detected. Use -Force to overwrite."
    }
}
New-Item -ItemType Directory -Force -Path $autoDst | Out-Null

# ─────────────────────────────
# Copy module manifest and core scripts
# ─────────────────────────────
foreach ($f in $filesToCopy) {
    $src = Join-Path $scriptRoot $f
    if (Test-Path $src) {
        Copy-Item $src $targetRoot -Force
        Write-Ok ("[OK] Copied {0}" -f $f)
    } else {
        Write-Err ("[ERROR] Missing {0} at source: {1}" -f $f, $src)
        exit 2
    }
}

# ─────────────────────────────
# Copy automation scripts
# ─────────────────────────────
if (Test-Path $automationSrc) {
    Copy-Item "$automationSrc\*" $autoDst -Recurse -Force
    Write-Ok ("[OK] Copied automation scripts ({0})" -f $automationSrc)
} else {
    Write-Warn "[WARN] No automation folder found in source."
}

# ─────────────────────────────
# Import module
# ─────────────────────────────
try {
    Import-Module (Join-Path $targetRoot "$moduleName.psd1") -Force
    Write-Ok ("[OK] Imported {0} v{1}" -f $moduleName, $moduleVersion)
} catch {
    Write-Err "[ERROR] Failed to import module after installation: $($_.Exception.Message)"
    exit 2
}

# ─────────────────────────────
# Verify functions
# ─────────────────────────────
$exported = Get-Command -Module $moduleName | Select-Object -ExpandProperty Name
Write-Info "[INFO] Exported functions:"
$exported | ForEach-Object { Write-Host ("  • {0}" -f $_) -ForegroundColor Gray }

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host ("✅ {0} module installed successfully." -f $moduleName) -ForegroundColor Green
Write-Host ("Version     : {0}" -f $moduleVersion) -ForegroundColor DarkGray
Write-Host ("Install path: {0}" -f $targetRoot) -ForegroundColor DarkGray
Write-Host "===============================================" -ForegroundColor Green
Write-Ok "[OK] You can now use:  Import-Module OraclePortfolioManager"
exit 0
