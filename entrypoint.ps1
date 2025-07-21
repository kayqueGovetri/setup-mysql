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

Write-Host "### Installing MySQL via Chocolatey with custom port $port"
choco install mysql --params "/port:$port" -y

Write-Host "### Starting MySQL service"
Start-Service MySQL
Start-Sleep -Seconds 10

Write-Host "### Setting root password"
& "C:\tools\mysql\current\bin\mysqladmin.exe" -u root -P $port password $rootPassword

Write-Host "### Waiting for MySQL to be reachable on port $port..."
$hostname = "127.0.0.1"
for ($i = 0; $i -lt 30; $i++) {
    try {
        $conn = New-Object System.Net.Sockets.TcpClient($hostname, $port)
        if ($conn.Connected) {
            Write-Host "✅ MySQL is reachable on ${hostname}:${port}"
            $conn.Close()
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
    if ($i -eq 29) {
        Write-Error "❌ Timeout waiting for MySQL on ${hostname}:${port}"
        exit 1
    }
}

Write-Host "### Creating database '$dbName' and user '$user'"

$sql = @"
CREATE DATABASE IF NOT EXISTS \`$dbName\`;
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';
FLUSH PRIVILEGES;
"@

& "C:\tools\mysql\current\bin\mysql.exe" -u root -P $port -p$rootPassword -e $sql

Write-Host "✅ MySQL installed, configured, and ready to use!"
