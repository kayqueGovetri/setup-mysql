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

Write-Host "### Installing MySQL via Chocolatey"
choco install mysql -y

Write-Host "### Stopping MySQL service (if running)"
Try {
    Stop-Service MySQL -ErrorAction SilentlyContinue
} catch {}

Write-Host "### Starting mysqld in safe mode (skip-grant-tables)"
Start-Process -FilePath "C:\tools\mysql\current\bin\mysqld.exe" -ArgumentList "--skip-grant-tables --skip-networking=0 --port=$port" -NoNewWindow

Start-Sleep -Seconds 10

Write-Host "### Running SQL commands to reset root password, create DB and user"

$sql = @"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$rootPassword';
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS \`$dbName\`;
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';
FLUSH PRIVILEGES;
"@

& "C:\tools\mysql\current\bin\mysql.exe" -u root -h 127.0.0.1 --protocol=tcp -P $port -e $sql

Write-Host "### Stopping mysqld from safe mode"
Get-Process mysqld | ForEach-Object { $_.Kill() }

Start-Sleep -Seconds 5

Write-Host "### Starting MySQL service normally"
Start-Service MySQL

Write-Host "### Checking MySQL connection"
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
