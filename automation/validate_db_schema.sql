param([string] $DbPath) Write - Host "[STEP] Validating DB schema..." - ForegroundColor Cyan $repoRoot = Split - Path $PSScriptRoot - Parent if (
    - not $DbPath -
    or $DbPath.Trim() - eq ""
) { $DbPath =
Join - Path $repoRoot "data\portfolio.db" } $DbPath = [System.IO.Path]::GetFullPath($DbPath) if (- not (Test - Path $DbPath)) { Write - Host ("[ERROR] DB file not found at: {0}" - f $DbPath) - ForegroundColor Red exit 1 } Write - Host ("[INFO] Using DB path: {0}" - f $DbPath) $pythonCode = @"
import sqlite3
import os

db_path = r""" $DbPath """
db_path = os.path.abspath(db_path)

print(f" [INFO] Opening DB at: { db_path } ")
conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute("
SELECT name
FROM sqlite_master
WHERE type = 'table' ")
tables = {row[0] for row in cur.fetchall()}

required = [" positions ", " trades ", " greeks_log ", " schema_migrations "]
missing = [t for t in required if t not in tables]

print(" [INFO] Existing tables :")
for t in sorted(tables):
    print(f" - { t } ")

if missing:
    print(" [WARN] Missing required tables :")
    for t in missing:
        print(f" - { t } ")
    status = 1
else:
    print(" [OK] All required tables are present.")
    status = 0

conn.close()
exit(status)
" @ $tmpPy =
    Join - Path $env :TEMP (
        "validate_schema_" + [guid]::NewGuid().ToString("N") + ".py"
    ) $pythonCode |
Set - Content - Path $tmpPy - Encoding UTF8 & python $tmpPy $exitCode = $LASTEXITCODE Remove - Item $tmpPy - ErrorAction SilentlyContinue if ($exitCode - ne 0) { Write - Host "[FAILED] DB schema validation reported issues." - ForegroundColor Yellow exit $exitCode } Write - Host "[DONE] DB schema validation passed." - ForegroundColor Green
