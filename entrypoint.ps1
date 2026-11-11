
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

# MySQL 8.4 paths
$MYSQL_BIN = "C:\Program Files\MySQL\MySQL Server 8.4\bin"
$MYSQLD = Join-Path $MYSQL_BIN "mysqld.exe"
$MYSQL = Join-Path $MYSQL_BIN "mysql.exe"

# Initialize MySQL
New-Item -ItemType Directory -Force -Path C:\mysql-data

& $MYSQLD `
    --initialize-insecure `
    --datadir=C:\mysql-data

Start-Process `
    -FilePath $MYSQLD `
    -ArgumentList `
    "--datadir=C:\mysql-data",
    "--port=$MYSQL_PORT",
    "--bind-address=$MYSQL_HOST"

Start-Sleep 20

# --------------------------------
# ROOT SETUP
# --------------------------------

& $MYSQL `
    --protocol=TCP `
    -h $MYSQL_HOST `
    -P $MYSQL_PORT `
    -u root `
    -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"

& $MYSQL `
    --protocol=TCP `
    -h $MYSQL_HOST `
    -P $MYSQL_PORT `
    -u root `
    "-p$MYSQL_ROOT_PASSWORD" `
    -e "CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD';"

& $MYSQL `
    --protocol=TCP `
    -h $MYSQL_HOST `
    -P $MYSQL_PORT `
    -u root `
    "-p$MYSQL_ROOT_PASSWORD" `
    -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION;"

& $MYSQL `
    --protocol=TCP `
    -h $MYSQL_HOST `
    -P $MYSQL_PORT `
    -u root `
    "-p$MYSQL_ROOT_PASSWORD" `
    -e "FLUSH PRIVILEGES;"

# --------------------------------
# DATABASE
# --------------------------------

& $MYSQL `
    --protocol=TCP `
    -h $MYSQL_HOST `
    -P $MYSQL_PORT `
    -u root `
    "-p$MYSQL_ROOT_PASSWORD" `
    -e "CREATE DATABASE IF NOT EXISTS ``$MYSQL_DATABASE``;"

# --------------------------------
# USER
# --------------------------------

& $MYSQL `
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

& $MYSQL `
    --protocol=TCP `
    -h $MYSQL_HOST `
    -P $MYSQL_PORT `
    -u root `
    "-p$MYSQL_ROOT_PASSWORD" `
    -e "SHOW DATABASES;"

& $MYSQL `
    --protocol=TCP `
    -h $MYSQL_HOST `
    -P $MYSQL_PORT `
    -u root `
    "-p$MYSQL_ROOT_PASSWORD" `
    -e "SELECT VERSION();"
