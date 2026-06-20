# --------------------------------
# Input parameters from environment
# --------------------------------

$rootPassword = $env:mysql_root_password
$port = $env:mysql_port
$dbName = $env:mysql_database
$user = $env:mysql_user
$userPassword = $env:mysql_password
$env:MYSQL_PWD = $rootPassword

# --------------------------------
# Fallbacks
# --------------------------------

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
$mysql = Join-Path $mysqlHome "mysql.exe"

$dataDir = "C:\mysql-data"

# --------------------------------
# Initialize data directory
# --------------------------------

New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

& $mysqld `
    --initialize-insecure `
    --datadir=$dataDir

# --------------------------------
# Start MySQL
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
# Wait for startup
# --------------------------------

Start-Sleep -Seconds 10

# --------------------------------
# Configure root user
# --------------------------------

& $mysql `
    --protocol=TCP `
    -h 127.0.0.1 `
    -P $port `
    -u root `
    -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$rootPassword';"

# --------------------------------
# Create remote root access
# --------------------------------

& $mysql `
    --protocol=TCP `
    -h 127.0.0.1 `
    -P $port `
    -u root `
    -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$rootPassword';"

& $mysql `
    --protocol=TCP `
    -h 127.0.0.1 `
    -P $port `
    -u root `
    -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"

# --------------------------------
# Create application database/user
# --------------------------------

& $mysql `
    --protocol=TCP `
    -h 127.0.0.1 `
    -P $port `
    -u root `
    -e "CREATE DATABASE IF NOT EXISTS \`$dbName;"

& $mysql `
    --protocol=TCP `
    -h 127.0.0.1 `
    -P $port `
    -u root `
    -e "CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';"

& $mysql `
    --protocol=TCP `
    -h 127.0.0.1 `
    -P $port `
    -u root `
    -e "GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';"

& $mysql `
    --protocol=TCP `
    -h 127.0.0.1 `
    -P $port `
    -u root `
    -e "FLUSH PRIVILEGES;"

Write-Host "✅ MySQL configured successfully"
