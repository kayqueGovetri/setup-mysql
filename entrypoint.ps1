$ErrorActionPreference = "Stop"

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

$initSqlPath = "C:\tools\mysql\init.sql"
$myIniPath = "C:\tools\mysql\current\my.ini"
$mysqlBaseDir = "C:\tools\mysql"

Write-Host "### Ensuring base directory $mysqlBaseDir exists"
if (-not (Test-Path $mysqlBaseDir)) {
    New-Item -ItemType Directory -Path $mysqlBaseDir -Force | Out-Null
}

Write-Host "### Creating SQL initialization file at $initSqlPath"
@"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$rootPassword';
CREATE DATABASE IF NOT EXISTS \`$dbName\`;
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';
FLUSH PRIVILEGES;
"@ | Out-File -Encoding ASCII $initSqlPath

Write-Host "### Creating my.ini file at $myIniPath with custom port and init-file"
# Conteúdo básico do my.ini com configurações essenciais
$myIniContent = @"
[mysqld]
port=$port
basedir=$mysqlBaseDir\current
datadir=$mysqlBaseDir\data
init-file=$initSqlPath
sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
skip-name-resolve
"@

# Criar diretório current caso não exista (Chocolatey cria depois da instalação, mas criamos para evitar erro)
$currentDir = Join-Path $mysqlBaseDir "current"
if (-not (Test-Path $currentDir)) {
    New-Item -ItemType Directory -Path $currentDir -Force | Out-Null
}

# Salvar my.ini no caminho esperado (Chocolatey espera em current)
$myIniDir = Split-Path $myIniPath
if (-not (Test-Path $myIniDir)) {
    New-Item -ItemType Directory -Path $myIniDir -Force | Out-Null
}

$myIniContent | Out-File -Encoding ASCII $myIniPath

Write-Host "### Installing MySQL via Chocolatey with custom port $port"
choco install mysql --params "/port:$port" -y

Write-Host "### Starting MySQL service"
Start-Service MySQL

Write-Host "### Waiting for 10 seconds to let init-file run"
Start-Sleep -Seconds 10

Write-Host "### Removing init-file line from my.ini to prevent repeated execution"
$content = Get-Content $myIniPath | Where-Object { $_ -notmatch 'init-file=' }
$content | Set-Content $myIniPath

Write-Host "### Restarting MySQL service without init-file"
Restart-Service MySQL

Write-Host "### Verifying MySQL availability on port $port"
for ($i=0; $i -lt 30; $i++) {
    try {
        $conn = New-Object System.Net.Sockets.TcpClient("127.0.0.1", $port)
        if ($conn.Connected) {
            Write-Host "✅ MySQL is available at 127.0.0.1:$port"
            $conn.Close()
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
    if ($i -eq 29) {
        Write-Error "❌ Timeout while waiting for MySQL at 127.0.0.1:$port"
        exit 1
    }
}

Write-Host "✅ MySQL installed, configured, and ready to use!"
