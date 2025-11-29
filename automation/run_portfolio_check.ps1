<#
run_portfolio_check.ps1 — Oracle Portfolio Manager
Version : v5.1.0
Author  : Oracle (for Kirk)
Date    : 2025-10-27
#>

$pythonPath = "python"
$scriptPath = "D:\Documents\OraclePortfolioManager\analytics\portfolio_registry.py"

if (-not (Test-Path $scriptPath)) {
    Write-Host "[ERROR] Portfolio registry script not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "=== Oracle Portfolio Manager — Portfolio Check ===" -ForegroundColor Cyan
& $pythonPath $scriptPath
