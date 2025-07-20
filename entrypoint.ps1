$ErrorActionPreference = "Stop"

$port = $env:INPUT_MYSQL_PORT
if (-not $port) { $port = 32768 }

$password = $env:INPUT_MYSQL_ROOT_PASSWORD
if (-not $password) { $password = "root" }

Write-Host "### Installing MySQL via Chocolatey"
choco install mysql -y

Write-Host "### Starting MySQL service"
Start-Service MySQL
Start-Sleep -Seconds 15

$myIniPath = 'C:\tools\mysql\current\my.ini'

if (Test-Path $myIniPath) {
    Write-Host "### Configuring my.ini to use port $port"
    $content = Get-Content $myIniPath

    if ($content -match 'port=') {
        $newContent = $content -replace 'port=\d+', "port=$port"
    }
    else {
        $newContent = $content -replace '\[mysqld\]', "[mysqld]`nport=$port"
    }

    $newContent | Set-Content $myIniPath
}
else {
    Write-Error "my.ini not found at $myIniPath"
    exit 1
}

Write-Host "### Restarting MySQL service"
Restart-Service MySQL
Start-Sleep -Seconds 10

Write-Host "### Setting root password"
& "C:\tools\mysql\current\bin\mysqladmin.exe" -u root -P $port password $password

Write-Host "### Waiting for MySQL to be reachable on port $port..."
$hostname = "127.0.0.1"
for ($i = 0; $i -lt 30; $i++) {
    try {
        $conn = New-Object System.Net.Sockets.TcpClient($hostname, $port)
        if ($conn.Connected) {
            Write-Host "✅ MySQL is reachable on $hostname:$port"
            $conn.Close()
            break
        }
    } catch {
        Start-Sleep -Seconds 2
    }
    if ($i -eq 29) {
        Write-Host "❌ Timeout waiting for MySQL on $hostname:$port"
        exit 1
    }
}
Write-Host "✅ MySQL installed and configured successfully!"
