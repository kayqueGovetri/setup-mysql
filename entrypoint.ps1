$initSqlPath = "C:\tools\mysql\init.sql"
$myIniPath = "C:\tools\mysql\current\my.ini"

# Create the SQL file with commands
@"
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$rootPassword';
CREATE DATABASE IF NOT EXISTS \`$dbName\`;
CREATE USER IF NOT EXISTS '$user'@'%' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON \`$dbName\`.* TO '$user'@'%';
FLUSH PRIVILEGES;
"@ | Out-File -Encoding ASCII $initSqlPath

# Install MySQL via Chocolatey with custom port (example)
choco install mysql --params "/port:$port" -y

# Modify my.ini to use init-file
$content = Get-Content $myIniPath
if ($content -notmatch 'init-file=') {
    Add-Content $myIniPath "`ninit-file=$initSqlPath"
} else {
    $content = $content -replace 'init-file=.*', "init-file=$initSqlPath"
    $content | Set-Content $myIniPath
}

# Restart MySQL service to run init-file and apply settings
Restart-Service MySQL

# Optional: after start, remove the init-file line from my.ini to avoid repeated execution
Start-Sleep -Seconds 10
$content = Get-Content $myIniPath | Where-Object { $_ -notmatch 'init-file=' }
$content | Set-Content $myIniPath

Write-Host "✅ MySQL installed and configured with init-file for database and user creation."
