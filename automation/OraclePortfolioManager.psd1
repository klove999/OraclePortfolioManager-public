@{
    # ─────────────────────────────
    # Module Identity
    # ─────────────────────────────
    RootModule           = 'OraclePortfolioManager.psm1'
    ModuleVersion        = '5.0.4'
    GUID                 = '9b1bca1b-23c4-4d7a-b154-8a2a1b47fa1b'
    Author               = 'Oracle (for Kirk)'
    CompanyName          = 'The Oracle Portfolio Manager Project'
    Copyright            = '(c) 2025 The Oracle Portfolio Manager Project. All rights reserved.'
    Description          = 'Automated environment setup, verification, and release management for the Oracle Portfolio Manager project.'
    PowerShellVersion    = '7.0'
    CompatiblePSEditions = @('Core', 'Desktop')

    # ─────────────────────────────
    # Module Components
    # ─────────────────────────────
    FunctionsToExport    = @(
        'Invoke-SetupEnvironment',
        'Invoke-VerifyBundle',
        'Invoke-ReleaseBundle'
    )
    CmdletsToExport      = @()
    VariablesToExport    = '*'
    AliasesToExport      = @()

    # ─────────────────────────────
    # Scripts and Assemblies
    # ─────────────────────────────
    FileList             = @(
        'setup_environment.ps1',
        'release_bundle.ps1',
        'verify_bundle.ps1',
        'make_v5_bundle.ps1',
        'integration_check.ps1',
        'paths_config.ps1',
        'repair_checksums_v2.ps1'
    )

    PrivateData          = @{
        PSData = @{
            Tags         = @('Oracle', 'Options', 'Portfolio', 'Automation', 'Release', 'CI/CD')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/KirkTheOracle/OraclePortfolioManager'
            IconUri      = 'https://example.com/oracle-icon.png'
            ReleaseNotes = @'
v5.0.4 — Converted Oracle Portfolio Manager automation to a PowerShell module.
Includes:
 - setup_environment.ps1 (Quiet + Logging + Return Codes)
 - Integrated bundle verification pipeline
 - SHA256 integrity checks
'@
        }
    }

    HelpInfoURI          = 'https://docs.optionsoracle.io/powershell-module'
}
