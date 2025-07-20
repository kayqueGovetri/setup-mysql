$ErrorActionPreference = "Stop"

$port = $env:INPUT_MYSQL_PORT
if (-not $port) { $port = 3306 }

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
    } else {
        $newContent = $content -replace '\[mysqld\]', "[mysqld]`nport=$port"
    }

    if ($newContent -match 'bind-address=') {
        $newContent = $newContent -replace 'bind-address=.*', 'bind-address=127.0.0.1'
    } else {
        $newContent = $newContent -replace '\[mysqld\]', "[mysqld]`nbind-address=127.0.0.1"
    }

    $newContent | Set-Content $myIniPath
} else {
    Write-Error "my.ini not found at $myIniPath"
    exit 1
}

Write-Host "### Restarting MySQL service"
Restart-Service MySQL
Start-Sleep -Seconds 10

Write-Host "### Trying to set root password with mysqladmin"
try {
    & 'C:\tools\mysql\current\bin\mysqladmin.exe' -u root password $password
    Write-Host "Password set successfully using mysqladmin."
} catch {
    Write-Warning "Could not set password using mysqladmin.exe. Maybe password already set."
}

Write-Host "### Testing MySQL connection on 127.0.0.1:$port"
try {
    & "C:\tools\mysql\current\bin\mysql.exe" -h 127.0.0.1 -P $port -u root -p$password -e "SELECT VERSION();"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Failed to connect"
        exit 1
    }
} catch {
    Write-Host "❌ Exception during connection attempt: $_"
    exit 1
}

Write-Host "✅ MySQL is installed and configured successfully!"
