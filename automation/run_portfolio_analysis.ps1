<#
run_portfolio_analysis.ps1
Author : Oracle (for Kirk)
Date   : 2025-10-27
Purpose: Invokes Python-based multi-trade analysis
#>

$pyDir = "D:\Documents\Oracle_Portfolio_Manager_v5\automation\python"
$registry = Join-Path $pyDir "trade_registry.py"
$analyzer = Join-Path $pyDir "analyze_positions.py"
$portfolioCsv = "D:\Documents\Oracle_Portfolio_Manager_v5\portfolio.csv"

if (-not (Test-Path $portfolioCsv)) {
  Write-Host "[INFO] No portfolio.csv found — creating baseline." -ForegroundColor Yellow
  python $registry
}

Write-Host "[STEP] Running Oracle Portfolio Analysis..." -ForegroundColor Cyan
python $analyzer $portfolioCsv
