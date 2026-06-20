# --------------------------------
# Safety
# --------------------------------
$ErrorActionPreference = "Stop"

# --------------------------------
# Inputs
# --------------------------------
$rootPassword  = $env:mysql_root_password
$port          = $env:mysql_port
$dbName        = $env:mysql_database
$user          = $env:mysql_user
$userPassword  = $env:mysql_password

if (-not $rootPassword) { $rootPassword = "root" }
if (-not $port) { $port = 32768 }
if (-not $dbName) { $dbName = "my_db" }
if (-not $user) { $user = "dev" }
if (-not $userPassword) { $userPassword = "devpass" }

# --------------------------------
# Paths
# --------------------------------
$mysqlHome = "C:\Program Files\MySQL\MySQL Server 8.0\bin"
$mysqld = Join-Path $mysqlHome "mysqld.exe"
$mysql  = Join-Path $mysqlHome "mysql.exe"

# --------------------------------
# Data dir
# --------------------------------
$dataDir = "C:\mysql-data"

if (Test-Path $dataDir) {
    Remove-Item $dataDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

# --------------------------------
# INIT DB
# --------------------------------
& $mysqld --initialize-insecure --datadir=$dataDir

if ($LASTEXITCODE -ne 0) {
    throw "MySQL initialization failed"
}

# --------------------------------
# START MYSQL
# --------------------------------
$logFile = Join-Path $dataDir "mysql.err"

$mysqlProcess = Start-Process `
    -FilePath $mysqld `
    -ArgumentList @(
        "--datadir=$dataDir",
        "--port=$port",
        "--bind-address=0.0.0.0",
        "--console",
        "--log-error=$logFile"
    ) `
    -PassThru

# --------------------------------
# STEP 1: WAIT PORT ONLY (safe)
# --------------------------------
$timeout = 40

while ($timeout -gt 0) {
    $tcp = Test-NetConnection 127.0.0.1 -Port $port -WarningAction SilentlyContinue

    if ($tcp.TcpTestSucceeded) {
        break
    }

    Start-Sleep 1
    $timeout--
}

if ($timeout -le 0) {
    throw "MySQL port never opened"
}

# --------------------------------
# STEP 2: WAIT MYSQL READY VIA LOG
# --------------------------------
$timeout = 60

while ($timeout -gt 0) {

    try {
        $result = & $mysql `
            -h 127.0.0.1 `
            -P $port `
            --protocol=TCP `
            -u root `
            -e "SELECT 1;" 2>$null

        if ($LASTEXITCODE -eq 0 -and $result) {
            break
        }
    }
    catch {}

    Start-Sleep 1
    $timeout--
}

if ($timeout -le 0) {
    throw "MySQL not ready (SQL readiness check failed)"
}
# --------------------------------
# STEP 3: BOOTSTRAP ROOT (NO AMBIGUITY)
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -e "
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED WITH mysql_native_password BY '$rootPassword';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to bootstrap root user"
}

# --------------------------------
# STEP 4: VERIFY AUTH
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -e "SELECT 1;"

if ($LASTEXITCODE -ne 0) {
    throw "Root authentication failed after bootstrap"
}

# --------------------------------
# STEP 5: CREATE DATABASE
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -e "CREATE DATABASE IF NOT EXISTS $dbName;"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create database"
}

# --------------------------------
# STEP 6: CREATE USER
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -e "
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON $dbName.* TO '$user'@'%';
FLUSH PRIVILEGES;
"

# --------------------------------
# STEP 7: FINAL VALIDATION
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -e "SELECT VERSION();"

if ($LASTEXITCODE -ne 0) {
    throw "Final validation failed"
}

Write-Host "✅ MySQL configured successfully"