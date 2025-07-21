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

Write-Host "### Ensuring directory C:\tools\mysql exists"
if (-not (Test-Path "C:\tools\mysql")) {
    New-Item -ItemType Directory -Path "C:\tools\mysql" -Force | Out-Null
}

Write-Host "### Creating SQL initialization file"
@"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$rootPassword';
CREATE DATABASE IF NOT EXISTS \`$dbName\`;
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';
FLUSH PRIVILEGES;
"@ | Out-File -Encoding ASCII $initSqlPath

Write-Host "### Installing MySQL via Chocolatey with custom port $port"
choco install mysql --params "/port:$port" -y

Write-Host "### Modifying my.ini to set init-file for SQL initialization"
if (-not (Test-Path $myIniPath)) {
    Write-Error "my.ini not found at $myIniPath"
    exit 1
}

$content = Get-Content $myIniPath

if ($content -notmatch 'init-file=') {
    Add-Content $myIniPath "`ninit-file=$initSqlPath"
} else {
    $content = $content -replace 'init-file=.*', "init-file=$initSqlPath"
    $content | Set-Content $myIniPath
}

Write-Host "### Restarting MySQL service to run init-file and apply settings"
Restart-Service MySQL

Write-Host "### Waiting for 10 seconds to let init-file run"
Start-Sleep -Seconds 10

Write-Host "### Removing init-file line from my.ini to prevent repeated execution"
$content = Get-Content $myIniPath | Where-Object { $_ -notmatch 'init-file=' }
$content | Set-Content $myIniPath

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
