
# Configuration
$MYSQL_HOST = "127.0.0.1"

$MYSQL_PORT = if ($env:mysql_port) {
    [int]$env:mysql_port
} else {
    32768
}

$MYSQL_ROOT_PASSWORD = if ($env:mysql_root_password) {
    $env:mysql_root_password
} else {
    "root"
}

$MYSQL_DATABASE = if ($env:mysql_database) {
    $env:mysql_database
} else {
    "my_db"
}

$MYSQL_USER = if ($env:mysql_user) {
    $env:mysql_user
} else {
    "dev"
}

$MYSQL_USER_PASSWORD = if ($env:mysql_password) {
    $env:mysql_password
} else {
    "devpass"
}

New-Item -ItemType Directory -Force -Path C:\mysql-data

& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe" `
  --initialize-insecure `
  --datadir=C:\mysql-data

Start-Process `
  -FilePath "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqld.exe" `
  -ArgumentList `
  "--datadir=C:\mysql-data",
  "--port=$MYSQL_PORT",
  "--bind-address=$MYSQL_HOST"

Start-Sleep 20

$mysql = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"

# --------------------------------
# ROOT SETUP
# --------------------------------

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  "-p$MYSQL_ROOT_PASSWORD" `
  -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  "-p$MYSQL_ROOT_PASSWORD" `
  -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  "-p$MYSQL_ROOT_PASSWORD" `
  -e "FLUSH PRIVILEGES;"

# --------------------------------
# DATABASE
# --------------------------------

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  "-p$MYSQL_ROOT_PASSWORD" `
  -e "CREATE DATABASE IF NOT EXISTS ``$MYSQL_DATABASE``;"

# --------------------------------
# USER
# --------------------------------

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  "-p$MYSQL_ROOT_PASSWORD" `
  -e "
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_USER_PASSWORD';
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'127.0.0.1' IDENTIFIED BY '$MYSQL_USER_PASSWORD';
GRANT ALL PRIVILEGES ON ``$MYSQL_DATABASE``.* TO '$MYSQL_USER'@'localhost';
GRANT ALL PRIVILEGES ON ``$MYSQL_DATABASE``.* TO '$MYSQL_USER'@'127.0.0.1';
FLUSH PRIVILEGES;
"

# --------------------------------
# VERIFY
# --------------------------------

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  "-p$MYSQL_ROOT_PASSWORD" `
  -e "SHOW DATABASES;"

& $mysql `
  --protocol=TCP `
  -h $MYSQL_HOST `
  -P $MYSQL_PORT `
  -u root `
  "-p$MYSQL_ROOT_PASSWORD" `
  -e "SELECT VERSION();"
