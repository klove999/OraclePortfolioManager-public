<#
setup_environment.ps1 — Options Oracle Portfolio Manager
Version : v5.0.5  (Quiet + Logging + SHA256 Summary + Return Codes + Structured Flow)
Author  : Oracle (for Kirk)
Date    : 2025-10-27

Exit codes:
  0  Success / verified OK
  1  Completed with warnings (e.g., non-admin, policy restriction)
  2  Error or missing components
#>

param(
  [switch]$VerifyOnly,
  [string]$Log,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$ExitCode = 0

# --- optional log stream ---
$LogStream = $null
if ($Log) {
    $logDir = Split-Path $Log -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
    $LogStream = [System.IO.StreamWriter]::new($Log, $false, [System.Text.Encoding]::UTF8)
    $LogStream.AutoFlush = $true
    $LogStream.WriteLine("=== Log started {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
}

# --- Write helpers ---
function Write-Line($text) {
    if (-not $Quiet) { Write-Host $text }
    if ($LogStream)  { $LogStream.WriteLine($text) }
}
function Write-Info($m){ if (-not $Quiet){Write-Host $m -ForegroundColor Cyan};  if($LogStream){$LogStream.WriteLine($m)} }
function Write-Ok($m){   if (-not $Quiet){Write-Host $m -ForegroundColor Green}; if($LogStream){$LogStream.WriteLine($m)} }
function Write-Warn($m){ if (-not $Quiet){Write-Host $m -ForegroundColor Yellow};if($LogStream){$LogStream.WriteLine($m)}; $script:ExitCode = [math]::Max($script:ExitCode,1) }
function Write-Err($m){  if (-not $Quiet){Write-Host $m -ForegroundColor Red};   if($LogStream){$LogStream.WriteLine($m)}; $script:ExitCode = 2 }

if (-not $Quiet) {
    Write-Host "=== Options Oracle Portfolio Manager — Environment Setup ===" -ForegroundColor Cyan
    Write-Info ("Timestamp: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    Write-Host ""
}

# --- expected paths ---
$programRoot = "C:\Program Files\Options Oracle Portfolio Manager"
$autoDir     = Join-Path $programRoot "automation"
$dataRoot    = "D:\Documents\Oracle_Portfolio_Manager_v5"
$subDirs     = @("logs","docs","exports","bundles","automation")
$autoFiles   = @("release_bundle.ps1","make_v5_bundle.ps1","verify_bundle.ps1","repair_checksums_v2.ps1","paths_config.ps1","integration_check.ps1")

# --- PowerShell + privileges ---
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Err "[ERROR] PowerShell 7 or later is required."
    $ExitCode = 2
    if ($LogStream) { $LogStream.Close() }
    exit $ExitCode
} else { Write-Ok ("[OK] PowerShell {0}" -f $PSVersionTable.PSVersion) }

if (-not ([bool](net session 2>$null))) {
    Write-Warn "[WARN] Not running as Administrator. Limited write permissions may apply."
} else { Write-Ok "[OK] Administrator privileges confirmed." }

# --- Verify-only mode ---
if ($VerifyOnly) {
    Write-Info "[MODE] Running in verification-only mode."
    $missing = @()
    foreach ($p in @($programRoot,$autoDir,$dataRoot)) { if (-not (Test-Path $p)) { $missing += $p } }
    foreach ($s in $subDirs) { $d = Join-Path $dataRoot $s; if (-not (Test-Path $d)) { $missing += $d } }
    foreach ($f in $autoFiles) { $a = Join-Path $autoDir $f; if (-not (Test-Path $a)) { $missing += $a } }

    if ($missing.Count -eq 0) {
        Write-Ok "[OK] All required directories and automation files are present."
        Write-Ok "[OK] Environment integrity verified."
    } else {
        Write-Err ("[ERROR] Missing {0} component(s):" -f $missing.Count)
        $missing | ForEach-Object { Write-Warn ("  - {0}" -f $_) }
    }

    # --- checksum summary ---
    Write-Info "[STEP] Generating SHA256 summary of automation scripts..."
    Get-ChildItem $autoDir -Filter "*.ps1" | ForEach-Object {
        $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
        $line = "{0}  {1}" -f $hash, $_.Name
        if (-not $Quiet) { Write-Host $line -ForegroundColor DarkGray }
        if ($LogStream)  { $LogStream.WriteLine($line) }
    }

    if ($LogStream) {
        $LogStream.WriteLine("=== Log ended {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        $LogStream.Close()
    }
    exit $ExitCode
}

# --- Create dirs (setup mode) ---
if (-not (Test-Path $autoDir)) {
    Write-Info "[STEP] Creating program directories..."
    New-Item -ItemType Directory -Force -Path $autoDir | Out-Null
    Write-Ok ("[OK] Created: {0}" -f $autoDir)
} else { Write-Info "[INFO] Program directories already exist." }

foreach ($s in $subDirs) {
    $p = Join-Path $dataRoot $s
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Force -Path $p | Out-Null
        Write-Ok ("[OK] Created data folder: {0}" -f $p)
    }
}

# --- Copy scripts safely ---
$sourceAuto = Split-Path -Parent $MyInvocation.MyCommand.Definition
$destAuto   = $autoDir
Write-Info "[STEP] Copying automation scripts..."
foreach ($f in $autoFiles) {
    $src = Join-Path $sourceAuto $f
    $dst = Join-Path $destAuto $f
    if (-not (Test-Path $src)) { Write-Warn ("[WARN] Missing {0} in source directory." -f $f); continue }
    if ((Resolve-Path $src).Path -eq (Resolve-Path $dst).Path) {
        Write-Warn ("[WARN] Skipping self-copy for {0}" -f $f); continue
    }
    Copy-Item $src $dst -Force
    Write-Info ("[INFO] Copied {0}" -f $f)
}

Write-Info "[STEP] Unblocking PowerShell scripts..."
Get-ChildItem $autoDir -Filter "*.ps1" | Unblock-File
Write-Ok "[OK] All scripts unblocked."

$policy = Get-ExecutionPolicy
if ($policy -notin @("RemoteSigned","Bypass","Unrestricted")) {
    Write-Warn ("[WARN] Execution policy ({0}) may restrict scripts." -f $policy)
} else { Write-Ok ("[OK] Execution policy: {0}" -f $policy) }

# --- checksum summary for full setup ---
Write-Info "[STEP] Generating SHA256 summary of automation scripts..."
Get-ChildItem $autoDir -Filter "*.ps1" | ForEach-Object {
    $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash
    $line = "{0}  {1}" -f $hash, $_.Name
    if (-not $Quiet) { Write-Host $line -ForegroundColor DarkGray }
    if ($LogStream)  { $LogStream.WriteLine($line) }
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "===============================================" -ForegroundColor Green
    Write-Host "✅ Environment setup complete." -ForegroundColor Green
    Write-Host ("Program root : {0}" -f $programRoot) -ForegroundColor DarkGray
    Write-Host ("Data root    : {0}" -f $dataRoot) -ForegroundColor DarkGray
    Write-Host ("PowerShell   : {0}" -f $PSVersionTable.PSVersion) -ForegroundColor DarkGray
    Write-Host ("Timestamp    : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor DarkGray
    Write-Host "===============================================" -ForegroundColor Green
    Write-Ok "[OK] Oracle Portfolio Manager is ready for use."
}

if ($LogStream) {
    $LogStream.WriteLine("=== Log ended {0} ===" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
    $LogStream.Close()
}

exit $ExitCode
