$ErrorActionPreference = "Stop"

# Variáveis de ambiente / padrões
$port = $env:INPUT_MYSQL_PORT
if (-not $port) { $port = 32768 }

$rootPassword = $env:INPUT_MYSQL_ROOT_PASSWORD
if (-not $rootPassword) { $rootPassword = "root" }

$dbName = $env:INPUT_MYSQL_DATABASE
if (-not $dbName) { $dbName = "test" }

$user = $env:INPUT_MYSQL_USER
if (-not $user) { $user = "test" }

$userPassword = $env:INPUT_MYSQL_PASSWORD
if (-not $userPassword) { $userPassword = "test" }

$baseDir = "C:\tools\mysql"
$currentDir = Join-Path $baseDir "current"
$dataDir = Join-Path $baseDir "data"
$initSqlPath = Join-Path $baseDir "init.sql"
$myIniPath = Join-Path $currentDir "my.ini"

Write-Host "### Ensuring base directory exists: $baseDir"
if (-not (Test-Path $baseDir)) {
    New-Item -ItemType Directory -Path $baseDir -Force | Out-Null
}

Write-Host "### Installing MySQL via Chocolatey with custom port $port"
choco install mysql --params "/port:$port" -y

Write-Host "### Ensuring data directory exists: $dataDir"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

Write-Host "### Setting permissions for MySQL data directory"
icacls $dataDir /grant "NT AUTHORITY\SYSTEM:(OI)(CI)F" /T | Out-Null

Write-Host "### Initializing MySQL data directory manually"
& "$currentDir\bin\mysqld.exe" --initialize-insecure --basedir="$currentDir" --datadir="$dataDir"

Write-Host "### Creating my.ini configuration file"
$myIniContent = @"
[mysqld]
port=$port
datadir=$dataDir
init-file=$initSqlPath
default_authentication_plugin=mysql_native_password
"@
$myIniContent | Out-File -Encoding ASCII $myIniPath -Force

Write-Host "### Creating SQL initialization file"
$sqlContent = @"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$rootPassword';
CREATE DATABASE IF NOT EXISTS \`$dbName\`;
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';
FLUSH PRIVILEGES;
"@
$sqlContent | Out-File -Encoding ASCII $initSqlPath -Force

Write-Host "### Starting MySQL service"
Start-Service MySQL

Write-Host "### Waiting for 10 seconds to allow MySQL to initialize"
Start-Sleep -Seconds 10

Write-Host "### Removing init-file from my.ini to av
