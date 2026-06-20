# --------------------------------
# Safety
# --------------------------------
$ErrorActionPreference = "Stop"

# --------------------------------
# Input parameters from environment
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
# MySQL paths
# --------------------------------
$mysqlHome = "C:\Program Files\MySQL\MySQL Server 8.0\bin"
$mysqld = Join-Path $mysqlHome "mysqld.exe"
$mysql  = Join-Path $mysqlHome "mysql.exe"

# --------------------------------
# Data directory
# --------------------------------
$dataDir = "C:\mysql-data"

if (Test-Path $dataDir) {
    Remove-Item $dataDir -Recurse -Force
}

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

# --------------------------------
# Initialize MySQL (CRITICAL)
# --------------------------------
& $mysqld --initialize-insecure --datadir=$dataDir

if ($LASTEXITCODE -ne 0) {
    throw "MySQL initialization failed"
}

# --------------------------------
# Start MySQL server
# --------------------------------
$mysqlProcess = Start-Process `
    -FilePath $mysqld `
    -ArgumentList @(
        "--datadir=$dataDir",
        "--port=$port",
        "--bind-address=0.0.0.0"
    ) `
    -PassThru

# --------------------------------
# Wait for MySQL to be ready (NO AUTH YET)
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
# Set root password
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPassword';"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to set root password"
}

# --------------------------------
# Enable remote root
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -p$rootPassword `
    -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$rootPassword';"

& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -p$rootPassword `
    -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"

# --------------------------------
# Create database
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -p$rootPassword `
    -e "CREATE DATABASE IF NOT EXISTS $dbName;"

if ($LASTEXITCODE -ne 0) {
    throw "Failed to create database"
}

# --------------------------------
# Create application user
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -p$rootPassword `
    -e "CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';"

& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -p$rootPassword `
    -e "GRANT ALL PRIVILEGES ON $dbName.* TO '$user'@'%';"

& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -p$rootPassword `
    -e "FLUSH PRIVILEGES;"

# --------------------------------
# Final validation
# --------------------------------
& $mysql `
    -h 127.0.0.1 `
    -P $port `
    --protocol=TCP `
    -u root `
    -p$rootPassword `
    -e "SELECT VERSION();"

if ($LASTEXITCODE -ne 0) {
    throw "Final MySQL validation failed"
}

Write-Host "✅ MySQL configured successfully"