# OraclePortfolioManager.psm1
# Version 5.0.4 — Module entry point
# Author: Oracle (for Kirk)

$script:ModuleRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$script:AutomationRoot = Join-Path $ModuleRoot 'automation'

# Import key automation scripts into session
. (Join-Path $AutomationRoot 'setup_environment.ps1')
. (Join-Path $AutomationRoot 'release_bundle.ps1')
. (Join-Path $AutomationRoot 'verify_bundle.ps1')

function Invoke-SetupEnvironment {
    param(
        [switch]$VerifyOnly,
        [string]$Log,
        [switch]$Quiet
    )
    & (Join-Path $AutomationRoot 'setup_environment.ps1') @PSBoundParameters
}

function Invoke-VerifyBundle {
    param(
        [string]$BundleRoot = (Join-Path $env:USERPROFILE 'Documents\Oracle_Portfolio_Manager_v5'),
        [switch]$Quiet
    )
    & (Join-Path $AutomationRoot 'verify_bundle.ps1') @PSBoundParameters
}

function Invoke-ReleaseBundle {
    param(
        [string]$Version = 'v5.0.4',
        [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),
        [switch]$Quiet
    )
    & (Join-Path $AutomationRoot 'release_bundle.ps1') @PSBoundParameters
}

Export-ModuleMember -Function Invoke-SetupEnvironment, Invoke-VerifyBundle, Invoke-ReleaseBundle
