$port = $env:INPUT_MYSQL_PORT
if (-not $port) { $port = 32768 }

$password = $env:INPUT_MYSQL_ROOT_PASSWORD
if (-not $password) { $password = "root" }

Write-Host "### Installing MySQL via Chocolatey"
choco install mysql -y

Write-Host "⚠️ Ensure the MySQL service is running."
Start-Sleep -Seconds 20

Write-Host "### Attempting MySQL connection"
try {
    & mysql -h 127.0.0.1 -P $port -u root -p$password -e "SELECT VERSION();"
} catch {
    Write-Host "❌ Failed to connect"
}
