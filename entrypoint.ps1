New-Item -ItemType Directory -Force -Path C:\mysql-data

& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe" `
  --initialize-insecure `
  --datadir=C:\mysql-data

Start-Process `
  -FilePath "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe" `
  -ArgumentList `
  "--datadir=C:\mysql-data",
  "--port=32768",
  "--bind-address=0.0.0.0"

Start-Sleep 20

$mysql = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"

# --------------------------------
# ROOT SETUP (mantido igual)
# --------------------------------
& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'root';"

& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -proot `
  -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';"

& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -proot `
  -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"

& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -proot `
  -e "FLUSH PRIVILEGES;"

# --------------------------------
# DATABASE
# --------------------------------
& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -proot `
  -e "CREATE DATABASE IF NOT EXISTS my_db;"

# --------------------------------
# USER DINÂMICO (NOVO)
# --------------------------------

$user = $env:mysql_user
$userPassword = $env:mysql_password

if (-not $user) { $user = "dev" }
if (-not $userPassword) { $userPassword = "devpass" }

& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -proot `
  -e "
CREATE USER IF NOT EXISTS '$user'@'localhost' IDENTIFIED BY '$userPassword';
CREATE USER IF NOT EXISTS '$user'@'127.0.0.1' IDENTIFIED BY '$userPassword';
GRANT ALL PRIVILEGES ON my_db.* TO '$user'@'localhost';
GRANT ALL PRIVILEGES ON my_db.* TO '$user'@'127.0.0.1';
FLUSH PRIVILEGES;
"

# --------------------------------
# VERIFY
# --------------------------------
& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -proot `
  -e "SHOW DATABASES;"

& $mysql `
  --protocol=TCP `
  -h 127.0.0.1 `
  -P 32768 `
  -u root `
  -proot `
  -e "SELECT VERSION();"