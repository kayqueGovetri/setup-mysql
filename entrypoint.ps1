# --------------------------------
# Input parameters from environment
# --------------------------------
$rootPassword = $env:mysql_root_password
$port = $env:mysql_port
$dbName = $env:mysql_database
$user = $env:mysql_user
$userPassword = $env:mysql_password

# --------------------------------
# Fallbacks for optional inputs
# --------------------------------
if (-not $rootPassword) { $rootPassword = "root" }
if (-not $port) { $port = 32768 }
if (-not $dbName) { $dbName = "my_db" }
if (-not $user) { $user = "dev" }
if (-not $userPassword) { $userPassword = "devpass" }

# --------------------------------
# Static configuration
# --------------------------------
$mysqlVersion = "mysql"
$serviceName = "mysql-ci"
$installLocation = "C:\tools\mysql"
$dataLocation = "$installLocation\data"
$initSqlPath = "$installLocation\init.sql"

# --------------------------------
# Install Chocolatey if needed
# --------------------------------
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}

# --------------------------------
# Install MySQL
# --------------------------------
choco install $mysqlVersion `
    --params "/installLocation:$installLocation /dataLocation:$dataLocation /port:$port /serviceName:$serviceName" `
    -y

# --------------------------------
# Wait for MySQL service to be available
# --------------------------------
Start-Sleep -Seconds 10

# --------------------------------
# Create initialization SQL
# --------------------------------
@"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$rootPassword';
CREATE DATABASE IF NOT EXISTS \`$dbName\`;
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';
FLUSH PRIVILEGES;
"@ | Out-File -Encoding ASCII -FilePath $initSqlPath

# --------------------------------
# Execute SQL file
# --------------------------------
$mysqlExe = "$installLocation\current\bin\mysql.exe"

# Wait for service to fully initialize
Start-Sleep -Seconds 10

& $mysqlExe --protocol=TCP -u root --password=$rootPassword -P $port --execute="source $initSqlPath"

# --------------------------------
# Cleanup
# --------------------------------
Remove-Item $initSqlPath -Force -ErrorAction SilentlyContinue

Write-Host "`n✅ MySQL installed and configured on port $port!"
