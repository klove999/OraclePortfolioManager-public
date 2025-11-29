param(
    # Path to the SQLite DB. Defaults to data/portfolio.db at repo root.
    [string] $DbPath
) Write - Host "[STEP] Running local DB migrations..." - ForegroundColor Cyan # Resolve repo root as the parent of automation\
$repoRoot = Split - Path $PSScriptRoot - Parent if (
    - not $DbPath -
    or $DbPath.Trim() - eq ""
) { $DbPath =
Join - Path $repoRoot "data\portfolio.db" } # Normalize & ensure data dir exists
$DbPath = [System.IO.Path]::GetFullPath($DbPath) $dataDir = Split - Path $DbPath - Parent if (- not (Test - Path $dataDir)) { New - Item - ItemType Directory - Path $dataDir | Out - Null } Write - Host ("[INFO] Using DB path: {0}" - f $DbPath) $pythonCode = @"
import os
import glob
import sqlite3
import datetime
import sys

db_path = r""" $DbPath """
db_path = os.path.abspath(db_path)
os.makedirs(os.path.dirname(db_path), exist_ok=True)

print(f" [INFO] Local DB: { db_path } ")

conn = sqlite3.connect(db_path)
cur = conn.cursor()

# Ensure schema_migrations table exists
cur.execute(""" CREATE TABLE IF NOT EXISTS schema_migrations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    filename TEXT NOT NULL UNIQUE,
    applied_at TEXT NOT NULL
) """)
conn.commit()

migrations_dir = os.path.join(" analytics ", " sql ")
pattern = os.path.join(migrations_dir, " migrate_ *.sql ")
migration_files = sorted(glob.glob(pattern))

if not migration_files:
    print(f" [WARN] No migration files found under { migrations_dir } ")
else:
    print(f" [INFO] Found { len(migration_files) } migration(s).")

applied_count = 0

for path in migration_files:
    filename = os.path.basename(path)

    cur.execute("
SELECT 1
FROM schema_migrations
WHERE filename = ? ", (filename,))
    if cur.fetchone():
        print(f" [SKIP] { filename } already applied.")
        continue

    print(f" [APPLY] { filename } ")
    with open(path, " r ", encoding=" utf -8 ") as f:
        sql = f.read()

    try:
        conn.executescript(sql)
        applied_at = datetime.datetime.utcnow().isoformat(timespec=" seconds ") + " Z "
        cur.execute(
            "
INSERT INTO schema_migrations (filename, applied_at)
VALUES (?, ?) ",
            (filename, applied_at)
        )
        conn.commit()
        print(f" [OK] { filename } applied.")
        applied_count += 1
    except Exception as e:
        conn.rollback()
        print(f" [ERROR] Failed to apply { filename }: { e } ")
        conn.close()
        sys.exit(1)

conn.close()
print(f" [OK] Migrations applied: { applied_count } ")
" @ # Write to a temp .py file so we avoid here-doc issues in PowerShell
    $tmpPy =
    Join - Path $env :TEMP (
        "run_migrations_" + [guid]::NewGuid().ToString("N") + ".py"
    ) $pythonCode |
Set - Content - Path $tmpPy - Encoding UTF8 # Run Python
    & python $tmpPy $exitCode = $LASTEXITCODE # Cleanup
    Remove - Item $tmpPy - ErrorAction SilentlyContinue if ($exitCode - ne 0) { Write - Host "[ERROR] Migration script failed with exit code $exitCode" - ForegroundColor Red exit $exitCode } Write - Host "[DONE] Local DB migrations completed successfully." - ForegroundColor Green
