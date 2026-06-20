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
$mysqlProcess = Start-Process `
    -FilePath $mysqld `
    -ArgumentList @(
        "--datadir=$dataDir",
        "--port=$port",
        "--bind-address=0.0.0.0",
        "--console"
    ) `
    -PassThru

# --------------------------------
# STEP 1: WAIT PORT ONLY
# --------------------------------
$timeout = 60

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
# STEP 2: WAIT SQL ENGINE (NO RELIANCE ON LOG OR ROOT STATE)
# --------------------------------
$timeout = 60

while ($timeout -gt 0) {

    try {
        & $mysql `
            -h 127.0.0.1 `
            -P $port `
            --protocol=TCP `
            -u root `
            -e "SELECT 1;" 2>$null

        if ($LASTEXITCODE -eq 0) {
            break
        }
    }
    catch {}

    Start-Sleep 1
    $timeout--
}

if ($timeout -le 0) {
    throw "MySQL not ready (SQL engine not responsive)"
}

# --------------------------------
# STEP 3: CREATE CI ADMIN (NÃO DEPENDE DE ROOT STATE STABILITY)
# --------------------------------
& $mysql `
  -h 127.0.0.1 `
  -P $port `
  -u root `
  -e "
CREATE USER IF NOT EXISTS 'ci_admin'@'localhost' IDENTIFIED BY '$rootPassword';
CREATE USER IF NOT EXISTS 'ci_admin'@'127.0.0.1' IDENTIFIED BY '$rootPassword';
GRANT ALL PRIVILEGES ON *.* TO 'ci_admin'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'ci_admin'@'127.0.0.1' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create CI admin user"
}

# --------------------------------
# STEP 4: SWITCH TO CI ADMIN (FROM HERE ROOT IS NOT USED ANYMORE)
# --------------------------------
$mysqlUser = "ci_admin"

# --------------------------------
# STEP 5: VERIFY AUTH
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u $mysqlUser `
    -p$rootPassword `
    -e "SELECT 1;"

if ($LASTEXITCODE -ne 0) {
    throw "CI admin authentication failed"
}

# --------------------------------
# STEP 6: CREATE DATABASE
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u $mysqlUser `
    -p$rootPassword `
    -e "CREATE DATABASE IF NOT EXISTS $dbName;"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create database"
}

# --------------------------------
# STEP 7: CREATE APP USER
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u $mysqlUser `
    -p$rootPassword `
    -e "
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON $dbName.* TO '$user'@'%';
FLUSH PRIVILEGES;
"

# --------------------------------
# STEP 8: FINAL VALIDATION
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u $mysqlUser `
    -p$rootPassword `
    -e "SELECT VERSION();"

if ($LASTEXITCODE -ne 0) {
    throw "Final validation failed"
}

Write-Host "✅ MySQL configured successfully"