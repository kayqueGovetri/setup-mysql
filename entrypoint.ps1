$ErrorActionPreference = "Stop"

$port = $env:INPUT_MYSQL_PORT
if (-not $port) { $port = 3306 }

$password = $env:INPUT_MYSQL_ROOT_PASSWORD
if (-not $password) { $password = "root" }

Write-Host "### Installing MySQL via Chocolatey"
choco install mysql -y

Write-Host "### Waiting for MySQL service to start"
Start-Sleep -Seconds 20

$myIniPath = "C:\ProgramData\MySQL\MySQL Server 8.0\my.ini"

if (-Not (Test-Path $myIniPath)) {
    Write-Warning "my.ini not found at $myIniPath. Skipping port configuration."
} else {
    Write-Host "### Updating my.ini to set port $port and bind-address=127.0.0.1"
    (Get-Content $myIniPath) `
      -replace '^(port\s*=).*$', "port=$port" `
      -replace '^(bind-address\s*=).*$', "bind-address=127.0.0.1" |
      Set-Content $myIniPath
}

Write-Host "### Restarting MySQL service"
Restart-Service -Name MySQL -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 10

Write-Host "### Setting root password and auth plugin"
& "C:\tools\mysql\bin\mysql.exe" -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$password'; FLUSH PRIVILEGES;"

Write-Host "### Testing MySQL connection on 127.0.0.1:$port"
try {
    & "C:\tools\mysql\bin\mysql.exe" -h 127.0.0.1 -P $port -u root -p$password -e "SELECT VERSION();"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to connect"
        exit 1
    }
} catch {
    Write-Host "❌ Exception during connection attempt: $_"
    exit 1
}

Write-Host "✅ MySQL is installed and configured successfully!"
