<#
run_smoke_test.ps1 — Options Oracle Portfolio Manager (Smoke Test)
Version : 1.0
Author  : Oracle (for Kirk)
Date    : 2025-10-27

Purpose:
  Fast, offline smoke test for short cash-secured puts using The Options Oracle rules.
  Defaults to your MSTR $260P Jan 16, 2026 position.

Usage examples:
  pwsh -NoProfile -File run_smoke_test.ps1
  pwsh -NoProfile -File run_smoke_test.ps1 -Sym MSTR -Strike 260 -Exp 2026-01-16 -EntryPrice 26.74 `
      -LiveMark 20.875 -Delta 0.299793 -EntryIV 0.725 -CurrentIV 0.6664 -Acct 700000 -Contracts 1 -UndPx 417.00
#>

param(
  [string]$Sym = "MSTR",
  [decimal]$Strike = 260,
  [string]$Exp = "2026-01-16",
  [decimal]$EntryPrice = 26.74,     # option premium received
  [decimal]$LiveMark = 20.875,      # current option mid/mark
  [decimal]$Delta = 0.299793,       # current absolute delta of the short put
  [decimal]$EntryIV = 0.725,        # at entry (Oct 16, 2025 per your note)
  [decimal]$CurrentIV = 0.6664,     # current IV
  [decimal]$Acct = 700000,          # account size
  [int]$Contracts = 1,
  [decimal]$UndPx = 0               # optional: current underlying price (if known)
)

$ErrorActionPreference = 'Stop'

function C($text,$color){ Write-Host $text -ForegroundColor $color }

# --- Computations ---
$mult = 100 * $Contracts
$credit = [math]::Round($EntryPrice * $mult, 2)
$mtm    = [math]::Round($LiveMark   * $mult, 2)
$upl    = [math]::Round(($EntryPrice - $LiveMark) * $mult, 2)   # positive = profit on short
$breakeven = [math]::Round(($Strike - $EntryPrice), 2)

# assignment collateral and max loss (cash-secured)
$collateral = [math]::Round($Strike * 100 * $Contracts, 2)
$maxLoss = [math]::Round(($Strike - 0 - $EntryPrice) * 100 * $Contracts, 2)

# simple POP approximation from delta (P(ITM) ~ |delta| → POP ≈ 1 - |delta|)
$pop = [math]::Round((1 - [math]::Abs([double]$Delta)) * 100, 1)

# IV compression since entry
$ivChangeAbs = [math]::Round(($CurrentIV - $EntryIV), 6)
$ivChangePct = if ($EntryIV -ne 0) { [math]::Round(($CurrentIV - $EntryIV)/$EntryIV * 100, 2) } else { 0 }

# DTE
$today = [datetime]::Now.Date
try { $expDt = [datetime]::Parse($Exp) } catch { throw "Invalid -Exp date. Use YYYY-MM-DD." }
$dte = (New-TimeSpan -Start $today -End $expDt).Days

# Buying power usage (cash-secured)
$bpUse = $collateral - $credit
$bpUsePct = if ($Acct -gt 0) { [math]::Round($bpUse / $Acct * 100, 2) } else { 0 }

# --- Oracle Rule Checks (concise bands) ---
# Rule 1: BP usage under 20% of account (configurable later)
$rule1 = if ($bpUsePct -le 20) { "PASS" } elseif ($bpUsePct -le 30) { "AT-RISK" } else { "FAIL" }

# Rule 2: POP >= 60% (using delta proxy)
$rule2 = if ($pop -ge 60) { "PASS" } elseif ($pop -ge 55) { "AT-RISK" } else { "FAIL" }

# Rule 3: Breakeven cushion vs underlying (if UndPx provided)
$rule3 = "N/A"
if ($UndPx -gt 0) {
  $cushion = [math]::Round((($UndPx - $breakeven) / $UndPx) * 100, 2)
  $rule3 = if ($cushion -ge 10) { "PASS" } elseif ($cushion -ge 5) { "AT-RISK" } else { "FAIL" }
}

# Rule 7 (IV): prefer IV contraction while short premium
$rule7 = if ($ivChangePct -lt 0) { "PASS" } elseif ($ivChangePct -le 3) { "AT-RISK" } else { "FAIL" }

# Status color helper
function BandColor($band){
  switch ($band) {
    "PASS"    { "Green" }
    "AT-RISK" { "Yellow" }
    "FAIL"    { "Red" }
    default   { "DarkGray" }
  }
}

# --- Output ---
C "=== Smoke Test — Short Cash-Secured Put ===" Cyan
C ("Symbol: {0}   Strike: {1}   Exp: {2}   Contracts: {3}" -f $Sym, $Strike, $expDt.ToString("yyyy-MM-dd"), $Contracts) Gray
if ($UndPx -gt 0) { C ("Underlying: {0:C2}" -f $UndPx) DarkGray }
Write-Host ""

# Summary table
$rows = @(
  @{ K="Entry Credit";   V=("${0:C2}" -f $credit) },
  @{ K="Current Mark";   V=("${0:C2}" -f $mtm) },
  @{ K="Unrealized P/L"; V=("${0:C2}" -f $upl) },
  @{ K="Breakeven Px";   V=("{0:F2}" -f $breakeven) },
  @{ K="Delta (abs)";    V=("{0:F3}" -f [math]::Abs([double]$Delta)) },
  @{ K="POP (≈1-|Δ|)";   V=("{0:F1}%" -f $pop) },
  @{ K="IV (entry→now)"; V=("{0:F4} → {1:F4} ({2:F2}%)" -f $EntryIV, $CurrentIV, $ivChangePct) },
  @{ K="DTE";            V=("{0} days" -f $dte) },
  @{ K="Collateral";     V=("${0:C2}" -f $collateral) },
  @{ K="BP Usage";       V=("${0:C2} ({1:F2}%)" -f $bpUse, $bpUsePct) }
)

# Print aligned
$w = ($rows | ForEach-Object { $_.K.Length } | Measure-Object -Maximum).Maximum
foreach ($r in $rows) {
  $pad = $r.K.PadRight($w)
  C ("{0}  :  {1}" -f $pad, $r.V) White
}

Write-Host ""
C "— Rule Bands —" Cyan
$bands = @(
  @{ Name="Rule 1: BP ≤ 20% (30% warn)"; Band=$rule1 },
  @{ Name="Rule 2: POP ≥ 60% (55–60 warn)"; Band=$rule2 },
  @{ Name="Rule 3: Breakeven cushion ≥ 10% (5–10 warn)"; Band=$rule3 },
  @{ Name="Rule 7: IV contraction favorable"; Band=$rule7 }
)
foreach ($b in $bands) {
  $color = BandColor $b.Band
  C ("{0}".PadRight(40) -f $b.Name) Gray
  C ("  {0}" -f $b.Band) $color
}

Write-Host ""
C "Guidance:" Cyan
C "- Maintain: Credit intact, IV contracting, POP strong; no action needed." DarkGray
C "- Consider partial close: if P/L ≥ 50–60% of max credit or DTE ≤ 75 and thesis intact." DarkGray
C "- Manage risk: if BP creeps >30% or POP <55% or IV re-expands materially, evaluate roll/close." DarkGray

exit 0
